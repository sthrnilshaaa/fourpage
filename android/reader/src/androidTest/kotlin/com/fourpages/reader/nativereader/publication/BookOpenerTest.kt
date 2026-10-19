package com.fourpages.reader.nativereader.publication

import android.util.Log
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.fourpages.reader.nativereader.core.TestBooks
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class BookOpenerTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val manifests = File(context.cacheDir, "manifest-test").also { it.deleteRecursively() }

    @Test
    fun open_cachedManifest_sameBook() = runBlocking {
        val file = TestBooks.copy(context, "pride.epub")
        val opener = BookOpener(context, manifests)

        var t = System.nanoTime()
        val first = opener.open(file)
        val firstMs = (System.nanoTime() - t) / 1e6
        assertFalse(opener.lastOpenFromCache)

        t = System.nanoTime()
        val second = opener.open(file)
        val secondMs = (System.nanoTime() - t) / 1e6
        Log.i("ARead-Spike", "manifestCache firstOpenMs=%.0f cachedOpenMs=%.0f".format(firstMs, secondMs))

        assertTrue(opener.lastOpenFromCache)
        assertEquals(first.readingOrder.map { it.href.toString() }, second.readingOrder.map { it.href.toString() })
        assertEquals(first.tableOfContents.size, second.tableOfContents.size)
        assertEquals(first.metadata.identifier, second.metadata.identifier)
        assertNotNull(second.readBytes(second.readingOrder[2].url()))
    }

    @Test
    fun open_corruptManifestCache_fallsBackToParse() = runBlocking {
        val file = TestBooks.copy(context, "alice.epub")
        val opener = BookOpener(context, manifests)
        opener.open(file)
        manifests.walk().filter { it.isFile }.forEach { it.writeText("{not json") }
        val pub = opener.open(file)
        assertFalse(opener.lastOpenFromCache)
        assertTrue(pub.readingOrder.isNotEmpty())
    }
}
