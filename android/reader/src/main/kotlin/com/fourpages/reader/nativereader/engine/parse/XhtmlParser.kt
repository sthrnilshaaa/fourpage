package com.fourpages.reader.nativereader.engine.parse

import org.jsoup.Jsoup
import org.jsoup.nodes.Document
import org.jsoup.nodes.Element
import org.jsoup.nodes.Node
import org.jsoup.nodes.TextNode
import org.jsoup.parser.Parser

/** Jsoup DOM → [Chapter] blocks. Unknown tags are treated as inline so their text is kept. */
object XhtmlParser {
    private val blockTags = setOf(
        "p", "div", "h1", "h2", "h3", "h4", "h5", "h6", "li", "blockquote", "pre", "section", "article",
        "figure", "figcaption", "table", "tr", "dd", "dt", "dl", "ul", "ol", "header", "footer", "aside",
        "nav", "main", "body", "center", "address", "caption", "tbody", "thead", "tfoot", "hgroup",
    )

    fun parse(
        xhtml: String,
        resourceIndex: Int,
        href: String,
        styleOf: (Element) -> BlockStyle = UaStyles::of,
    ): Chapter {
        val doc = if (xhtml.trimStart().startsWith("<?xml")) Jsoup.parse(xhtml, "", Parser.xmlParser()) else Jsoup.parse(xhtml)
        return parse(doc, resourceIndex, href, styleOf)
    }

    fun parse(
        doc: Document,
        resourceIndex: Int,
        href: String,
        styleOf: (Element) -> BlockStyle = UaStyles::of,
    ): Chapter {
        val body = doc.selectFirst("body") ?: doc
        val builder = Builder(styleOf)
        builder.walkBlock(body as Element)
        return Chapter(resourceIndex, href, builder.blocks, builder.blocks.lastOrNull()?.charEnd ?: 0)
    }

    private class Ctx(val element: Element, val style: BlockStyle)

    private class OpenSpan(val template: Span, var start: Int)

    private class Builder(val styleOf: (Element) -> BlockStyle) {
        val blocks = mutableListOf<Block>()
        private var offset = 0
        private val pendingAnchors = mutableListOf<String>()
        private val stack = ArrayDeque<Ctx>()
        private val text = StringBuilder()
        private val spans = mutableListOf<Span>()
        private var preDepth = 0
        /** Inline elements still open; a block flushed inside them splits their spans across blocks. */
        private val openSpans = ArrayDeque<OpenSpan>()

        fun walkBlock(e: Element) {
            val style = styleOf(e)
            if (style.hidden) return
            flush()
            e.id().takeIf { it.isNotEmpty() }?.let { pendingAnchors += it }
            stack.addLast(Ctx(e, style))
            if (e.normalName() == "pre") preDepth++
            if (e.normalName() == "li") text.append("• ")
            e.childNodes().forEach { walk(it) }
            flush()
            if (e.normalName() == "pre") preDepth--
            stack.removeLast()
        }

        private fun walk(n: Node) {
            when (n) {
                is TextNode -> appendText(n.wholeText)
                is Element -> walkElement(n)
                else -> Unit
            }
        }

        private fun walkElement(e: Element) {
            when (val name = e.normalName()) {
                "img", "image" -> {
                    if (styleOf(e).hidden) return
                    val src = e.attr("src").ifEmpty { e.attr("xlink:href") }.ifEmpty { e.attr("href") }
                    if (src.isEmpty()) return
                    flush()
                    e.id().takeIf { it.isNotEmpty() }?.let { pendingAnchors += it }
                    emit { start -> ImageBlock(src, e.attr("alt"), start, start + 1, takeAnchors()) }
                }
                "hr" -> {
                    flush()
                    emit { start -> SeparatorBlock(start, start + 1, takeAnchors()) }
                }
                "br" -> text.append('\n')
                "td", "th" -> {
                    if (text.isNotEmpty()) text.append('\t')
                    walkInline(e)
                }
                in blockTags -> walkBlock(e)
                else -> walkInline(e)
            }
        }

