package com.fourpages.reader.nativereader.engine.parse

/**
 * The PageEngine's model of one chapter: a flat list of blocks.
 *
 * Character offsets are chapter-global and contiguous: each block starts one
 * character after the previous one ends (that gap stands for the block break),
 * so any offset belongs to exactly one block. Images and separators take one
 * character each.
 */

/** Inline formatting over [start, end) of a [TextBlock]'s text. */
data class Span(
    val start: Int,
    val end: Int,
    val italic: Boolean = false,
    val bold: Boolean = false,
    val underline: Boolean = false,
    val strike: Boolean = false,
    val smallCaps: Boolean = false,
    val sup: Boolean = false,
    val sub: Boolean = false,
    val sizeScale: Float = 1f,
    val href: String? = null,
)

enum class Align { START, CENTER, END, JUSTIFY }

/** Computed block-level style. Lengths in em of the base font size. */
data class BlockStyle(
    val align: Align = Align.JUSTIFY,
    val indentEm: Float = 0f,
    val marginTopEm: Float = 0f,
    val marginBottomEm: Float = 0f,
    val sizeScale: Float = 1f,
    val bold: Boolean = false,
    val italic: Boolean = false,
    val pageBreakBefore: Boolean = false,
    val hidden: Boolean = false,
    val leftInsetEm: Float = 0f,
    val smallCaps: Boolean = false,
    val underline: Boolean = false,
    val strike: Boolean = false,
    val sup: Boolean = false,
    val sub: Boolean = false,
)

sealed interface Block {
    val charStart: Int
    val charEnd: Int
    /** `id` attributes that resolve to this block (TOC fragments, footnotes, links). */
    val anchors: List<String>
    val style: BlockStyle
}

data class TextBlock(
    val kind: Kind,
    val text: String,
    val spans: List<Span>,
    override val charStart: Int,
    override val charEnd: Int,
    override val anchors: List<String> = emptyList(),
    override val style: BlockStyle = BlockStyle(),
) : Block {
    enum class Kind { PARAGRAPH, HEADING1, HEADING2, HEADING3, HEADING4, HEADING5, HEADING6, LIST_ITEM, BLOCKQUOTE, PRE, TABLE_ROW }
}

data class ImageBlock(
    val href: String,
    val alt: String,
    override val charStart: Int,
    override val charEnd: Int,
    override val anchors: List<String> = emptyList(),
    override val style: BlockStyle = BlockStyle(align = Align.CENTER),
) : Block

data class SeparatorBlock(
    override val charStart: Int,
    override val charEnd: Int,
    override val anchors: List<String> = emptyList(),
    override val style: BlockStyle = BlockStyle(align = Align.CENTER, marginTopEm = 1f, marginBottomEm = 1f),
) : Block

data class Chapter(
    val resourceIndex: Int,
    val href: String,
    val blocks: List<Block>,
    /** == the last block's charEnd, or 0 for an empty chapter. */
    val length: Int,
)
