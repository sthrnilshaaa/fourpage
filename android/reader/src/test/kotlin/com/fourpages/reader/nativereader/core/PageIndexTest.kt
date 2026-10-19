package com.fourpages.reader.nativereader.core

import com.fourpages.reader.nativereader.engine.layout.Page
import org.junit.Assert.assertEquals
import org.junit.Test

class PageIndexTest {
    @Test
    fun pageIndex_globalAndLocate() {
        val idx = PageIndex(intArrayOf(3, 1, 5))
        assertEquals(9, idx.totalPages)
        assertEquals(4, idx.globalPage(2, 0))
        assertEquals(2 to 0, idx.locate(4))
        assertEquals(4, idx.pagesLeftInBook(4))
        assertEquals(0 to 0, idx.locate(0))
        assertEquals(2 to 4, idx.locate(8))
    }

    @Test
    fun pageIndex_locateClamps() {
        val idx = PageIndex(intArrayOf(3, 1, 5))
        assertEquals(2 to 4, idx.locate(99))
        assertEquals(0 to 0, idx.locate(-1))
        assertEquals(0, idx.pagesLeftInBook(8))
    }

    @Test
    fun pageIndex_offsetPastEnd_clampsToLastPage() {
        val pages = listOf(Page(0, 0, 100, 0, 1), Page(1, 100, 200, 2, 3), Page(2, 200, 250, 4, 5))
        assertEquals(2, pages.pageAt(9999))
        assertEquals(0, pages.pageAt(-5))
        assertEquals(1, pages.pageAt(100))
        assertEquals(0, pages.pageAt(99))
        assertEquals(0, listOf(Page(0, 0, 0, 0, -1)).pageAt(10))
    }
}
