package com.fourpages.reader

import android.content.Context
import com.fourpages.reader.nativereader.core.Highlight
import com.fourpages.reader.nativereader.core.PageRef
import com.fourpages.reader.nativereader.core.ReaderSession
import com.fourpages.reader.nativereader.core.RenderPrefs
import com.fourpages.reader.nativereader.core.StartPosition
import com.fourpages.reader.nativereader.core.TextSelection
import com.fourpages.reader.nativereader.core.TocEntry
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.launch
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlinx.coroutines.withContext
import java.io.File

/**
 * Flutter ↔ native PageEngine (channel "fourpages/native_reader"). The Flutter reader screen keeps
 * all UI, gestures and saving; this answers engine questions (pages, positions, text) and pushes
 * "pageIndex" when the exact page count is known or changes. Page refs are {r: chapter, p: page}.
 */
class NativeReaderChannel(private val context: Context, messenger: BinaryMessenger) {
    private val channel = MethodChannel(messenger, "fourpages/native_reader")
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
    private val sessions = java.util.concurrent.ConcurrentHashMap<Int, ReaderSession>()
    private val watchers = java.util.concurrent.ConcurrentHashMap<Int, Job>()
    private val highlights = java.util.concurrent.ConcurrentHashMap<Int, List<Highlight>>()
    private val locks = java.util.concurrent.ConcurrentHashMap<Int, Mutex>()
    private var nextId = 1

    init {
        channel.setMethodCallHandler { call, result ->
            scope.launch {
                try {
                    // Engine work off the main thread; one call at a time per book, so a settings
                    // change never interleaves with a render on the old layout.
                    val value = withContext(Dispatchers.Default) {
                        val id = (call.argument<Any>("sessionId") as? Number)?.toInt()
                        val lock = id?.let { locks.getOrPut(it) { Mutex() } }
                        if (lock == null || call.method == "close") handle(call) else lock.withLock { handle(call) }
                    }
                    result.success(value)
                } catch (e: Exception) {
                    result.error("native_reader", e.message ?: e.toString(), null)
                }
            }
        }
    }

    private suspend fun handle(call: MethodCall): Any? {
        if (call.method == "open") return open(call)
        val id = call.int("sessionId")
        val s = sessions[id] ?: throw IllegalStateException("session $id is closed")
        val hl = highlights[id].orEmpty()
        return when (call.method) {
            "close" -> {
                watchers.remove(id)?.cancel(); highlights.remove(id); locks.remove(id); sessions.remove(id)?.close(); null
            }
            "step" -> s.step(call.ref(), call.int("dir"))?.toMap()
            "locate" -> s.locate(call.int("globalPage")).toMap()
            "atProgression" -> s.atProgression(call.double("t")).toMap()
            "atHref" -> s.atHref(call.argument<String>("href")!!).toMap()
            "at" -> s.at(call.int("r"), call.int("offset")).toMap()
            "locator" -> s.locator(call.ref()).let {
                mapOf(
                    "href" to it.href, "r" to it.resourceIndex, "charOffset" to it.charOffset,
                    "progression" to it.progression, "totalProgression" to it.totalProgression,
                    "globalPage" to it.globalPage, "pagesLeft" to it.pagesLeft,
                    "textBefore" to it.textBefore, "textAfter" to it.textAfter, "cfi" to it.cfi,
                )
            }
            "chapterInfo" -> s.chapterInfo(call.ref()).mapValues { (_, v) -> v?.let { mapOf("title" to it.first, "href" to it.second) } }
            "render" -> s.render(call.ref(), call.double("scale").toFloat(), hl).let {
                mapOf("width" to it.width, "height" to it.height, "rgba" to it.rgba)
            }
            "tiles" -> s.tiles(call.int("r"))
            "renderTile" -> s.renderTile(call.int("r"), call.int("tile"), hl).let {
                mapOf("width" to it.width, "height" to it.height, "rgba" to it.rgba)
            }
            "setPrefs" -> if (call.argument<Any>("r") != null) {
                s.setPrefsAt(call.prefs(), call.int("width"), call.int("height"), call.int("r"), call.int("offset")).toMap() + ("index" to indexMap(s))
            } else {
                s.setPrefs(call.prefs(), call.int("width"), call.int("height"), call.ref()).toMap() + ("index" to indexMap(s))
            }
            "search" -> s.search(call.argument<String>("query")!!).map {
                mapOf("r" to it.resourceIndex, "start" to it.start, "end" to it.end, "snippet" to it.snippet, "href" to it.href)
            }
            "resolveLegacy" -> s.resolveLegacy(
                call.argument<String>("cfi"), call.argument<String>("quote"), (call.argument<Any>("progression") as? Number)?.toDouble(),
            )?.let { (r, range) -> mapOf("r" to r, "start" to range.first, "end" to range.last + 1) }
            "wordAt" -> s.wordAt(call.ref(), call.double("x").toFloat(), call.double("y").toFloat())?.toMap(s)
            "rangeBetween" -> s.rangeBetween(
                call.ref(), call.double("x1").toFloat(), call.double("y1").toFloat(),
                call.double("x2").toFloat(), call.double("y2").toFloat(),
            )?.toMap(s)
            "cfiRange" -> s.cfiRangeAt(call.int("r"), call.int("start"), call.int("end"))
            "chapterHref" -> s.chapterHref(call.int("r"))
            "highlightAt" -> s.highlightAt(call.ref(), call.double("x").toFloat(), call.double("y").toFloat(), hl)
            "setHighlights" -> {
                highlights[id] = call.argument<List<Map<String, Any?>>>("highlights").orEmpty().mapNotNull {
                    val r = (it["r"] as Number?)?.toInt() ?: (it["href"] as String?)?.let { h -> s.hrefIndex(h) } ?: return@mapNotNull null
                    Highlight(
                        it["id"] as String, r, (it["start"] as Number).toInt(),
                        (it["end"] as Number).toInt(), (it["color"] as Number).toInt(),
                    )
                }
                null
            }
            else -> throw IllegalArgumentException("unknown method ${call.method}")
        }
    }

