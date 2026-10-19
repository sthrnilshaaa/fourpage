package com.fourpages.reader.nativereader.engine.parse

import org.jsoup.Jsoup
import org.jsoup.nodes.Element
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class StyleResolverTest {
    private fun el(body: String, css: String = "", select: String = "p"): Element =
        Jsoup.parse("<html><body>$body</body></html>").selectFirst(select)!!

    private fun resolve(css: String, body: String, select: String = "p", publisher: Boolean = true): BlockStyle =
        StyleResolver(CssSubset.parse(css), publisher).of(el(body, select = select))

    @Test
    fun parse_rulesAndComments() {
        val rules = CssSubset.parse("/*x*/ p.noindent{text-indent:0} h2 , .c{text-align:center}")
        assertEquals(3, rules.size)
        assertEquals(SimpleSelector("p", null, setOf("noindent")), rules[0].selector)
        assertEquals(SimpleSelector("h2", null, emptySet()), rules[1].selector)
        assertEquals(SimpleSelector(null, null, setOf("c")), rules[2].selector)
    }

    @Test
    fun resolve_classOverridesTag() {
        assertEquals(0f, resolve("p{text-indent:1em} .noindent{text-indent:0}", "<p class=\"noindent\">x</p>").indentEm)
    }

    @Test
    fun resolve_inlineStyleWins() {
        assertEquals(Align.CENTER, resolve("p{text-align:left}", "<p style=\"text-align:center\">x</p>").align)
    }

    @Test
    fun resolve_percentAndEm() {
        val s = resolve("p{font-size:120%; margin-top:2em}", "<p>x</p>")
        assertEquals(1.2f, s.sizeScale, 1e-4f)
        assertEquals(2f, s.marginTopEm, 1e-4f)
    }

    @Test
    fun resolve_pageBreak() {
        assertTrue(resolve("h1{page-break-before:always}", "<h1>x</h1>", "h1").pageBreakBefore)
        assertTrue(resolve("h1{break-before:page}", "<h1>x</h1>", "h1").pageBreakBefore)
    }

    @Test
    fun resolve_displayNone() {
        assertTrue(resolve(".hide{display:none}", "<p class=\"hide\">x</p>").hidden)
    }

    @Test
    fun resolve_publisherOff() {
        val body = "<p class=\"c\">x</p>"
        assertEquals(UaStyles.of(el(body)), resolve(".c{text-align:center;text-indent:3em}", body, publisher = false))
    }

    @Test
    fun resolve_descendantNeedsMatchingAncestor() {
        val css = "div.poem p{text-align:left}"
        assertEquals(Align.JUSTIFY, resolve(css, "<div><p>x</p></div>").align)
        assertEquals(Align.START, resolve(css, "<div class=\"poem\"><section><p>x</p></section></div>").align)
        assertEquals(Align.START, resolve("div > p{text-align:left}", "<div><p>x</p></div>").align)
    }

    @Test
    fun resolve_descendantAddsSpecificity() {
        assertEquals(Align.CENTER, resolve(".poem p{text-align:center} p{text-align:left}", "<div class=\"poem\"><p>x</p></div>").align)
    }

    @Test
    fun parse_garbageIgnored() {
        val rules = CssSubset.parse("@font-face{font-family:x;src:url(a.ttf)} @media print{p{color:red}} p{color:red;;font-weight:bold")
        assertEquals(1, rules.size)
        assertEquals("bold", rules[0].decls["font-weight"])
    }

    @Test
    fun resolve_inheritsItalicAndSize() {
        val s = resolve("div{font-style:italic;font-size:2em} p{font-size:50%}", "<div><p>x</p></div>")
        assertTrue(s.italic)
        assertEquals(1f, s.sizeScale, 1e-4f)
    }

    @Test
    fun resolve_pseudoClassRulesDropped() {
        assertEquals(1.5f, resolve("p:first-child{text-indent:0}", "<p>x</p>").indentEm)
    }

    @Test
    fun resolve_laterLonghandBeatsEarlierShorthand() {
        // UA h2{margin-top} < publisher h2{margin:0} < publisher h2.chapter{margin-top:3em}
        val s = resolve("h2{margin:0} h2.chapter{margin-top:3em}", "<h2 class=\"chapter\">x</h2>", "h2")
        assertEquals(3f, s.marginTopEm, 1e-4f)
    }
}
