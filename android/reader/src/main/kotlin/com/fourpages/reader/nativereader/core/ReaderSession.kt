package com.fourpages.reader.nativereader.core

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.RectF
import android.text.StaticLayout
import com.fourpages.reader.nativereader.engine.layout.BlockLayout
import com.fourpages.reader.nativereader.engine.layout.LaidOutChapter
import com.fourpages.reader.nativereader.engine.layout.LayoutCache
import com.fourpages.reader.nativereader.engine.layout.LayoutParams
import com.fourpages.reader.nativereader.engine.layout.Page
import com.fourpages.reader.nativereader.engine.parse.Chapter
import com.fourpages.reader.nativereader.engine.parse.ImageBlock
import com.fourpages.reader.nativereader.engine.parse.TextBlock
import com.fourpages.reader.nativereader.engine.render.PageRenderer
import com.fourpages.reader.nativereader.publication.BookOpener
import com.fourpages.reader.nativereader.publication.readBytes
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import org.readium.r2.shared.publication.Link
import org.readium.r2.shared.publication.Publication
import java.io.File
import java.nio.ByteBuffer
import java.text.BreakIterator

data class PageRef(val resourceIndex: Int, val page: Int)

sealed interface StartPosition {
    data object Beginning : StartPosition
    data class Chars(val resourceIndex: Int, val charOffset: Int) : StartPosition
    data class Progression(val total: Double) : StartPosition
    data class Href(val href: String) : StartPosition
    /** A chapter given by href plus a char offset in it (saved native locators). */
    data class HrefChars(val href: String, val charOffset: Int) : StartPosition
    /** An epub.js CFI saved by the old reader. */
    data class Legacy(val cfi: String) : StartPosition
}

data class NativeLocator(
    val href: String,
    val resourceIndex: Int,
    val charOffset: Int,
    val progression: Double,
    val totalProgression: Double,
    val globalPage: Int?,
    val pagesLeft: Int?,
    val textBefore: String,
    val textAfter: String,
    /** The same place as an epub.js CFI (for the original-layout reader), or null. */
    val cfi: String? = null,
)

data class TocEntry(val title: String, val href: String, val level: Int, val children: List<TocEntry>)
data class SearchHit(val resourceIndex: Int, val start: Int, val end: Int, val snippet: String, val href: String)
data class TextSelection(val resourceIndex: Int, val start: Int, val end: Int, val text: String, val rects: List<RectF>)
class RenderedPage(val width: Int, val height: Int, val rgba: ByteArray)

/**
 * One open book for the Flutter reader screen: navigation, page images, locators, selection,
 * search and old-position migration on top of [ChapterPipeline]. Coordinates are page pixels.
 */
