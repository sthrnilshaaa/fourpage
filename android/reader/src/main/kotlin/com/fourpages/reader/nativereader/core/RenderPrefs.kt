package com.fourpages.reader.nativereader.core

import android.graphics.Typeface
import com.fourpages.reader.nativereader.engine.layout.LayoutParams
import com.fourpages.reader.nativereader.engine.parse.Align
import java.io.File
import java.util.concurrent.ConcurrentHashMap

/** Reader settings as the Flutter side knows them (ReaderPreferences + app page padding + theme colours). */
data class RenderPrefs(
    /** Font file on disk (written by Flutter from its bundled fonts); null = system serif. */
    val fontPath: String?,
    val fontKey: String,
    val fontSizeSp: Float,
    val lineHeight: Float,
    /** left | right | center | justify */
    val textAlign: String,
    val publisherStyles: Boolean,
    val pageColor: Int,
    val textColor: Int,
    val paddingDp: Float,
)

/** A saved highlight or note to draw on the page. [start]/[end] are chapter char offsets. */
data class Highlight(val id: String, val resourceIndex: Int, val start: Int, val end: Int, val color: Int)

private val typefaces = ConcurrentHashMap<String, Typeface>()

fun RenderPrefs.typeface(): Typeface = fontPath
    ?.takeIf { File(it).isFile }
    ?.let { path -> typefaces.getOrPut(path) { runCatching { Typeface.createFromFile(path) }.getOrDefault(Typeface.SERIF) } }
    ?: Typeface.SERIF

fun RenderPrefs.toLayoutParams(widthPx: Int, heightPx: Int, density: Float, scaledDensity: Float): LayoutParams {
    val align = when (textAlign) {
        "justify" -> Align.JUSTIFY
        "center" -> Align.CENTER
        "right" -> Align.END
        else -> Align.START
    }
    return LayoutParams(
        widthPx = widthPx,
        heightPx = heightPx,
        paddingPx = (paddingDp * density).toInt(),
        textSizePx = fontSizeSp * scaledDensity,
        lineHeightMult = lineHeight,
        typeface = typeface(),
        justify = align == Align.JUSTIFY,
        hyphenate = true,
        textColor = textColor,
        backgroundColor = pageColor,
        fontKey = fontKey,
        density = density,
        alignOverride = align,
        publisherStyles = publisherStyles,
    )
}
