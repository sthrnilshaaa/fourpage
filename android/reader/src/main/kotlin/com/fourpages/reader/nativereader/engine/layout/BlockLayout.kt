package com.fourpages.reader.nativereader.engine.layout

import android.content.res.Resources
import android.graphics.Typeface
import android.os.Build
import android.text.Layout
import android.text.SpannableString
import android.text.Spanned
import android.text.StaticLayout
import android.text.TextPaint
import android.text.style.LeadingMarginSpan
import android.text.style.RelativeSizeSpan
import android.text.style.StrikethroughSpan
import android.text.style.StyleSpan
import android.text.style.SubscriptSpan
import android.text.style.SuperscriptSpan
import android.text.style.URLSpan
import android.text.style.UnderlineSpan
import android.util.Size
import java.util.Locale
import com.fourpages.reader.nativereader.engine.parse.Align
import com.fourpages.reader.nativereader.engine.parse.Block
import com.fourpages.reader.nativereader.engine.parse.Chapter
import com.fourpages.reader.nativereader.engine.parse.ImageBlock
import com.fourpages.reader.nativereader.engine.parse.SeparatorBlock
import com.fourpages.reader.nativereader.engine.parse.TextBlock
import kotlin.math.max
import kotlin.math.min
import kotlin.math.roundToInt

data class LayoutParams(
    val widthPx: Int,
    val heightPx: Int,
    val paddingPx: Int,
    val textSizePx: Float,
    val lineHeightMult: Float,
    val typeface: Typeface,
    val justify: Boolean,
    val hyphenate: Boolean,
    val textColor: Int,
    val backgroundColor: Int,
    /** Stable name of [typeface] for [key] (Typeface itself has no stable identity). Required on purpose. */
    val fontKey: String,
    /** Hyphenation follows the system locale, so it moves page breaks. */
    val locale: String = Locale.getDefault().toLanguageTag(),
    /** Caps image upscaling. */
    val density: Float = Resources.getSystem().displayMetrics.density,
    /** The reader's text-align setting: replaces justified/start body text (centred/right blocks keep theirs). */
    val alignOverride: Align? = null,
    /** false = book CSS ignored, only built-in styles. */
    val publisherStyles: Boolean = true,
) {
    val contentWidth: Int get() = widthPx - 2 * paddingPx
    val contentHeight: Int get() = heightPx - 2 * paddingPx

    /** Identifies a layout: everything that moves page breaks, nothing that only changes colours. */
    fun key(): String = listOf(
        LAYOUT_VERSION, Build.VERSION.SDK_INT, widthPx, heightPx, paddingPx, textSizePx, lineHeightMult, fontKey,
        justify, hyphenate, locale, density, alignOverride, publisherStyles,
    ).joinToString("|").hashCode().toUInt().toString(16)

    companion object {
        /**
         * Bump on ANY change that can move page breaks: layout, the paginator, the XHTML parser,
         * the CSS subset/resolver or the UA sheet. Old cached page breaks are then ignored.
         */
        const val LAYOUT_VERSION = 4
    }
}

/** [failed]: the chapter couldn't be read and is shown empty; it is never cached and is retried. */
class LaidOutChapter(val chapter: Chapter, val lines: List<LineBox>, val pages: List<Page>, val failed: Boolean = false)

/** Lays out a chapter's blocks with StaticLayout into one continuous column, then paginates it. */
class BlockLayout(private val params: LayoutParams, private val imageSize: (href: String) -> Size?) {
    fun layoutChapter(chapter: Chapter): LaidOutChapter {
        val lines = ArrayList<LineBox>()
        var y = 0
        var prevMarginBottom = 0
        chapter.blocks.forEachIndexed { i, block ->
            val em = params.textSizePx * block.style.sizeScale
            y += if (i == 0) 0 else max(prevMarginBottom, (block.style.marginTopEm * em).roundToInt())
            val breakBefore = i > 0 && block.style.pageBreakBefore
            when (block) {
                is TextBlock -> {
                    val sl = buildLayout(block)
                    for (l in 0 until sl.lineCount) {
                        lines += LineBox(
                            blockIndex = i,
                            charStart = block.charStart + sl.getLineStart(l),
                            charEnd = block.charStart + sl.getLineEnd(l),
                            top = y + sl.getLineTop(l),
                            bottom = y + sl.getLineBottom(l),
                            breakBefore = breakBefore && l == 0,
                        )
                    }
                    // StaticLayout leaves line spacing off the last line; add it back so the step
                    // into the next block matches the line pitch inside a block.
                    y += sl.height + lastLineExtra(sl)
                }
                is ImageBlock, is SeparatorBlock -> {
                    val h = atomHeight(block)
                    lines += LineBox(i, block.charStart, block.charEnd, y, y + h, breakBefore, atom = true)
                    y += h
                }
            }
            prevMarginBottom = (block.style.marginBottomEm * em).roundToInt()
        }
        return LaidOutChapter(chapter, lines, Paginator.paginate(lines, params.contentHeight, chapter.length))
    }