class ReaderSession(
    private val context: Context,
    private val file: File,
    private val cacheDir: File,
    prefs: RenderPrefs,
    widthPx: Int,
    heightPx: Int,
) {
    private val opener = BookOpener(context, File(cacheDir, "manifests"))
    private val dm = context.resources.displayMetrics
    private var scope = newScope()
    private lateinit var publication: Publication
    private lateinit var bookKey: String
    private lateinit var pipeline: ChapterPipeline
    private var params: LayoutParams = prefs.toLayoutParams(widthPx, heightPx, dm.density, dm.scaledDensity)
    private var geometry = BlockLayout(params) { null }
    private var renderer = PageRenderer(params) { null }
    private val _pageIndex = MutableStateFlow<PageIndex?>(null)
    private var titles: Map<Int, String> = emptyMap()

    val pageIndex: StateFlow<PageIndex?> = _pageIndex
    var toc: List<TocEntry> = emptyList()
        private set
    val chapterCount: Int get() = publication.readingOrder.size
    val widthPx: Int get() = params.widthPx
    val heightPx: Int get() = params.heightPx

    private fun newScope() = CoroutineScope(SupervisorJob() + Dispatchers.Default)

    /** Which renderer this book should use (decided at open). */
    var rendererDecision: RendererDecision = RendererDecision(RendererDecision.NATIVE, "")
        private set

    /** Opens the publication only and decides the renderer (no layout). */
    suspend fun probe(): RendererDecision {
        if (!::publication.isInitialized) publication = opener.open(file)
        rendererDecision = RendererPolicy.decide(publication)
        return rendererDecision
    }

    suspend fun open(start: StartPosition): PageRef {
        publication = opener.open(file)
        rendererDecision = runCatching { RendererPolicy.decide(publication) }.getOrDefault(rendererDecision)
        bookKey = BookOpener.bookKey(file, publication)
        toc = publication.tableOfContents.map { it.toEntry(0) }
        titles = buildTitles()
        startPipeline()
        return resolve(start)
    }

    private fun startPipeline() {
        pipeline = ChapterPipeline(publication, params, LayoutCache(File(cacheDir, "layout")), bookKey, scope)
        geometry = BlockLayout(params, pipeline.images::size)
        renderer = PageRenderer(params, pipeline.images::size, pipeline.images::bitmap)
        val p = pipeline
        scope.launch { p.allLaidOut.collect { _pageIndex.value = it } }
    }

    private suspend fun resolve(start: StartPosition): PageRef = when (start) {
        StartPosition.Beginning -> openAt(0, 0)
        is StartPosition.Chars -> openAt(start.resourceIndex, start.charOffset)
        is StartPosition.Href -> openAt(hrefIndex(start.href) ?: 0, 0).let { atHref(start.href) }
        is StartPosition.Progression -> {
            openAt(0, 0)
            atProgression(start.total)
        }
        is StartPosition.HrefChars -> openAt(hrefIndex(start.href) ?: 0, start.charOffset)
        is StartPosition.Legacy -> {
            val ri = legacyChapter(start.cfi) ?: 0
            openAt(ri, 0)
            resolveLegacy(start.cfi, null, null)?.let { (r, range) -> at(r, range.first) } ?: PageRef(ri, 0)
        }
    }

    private suspend fun openAt(resourceIndex: Int, charOffset: Int): PageRef {
        val ri = resourceIndex.coerceIn(0, (chapterCount - 1).coerceAtLeast(0))
        val (laid, page) = pipeline.openAt(Position(ri, charOffset))
        return PageRef(laid.chapter.resourceIndex, page)
    }

    suspend fun close() {
        scope.cancel()
    }

    // --- navigation -----------------------------------------------------------------------------

    suspend fun step(ref: PageRef, dir: Int): PageRef? {
        val laid = pipeline.ensure(ref.resourceIndex)
        val p = ref.page + dir
        return when {
            p in laid.pages.indices -> PageRef(ref.resourceIndex, p)
            dir > 0 && ref.resourceIndex + 1 < chapterCount -> PageRef(ref.resourceIndex + 1, 0)
            dir < 0 && ref.resourceIndex > 0 ->
                PageRef(ref.resourceIndex - 1, pipeline.ensure(ref.resourceIndex - 1).pages.lastIndex)
            else -> null
        }
    }

    suspend fun locate(globalPage: Int): PageRef {
        val index = _pageIndex.filterNotNull().first()
        val (ri, p) = index.locate(globalPage)
        return PageRef(ri, p.coerceIn(pipeline.ensure(ri).pages.indices))
    }

    suspend fun atProgression(total: Double): PageRef {
        val index = _pageIndex.filterNotNull().first()
        return locate(Math.round(total.coerceIn(0.0, 1.0) * (index.totalPages - 1)).toInt())
    }

    suspend fun at(resourceIndex: Int, charOffset: Int): PageRef {
        val ri = resourceIndex.coerceIn(0, chapterCount - 1)
        return PageRef(ri, pipeline.ensure(ri).pages.pageAt(charOffset))
    }

    suspend fun atHref(href: String): PageRef {
        val ri = hrefIndex(href) ?: return at(0, 0)
        val fragment = href.substringAfter('#', "")
        if (fragment.isEmpty()) return PageRef(ri, 0)
        // "#aread:<offset>": an exact char offset (saved notes/highlights).
        fragment.removePrefix("aread:").takeIf { it != fragment }?.toIntOrNull()?.let { return at(ri, it) }
        val chapter = pipeline.ensure(ri).chapter
        val block = chapter.blocks.firstOrNull { fragment in it.anchors } ?: return PageRef(ri, 0)
        return at(ri, block.charStart)
    }

    /** Index of the spine item [href] points into (fragment and leading "/" ignored). */
    fun hrefIndex(href: String): Int? {
        val path = href.substringBefore('#').trimStart('/')
        if (path.isEmpty()) return null
        return publication.readingOrder.indexOfFirst { it.href.toString().substringBefore('#').trimStart('/') == path }
            .takeIf { it >= 0 }
            ?: publication.readingOrder.indexOfFirst { it.href.toString().substringBefore('#').trimStart('/').endsWith(path) }
                .takeIf { it >= 0 }
    }

    suspend fun locator(ref: PageRef): NativeLocator {
        val laid = pipeline.ensure(ref.resourceIndex)
        val page = laid.pages[ref.page.coerceIn(laid.pages.indices)]
        val length = laid.chapter.length.coerceAtLeast(1)
        val index = _pageIndex.value
        val global = index?.globalPage(ref.resourceIndex, ref.page)
        val progression = page.charStart.toDouble() / length
        val total = if (index != null && global != null) {
            global.toDouble() / (index.totalPages - 1).coerceAtLeast(1)
        } else {
            (ref.resourceIndex + progression) / chapterCount.coerceAtLeast(1)
        }
        val text = laid.chapter.text()
        return NativeLocator(
            href = publication.readingOrder[ref.resourceIndex].href.toString(),
            resourceIndex = ref.resourceIndex,
            charOffset = page.charStart,
            progression = progression,
            totalProgression = total.coerceIn(0.0, 1.0),
            globalPage = global,
            pagesLeft = global?.let { index.pagesLeftInBook(it) },
            textBefore = text.substring((page.charStart - 60).coerceAtLeast(0), page.charStart.coerceAtMost(text.length)),
            textAfter = text.substring(page.charStart.coerceAtMost(text.length), (page.charStart + 60).coerceAtMost(text.length)),
            cfi = runCatching { cfiAt(ref.resourceIndex, page.charStart) }.getOrNull(),
        )
    }

    // --- CFIs for the original-layout (epub.js) reader -------------------------------------------

    private var docCache: Pair<Int, org.jsoup.nodes.Document>? = null

    private suspend fun chapterDoc(ri: Int): org.jsoup.nodes.Document? {
        docCache?.let { (i, d) -> if (i == ri) return d }
        val bytes = publication.readBytes(publication.readingOrder[ri].url()) ?: return null
        return org.jsoup.Jsoup.parse(bytes.decodeToString()).also { docCache = ri to it }
    }

    /** `/6/<n>` step of a chapter: its position in the OPF spine (epub.js counts every itemref). */
    private suspend fun spineStep(ri: Int): Int {
        val spine = spineHrefs ?: loadSpineHrefs().also { spineHrefs = it }
        val i = spine.indexOfFirst { hrefIndex(it) == ri }
        return ((if (i >= 0) i else ri) + 1) * 2
    }

    /** Visible (non-whitespace) characters before [offset] in our chapter text. */
    private suspend fun visibleBefore(ri: Int, offset: Int): Int {
        val text = pipeline.ensure(ri).chapter.text()
        var n = 0
        for (i in 0 until offset.coerceAtMost(text.length)) {
            val c = text[i]
            if (!c.isWhitespace() && c != '\uFFFC' && c != '•') n++
        }
        return n
    }

    suspend fun cfiAt(ri: Int, offset: Int): String? {
        val doc = chapterDoc(ri) ?: return null
        return LegacyCfi.cfiFor(doc, spineStep(ri), visibleBefore(ri, offset))
    }

    suspend fun cfiRangeAt(ri: Int, start: Int, end: Int): String? {
        val doc = chapterDoc(ri) ?: return null
        return LegacyCfi.cfiRange(doc, spineStep(ri), visibleBefore(ri, start), visibleBefore(ri, end))
    }

    /** prev/current/next chapter (title, href); null where there's none. */
    suspend fun chapterInfo(ref: PageRef): Map<String, Pair<String, String>?> {
        fun entry(i: Int?) = i?.let { titles[it]?.let { t -> t to publication.readingOrder[it].href.toString() } }
        val current = titles.keys.filter { it <= ref.resourceIndex }.maxOrNull()
        val prev = titles.keys.filter { it < (current ?: ref.resourceIndex) }.maxOrNull()
        val next = titles.keys.filter { it > ref.resourceIndex }.minOrNull()
        return mapOf("prev" to entry(prev), "current" to entry(current), "next" to entry(next))
    }

    private fun buildTitles(): Map<Int, String> {
        val out = sortedMapOf<Int, String>()
        fun walk(entries: List<TocEntry>) {
            for (e in entries) {
                hrefIndex(e.href)?.let { i -> if (i !in out && e.title.isNotBlank()) out[i] = e.title.trim() }
                walk(e.children)
            }
        }
        walk(toc)
        return out
    }

    private fun Link.toEntry(level: Int): TocEntry =
        TocEntry(title ?: "", href.toString(), level, children.map { it.toEntry(level + 1) })

    // --- drawing --------------------------------------------------------------------------------

    suspend fun render(ref: PageRef, scale: Float, highlights: List<Highlight>): RenderedPage {
        val laid = pipeline.ensure(ref.resourceIndex)
        val page = laid.pages[ref.page.coerceIn(laid.pages.indices)]
        val layouts = layoutsFor(laid, page)
        val w = (params.widthPx * scale).toInt().coerceAtLeast(1)
        val h = (params.heightPx * scale).toInt().coerceAtLeast(1)
        return withContext(Dispatchers.Default) {
            val bmp = Bitmap.createBitmap(w, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            canvas.scale(scale, scale)
            renderer.draw(canvas, laid, page, layouts, highlights)
            bmp.toRendered()
        }
    }

    /** Scrolled mode: per page of the chapter, the height of its slice (content only, gaps kept). */
    suspend fun tiles(resourceIndex: Int): List<Int> {
        val laid = pipeline.ensure(resourceIndex)
        return laid.pages.mapIndexed { i, page -> tileHeight(laid, i, page) }
    }

    private fun tileHeight(laid: LaidOutChapter, i: Int, page: Page): Int {
        if (page.lastLine < page.firstLine) return params.heightPx / 4
        val top = laid.lines[page.firstLine].top
        val next = laid.pages.getOrNull(i + 1)?.takeIf { it.lastLine >= it.firstLine }
        val bottom = next?.let { laid.lines[it.firstLine].top } ?: laid.lines[page.lastLine].bottom
        return (bottom - top).coerceAtLeast(1)
    }

    suspend fun renderTile(resourceIndex: Int, tile: Int, highlights: List<Highlight>): RenderedPage {
        val laid = pipeline.ensure(resourceIndex)
        val page = laid.pages[tile.coerceIn(laid.pages.indices)]
        val h = tileHeight(laid, tile, page)
        val layouts = layoutsFor(laid, page)
        return withContext(Dispatchers.Default) {
            val bmp = Bitmap.createBitmap(params.widthPx, h, Bitmap.Config.ARGB_8888)
            val canvas = Canvas(bmp)
            canvas.translate(0f, -params.paddingPx.toFloat())
            renderer.draw(canvas, laid, page, layouts, highlights)
            bmp.toRendered()
        }
    }

    private suspend fun layoutsFor(laid: LaidOutChapter, page: Page): Map<Int, StaticLayout> {
        if (page.lastLine < page.firstLine) return emptyMap()
        val blocks = blockRange(laid, page)
        pipeline.images.prepare(blocks.mapNotNull { (laid.chapter.blocks[it] as? ImageBlock)?.href })
        return geometry.layoutBlocks(laid.chapter, blocks)
    }

    private fun blockRange(laid: LaidOutChapter, page: Page) =
        laid.lines[page.firstLine].blockIndex..laid.lines[page.lastLine].blockIndex

    private fun Bitmap.toRendered(): RenderedPage {
        val buf = ByteBuffer.allocate(byteCount)
        copyPixelsToBuffer(buf)
        val out = RenderedPage(width, height, buf.array())
        recycle()
        return out
    }

    // --- settings -------------------------------------------------------------------------------

    /** New settings or viewport: lays out again and returns the page holding [keep]'s first character. */
    suspend fun setPrefs(prefs: RenderPrefs, widthPx: Int, heightPx: Int, keep: PageRef): PageRef {
        val laid = pipeline.ensure(keep.resourceIndex)
        val offset = laid.pages[keep.page.coerceIn(laid.pages.indices)].charStart
        return setPrefsAt(prefs, widthPx, heightPx, keep.resourceIndex, offset)
    }

    /** Same, keeping an exact (chapter, char offset): safe across several relayouts in a row. */
    suspend fun setPrefsAt(prefs: RenderPrefs, widthPx: Int, heightPx: Int, resourceIndex: Int, offset: Int): PageRef {
        val keepIndex = resourceIndex.coerceIn(0, chapterCount - 1)
        scope.cancel()
        scope = newScope()
        params = prefs.toLayoutParams(widthPx, heightPx, dm.density, dm.scaledDensity)
        _pageIndex.value = null
        startPipeline()
        return openAt(keepIndex, offset)
    }

    fun chapterHref(resourceIndex: Int): String = publication.readingOrder[resourceIndex].href.toString()

    // --- search & migration ---------------------------------------------------------------------

    suspend fun search(query: String, limit: Int = 200): List<SearchHit> {
        val q = query.trim()
        if (q.isEmpty()) return emptyList()
        val hits = mutableListOf<SearchHit>()
        for (ri in 0 until chapterCount) {
            val chapter = pipeline.ensure(ri).chapter
            for (block in chapter.blocks) {
                if (block !is TextBlock) continue
                var i = block.text.indexOf(q, ignoreCase = true)
                while (i >= 0) {
                    val a = (i - 40).coerceAtLeast(0)
                    val b = (i + q.length + 40).coerceAtMost(block.text.length)
                    hits += SearchHit(
                        ri, block.charStart + i, block.charStart + i + q.length,
                        block.text.substring(a, b).replace('\n', ' '),
                        publication.readingOrder[ri].href.toString(),
                    )
                    if (hits.size >= limit) return hits
                    i = block.text.indexOf(q, i + q.length, ignoreCase = true)
                }
            }
        }
        return hits
    }

    /**
     * Where an old epub.js position or highlight lands: the spine item from the CFI, then the
     * quoted text nearest to [progression] in that chapter (or just the progression).
     */
    suspend fun resolveLegacy(cfi: String?, quote: String?, progression: Double?): Pair<Int, IntRange>? {
        val ri = legacyChapter(cfi) ?: return null
        val chapter = pipeline.ensure(ri).chapter
        val fromPath = cfiOffset(ri, cfi!!, chapter)
        val target = fromPath ?: ((progression ?: 0.0).coerceIn(0.0, 1.0) * chapter.length).toInt()
        val q = quote?.replace(Regex("\\s+"), " ")?.trim().orEmpty()
        if (q.isNotEmpty()) {
            val found = findNearest(chapter, q, target) ?: findNearest(chapter, q.take(30), target)?.let {
                it.first until (it.first + q.length).coerceAtMost(chapter.length)
            }
            return found?.let { ri to it }
        }
        return ri to (target until target)
    }

    private var spineHrefs: List<String>? = null

    /**
     * The chapter an epub.js CFI points at. epub.js counts every spine itemref (also linear="no"
     * ones that Readium leaves out of the reading order), so the step goes through the OPF spine.
     */
    private suspend fun legacyChapter(cfi: String?): Int? {
        val step = LegacyCfi.spineIndex(cfi) ?: return null
        val spine = spineHrefs ?: loadSpineHrefs().also { spineHrefs = it }
        spine.getOrNull(step)?.let { href -> hrefIndex(href)?.let { return it } }
        return step.takeIf { it in 0 until chapterCount }
    }

    /** Every spine itemref's href (publication-relative), in OPF order; empty if unreadable. */
    private suspend fun loadSpineHrefs(): List<String> = try {
        val container = publication.readBytes(org.readium.r2.shared.util.Url("META-INF/container.xml")!!)?.decodeToString().orEmpty()
        val opfPath = Regex("full-path=\"([^\"]+)\"").find(container)?.groupValues?.get(1) ?: ""
        val opf = publication.readBytes(org.readium.r2.shared.util.Url(opfPath)!!)?.decodeToString().orEmpty()
        val doc = org.jsoup.Jsoup.parse(opf, "", org.jsoup.parser.Parser.xmlParser())
        val base = opfPath.substringBeforeLast('/', "").let { if (it.isEmpty()) "" else "$it/" }
        val items = doc.select("manifest > item").associate { it.attr("id") to it.attr("href") }
        doc.select("spine > itemref").mapNotNull { items[it.attr("idref")]?.let { h -> base + h } }
    } catch (e: Exception) {
        emptyList()
    }

    /** Chapter offset of a CFI's in-document path (visible characters before it), or null. */
    private suspend fun cfiOffset(ri: Int, cfi: String, chapter: Chapter): Int? {
        val bytes = publication.readBytes(publication.readingOrder[ri].url()) ?: return null
        val doc = org.jsoup.Jsoup.parse(bytes.decodeToString())
        val count = LegacyCfi.visibleCharsBefore(doc, cfi) ?: return null
        // Walk our chapter text to the same number of visible characters.
        val text = chapter.text()
        var seen = 0
        for (i in text.indices) {
            val c = text[i]
            if (c.isWhitespace() || c == '\uFFFC' || c == '•') continue
            if (seen == count) return i
            seen++
        }
        return text.length
    }

    private fun findNearest(chapter: Chapter, q: String, target: Int): IntRange? {
        var best: IntRange? = null
        for (block in chapter.blocks) {
            if (block !is TextBlock) continue
            val text = block.text.replace(Regex("\\s"), " ")
            var i = text.indexOf(q, ignoreCase = true)
            while (i >= 0) {
                val r = (block.charStart + i) until (block.charStart + i + q.length)
                if (best == null || kotlin.math.abs(r.first - target) < kotlin.math.abs(best.first - target)) best = r
                i = text.indexOf(q, i + 1, ignoreCase = true)
            }
        }
        return best
    }

    // --- selection ------------------------------------------------------------------------------

    suspend fun wordAt(ref: PageRef, x: Float, y: Float): TextSelection? {
        val hit = hitTest(ref, x, y, strict = true) ?: return null
        val block = hit.laid.chapter.blocks[hit.blockIndex] as TextBlock
        val it = BreakIterator.getWordInstance().apply { setText(block.text) }
        val local = (hit.offset - block.charStart).coerceIn(0, (block.text.length - 1).coerceAtLeast(0))
        var end = it.following(local)
        if (end == BreakIterator.DONE) end = block.text.length
        var start = it.previous()
        if (start == BreakIterator.DONE) start = 0
        if (end <= start || block.text.substring(start, end).isBlank()) return null
        return selection(ref, hit.laid, block.charStart + start, block.charStart + end)
    }

    suspend fun rangeBetween(ref: PageRef, x1: Float, y1: Float, x2: Float, y2: Float): TextSelection? {
        val a = hitTest(ref, x1, y1, strict = false) ?: return null
        val b = hitTest(ref, x2, y2, strict = false) ?: return null
        val start = minOf(a.offset, b.offset)
        val end = maxOf(a.offset, b.offset)
        if (end <= start) return null
        return selection(ref, a.laid, start, end)
    }

    suspend fun highlightAt(ref: PageRef, x: Float, y: Float, highlights: List<Highlight>): String? {
        val hit = hitTest(ref, x, y, strict = true) ?: return null
        return highlights.firstOrNull {
            it.resourceIndex == ref.resourceIndex && hit.offset >= it.start && hit.offset < it.end
        }?.id
    }

    private class Hit(val laid: LaidOutChapter, val blockIndex: Int, val offset: Int)

    /** Chapter offset under a page point. strict: null unless the point is on a text line. */
    private suspend fun hitTest(ref: PageRef, x: Float, y: Float, strict: Boolean): Hit? {
        val laid = pipeline.ensure(ref.resourceIndex)
        val page = laid.pages[ref.page.coerceIn(laid.pages.indices)]
        if (page.lastLine < page.firstLine) return null
        val pageTop = laid.lines[page.firstLine].top
        val cy = y - params.paddingPx + pageTop
        val range = page.firstLine..page.lastLine
        var li = range.firstOrNull { cy >= laid.lines[it].top && cy < laid.lines[it].bottom }
        if (li == null) {
            if (strict) return null
            li = range.minBy { minOf(kotlin.math.abs(cy - laid.lines[it].top), kotlin.math.abs(cy - laid.lines[it].bottom)) }
        }
        val line = laid.lines[li]
        val block = laid.chapter.blocks[line.blockIndex] as? TextBlock ?: return if (strict) null else Hit(laid, line.blockIndex, line.charStart)
        val sl = geometry.layoutBlocks(laid.chapter, line.blockIndex..line.blockIndex)[line.blockIndex] ?: return null
        val blockTop = laid.lines.first { it.blockIndex == line.blockIndex }.top
        val localY = (cy - blockTop).toInt()
        val localX = x - params.paddingPx - geometry.insetPx(block)
        val sline = sl.getLineForVertical(localY)
        if (strict && (localX < sl.getLineLeft(sline) || localX > sl.getLineRight(sline))) return null
        val off = sl.getOffsetForHorizontal(sline, localX)
        return Hit(laid, line.blockIndex, block.charStart + off)
    }

    private fun selection(ref: PageRef, laid: LaidOutChapter, start: Int, end: Int): TextSelection {
        val page = laid.pages[ref.page.coerceIn(laid.pages.indices)]
        val pageTop = laid.lines[page.firstLine].top
        val rects = mutableListOf<RectF>()
        for (bi in blockRange(laid, page)) {
            val block = laid.chapter.blocks[bi] as? TextBlock ?: continue
            val a = (start - block.charStart).coerceIn(0, block.text.length)
            val b = (end - block.charStart).coerceIn(0, block.text.length)
            if (b <= a) continue
            val sl = geometry.layoutBlocks(laid.chapter, bi..bi)[bi] ?: continue
            val blockTop = laid.lines.first { it.blockIndex == bi }.top
            val dx = (params.paddingPx + geometry.insetPx(block)).toFloat()
            for (l in 0 until sl.lineCount) {
                val ls = sl.getLineStart(l)
                val le = sl.getLineEnd(l)
                if (le <= a || ls >= b) continue
                val top = blockTop + sl.getLineTop(l)
                // Only lines on this page.
                if (top < pageTop || top >= laid.lines[page.lastLine].bottom) continue
                val left = sl.getPrimaryHorizontal(maxOf(a, ls))
                val right = if (b >= le) sl.getLineRight(l) else sl.getPrimaryHorizontal(b)
                val y0 = (top - pageTop + params.paddingPx).toFloat()
                val y1 = y0 + (sl.getLineBaseline(l) - sl.getLineTop(l)) + sl.paint.descent()
                rects += RectF(dx + left, y0, dx + right, y1)
            }
        }
        return TextSelection(ref.resourceIndex, start, end, laid.chapter.text().substring(start, end.coerceAtMost(laid.chapter.length)), rects)
    }
}

/** The chapter's text with one '\n' between blocks, so string offsets equal chapter offsets. */
fun Chapter.text(): String {
    val sb = StringBuilder(length)
    for (b in blocks) {
        while (sb.length < b.charStart) sb.append('\n')
        when (b) {
            is TextBlock -> sb.append(b.text)
            else -> sb.append('￼')
        }
    }
    return sb.toString()
}

object LegacyCfi {
    private class Point(val steps: List<Int>, val offset: Int)

    /**
     * The epub.js-style CFI for the point before the [visible]-th visible character of [doc]'s body
     * ([after] = just after the character before it, for range ends). [spineStep] is the `/6/<n>`
     * step of the chapter. Inverse of [visibleCharsBefore].
     */
    fun cfiFor(doc: org.jsoup.nodes.Document, spineStep: Int, visible: Int, after: Boolean = false): String? {
        val p = point(doc, visible, after) ?: return null
        return "epubcfi(/6/$spineStep!${p.steps.joinToString("") { "/$it" }}:${p.offset})"
    }

    /** Range CFI `epubcfi(<common>,<start>,<end>)` for visible chars [start, end). */
    fun cfiRange(doc: org.jsoup.nodes.Document, spineStep: Int, start: Int, end: Int): String? {
        val a = point(doc, start, after = false) ?: return null
        val b = point(doc, end, after = true) ?: return null
        var common = 0
        while (common < a.steps.size && common < b.steps.size && a.steps[common] == b.steps[common]) common++
        fun rest(p: Point) = p.steps.drop(common).joinToString("") { "/$it" } + ":" + p.offset
        return "epubcfi(/6/$spineStep!${a.steps.take(common).joinToString("") { "/$it" }},${rest(a)},${rest(b)})"
    }

    private fun point(doc: org.jsoup.nodes.Document, visible: Int, after: Boolean): Point? {
        val body = doc.body() ?: return null
        val target = if (after) visible - 1 else visible
        var seen = 0
        var last: Pair<org.jsoup.nodes.TextNode, Int>? = null
        var found: Pair<org.jsoup.nodes.TextNode, Int>? = null
        fun walk(node: org.jsoup.nodes.Node) {
            if (found != null) return
            when (node) {
                is org.jsoup.nodes.TextNode -> {
                    val t = node.wholeText
                    for (i in t.indices) {
                        if (t[i].isWhitespace()) continue
                        if (seen == target) { found = node to (if (after) i + 1 else i); return }
                        seen++
                        last = node to i + 1
                    }
                }
                is org.jsoup.nodes.Element -> if (node.normalName() !in setOf("script", "style")) node.childNodes().forEach { walk(it) }
            }
        }
        if (target < 0) {
            // Before the first character.
            walk(body)
            return pointOf(firstText(body) ?: return null, 0)
        }
        walk(body)
        val (node, offset) = found ?: last ?: return null
        return pointOf(node, offset)
    }

    private fun firstText(e: org.jsoup.nodes.Element): org.jsoup.nodes.TextNode? {
        for (n in e.childNodes()) {
            if (n is org.jsoup.nodes.TextNode && n.wholeText.any { !it.isWhitespace() }) return n
            if (n is org.jsoup.nodes.Element) firstText(n)?.let { return it }
        }
        return null
    }

    /** Steps from <html> down to [text] (element steps even, the text chunk odd), plus the offset. */
    private fun pointOf(text: org.jsoup.nodes.TextNode, offset: Int): Point {
        val parent = text.parentNode() as org.jsoup.nodes.Element
        // Text step: 2k+1 where k = element children before it; offset counts the whole chunk.
        var k = 0
        var chunkStart = 0
        for (n in parent.childNodes()) {
            if (n === text) break
            if (n is org.jsoup.nodes.Element) { k++; chunkStart = 0 } else if (n is org.jsoup.nodes.TextNode) chunkStart += n.wholeText.length
        }
        val steps = ArrayList<Int>()
        var e: org.jsoup.nodes.Element = parent
        while (e.parent() != null && e.parent() !is org.jsoup.nodes.Document) {
            steps.add(0, (e.elementSiblingIndex() + 1) * 2)
            e = e.parent()!!
        }
        steps.add(2 * k + 1)
        return Point(steps, chunkStart + offset)
    }

    /**
     * Visible (non-whitespace) characters in the document body before the point a CFI names:
     * `epubcfi(/6/14!/4/2/48/1:120)` or a range `epubcfi(/6/14!/4/2,/1:0,/1:20)` (its start).
     */
    fun visibleCharsBefore(doc: org.jsoup.nodes.Document, cfi: String): Int? {
        val inner = cfi.substringAfter("epubcfi(", "").substringBeforeLast(')')
        val local = inner.substringAfter('!', "").ifEmpty { return null }
        val path = local.split(',').let { if (it.size >= 2) it[0] + it[1] else it[0] }
        val steps = Regex("/(\\d+)(?:\\[[^\\]]*\\])?").findAll(path.substringBefore(':')).map { it.groupValues[1].toInt() }.toList()
        val charOffset = path.substringAfter(':', "").takeWhile { it.isDigit() }.toIntOrNull() ?: 0
        if (steps.isEmpty()) return null
        var element: org.jsoup.nodes.Element = doc.root().children().firstOrNull() ?: return null // <html>
        var before = 0 // visible chars before the target inside its parent
        for ((i, n) in steps.withIndex()) {
            if (n % 2 == 0) {
                element = element.children().getOrNull(n / 2 - 1) ?: return null
            } else {
                // Odd step: the text between element children (n-1)/2 - 1 and (n-1)/2.
                if (i != steps.lastIndex) return null
                val k = (n - 1) / 2
                var elements = 0
                for (node in element.childNodes()) {
                    if (node is org.jsoup.nodes.Element) { if (elements == k) break; elements++ }
                    if (elements == k && node is org.jsoup.nodes.TextNode) {
                        // Inside the target chunk: count up to the char offset.
                        before += node.wholeText.take(charOffset).count { !it.isWhitespace() }
                        break
                    }
                    before += visible(node)
                }
            }
        }
        val body = doc.body() ?: return null
        // before: visible chars inside the parent ahead of an odd (text) step, else 0.
        return visibleBefore(body, element) + (if (steps.last() % 2 == 1) before else 0)
    }

    private fun visible(node: org.jsoup.nodes.Node): Int = when (node) {
        is org.jsoup.nodes.TextNode -> node.wholeText.count { !it.isWhitespace() }
        is org.jsoup.nodes.Element -> if (node.normalName() in setOf("script", "style", "head")) 0 else node.childNodes().sumOf { visible(it) }
        else -> 0
    }

    /** Visible chars in [root] before [target] starts (document order); [target] itself excluded. */
    private fun visibleBefore(root: org.jsoup.nodes.Element, target: org.jsoup.nodes.Element): Int {
        var count = 0
        var found = false
        fun walk(node: org.jsoup.nodes.Node) {
            if (found) return
            if (node === target) { found = true; return }
            when (node) {
                is org.jsoup.nodes.TextNode -> count += node.wholeText.count { !it.isWhitespace() }
                is org.jsoup.nodes.Element -> if (node.normalName() !in setOf("script", "style")) node.childNodes().forEach { walk(it) }
            }
        }
        if (target === root || !target.parents().contains(root)) return 0
        walk(root)
        return count
    }

    /** Spine index from an epub.js CFI: `epubcfi(/6/14!/4/2)` → 14/2 − 1 = 6. */
    fun spineIndex(cfi: String?): Int? {
        val m = Regex("epubcfi\\(/6/(\\d+)").find(cfi ?: return null) ?: return null
        val step = m.groupValues[1].toIntOrNull() ?: return null
        return step / 2 - 1
    }
}
