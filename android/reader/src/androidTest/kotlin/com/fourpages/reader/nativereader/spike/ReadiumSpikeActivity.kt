package com.fourpages.reader.nativereader.spike

import android.os.Bundle
import android.view.KeyEvent
import android.view.View
import android.widget.FrameLayout
import androidx.fragment.app.FragmentActivity
import androidx.lifecycle.lifecycleScope
import com.fourpages.reader.nativereader.publication.BookOpener
import kotlinx.coroutines.launch
import org.readium.r2.navigator.epub.EpubNavigatorFactory
import org.readium.r2.navigator.epub.EpubNavigatorFragment
import org.readium.r2.navigator.epub.EpubPreferences
import org.readium.r2.navigator.preferences.Theme
import org.readium.r2.shared.publication.Locator
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.publication.services.locateProgression
import org.readium.r2.shared.publication.services.positions
import java.io.File
import kotlin.random.Random

/**
 * Spike (b): Readium's EPUB navigator (WebView per chapter) in a bare Activity.
 * Extras: book (asset path), progression (0–1, jump after first page). Volume-down jumps randomly.
 * Logs readium:firstPage (onCreate → first page loaded), readium:jump, readium:positions.
 */
class ReadiumSpikeActivity : FragmentActivity() {
    private var navigator: EpubNavigatorFragment? = null
    private lateinit var publication: Publication
    private var firstPageLogged = false

    override fun onCreate(savedInstanceState: Bundle?) {
        SpikeLog.mark("readium:firstPage")
        super.onCreate(savedInstanceState)
        val container = FrameLayout(this).apply { id = View.generateViewId() }
        setContentView(container)
        val name = intent.getStringExtra("book") ?: "pride.epub"
        val progression = intent.getDoubleExtra("progression", -1.0)

        lifecycleScope.launch {
            // Full parse (no manifest cache): the navigator relies on Readium's publication services.
            SpikeLog.mark("readium:open")
            publication = BookOpener(this@ReadiumSpikeActivity).open(copyAsset(name))
            SpikeLog.since("readium:open")
            val factory = EpubNavigatorFactory(publication).createFragmentFactory(
                initialLocator = null,
                initialPreferences = EpubPreferences(
                    fontSize = 1.0, lineHeight = 2.0, theme = Theme.SEPIA, scroll = false, publisherStyles = false,
                ),
                paginationListener = object : EpubNavigatorFragment.PaginationListener {
                    override fun onPageLoaded() {
                        if (!firstPageLogged) {
                            firstPageLogged = true
                            SpikeLog.since("readium:firstPage")
                            afterFirstPage(progression)
                        } else {
                            SpikeLog.since("readium:jump")
                        }
                    }
                },
            )
            supportFragmentManager.fragmentFactory = factory
            supportFragmentManager.beginTransaction()
                .add(container.id, EpubNavigatorFragment::class.java, null, "nav")
                .commitNow()
            navigator = supportFragmentManager.findFragmentByTag("nav") as EpubNavigatorFragment
        }
    }

    private fun afterFirstPage(progression: Double) {
        lifecycleScope.launch {
            SpikeLog.mark("readium:positions")
            val n = publication.positions().size
            SpikeLog.since("readium:positions")
            SpikeLog.info("readium:positionCount=$n")
            if (progression >= 0) jump(progression)
        }
    }

    private fun jump(progression: Double) {
        lifecycleScope.launch {
            val locator: Locator = publication.locateProgression(progression) ?: return@launch
            SpikeLog.mark("readium:jump")
            navigator?.go(locator)
        }
    }

    override fun onKeyDown(keyCode: Int, event: KeyEvent?): Boolean {
        if (keyCode == KeyEvent.KEYCODE_VOLUME_DOWN && navigator != null) {
            jump(Random.nextDouble())
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
}
