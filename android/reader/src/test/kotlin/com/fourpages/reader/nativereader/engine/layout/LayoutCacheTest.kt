package com.fourpages.reader.nativereader.engine.layout

import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertNull
import org.junit.Rule
import org.junit.Test
import org.junit.rules.TemporaryFolder

class LayoutCacheTest {
    @get:Rule val tmp = TemporaryFolder()

    @Test
    fun layoutCache_roundTrip() {
        val cache = LayoutCache(tmp.root)
        cache.write("book", "k1", 3, intArrayOf(0, 120, 450))
        assertArrayEquals(intArrayOf(0, 120, 450), cache.read("book", "k1", 3))
        assertNull(cache.read("book", "k2", 3))
        assertNull(cache.read("book", "k1", 4))
    }

    @Test
    fun layoutCache_corruptFileReadsNull() {
        val cache = LayoutCache(tmp.root)
        cache.write("book", "k1", 0, intArrayOf(0, 10))
        tmp.root.walk().filter { it.isFile }.forEach { it.writeBytes(byteArrayOf(1, 2, 3)) }
        assertNull(cache.read("book", "k1", 0))
    }
}
