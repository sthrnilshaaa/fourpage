package com.fourpages.reader.nativereader.spike

import android.app.Activity
import android.graphics.Typeface
import android.os.Bundle
import android.view.KeyEvent
import com.fourpages.reader.nativereader.core.ChapterPipeline
import com.fourpages.reader.nativereader.core.Position
import com.fourpages.reader.nativereader.engine.layout.LayoutCache
import com.fourpages.reader.nativereader.engine.layout.LayoutParams
import com.fourpages.reader.nativereader.publication.BookOpener
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.cancel
import kotlinx.coroutines.flow.filterNotNull
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import java.io.File
import kotlin.random.Random

/**
 * Spike (a): PageEngine in a bare Activity.
 * Extras: book (asset path, e.g. pride.epub or private/x.epub), path (absolute file instead of book), page (global page to jump to once
 * laid out), clearCache (boolean). Volume-down jumps to a random page.
 */
class EngineSpikeActivity : Activity() {
    private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main.immediate)
    private lateinit var view: PageView

    override fun onCreate(savedInstanceState: Bundle?) {
        SpikeLog.mark("firstPage")
        SpikeLog.mark("wholeBook")
        super.onCreate(savedInstanceState)
        view = PageView(this)
        setContentView(view)
        val bookName = intent.getStringExtra("book") ?: "pride.epub"
        val jumpTo = intent.getIntExtra("page", -1)
        val cacheDir = File(cacheDir, "layout")
        val manifestDir = File(this.cacheDir, "manifests")
        if (intent.getBooleanExtra("clearCache", false)) { cacheDir.deleteRecursively(); manifestDir.deleteRecursively() }

        SpikeLog.mark("viewReady")
        view.post {
            SpikeLog.since("viewReady")
            val d = resources.displayMetrics
            val params = LayoutParams(
                widthPx = view.width, heightPx = view.height, paddingPx = (24 * d.density).toInt(),
                textSizePx = 16 * d.scaledDensity, lineHeightMult = 2.0f, typeface = Typeface.SERIF, fontKey = "serif",
                justify = true, hyphenate = true, textColor = 0xFF2B2620.toInt(), backgroundColor = 0xFFC2BAA5.toInt(),
            )
            scope.launch {
                val file = intent.getStringExtra("path")?.let { File(it) } ?: copyAsset(bookName)
                if (intent.getBooleanExtra("warmup", false)) {
                    // Opens another book first, so the timed open below runs with Readium already initialised.
                    SpikeLog.mark("warmupOpen")
                    BookOpener(this@EngineSpikeActivity).open(copyAsset("alice.epub"))
                    SpikeLog.since("warmupOpen")
                }
                SpikeLog.mark("readiumOpen")
                val sampler = if (intent.getBooleanExtra("profile", false)) StackSampler() else null
                val opener = BookOpener(this@EngineSpikeActivity, manifestDir)
                val pub = opener.open(file)
                SpikeLog.since("readiumOpen")
                SpikeLog.info("manifestFromCache=${opener.lastOpenFromCache}")
                sampler?.stop()
                val pipeline = ChapterPipeline(pub, params, LayoutCache(cacheDir), BookOpener.bookKey(file, pub), scope)
                view.bind(pipeline, params, scope)
                view.onFirstPage = { SpikeLog.since("render"); SpikeLog.since("firstPage") }
                SpikeLog.mark("openAt")
                val (laid, page) = pipeline.openAt(Position(0, 0))
                SpikeLog.since("openAt")
                SpikeLog.mark("render")
                SpikeLog.info("book=$bookName cacheHits=${pipeline.cacheHits}/${pipeline.chapterCount}")
                view.show(PageView.Loc(laid.chapter.resourceIndex, page))
                val index = pipeline.allLaidOut.filterNotNull().first()
                SpikeLog.since("wholeBook")
                SpikeLog.info("totalPages=${index.totalPages}")
                view.index = index
                if (jumpTo >= 0) jump(jumpTo)
            }
        }
    }

    private fun jump(globalPage: Int) {
        val index = view.index ?: return
        SpikeLog.mark("jump")
        val (ri, p) = index.locate(globalPage)
        view.show(PageView.Loc(ri, p), event = "jump")
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN) {
            view.index?.let { jump(Random.nextInt(it.totalPages)) }
            return true
        }
        return super.onKeyDown(keyCode, event)
    }

    private fun copyAsset(name: String): File {
        val out = File(cacheDir, "books/$name")
        if (!out.exists()) {
            out.parentFile!!.mkdirs()
            assets.open(name).use { input -> out.outputStream().use { input.copyTo(it) } }
        }
        return out
    }

    override fun onDestroy() {
        scope.cancel()
        super.onDestroy()
    }
}
