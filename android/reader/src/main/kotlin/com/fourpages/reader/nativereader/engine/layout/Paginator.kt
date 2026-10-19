package com.fourpages.reader.nativereader.engine.layout

/**
 * One laid-out line in a chapter's continuous column. [top]/[bottom] are px from the
 * chapter top, with block margins already included.
 */
data class LineBox(
    val blockIndex: Int,
    val charStart: Int,
    val charEnd: Int,
    val top: Int,
    val bottom: Int,
    /** First line of a block with page-break-before. */
    val breakBefore: Boolean = false,
    /** An image or separator: never split. */
    val atom: Boolean = false,
)

/** A page covers chapter chars [charStart, charEnd) and lines [firstLine, lastLine] (lastLine = -1 when empty). */
data class Page(val index: Int, val charStart: Int, val charEnd: Int, val firstLine: Int, val lastLine: Int)

object Paginator {
    /**
     * Greedy fill with widow/orphan control: a block split across pages keeps at least
     * [minLinesAtEdge] lines on each side, unless that would leave a page empty.
     * Always returns at least one page; pages are contiguous and cover [0, chapterLength].
     */
    fun paginate(lines: List<LineBox>, pageHeight: Int, chapterLength: Int, minLinesAtEdge: Int = 2): List<Page> {
        if (lines.isEmpty()) return listOf(Page(0, 0, chapterLength, 0, -1))
        val ranges = mutableListOf<IntRange>()
        var start = 0
        while (start < lines.size) {
            val top = lines[start].top
            var end = start + 1 // exclusive; the first line always goes on the page, even if oversized
            while (end < lines.size && !lines[end].breakBefore && lines[end].bottom - top <= pageHeight) end++
            end = balanceSplit(lines, start, end, minLinesAtEdge)
            ranges += start until end
            start = end
        }
        return ranges.mapIndexed { i, r ->
            Page(
                index = i,
                charStart = if (i == 0) 0 else lines[r.first].charStart,
                charEnd = if (i == ranges.lastIndex) chapterLength else lines[ranges[i + 1].first].charStart,
                firstLine = r.first,
                lastLine = r.last,
            )
        }
    }

    /** Moves the page end back when it splits a block leaving an orphan (this page) or widow (next page). */
    private fun balanceSplit(lines: List<LineBox>, start: Int, end: Int, min: Int): Int {
        if (end >= lines.size) return end
        val block = lines[end - 1].blockIndex
        if (lines[end].blockIndex != block) return end
        var blockStart = end - 1
        while (blockStart > start && lines[blockStart - 1].blockIndex == block) blockStart--
        var blockEnd = end
        while (blockEnd + 1 < lines.size && lines[blockEnd + 1].blockIndex == block) blockEnd++
        val after = blockEnd - end + 1
        var newEnd = end
        if (after < min) newEnd = end - (min - after)
        if (newEnd - blockStart < min) newEnd = blockStart
        return if (newEnd <= start) end else newEnd
    }
}
