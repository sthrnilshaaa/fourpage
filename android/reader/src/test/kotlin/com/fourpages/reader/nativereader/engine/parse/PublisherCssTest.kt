package com.fourpages.reader.nativereader.engine.parse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

/** Regressions from real books (Gutenberg Pride and Prejudice's 0.css). */
class PublisherCssTest {
    private val css = javaClass.getResource("/pride-0.css")!!.readText()

    private fun paragraph(html: String): TextBlock {
        val resolver = StyleResolver(CssSubset.parse(css))
        val c = XhtmlParser.parse("<html><body>$html</body></html>", 0, "c.html", resolver::of)
        return c.blocks.single() as TextBlock
    }

    @Test
    fun pride_paragraphIsIndented() {
        val p = paragraph("<p>“I know you do: and it is <i>that</i> which makes the wonder.</p>")
        assertTrue("indentEm=${p.style.indentEm}", p.style.indentEm > 0.5f)
        assertEquals(0.2f, p.style.marginTopEm, 1e-4f)
    }

    @Test
    fun percentIndent_convertsToEm() {
        // 4% of a ~30em measure.
        assertEquals(1.2f, StyleResolver.length("4%")!!, 1e-4f)
        assertEquals(0f, StyleResolver.length("0%")!!, 1e-4f)
    }

    @Test
    fun bodyAndHtmlMargins_ignored() {
        // Page edges come from the app's page-margin setting, so body/html margins don't inset text.
        val p = paragraph("<p>x</p>")
        assertEquals(0f, p.style.leftInsetEm, 1e-4f)
    }
}
