package com.fourpages.reader.nativereader.core

import android.graphics.Bitmap
import android.util.Log
import android.util.Size
import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.fourpages.reader.nativereader.engine.TestChapters
import com.fourpages.reader.nativereader.engine.layout.LayoutCache
import com.fourpages.reader.nativereader.engine.render.ImageSource
import com.fourpages.reader.nativereader.publication.BookOpener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.awaitCancellation
import kotlinx.coroutines.cancel
import kotlinx.coroutines.cancelAndJoin
import kotlinx.coroutines.launch
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.withTimeout
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File

@RunWith(AndroidJUnit4::class)
class ChapterPipelineTest {
    private val context = InstrumentationRegistry.getInstrumentation().targetContext
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Default)
    private val cacheDir = File(context.cacheDir, "pipeline-test").also { it.deleteRecursively() }

    @After fun tearDown() = scope.cancel()

    private fun book(name: String): File = TestBooks.copy(context, name)

    private suspend fun pipeline(file: File, images: ImageSource? = null): ChapterPipeline {
        val pub = BookOpener(context).open(file)
        return ChapterPipeline(
            pub, TestChapters.params(), LayoutCache(cacheDir), BookOpener.bookKey(file, pub), scope,
            images ?: PublicationImages(pub),
        )
    }

    @Test
    fun openAt_returnsCurrentChapterBeforeOthers() = runBlocking {
        val p = pipeline(book("pride.epub"))
        val (laid, page) = p.openAt(Position(5, 0))
        assertEquals(5, laid.chapter.resourceIndex)
        assertEquals(0, page)
        val index = withTimeout(20_000) { p.allLaidOut.filterNotNull().first() }
        assertTrue("totalPages=${index.totalPages}", index.totalPages > 100)
    }

    @Test
    fun openAt_cachedSecondOpen_pageIndexReadyImmediately() = runBlocking {
        val file = book("pride.epub")
        val first = pipeline(file)
        first.openAt(Position(5, 0))
        val total = withTimeout(20_000) { first.allLaidOut.filterNotNull().first() }.totalPages

        val second = pipeline(file)
        val (_, page) = second.openAt(Position(5, 0))
        assertEquals(0, page)
        val index = second.allLaidOut.value
        assertNotNull("page index should come from the cache at open", index)
        assertEquals(total, index!!.totalPages)
        assertEquals(second.chapterCount, second.cacheHits)
    }

    @Test
    fun openChapter_missingImage_stillPaginates() = runBlocking {
        val noImages = object : ImageSource {
            override suspend fun measure(hrefs: Collection<String>) = Unit
            override suspend fun prepare(hrefs: Collection<String>) = Unit
            override fun size(href: String): Size? = null
            override fun bitmap(href: String): Bitmap? = null
        }
        val p = pipeline(book("alice.epub"), noImages)
        for (i in 0 until p.chapterCount) assertTrue(p.ensure(i).pages.isNotEmpty())
    }

    @Test
    fun allBooks_paginate() = runBlocking {
        for (name in TestBooks.all(context)) {
            val t0 = System.nanoTime()
            val p = pipeline(book(name))
            val (laid, _) = p.openAt(Position(0, 0))
            val firstMs = (System.nanoTime() - t0) / 1e6
            val index = withTimeout(60_000) { p.allLaidOut.filterNotNull().first() }
            val wholeMs = (System.nanoTime() - t0) / 1e6
            Log.i("ARead-Spike", "book=$name chapters=${p.chapterCount} pages=${index.totalPages} " +
                "firstPageMs=%.0f wholeBookMs=%.0f".format(firstMs, wholeMs))
            assertTrue(laid.pages.isNotEmpty())
        }
    }

    /** Delegates to real images, but can hang or fail [measure] for chosen chapters' images. */
    private class FlakyImages(private val real: ImageSource) : ImageSource {
        @Volatile var hang = false
        @Volatile var failOnce = false
        var prepareCalls = 0
        override suspend fun measure(hrefs: Collection<String>) {
            if (hang && hrefs.isNotEmpty()) awaitCancellation()
            if (failOnce && hrefs.isNotEmpty()) { failOnce = false; throw java.io.IOException("flaky read") }
            real.measure(hrefs)
        }
        override suspend fun prepare(hrefs: Collection<String>) { prepareCalls++; real.prepare(hrefs) }
        override fun size(href: String) = real.size(href)
        override fun bitmap(href: String) = real.bitmap(href)
    }

    private fun imageChapter(p: ChapterPipeline): Int = runBlocking {
        (0 until p.chapterCount).first { i -> p.ensure(i).chapter.blocks.any { it is com.fourpages.reader.nativereader.engine.parse.ImageBlock } }
    }

    @Test
    fun cancelledLayout_isNotCached() = runBlocking {
        val file = book("alice.epub")
        val pub = BookOpener(context).open(file)
        val target = imageChapter(pipeline(file))
        cacheDir.deleteRecursively()

        val flaky = FlakyImages(PublicationImages(pub)).apply { hang = true }
        val inner = CoroutineScope(SupervisorJob() + Dispatchers.Default)
        val p = ChapterPipeline(pub, TestChapters.params(), LayoutCache(cacheDir), BookOpener.bookKey(file, pub), inner, flaky)
        val job = inner.launch { p.ensure(target) }
        kotlinx.coroutines.delay(500)
        job.cancelAndJoin(); inner.cancel()
        kotlinx.coroutines.delay(200)
        assertNull(LayoutCache(cacheDir).read(BookOpener.bookKey(file, pub), TestChapters.params().key(), target))
    }

    @Test
    fun failedLayout_notCached_andRetried() = runBlocking {
        val file = book("alice.epub")
        val pub = BookOpener(context).open(file)
        val target = imageChapter(pipeline(file))
        cacheDir.deleteRecursively()

        val flaky = FlakyImages(PublicationImages(pub)).apply { failOnce = true }
        val p = ChapterPipeline(pub, TestChapters.params(), LayoutCache(cacheDir), BookOpener.bookKey(file, pub), scope, flaky)
        val first = p.ensure(target)
        assertTrue(first.failed)
        assertNull(LayoutCache(cacheDir).read(BookOpener.bookKey(file, pub), TestChapters.params().key(), target))
        val second = p.ensure(target)
        assertTrue(!second.failed && second.chapter.blocks.isNotEmpty())
    }

    @Test
    fun staleCache_pageIndexRefreshes() = runBlocking {
        val file = book("pride.epub")
        val pub = BookOpener(context).open(file)
        val key = BookOpener.bookKey(file, pub)
        val cache = LayoutCache(cacheDir)
        for (i in pub.readingOrder.indices) cache.write(key, TestChapters.params().key(), i, intArrayOf(0))
        val p = ChapterPipeline(pub, TestChapters.params(), cache, key, scope, PublicationImages(pub))
        p.openAt(Position(5, 0))
        // Every count came from the (stale) cache at open; layouts then correct the index.
        assertEquals(p.chapterCount, p.cacheHits)
        val fixed = withTimeout(30_000) { p.allLaidOut.first { it != null && it.totalPages > 100 } }
        assertNotEquals(p.chapterCount, fixed!!.totalPages)
    }

    @Test
    fun layout_measuresImagesWithoutDecodingPixels() = runBlocking {
        val file = book("alice.epub")
        val pub = BookOpener(context).open(file)
        val images = FlakyImages(PublicationImages(pub))
        val p = ChapterPipeline(pub, TestChapters.params(), LayoutCache(cacheDir), BookOpener.bookKey(file, pub), scope, images)
        for (i in 0 until p.chapterCount) p.ensure(i)
        assertEquals(0, images.prepareCalls)
    }
}
