package com.fourpages.reader.nativereader.engine

import android.graphics.Bitmap
import android.util.Size
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.fourpages.reader.nativereader.core.Highlight
import com.fourpages.reader.nativereader.core.RenderPrefs
import com.fourpages.reader.nativereader.core.toLayoutParams
import com.fourpages.reader.nativereader.engine.layout.BlockLayout
import com.fourpages.reader.nativereader.engine.layout.LaidOutChapter
import com.fourpages.reader.nativereader.engine.layout.LayoutParams
import com.fourpages.reader.nativereader.engine.parse.CssSubset
import com.fourpages.reader.nativereader.engine.parse.StyleResolver
import com.fourpages.reader.nativereader.engine.parse.XhtmlParser
import com.fourpages.reader.nativereader.engine.render.PageRenderer
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class RenderPrefsTest {
    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext
    private val dm = ctx.resources.displayMetrics

    private fun prefs(align: String = "justify", font: String? = null, publisher: Boolean = true) = RenderPrefs(
        fontPath = font, fontKey = font ?: "serif", fontSizeSp = 16f, lineHeight = 2f, textAlign = align,
        publisherStyles = publisher, pageColor = 0xFFC2BAA5.toInt(), textColor = 0xFF2B2620.toInt(), paddingDp = 24f,
    )

    private fun params(p: RenderPrefs) = p.toLayoutParams(1080, 2200, dm.density, dm.scaledDensity)

    private fun render(params: LayoutParams, highlights: List<Highlight> = emptyList()): Pair<Bitmap, LaidOutChapter> {
        val layout = BlockLayout(params) { null as Size? }
        val laid = layout.layoutChapter(TestChapters.lorem(6))
        val page = laid.pages[0]
        val blocks = laid.lines[page.firstLine].blockIndex..laid.lines[page.lastLine].blockIndex
        return PageRenderer(params) { null }.renderToBitmap(laid, page, layout.layoutBlocks(laid.chapter, blocks), highlights) to laid
    }

    private fun Bitmap.pixels() = IntArray(width * height).also { getPixels(it, 0, width, 0, 0, width, height) }

    @Test
    fun alignOverride_left_differsFromJustify() {
        val left = render(params(prefs("left"))).first.pixels()
        val justify = render(params(prefs("justify"))).first.pixels()
        assertTrue(!left.contentEquals(justify))
        assertNotEquals(params(prefs("left")).key(), params(prefs("justify")).key())
    }

    @Test
    fun fontFromFile_loads() {
        val out = File(ctx.cacheDir, "DroidSans.ttf")
        InstrumentationRegistry.getInstrumentation().context.assets.open("fonts/DroidSans.ttf").use { i -> out.outputStream().use { i.copyTo(it) } }
        val serif = BlockLayout(params(prefs()), { null }).layoutChapter(TestChapters.lorem(6)).lines.map { it.charEnd }
        val sans = BlockLayout(params(prefs(font = out.path)), { null }).layoutChapter(TestChapters.lorem(6)).lines.map { it.charEnd }
        assertNotEquals(serif, sans)
    }

    @Test
    fun highlight_drawsBehindText() {
        val p = params(prefs())
        val (plain, laid) = render(p)
        val block = laid.chapter.blocks[1]
        val hl = listOf(Highlight("h", 0, block.charStart, block.charStart + 20, 0xFFFFEB3B.toInt()))
        val marked = render(p, hl).first
        val a = plain.pixels(); val b = marked.pixels()
        val changed = a.indices.count { a[it] != b[it] }
        assertTrue("changed=$changed", changed > 500)
    }

    @Test
    fun publisherStylesOff_ignoresBookCss() {
        val html = "<html><body><p class=\"c\">x</p></body></html>"
        val rules = CssSubset.parse(".c{text-align:center}")
        val on = XhtmlParser.parse(html, 0, "c", StyleResolver(rules, true)::of).blocks[0].style.align
        val off = XhtmlParser.parse(html, 0, "c", StyleResolver(rules, false)::of).blocks[0].style.align
        assertNotEquals(on, off)
        assertEquals(params(prefs(publisher = false)).publisherStyles, false)
    }
}