    /** StaticLayouts for the text blocks in [blockRange], for drawing one page. */
    fun layoutBlocks(chapter: Chapter, blockRange: IntRange): Map<Int, StaticLayout> =
        blockRange.mapNotNull { i -> (chapter.blocks.getOrNull(i) as? TextBlock)?.let { i to buildLayout(it) } }.toMap()

    fun insetPx(block: Block): Int = (block.style.leftInsetEm * params.textSizePx).roundToInt()

    /** Image draw size: fit the content box, upscaling at most to the screen density. */
    fun imageDrawSize(block: ImageBlock): Size? {
        val s = imageSize(block.href) ?: return null
        if (s.width <= 0 || s.height <= 0) return null
        val scale = min(params.density, min(params.contentWidth / s.width.toFloat(), params.contentHeight / s.height.toFloat()))
        return Size(max(1, (s.width * scale).toInt()), max(1, (s.height * scale).toInt()))
    }

    /**
     * CSS line-height semantics (as in the WebView reader): line pitch = multiplier x font size.
     * Returned as the extra px StaticLayout adds to the font's natural line height.
     */
    private fun extraSpacing(paint: TextPaint): Float = paint.textSize * params.lineHeightMult - paint.getFontMetricsInt(null)

    /** StaticLayout leaves the extra spacing off the last line; this is that missing amount. */
    private fun lastLineExtra(sl: StaticLayout): Int = extraSpacing(sl.paint).roundToInt()

    private fun lineHeight(): Int = (params.textSizePx * params.lineHeightMult).roundToInt()

    private fun atomHeight(block: Block): Int = when (block) {
        is ImageBlock -> imageDrawSize(block)?.height ?: lineHeight()
        else -> lineHeight()
    }

    private fun buildLayout(block: TextBlock): StaticLayout {
        val s = block.style
        val paint = TextPaint(TextPaint.ANTI_ALIAS_FLAG or TextPaint.SUBPIXEL_TEXT_FLAG).apply {
            textSize = params.textSizePx * s.sizeScale
            color = params.textColor
            typeface = Typeface.create(params.typeface, styleBits(s.bold, s.italic))
            isUnderlineText = s.underline
            isStrikeThruText = s.strike
        }
        val text = SpannableString(block.text)
        for (sp in block.spans) {
            val f = Spanned.SPAN_EXCLUSIVE_EXCLUSIVE
            if (sp.bold || sp.italic) text.setSpan(StyleSpan(styleBits(sp.bold, sp.italic)), sp.start, sp.end, f)
            if (sp.underline) text.setSpan(UnderlineSpan(), sp.start, sp.end, f)
            if (sp.strike) text.setSpan(StrikethroughSpan(), sp.start, sp.end, f)
            if (sp.sup) text.setSpan(SuperscriptSpan(), sp.start, sp.end, f)
            if (sp.sub) text.setSpan(SubscriptSpan(), sp.start, sp.end, f)
            if (sp.sizeScale != 1f) text.setSpan(RelativeSizeSpan(sp.sizeScale), sp.start, sp.end, f)
            if (sp.href != null) text.setSpan(URLSpan(sp.href), sp.start, sp.end, f)
        }
        val indent = (s.indentEm * paint.textSize).roundToInt()
        if (indent > 0) text.setSpan(LeadingMarginSpan.Standard(indent, 0), 0, text.length, Spanned.SPAN_INCLUSIVE_INCLUSIVE)
        val width = max(1, params.contentWidth - insetPx(block))
        val effective = params.alignOverride
            ?.takeIf { s.align == Align.JUSTIFY || s.align == Align.START }
            ?: s.align
        val align = when (effective) {
            Align.CENTER -> Layout.Alignment.ALIGN_CENTER
            Align.END -> Layout.Alignment.ALIGN_OPPOSITE
            else -> Layout.Alignment.ALIGN_NORMAL
        }
        val b = StaticLayout.Builder.obtain(text, 0, text.length, paint, width)
            .setAlignment(align)
            .setLineSpacing(extraSpacing(paint), 1f)
            .setIncludePad(false)
            .setBreakStrategy(Layout.BREAK_STRATEGY_HIGH_QUALITY)
            .setHyphenationFrequency(if (params.hyphenate) Layout.HYPHENATION_FREQUENCY_NORMAL else Layout.HYPHENATION_FREQUENCY_NONE)
        if (Build.VERSION.SDK_INT >= 26 && effective == Align.JUSTIFY && params.justify) {
            b.setJustificationMode(Layout.JUSTIFICATION_MODE_INTER_WORD)
        }
        return b.build()
    }

    private fun styleBits(bold: Boolean, italic: Boolean) = when {
        bold && italic -> Typeface.BOLD_ITALIC
        bold -> Typeface.BOLD
        italic -> Typeface.ITALIC
        else -> Typeface.NORMAL
    }
}
