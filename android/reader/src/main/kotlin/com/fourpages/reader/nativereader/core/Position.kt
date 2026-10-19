package com.fourpages.reader.nativereader.core

import com.fourpages.reader.nativereader.engine.layout.Page

/** A reading position: spine item + character offset in that chapter's PageEngine text. */
data class Position(val resourceIndex: Int, val charOffset: Int)

/** Exact global page numbering across all chapters. */
class PageIndex(private val pagesPerChapter: IntArray) {
    /** A copy of the per-chapter page counts. */
    val counts: IntArray get() = pagesPerChapter.copyOf()

    private val firstPage = IntArray(pagesPerChapter.size).also { a ->
        var sum = 0
        pagesPerChapter.forEachIndexed { i, n -> a[i] = sum; sum += n }
    }

    val totalPages: Int = pagesPerChapter.sum()

    fun pagesIn(resourceIndex: Int): Int = pagesPerChapter[resourceIndex]

    fun globalPage(resourceIndex: Int, pageInChapter: Int): Int = firstPage[resourceIndex] + pageInChapter

    /** (resourceIndex, pageInChapter) for a global page, clamped to the book. */
    fun locate(globalPage: Int): Pair<Int, Int> {
        val g = globalPage.coerceIn(0, (totalPages - 1).coerceAtLeast(0))
        var lo = 0
        var hi = firstPage.lastIndex
        while (lo < hi) { // last chapter whose first page <= g, skipping empty chapters
            val mid = (lo + hi + 1) / 2
            if (firstPage[mid] <= g) lo = mid else hi = mid - 1
        }
        while (lo > 0 && pagesPerChapter[lo] == 0) lo--
        return lo to (g - firstPage[lo])
    }

    fun pagesLeftInBook(globalPage: Int): Int = (totalPages - 1 - globalPage).coerceAtLeast(0)
}

/** Index of the page containing [charOffset] (binary search on page starts), clamped to the chapter. */
fun List<Page>.pageAt(charOffset: Int): Int {
    var lo = 0
    var hi = lastIndex
    while (lo < hi) {
        val mid = (lo + hi + 1) / 2
        if (this[mid].charStart <= charOffset) lo = mid else hi = mid - 1
    }
    return lo
}
