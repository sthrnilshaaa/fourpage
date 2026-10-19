package com.fourpages.reader.nativereader.engine.parse

import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class XhtmlParserTest {
    private fun parse(body: String, styleOf: ((org.jsoup.nodes.Element) -> BlockStyle)? = null): Chapter {
        val html = "<html><body>$body</body></html>"
        return if (styleOf == null) XhtmlParser.parse(html, 0, "c.xhtml")
        else XhtmlParser.parse(html, 0, "c.xhtml", styleOf)
    }

    private fun Chapter.text(i: Int) = (blocks[i] as TextBlock).text

    @Test
    fun parse_paragraphsAndHeading() {
        val c = parse("<h1>One</h1><p>Hello <i>big</i> world</p>")
        assertEquals(2, c.blocks.size)
        val h = c.blocks[0] as TextBlock
        assertEquals(TextBlock.Kind.HEADING1, h.kind)
        assertEquals("One", h.text)
        val p = c.blocks[1] as TextBlock
        assertEquals("Hello big world", p.text)
        assertEquals(listOf(Span(start = 6, end = 9, italic = true)), p.spans)
        assertEquals(4, p.charStart)
    }

    @Test
    fun parse_anchorsKept() {
        val c = parse("<p id=\"n1\">x</p><div id=\"c2\"><p>y</p></div>")
        assertEquals(listOf("n1"), c.blocks[0].anchors)
        assertEquals(listOf("c2"), c.blocks[1].anchors)
    }

    @Test
    fun parse_imageAndHr() {
        val c = parse("<p>a</p><img src=\"../images/f.jpg\" alt=\"Fig\"/><hr/>")
        assertEquals(3, c.blocks.size)
        val img = c.blocks[1] as ImageBlock
        assertEquals("../images/f.jpg", img.href)
        assertEquals("Fig", img.alt)
        assertEquals(1, img.charEnd - img.charStart)
        val hr = c.blocks[2] as SeparatorBlock
        assertEquals(1, hr.charEnd - hr.charStart)
    }

    @Test
    fun parse_imageOnlyBody() {
        val c = parse("<div><img src=\"cover.jpg\"/></div>")
        assertEquals(1, c.blocks.size)
        assertTrue(c.blocks[0] is ImageBlock)
        assertEquals(1, c.length)
    }

    @Test
    fun parse_unknownTagsKeepText() {
        val c = parse("<foo><bar>keep me</bar></foo>")
        assertEquals(1, c.blocks.size)
        assertEquals(TextBlock.Kind.PARAGRAPH, (c.blocks[0] as TextBlock).kind)
        assertEquals("keep me", c.text(0))
    }

    @Test
    fun parse_bareBodyText() {
        val c = parse("loose text<p>p</p>")
        assertEquals(2, c.blocks.size)
        assertEquals("loose text", c.text(0))
        assertEquals("p", c.text(1))
    }

    @Test
    fun parse_whitespaceCollapsed() {
        assertEquals("a b", parse("<p>  a\n   b </p>").text(0))
        assertEquals("a\n  b", parse("<pre>a\n  b</pre>").text(0))
    }

    @Test
    fun parse_hiddenSkipped() {
        val c = parse("<p>a<span class=\"x\">b</span></p>") { e ->
            if (e.hasClass("x")) BlockStyle(hidden = true) else UaStyles.of(e)
        }
        assertEquals("a", c.text(0))
    }

    @Test
    fun parse_tableFlattened() {
        val c = parse("<table><tr><td>a</td><td>b</td></tr></table>")
        assertEquals(1, c.blocks.size)
        val row = c.blocks[0] as TextBlock
        assertEquals(TextBlock.Kind.TABLE_ROW, row.kind)
        assertEquals("a\tb", row.text)
    }

    @Test
    fun parse_offsetsContiguous() {
        val c = parse("<p>ab</p><p>cde</p><hr/><p>f</p>")
        for (i in 1 until c.blocks.size) assertEquals(c.blocks[i - 1].charEnd + 1, c.blocks[i].charStart)
        assertEquals(c.blocks.last().charEnd, c.length)
    }

    @Test
    fun parse_nestedInlineSizeNotCompounded() {
        val p = parse("<p>a<small>b<span>c</span></small></p>").blocks[0] as TextBlock
        assertEquals(listOf(Span(start = 1, end = 3, sizeScale = 0.85f)), p.spans)
    }

    @Test
    fun parse_blockInsideInline_keepsSpansOnBothSides() {
        val d = parse("<b>A<div>B</div>CCC</b>")
        assertEquals(3, d.blocks.size)
        assertEquals(listOf(Span(start = 0, end = 1, bold = true)), (d.blocks[0] as TextBlock).spans)
        assertEquals(listOf(Span(start = 0, end = 1, bold = true)), (d.blocks[1] as TextBlock).spans)
        assertEquals(listOf(Span(start = 0, end = 3, bold = true)), (d.blocks[2] as TextBlock).spans)
    }

    @Test
    fun parse_linkWrappingHeading_keepsHeadingText() {
        val c = parse("<p>xx <b>A<div>B</div>CCCCCCCCC</b></p>")
        val last = c.blocks.last() as TextBlock
        assertEquals("CCCCCCCCC", last.text)
        assertEquals(listOf(Span(start = 0, end = 9, bold = true)), last.spans)
    }
}
