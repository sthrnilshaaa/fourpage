package com.fourpages.reader.nativereader.engine

import android.content.res.Resources
import android.graphics.Typeface
import com.fourpages.reader.nativereader.engine.layout.LayoutParams
import com.fourpages.reader.nativereader.engine.parse.Chapter
import com.fourpages.reader.nativereader.engine.parse.XhtmlParser

object TestChapters {
    private const val LOREM = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor " +
        "incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation " +
        "ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit."

    fun lorem(paragraphs: Int = 30): Chapter {
        val body = buildString {
            append("<h1>Chapter One</h1>")
            repeat(paragraphs) { append("<p>").append(LOREM).append(" <i>Paragraph $it.</i></p>") }
        }
        return XhtmlParser.parse("<html><body>$body</body></html>", 0, "lorem.xhtml")
    }

    fun sp(v: Float) = v * Resources.getSystem().displayMetrics.scaledDensity
    fun dp(v: Float) = (v * Resources.getSystem().displayMetrics.density).toInt()

    fun params(textSp: Float = 18f, textColor: Int = 0xFF2B2620.toInt(), bg: Int = 0xFFC2BAA5.toInt()) = LayoutParams(
        widthPx = 1080, heightPx = 2200, paddingPx = dp(24f), textSizePx = sp(textSp), lineHeightMult = 2.0f,
        typeface = Typeface.SERIF, fontKey = "serif", justify = true, hyphenate = true, textColor = textColor, backgroundColor = bg,
    )

}
