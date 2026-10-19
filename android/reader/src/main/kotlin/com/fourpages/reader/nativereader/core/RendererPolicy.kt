package com.fourpages.reader.nativereader.core

import com.fourpages.reader.nativereader.publication.readBytes
import org.readium.r2.shared.publication.Layout
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.publication.ReadingProgression
import org.readium.r2.shared.publication.epub.contains

/** Which renderer a book should use: the native PageEngine, or the book's original layout (WebView). */
data class RendererDecision(val renderer: String, val reason: String) {
    val native: Boolean get() = renderer == NATIVE

    companion object {
        const val NATIVE = "native"
        const val ORIGINAL = "original"
    }
}

/**
 * Spec §5.3: the PageEngine's CSS subset can't lay out fixed-layout pages, vertical text,
 * right-to-left books or MathML faithfully; those keep their original layout.
 */
object RendererPolicy {
    private val vertical = Regex("writing-mode\\s*:\\s*vertical", RegexOption.IGNORE_CASE)

    suspend fun decide(publication: Publication): RendererDecision {
        fun original(reason: String) = RendererDecision(RendererDecision.ORIGINAL, reason)
        if (publication.metadata.layout == Layout.FIXED) return original("fixed layout")
        if (publication.metadata.readingProgression == ReadingProgression.RTL) return original("right-to-left")
        if (publication.readingOrder.any { "mathml" in it.properties.contains }) return original("MathML")
        // Markup of the first chapters, and every stylesheet.
        for (link in publication.readingOrder.take(6)) {
            val text = publication.readBytes(link.url())?.decodeToString() ?: continue
            if (text.contains("<math", ignoreCase = true)) return original("MathML")
            if (vertical.containsMatchIn(text)) return original("vertical text")
        }
        for (link in publication.resources.filter { it.mediaType?.toString()?.contains("css") == true }) {
            val css = publication.readBytes(link.url())?.decodeToString() ?: continue
            if (vertical.containsMatchIn(css)) return original("vertical text")
        }
        return RendererDecision(RendererDecision.NATIVE, "")
    }
}
