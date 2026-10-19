package com.fourpages.reader.nativereader.engine.parse

/**
 * One compound selector plus the compounds it must have as ancestors, nearest last
 * (`div.poem p` → ancestors [div.poem]). Child combinators (`>`) are matched as descendants.
 */
data class SimpleSelector(
    val tag: String?,
    val id: String?,
    val classes: Set<String>,
    val ancestors: List<SimpleSelector> = emptyList(),
) {
    val specificity: Int get() = ownSpecificity + ancestors.sumOf { it.ownSpecificity }
    private val ownSpecificity: Int get() = (if (id != null) 100 else 0) + classes.size * 10 + (if (tag != null) 1 else 0)
}

data class CssRule(val selector: SimpleSelector, val decls: Map<String, String>, val specificity: Int, val order: Int)

/** Hand-written parser for the stylesheet subset the PageEngine understands. Never throws. */
object CssSubset {
    fun parse(css: String, orderOffset: Int = 0): List<CssRule> {
        val src = css.replace(Regex("/\\*.*?\\*/", RegexOption.DOT_MATCHES_ALL), " ")
        val rules = mutableListOf<CssRule>()
        var i = 0
        var order = orderOffset
        while (i < src.length) {
            val open = src.indexOf('{', i)
            if (open < 0) break
            val prelude = src.substring(i, open).trim()
            val close = matchingBrace(src, open)
            val body = src.substring(open + 1, close)
            i = close + 1
            if (prelude.startsWith("@")) continue // @media, @font-face, @page …: skipped
            val decls = parseDecls(body)
            if (decls.isEmpty()) continue
            for (sel in prelude.split(',')) {
                val s = parseSelector(sel.trim()) ?: continue
                rules += CssRule(s, decls, s.specificity, order++)
            }
        }
        return rules
    }

    fun parseDecls(body: String): Map<String, String> {
        val out = LinkedHashMap<String, String>()
        for (d in body.split(';')) {
            val c = d.indexOf(':')
            if (c <= 0) continue
            val k = d.substring(0, c).trim().lowercase()
            val v = d.substring(c + 1).replace("!important", "").trim().lowercase()
            if (k.isNotEmpty() && v.isNotEmpty()) out[k] = v
        }
        return out
    }

    private fun matchingBrace(s: String, open: Int): Int {
        var depth = 0
        for (j in open until s.length) {
            when (s[j]) {
                '{' -> depth++
                '}' -> if (--depth == 0) return j
            }
        }
        return s.length // unclosed: take the rest
    }

    /** Returns null for selectors the subset can't honour (pseudo-classes, attributes, sibling combinators). */
    private fun parseSelector(sel: String): SimpleSelector? {
        if (sel.isEmpty() || sel.contains('+') || sel.contains('~')) return null
        val parts = sel.split(Regex("[\\s>]+")).filter { it.isNotEmpty() }
        if (parts.isEmpty()) return null
        val compounds = parts.map { parseCompound(it) ?: return null }
        return compounds.last().copy(ancestors = compounds.dropLast(1))
    }

    private fun parseCompound(last: String): SimpleSelector? {
        if (last.contains(':') || last.contains('[')) return null
        var tag: String? = null
        var id: String? = null
        val classes = mutableSetOf<String>()
        Regex("([.#]?)([\\w-]+|\\*)").findAll(last).forEach { m ->
            when (m.groupValues[1]) {
                "." -> classes += m.groupValues[2]
                "#" -> id = m.groupValues[2]
                else -> if (m.groupValues[2] != "*") tag = m.groupValues[2].lowercase()
            }
        }
        return SimpleSelector(tag, id, classes)
    }
}
