package com.fourpages.reader.nativereader.engine.layout

import org.junit.Assert.assertEquals
import org.junit.Test

class PaginatorTest {
    /** Builds stacked lines; each line gets 10 chars. [blockOf] maps line index → block index. */
    private fun lines(
        heights: List<Int>,
        blockOf: (Int) -> Int = { it },
        breakBefore: Set<Int> = emptySet(),
        atoms: Set<Int> = emptySet(),
    ): List<LineBox> {
        var top = 0
        return heights.mapIndexed { i, h ->
            LineBox(blockOf(i), i * 10, i * 10 + 10, top, top + h, i in breakBefore, i in atoms).also { top += h }
        }
    }

    private fun List<Page>.ranges() = map { it.firstLine to it.lastLine }

    @Test
    fun paginate_fillsPages() {
        val pages = Paginator.paginate(lines(List(10) { 100 }), 300, 100)
        assertEquals(listOf(0 to 2, 3 to 5, 6 to 8, 9 to 9), pages.ranges())
    }

    @Test
    fun paginate_breakBeforeStartsNewPage() {
        val pages = Paginator.paginate(lines(List(4) { 100 }, breakBefore = setOf(2)), 1000, 40)
        assertEquals(listOf(0 to 1, 2 to 3), pages.ranges())
    }

    @Test
    fun paginate_widowOrphan() {
        val pages = Paginator.paginate(lines(List(7) { 100 }, blockOf = { if (it < 4) 0 else 1 }), 500, 70)
        assertEquals(listOf(0 to 3, 4 to 6), pages.ranges())
    }

    @Test
    fun paginate_widowPullsLinesForward() {
        // Block 0 has 6 lines; 5 fit. Leaving 1 line alone on the next page is a widow → move 1 more.
        val pages = Paginator.paginate(lines(List(6) { 100 }, blockOf = { 0 }), 500, 60)
        assertEquals(listOf(0 to 3, 4 to 5), pages.ranges())
    }

    @Test
    fun paginate_paragraphTallerThanPage_splitsWithoutLoss() {
        val pages = Paginator.paginate(lines(List(25) { 40 }, blockOf = { 0 }), 400, 250)
        assertEquals(3, pages.size)
        val covered = pages.flatMap { (it.firstLine..it.lastLine).toList() }
        assertEquals((0..24).toList(), covered)
    }

    @Test
    fun paginate_oversizedAtom_getsOwnPage() {
        val ls = lines(listOf(100, 900, 100), atoms = setOf(1))
        val pages = Paginator.paginate(ls, 400, 30)
        assertEquals(listOf(0 to 0, 1 to 1, 2 to 2), pages.ranges())
    }

    @Test
    fun paginate_emptyChapter_yieldsOnePage() {
        val pages = Paginator.paginate(emptyList(), 400, 0)
        assertEquals(1, pages.size)
        assertEquals(0, pages[0].charStart)
        assertEquals(0, pages[0].charEnd)
    }

    @Test
    fun paginate_coversWholeChapter() {
        val pages = Paginator.paginate(lines(List(10) { 100 }), 300, 104)
        assertEquals(0, pages.first().charStart)
        assertEquals(104, pages.last().charEnd)
        for (k in 1 until pages.size) assertEquals(pages[k - 1].charEnd, pages[k].charStart)
        pages.forEachIndexed { k, p -> assertEquals(k, p.index) }
    }
}
