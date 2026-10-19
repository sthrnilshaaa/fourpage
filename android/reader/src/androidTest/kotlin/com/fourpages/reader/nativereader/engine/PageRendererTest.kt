package com.fourpages.reader.nativereader.engine

import android.graphics.Canvas
import android.util.Log
import android.util.Size
import androidx.test.ext.junit.runners.AndroidJUnit4
import com.fourpages.reader.nativereader.engine.layout.BlockLayout
import com.fourpages.reader.nativereader.engine.render.PageRenderer
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith

@RunWith(AndroidJUnit4::class)
class PageRendererTest {
    @Test
    fun renderToBitmap_notBlank_andFast() {
        val params = TestChapters.params()
        val layout = BlockLayout(params) { null as Size? }
        val laid = layout.layoutChapter(TestChapters.lorem())
        val page = laid.pages[0]
        val blocks = laid.lines[page.firstLine].blockIndex..laid.lines[page.lastLine].blockIndex
        val layouts = layout.layoutBlocks(laid.chapter, blocks)
        val renderer = PageRenderer(params) { null }

        val bmp = renderer.renderToBitmap(laid, page, layouts)
        val px = IntArray(bmp.width * bmp.height).also { bmp.getPixels(it, 0, bmp.width, 0, 0, bmp.width, bmp.height) }
        val inked = px.count { it != params.backgroundColor }
        assertTrue("inked=$inked", inked > px.size / 100)

        val canvas = Canvas(bmp)
        val times = (0 until 20).map {
            val t = System.nanoTime(); renderer.draw(canvas, laid, page, layouts); (System.nanoTime() - t) / 1e6
        }.sorted()
        val median = times[10]
        Log.i("ARead-Spike", "renderMedianMs=%.2f".format(median))
        assertTrue("median=$median ms", median < 8.0)
    }

    @Test
    fun draw_pageStartingMidBlock_showsThatPagesLines() {
        // One paragraph spanning several pages: page 1 must start with its own first line, not page 0's.
        val params = TestChapters.params()
        val text = (0 until 40).joinToString(" ") { "Sentence number $it of one very long paragraph." }
        val chapter = com.fourpages.reader.nativereader.engine.parse.XhtmlParser.parse("<html><body><p>$text</p></body></html>", 0, "c")
        val layout = BlockLayout(params) { null as Size? }
        val laid = layout.layoutChapter(chapter)
        assertTrue(laid.pages.size >= 2)
        val renderer = PageRenderer(params) { null }
        val layouts = layout.layoutBlocks(chapter, 0..0)
        fun firstRow(pageIndex: Int): IntArray {
            val bmp = renderer.renderToBitmap(laid, laid.pages[pageIndex], layouts)
            val line = laid.lines[laid.pages[pageIndex].firstLine]
            val h = line.bottom - line.top
            return IntArray(bmp.width * h).also { bmp.getPixels(it, 0, bmp.width, 0, params.paddingPx, bmp.width, h) }
        }
        val p0 = firstRow(0)
        val p1 = firstRow(1)
        assertTrue("page 1's first row is blank", p1.count { it != params.backgroundColor } > p1.size / 200)
        assertTrue("page 1 starts with page 0's text", !p0.contentEquals(p1))
    }
}
