package com.fourpages.reader.nativereader.core

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class ReaderSessionTest {
    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext
    private val cache = File(ctx.cacheDir, "session-test")
    private val sessions = mutableListOf<ReaderSession>()

    @After fun tearDown() = runBlocking { sessions.forEach { it.close() } }

    private fun prefs(size: Float = 16f) = RenderPrefs(null, "serif", size, 2f, "justify", true, 0xFFC2BAA5.toInt(), 0xFF2B2620.toInt(), 24f)

    private suspend fun session(book: String = "pride.epub", size: Float = 16f, start: StartPosition = StartPosition.Beginning): Pair<ReaderSession, PageRef> {
        val s = ReaderSession(ctx, TestBooks.copy(ctx, book), cache, prefs(size), 1080, 2200)
        sessions += s
        return s to s.open(start)
    }

    @Test fun step_crossesChapterBoundary() = runBlocking {
        val (s, _) = session()
        val lastOf2 = s.at(2, Int.MAX_VALUE)
        assertEquals(PageRef(3, 0), s.step(lastOf2, 1))
        assertEquals(lastOf2, s.step(PageRef(3, 0), -1))
    }

    @Test fun step_atBookEnd_null() = runBlocking {
        val (s, first) = session()
        assertNull(s.step(first, -1))
        val last = s.at(s.chapterCount - 1, Int.MAX_VALUE)
        assertNull(s.step(last, 1))
    }

    @Test fun locator_roundTrip() = runBlocking {
        val (s, _) = session()
        val ref = s.at(5, 4000)
        val loc = s.locator(ref)
        assertEquals(ref, s.at(loc.resourceIndex, loc.charOffset))
        assertTrue(loc.href.isNotEmpty())
    }

    @Test fun atProgression_monotonic() = runBlocking {
        val (s, _) = session()
        withTimeout(30_000) { s.pageIndex.filterNotNull().first() }
        val a = s.locator(s.atProgression(0.2)).totalProgression
        val b = s.locator(s.atProgression(0.6)).totalProgression
        assertTrue("a=$a b=$b", a < b && kotlin.math.abs(b - 0.6) < 0.02)
    }

    @Test fun atHref_withFragment_landsOnAnchor() = runBlocking {
        val (s, _) = session()
        val entry = generateSequence(s.toc) { l -> l.flatMap { it.children }.takeIf { it.isNotEmpty() } }.flatten()
            .first { '#' in it.href && (s.hrefIndex(it.href) ?: -1) > 2 }
        val ref = s.atHref(entry.href)
        assertEquals(s.hrefIndex(entry.href), ref.resourceIndex)
    }

    @Test fun toc_hasTitles() = runBlocking {
        val (s, _) = session()
        assertTrue(s.toc.isNotEmpty())
        assertTrue(s.toc.any { it.title.isNotBlank() })
    }

    @Test fun chapterInfo_prevCurrentNext() = runBlocking {
        val (s, _) = session()
        val info = s.chapterInfo(s.at(5, 0))
        assertNotNull(info["current"])
        assertNotNull(info["next"])
    }

    @Test fun search_findsAllCaseInsensitive() = runBlocking {
        val (s, _) = session()
        val hits = s.search("elizabeth", limit = 5000)
        assertTrue("hits=${hits.size}", hits.size >= 600)
        assertTrue(hits.first().snippet.contains("elizabeth", ignoreCase = true))
    }

    @Test fun resolveLegacy_findsQuoteInChapter() = runBlocking {
        val (s, _) = session()
        val ref = s.at(3, 3000)
        val loc = s.locator(ref)
        val quote = loc.textAfter.trim().take(40)
        val r = s.resolveLegacy("epubcfi(/6/8!/4/2/1:0)", quote, loc.progression)
        assertNotNull(r)
        assertEquals(3, r!!.first)
        assertTrue("start=${r.second.first} expected~${loc.charOffset}", kotlin.math.abs(r.second.first - loc.charOffset) < 10)
    }

    @Test fun resolveLegacy_missingQuote_returnsNull() = runBlocking {
        val (s, _) = session()
        assertNull(s.resolveLegacy("epubcfi(/6/8!/4/2/1:0)", "zzzz qqqq never in this book", 0.5))
        assertNull(s.resolveLegacy("not a cfi", "x", 0.5))
    }

    @Test fun setPrefs_keepsPosition() = runBlocking {
        val (s, _) = session()
        val ref = s.at(5, 6000)
        val before = s.locator(ref).charOffset
        val moved = s.setPrefs(prefs(24f), 1080, 2200, ref)
        val after = s.locator(moved)
        assertEquals(5, after.resourceIndex)
        val next = s.step(moved, 1)?.let { s.locator(it).charOffset } ?: Int.MAX_VALUE
        assertTrue("before=$before after=${after.charOffset} next=$next", after.charOffset <= before && before < next)
        // Rotation: new viewport, same text.
        val rotated = s.setPrefs(prefs(24f), 2200, 1080, moved)
        assertEquals(5, rotated.resourceIndex)
    }

    @Test fun tiles_coverChapter() = runBlocking {
        val (s, _) = session()
        val tiles = s.tiles(5)
        assertTrue(tiles.all { it > 0 })
        val img = s.renderTile(5, 0, emptyList())
        assertEquals(tiles[0], img.height)
        assertEquals(img.width * img.height * 4, img.rgba.size)
    }

    @Test fun render_scaledSize() = runBlocking {
        val (s, first) = session()
        val img = s.render(first, 0.62f, emptyList())
        assertEquals(669, img.width)
        assertEquals(img.width * img.height * 4, img.rgba.size)
    }

    @Test fun selection_wordAndRangeAndHighlight() = runBlocking {
        val (s, _) = session()
        val ref = s.at(5, 6000)
        // Middle of the page, inside the text column.
        var word: TextSelection? = null
        var y = 400f
        while (word == null && y < 2000f) { word = s.wordAt(ref, 540f, y); y += 37f }
        assertNotNull(word)
        assertTrue("'${word!!.text}'", word.text.isNotBlank() && !word.text.contains(' '))
        assertNull(s.wordAt(ref, 5f, 1000f)) // left margin
        val range = s.rangeBetween(ref, 100f, 300f, 900f, 900f)
        assertNotNull(range)
        assertTrue(range!!.rects.size >= 2)
        val h = Highlight("h1", ref.resourceIndex, word.start, word.end, 0xFFFFEB3B.toInt())
        val r = word.rects.first()
        assertEquals("h1", s.highlightAt(ref, r.centerX(), r.centerY(), listOf(h)))
    }

    @Test fun setPrefsAt_twiceInARow_keepsText() = runBlocking {
        val (s, _) = session()
        val start = s.locator(s.at(5, 6000)).charOffset
        for (size in listOf(17f, 18f)) {
            val ref = s.setPrefsAt(prefs(size), 1080, 2200, 5, start)
            val off = s.locator(ref).charOffset
            val next = s.step(ref, 1)?.let { s.locator(it).charOffset } ?: Int.MAX_VALUE
            assertTrue("off=$off start=$start next=$next", off <= start && start < next)
        }
    }

    @Test fun selection_carriesChapterHref() = runBlocking {
        val (s, _) = session()
        assertTrue(s.chapterHref(5).isNotEmpty())
        assertEquals(5, s.hrefIndex(s.chapterHref(5)))
    }
}
