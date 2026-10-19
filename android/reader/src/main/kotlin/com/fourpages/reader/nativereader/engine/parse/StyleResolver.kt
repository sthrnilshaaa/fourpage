package com.fourpages.reader.nativereader.engine.parse

import org.jsoup.nodes.Element
import java.util.IdentityHashMap

/**
 * Computes a [BlockStyle] per element: UA defaults < publisher rules (by specificity, then order)
 * < inline `style`. Inherits italic, bold, small-caps, alignment and font size (multiplied).
 * Colours are ignored. With [publisherStyles] off only the UA sheet applies.
 */
class StyleResolver(rules: List<CssRule>, val publisherStyles: Boolean = true) {
    private val rules = rules.sortedWith(compareBy({ it.specificity }, { it.order }))
    private val cache = IdentityHashMap<Element, BlockStyle>()

    fun of(e: Element): BlockStyle = cache.getOrPut(e) { compute(e) }

    private fun compute(e: Element): BlockStyle {
        val parent = e.parent()?.takeIf { it.normalName() != "#root" }?.let { of(it) } ?: BlockStyle()
        var s = BlockStyle(
            align = parent.align, italic = parent.italic, bold = parent.bold,
            smallCaps = parent.smallCaps, sizeScale = parent.sizeScale,
        )
        // Insertion order = application order, so a re-declared property moves to the end
        // (a later margin-top must beat an earlier margin shorthand).
        val decls = LinkedHashMap<String, String>()
        fun add(d: Map<String, String>) = d.forEach { (k, v) -> decls.remove(k); decls[k] = v }
        UA_RULES.filter { matches(it.selector, e) }.forEach { add(it.decls) }
        if (publisherStyles) {
            rules.filter { matches(it.selector, e) }.forEach { add(it.decls) }
            e.attr("style").takeIf { it.isNotBlank() }?.let { add(CssSubset.parseDecls(it)) }
        }
        // Page edges come from the app's page-margin setting, not the book's html/body margins.
        if (e.normalName() == "body" || e.normalName() == "html") decls.keys.removeAll { it.startsWith("margin") }
        for ((k, v) in decls) s = apply(s, k, v, parent)
        return s
    }

    private fun matches(sel: SimpleSelector, e: Element): Boolean {
        if (!matchesCompound(sel, e)) return false
        // Each ancestor compound, nearest last, must match some ancestor further up than the previous one.
        var node: Element? = e.parent()
        for (anc in sel.ancestors.asReversed()) {
            while (node != null && !matchesCompound(anc, node)) node = node.parent()
            if (node == null) return false
            node = node.parent()
        }
        return true
    }

    private fun matchesCompound(sel: SimpleSelector, e: Element): Boolean =
        (sel.tag == null || sel.tag == e.normalName()) &&
            (sel.id == null || sel.id == e.id()) &&
            sel.classes.all { e.hasClass(it) }

    private fun apply(s: BlockStyle, k: String, v: String, parent: BlockStyle): BlockStyle = when (k) {
        "font-style" -> s.copy(italic = v == "italic" || v == "oblique")
        "font-weight" -> s.copy(bold = v == "bold" || v == "bolder" || (v.toIntOrNull() ?: 400) >= 600)
        "font-size" -> fontScale(v, parent.sizeScale)?.let { s.copy(sizeScale = it) } ?: s
        "text-align" -> when (v) {
            "left", "start" -> s.copy(align = Align.START)
            "right", "end" -> s.copy(align = Align.END)
            "center" -> s.copy(align = Align.CENTER)
            "justify" -> s.copy(align = Align.JUSTIFY)
            else -> s
        }
        "text-indent" -> length(v)?.let { s.copy(indentEm = it) } ?: s
        "margin-top" -> length(v)?.let { s.copy(marginTopEm = it) } ?: s
        "margin-bottom" -> length(v)?.let { s.copy(marginBottomEm = it) } ?: s
        "margin-left" -> length(v)?.let { s.copy(leftInsetEm = it) } ?: s
        "margin" -> {
            val p = v.split(Regex("\\s+"))
            val top = length(p[0])
            val bottom = length(p.getOrElse(2) { p[0] })
            val left = length(p.getOrElse(3) { p.getOrElse(1) { p[0] } })
            s.copy(
                marginTopEm = top ?: s.marginTopEm,
                marginBottomEm = bottom ?: s.marginBottomEm,
                leftInsetEm = left ?: s.leftInsetEm,
            )
        }
        "font-variant" -> s.copy(smallCaps = v.contains("small-caps"))
        "text-decoration", "text-decoration-line" -> s.copy(underline = v.contains("underline"), strike = v.contains("line-through"))
        "vertical-align" -> s.copy(sup = v == "super", sub = v == "sub")
        "display" -> s.copy(hidden = v == "none")
        "page-break-before", "break-before" -> s.copy(pageBreakBefore = v in setOf("always", "page", "left", "right"))
        else -> s
    }

    companion object {
        /** Lengths in em. px convert at 16px = 1em, % of a ~30em measure; auto and other units are ignored. */
        fun length(v: String): Float? = when {
            v == "0" -> 0f
            v.endsWith("%") -> v.removeSuffix("%").toFloatOrNull()?.times(0.3f)
            v.endsWith("rem") -> v.removeSuffix("rem").toFloatOrNull()
            v.endsWith("em") -> v.removeSuffix("em").toFloatOrNull()
            v.endsWith("px") -> v.removeSuffix("px").toFloatOrNull()?.div(16f)
            else -> null
        }

        fun fontScale(v: String, parent: Float): Float? = when {
            v.endsWith("%") -> v.removeSuffix("%").toFloatOrNull()?.let { parent * it / 100f }
            v.endsWith("rem") -> v.removeSuffix("rem").toFloatOrNull()
            v.endsWith("em") -> v.removeSuffix("em").toFloatOrNull()?.let { parent * it }
            v == "smaller" -> parent * 0.85f
            v == "larger" -> parent * 1.2f
            else -> mapOf(
                "xx-small" to 0.6f, "x-small" to 0.75f, "small" to 0.89f, "medium" to 1f,
                "large" to 1.2f, "x-large" to 1.5f, "xx-large" to 2f,
            )[v]
        }

        private val UA_CSS = """
            h1{text-align:center;font-size:1.6em;font-weight:bold;margin-top:1.5em;margin-bottom:1em}
            h2{text-align:center;font-size:1.4em;font-weight:bold;margin-top:1.4em;margin-bottom:0.9em}
            h3{text-align:center;font-size:1.2em;font-weight:bold;margin-top:1.2em;margin-bottom:0.8em}
            h4,h5,h6{text-align:left;font-weight:bold;margin-top:1em;margin-bottom:0.6em}
            p{text-indent:1.5em}
            blockquote{margin-left:2em;margin-top:0.8em;margin-bottom:0.8em}
            pre{text-align:left;margin-top:0.8em;margin-bottom:0.8em}
            li{text-align:left;margin-left:1.5em}
            hr,img,figure,figcaption,center{text-align:center}
            i,em,cite,var,dfn{font-style:italic}
            b,strong,th{font-weight:bold}
            u,ins{text-decoration:underline}
            s,strike,del{text-decoration:line-through}
            sup{vertical-align:super;font-size:0.75em}
            sub{vertical-align:sub;font-size:0.75em}
            small{font-size:0.85em}
            big{font-size:1.2em}
            head,script,style,title{display:none}
        """.trimIndent()

        val UA_RULES: List<CssRule> = CssSubset.parse(UA_CSS)
    }
}
