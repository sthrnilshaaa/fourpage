package com.fourpages.reader.nativereader.core

import android.util.Log
import com.fourpages.reader.nativereader.engine.layout.BlockLayout
import com.fourpages.reader.nativereader.engine.layout.LaidOutChapter
import com.fourpages.reader.nativereader.engine.layout.LayoutCache
import com.fourpages.reader.nativereader.engine.layout.LayoutParams
import com.fourpages.reader.nativereader.engine.parse.Chapter
import com.fourpages.reader.nativereader.engine.parse.CssRule
import com.fourpages.reader.nativereader.engine.parse.CssSubset
import com.fourpages.reader.nativereader.engine.parse.ImageBlock
import com.fourpages.reader.nativereader.engine.parse.StyleResolver
import com.fourpages.reader.nativereader.engine.parse.XhtmlParser
import com.fourpages.reader.nativereader.engine.render.ImageSource
import com.fourpages.reader.nativereader.publication.readBytes
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.jsoup.Jsoup
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.util.Url
import java.util.concurrent.ConcurrentHashMap

/**
 * Resource → blocks → pages for one book at one layout. The chapter being opened is laid out first,
 * then every other chapter nearest-first in the background.
 *
 * Page counts come from [LayoutCache] at open when this book was laid out with these params before,
 * so the exact [PageIndex] is ready immediately; each fresh layout then corrects the index (and the
 * cache) if it disagrees. Chapters that fail to load show empty, are never cached, and are retried.
 * Work runs in a supervisor child of [scope], so a failed chapter never cancels the caller.
 */
class ChapterPipeline(
    private val publication: Publication,
    private val params: LayoutParams,
    private val cache: LayoutCache,
    private val bookKey: String,
    scope: CoroutineScope,
    val images: ImageSource = PublicationImages(publication),
) {
    @OptIn(ExperimentalCoroutinesApi::class)
    private val layoutDispatcher = Dispatchers.Default.limitedParallelism(2)
    private val scope = CoroutineScope(scope.coroutineContext + SupervisorJob(scope.coroutineContext[Job]))
    private val layoutKey = params.key()
    private val blockLayout = BlockLayout(params, images::size)
    private val jobs = ConcurrentHashMap<Int, Deferred<LaidOutChapter>>()
    private val css = ConcurrentHashMap<String, List<CssRule>>()
    private val countsLock = Any()
    private val pageCounts = arrayOfNulls<Int>(publication.readingOrder.size) // guarded by countsLock
    private val _allLaidOut = MutableStateFlow<PageIndex?>(null)
    private var background: Job? = null

    val chapterCount: Int = publication.readingOrder.size

    /** The exact page index once every chapter's page count is known; re-emitted when a count changes. */
    val allLaidOut: StateFlow<PageIndex?> = _allLaidOut

    /** Chapters whose page count came from the disk cache on the last [openAt]. */
    var cacheHits: Int = 0
        private set

    suspend fun openAt(position: Position): Pair<LaidOutChapter, Int> {
        val current = position.resourceIndex.coerceIn(0, (chapterCount - 1).coerceAtLeast(0))
        val cached = withContext(Dispatchers.IO) { (0 until chapterCount).map { cache.read(bookKey, layoutKey, it)?.size } }
        synchronized(countsLock) {
            cacheHits = 0
            cached.forEachIndexed { i, n -> if (n != null && pageCounts[i] == null) { pageCounts[i] = n; cacheHits++ } }
        }
        publishIndex()
        val laid = ensure(current)
        background?.cancel()
        background = scope.launch { for (i in nearestFirst(current)) ensure(i) }
        return laid to laid.pages.pageAt(position.charOffset)
    }

    /** The laid-out chapter if it's ready (and didn't fail), without waiting. */
    fun chapter(resourceIndex: Int): LaidOutChapter? = jobs[resourceIndex]
        ?.takeIf { it.isCompleted && !it.isCancelled && it.getCompletionExceptionOrNull() == null }
        ?.getCompleted()
        ?.takeIf { !it.failed }

    suspend fun ensure(resourceIndex: Int): LaidOutChapter {
        val job = jobs.computeIfAbsent(resourceIndex) { scope.async(layoutDispatcher) { layout(resourceIndex) } }
        val result = try {
            job.await()
        } catch (e: CancellationException) {
            jobs.remove(resourceIndex, job)
            throw e
        }
        if (result.failed) jobs.remove(resourceIndex, job) // shown empty now, retried next time
        return result
    }

    private fun nearestFirst(from: Int): List<Int> = buildList {
        for (d in 1 until chapterCount) {
            if (from + d < chapterCount) add(from + d)
            if (from - d >= 0) add(from - d)
        }
    }

    private suspend fun layout(i: Int): LaidOutChapter {
        val chapter = try {
            load(i).also { c -> images.measure(c.blocks.filterIsInstance<ImageBlock>().map { it.href }) }
        } catch (e: CancellationException) {
            throw e
        } catch (e: Exception) {
            Log.w(TAG, "chapter $i failed to load; showing it empty", e)
            val empty = Chapter(i, publication.readingOrder[i].href.toString(), emptyList(), 0)
            val laid = blockLayout.layoutChapter(empty)
            return LaidOutChapter(empty, laid.lines, laid.pages, failed = true)
        }
        val laid = blockLayout.layoutChapter(chapter)
        val starts = IntArray(laid.pages.size) { laid.pages[it].charStart }
        val changed = synchronized(countsLock) {
            (pageCounts[i] != starts.size).also { pageCounts[i] = starts.size }
        }
        if (changed) {
            cache.write(bookKey, layoutKey, i, starts)
            publishIndex()
        }
        return laid
    }

    private suspend fun load(i: Int): Chapter {
        val link = publication.readingOrder[i]
        val url = link.url()
        if (link.mediaType?.isHtml != true) {
            // A spine item that is itself an image (comics-style covers): one image block.
            return Chapter(i, url.toString(), listOf(ImageBlock(url.toString(), "", 0, 1)), 1)
        }
        val bytes = publication.readBytes(url) ?: error("missing resource $url")
        val doc = Jsoup.parse(bytes.decodeToString())
        val rules = mutableListOf<CssRule>()
        for (el in doc.select("link[rel~=(?i)stylesheet], style")) {
            rules += if (el.normalName() == "style") {
                CssSubset.parse(el.data(), rules.size)
            } else {
                val href = Url(el.attr("href"))?.let { url.resolve(it) }?.toString() ?: continue
                css[href] ?: run {
                    val text = Url(href)?.let { publication.readBytes(it) }?.decodeToString()
                    CssSubset.parse(text.orEmpty()).also { css[href] = it }
                }.map { it.copy(order = it.order + rules.size) }
            }
        }
        val resolver = StyleResolver(rules, params.publisherStyles)
        val parsed = XhtmlParser.parse(doc, i, url.toString(), resolver::of)
        return parsed.copy(blocks = parsed.blocks.map { b ->
            if (b is ImageBlock) b.copy(href = Url(b.href)?.let { url.resolve(it) }?.toString() ?: b.href) else b
        })
    }

    /** Publishes the index when every count is known, and again whenever a count changes. */
    private fun publishIndex() {
        synchronized(countsLock) {
            if (pageCounts.any { it == null }) return
            val counts = IntArray(pageCounts.size) { pageCounts[it]!! }
            if (_allLaidOut.value?.counts?.contentEquals(counts) != true) _allLaidOut.value = PageIndex(counts)
        }
    }

    private companion object {
        const val TAG = "ChapterPipeline"
    }
}