        private fun walkInline(e: Element) {
            val s = styleOf(e)
            if (s.hidden) return
            e.id().takeIf { it.isNotEmpty() }?.let { pendingAnchors += it }
            val href = if (e.normalName() == "a") e.attr("href").ifEmpty { null } else null
            val parent = e.parent()?.let { styleOf(it) } ?: BlockStyle()
            val template = Span(
                0, 0,
                italic = s.italic && !parent.italic,
                bold = s.bold && !parent.bold,
                underline = s.underline, strike = s.strike, smallCaps = s.smallCaps,
                sup = s.sup, sub = s.sub, sizeScale = s.sizeScale / parent.sizeScale, href = href,
            )
            val open = OpenSpan(template, text.length)
            openSpans.addLast(open)
            e.childNodes().forEach { walk(it) }
            openSpans.removeLast()
            closeSpan(open)
        }

        /** Emits [open]'s span over [start, text.length) if it carries any formatting. */
        private fun closeSpan(open: OpenSpan) {
            val end = text.length
            if (end > open.start && open.template != Span(0, 0)) spans += open.template.copy(start = open.start, end = end)
        }

        private fun appendText(raw: String) {
            if (preDepth > 0) { text.append(raw); return }
            for (ch in raw) {
                if (ch.isWhitespace()) {
                    if (text.isNotEmpty() && !text.last().isWhitespace()) text.append(' ')
                } else text.append(ch)
            }
        }

        private fun takeAnchors(): List<String> = pendingAnchors.toList().also { pendingAnchors.clear() }

        private fun emit(make: (start: Int) -> Block) {
            val start = if (blocks.isEmpty()) 0 else offset + 1
            val b = make(start)
            blocks += b
            offset = b.charEnd
        }

        /** Turn the pending inline text into a block of the innermost block element's kind. */
        private fun flush() {
            openSpans.forEach { closeSpan(it) }
            val raw = text.toString()
            val spanList = spans.toList()
            text.setLength(0); spans.clear()
            openSpans.forEach { it.start = 0 }
            val lead = if (preDepth > 0) 0 else raw.indexOfFirst { !it.isWhitespace() }.let { if (it < 0) raw.length else it }
            val trail = if (preDepth > 0) raw.length else raw.indexOfLast { !it.isWhitespace() } + 1
            if (trail <= lead) return
            val t = raw.substring(lead, trail)
            if (t.isBlank() || t == "•") return
            val ctx = stack.lastOrNull()
            val kind = kindOf(ctx?.element?.normalName())
            val inset = stack.sumOf { it.style.leftInsetEm.toDouble() }.toFloat()
            val style = (ctx?.style ?: BlockStyle()).copy(leftInsetEm = inset)
            val adjusted = spanList.mapNotNull { s ->
                val a = (s.start - lead).coerceIn(0, t.length)
                val b = (s.end - lead).coerceIn(0, t.length)
                if (b > a) s.copy(start = a, end = b) else null
            }
            emit { start -> TextBlock(kind, t, adjusted, start, start + t.length, takeAnchors(), style) }
        }

        private fun kindOf(tag: String?) = when (tag) {
            "h1" -> TextBlock.Kind.HEADING1
            "h2" -> TextBlock.Kind.HEADING2
            "h3" -> TextBlock.Kind.HEADING3
            "h4" -> TextBlock.Kind.HEADING4
            "h5" -> TextBlock.Kind.HEADING5
            "h6" -> TextBlock.Kind.HEADING6
            "li" -> TextBlock.Kind.LIST_ITEM
            "blockquote" -> TextBlock.Kind.BLOCKQUOTE
            "pre" -> TextBlock.Kind.PRE
            "tr" -> TextBlock.Kind.TABLE_ROW
            else -> TextBlock.Kind.PARAGRAPH
        }
    }
}