    private suspend fun open(call: MethodCall): Map<String, Any?> {
        val session = ReaderSession(
            context, File(call.argument<String>("path")!!), File(context.filesDir, "native_reader"),
            call.prefs(), call.int("width"), call.int("height"),
        )
        val start = call.argument<Map<String, Any?>>("start").orEmpty()
        val startPos = when {
            start["cfi"] != null -> StartPosition.Legacy(start["cfi"] as String)
            start["href"] != null && start["offset"] != null ->
                StartPosition.HrefChars(start["href"] as String, (start["offset"] as Number).toInt())
            start["r"] != null -> StartPosition.Chars((start["r"] as Number).toInt(), (start["offset"] as? Number)?.toInt() ?: 0)
            start["href"] != null -> StartPosition.Href(start["href"] as String)
            start["progression"] != null -> StartPosition.Progression((start["progression"] as Number).toDouble())
            else -> StartPosition.Beginning
        }
        val first = session.open(startPos)
        val id = nextId++
        sessions[id] = session
        watchers[id] = scope.launch {
            session.pageIndex.collect { index ->
                if (index != null) {
                    channel.invokeMethod("pageIndex", mapOf("sessionId" to id, "total" to index.totalPages, "counts" to index.counts.toList()))
                }
            }
        }
        return mapOf(
            "sessionId" to id, "page" to first.toMap(), "chapterCount" to session.chapterCount,
            "toc" to session.toc.map { it.toMap() }, "index" to indexMap(session),
            "renderer" to session.rendererDecision.renderer, "rendererReason" to session.rendererDecision.reason,
        )
    }

    private fun PageRef.toMap() = mapOf("r" to resourceIndex, "p" to page)

    /** The exact page index if already known (e.g. from the layout cache), else null. Sent in replies
     *  too, because a "pageIndex" push made during the call can reach Dart before it listens. */
    private fun indexMap(s: ReaderSession) = s.pageIndex.value?.let { mapOf("total" to it.totalPages, "counts" to it.counts.toList()) }
    private fun TocEntry.toMap(): Map<String, Any> = mapOf("title" to title, "href" to href, "children" to children.map { it.toMap() })
    private fun TextSelection.toMap(s: ReaderSession) = mapOf(
        "r" to resourceIndex, "start" to start, "end" to end, "text" to text, "href" to s.chapterHref(resourceIndex),
        "rects" to rects.flatMap { listOf(it.left.toDouble(), it.top.toDouble(), it.right.toDouble(), it.bottom.toDouble()) },
    )

    private fun MethodCall.int(key: String) = (argument<Any>(key) as Number).toInt()
    private fun MethodCall.double(key: String) = (argument<Any>(key) as Number).toDouble()
    private fun MethodCall.ref(): PageRef {
        val m = argument<Map<String, Any>>("ref")!!
        return PageRef((m["r"] as Number).toInt(), (m["p"] as Number).toInt())
    }
    private fun MethodCall.prefs(): RenderPrefs {
        val m = argument<Map<String, Any?>>("prefs")!!
        return RenderPrefs(
            fontPath = m["fontPath"] as String?,
            fontKey = m["fontKey"] as String,
            fontSizeSp = (m["fontSize"] as Number).toFloat(),
            lineHeight = (m["lineHeight"] as Number).toFloat(),
            textAlign = m["textAlign"] as String,
            publisherStyles = m["publisherStyles"] as Boolean,
            pageColor = (m["pageColor"] as Number).toInt(),
            textColor = (m["textColor"] as Number).toInt(),
            paddingDp = (m["padding"] as Number).toFloat(),
        )
    }
}
