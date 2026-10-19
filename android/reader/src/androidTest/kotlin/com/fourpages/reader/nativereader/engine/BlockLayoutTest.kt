package com.fourpages.reader.nativereader.engine

import android.util.Size
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.fourpages.reader.nativereader.engine.layout.BlockLayout
import com.fourpages.reader.nativereader.engine.parse.XhtmlParser
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class BlockLayoutTest {
    private val noImages: (String) -> Size? = { null }

    @Test
    fun layoutChapter_linesMonotonic() {
        val chapter = TestChapters.lorem()
        val laid = BlockLayout(TestChapters.params(), noImages).layoutChapter(chapter)
        for (i in 1 until laid.lines.size) assertTrue(laid.lines[i].top >= laid.lines[i - 1].top)
        laid.lines.forEach { assertTrue(it.bottom > it.top) }
        assertTrue("pages=${laid.pages.size}", laid.pages.size >= 2)
        assertEquals(chapter.length, laid.pages.last().charEnd)
    }

    @Test
    fun layoutImage_tallerThanPage_scaledToFit() {
        val chapter = XhtmlParser.parse("<html><body><p>Before</p><img src=\"tall.png\"/><p>After</p></body></html>", 0, "i.xhtml")
        val params = TestChapters.params()
        val laid = BlockLayout(params) { if (it == "tall.png") Size(1000, 5000) else null }.layoutChapter(chapter)
        val img = laid.lines.single { it.atom }
        assertTrue(img.bottom - img.top <= params.heightPx - 2 * params.paddingPx)
        val page = laid.pages.single { img.blockIndex == laid.lines[it.firstLine].blockIndex }
        assertEquals(page.firstLine, page.lastLine)
    }

    @Test
    fun layoutChapter_largerFontMorePages() {
        val chapter = TestChapters.lorem()
        val small = BlockLayout(TestChapters.params(18f), noImages).layoutChapter(chapter).pages.size
        val large = BlockLayout(TestChapters.params(28f), noImages).layoutChapter(chapter).pages.size
        assertTrue("18sp=$small 28sp=$large", large > small)
    }

    @Test
    fun key_ignoresColours() {
        val a = TestChapters.params(textColor = 1, bg = 2)
        val b = TestChapters.params(textColor = 3, bg = 4)
        assertEquals(a.key(), b.key())
        assertNotEquals(a.key(), TestChapters.params(textSp = 20f).key())
    }

    @Test
    fun layoutChapter_paragraphPitchMatchesLinePitch() {
        // With no margins, the step from a paragraph's last line to the next paragraph's first line
        // must equal the line pitch inside a paragraph (line spacing applies after the last line too).
        val chapter = TestChapters.lorem(3)
        val laid = BlockLayout(TestChapters.params(), noImages).layoutChapter(chapter)
        val b1 = laid.lines.filter { it.blockIndex == 1 }
        val b2first = laid.lines.first { it.blockIndex == 2 }
        val pitch = b1[1].top - b1[0].top
        assertEquals(pitch.toFloat(), (b2first.top - b1.last().top).toFloat(), 2f)
    }

    @Test
    fun layoutChapter_lineHeightIsCssStyle() {
        // CSS line-height: pitch = multiplier x font size (what the WebView reader does), not x font metrics.
        val params = TestChapters.params()
        val laid = BlockLayout(params, noImages).layoutChapter(TestChapters.lorem(3))
        val b1 = laid.lines.filter { it.blockIndex == 1 }
        assertEquals(params.textSizePx * params.lineHeightMult, (b1[1].top - b1[0].top).toFloat(), 1.5f)
    }

    @Test
    fun key_includesFontLocaleAndDensity() {
        val base = TestChapters.params()
        assertNotEquals(base.key(), base.copy(fontKey = "sans").key())
        assertNotEquals(base.key(), base.copy(locale = "de-DE").key())
        assertNotEquals(base.key(), base.copy(density = base.density + 1f).key())
    }
}
