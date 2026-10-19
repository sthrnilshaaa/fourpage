package com.fourpages.reader.nativereader.engine.render

import android.graphics.Bitmap
import android.util.Size

/**
 * Images by resolved href. [measure] reads sizes only (for layout); [prepare] decodes pixels (for
 * drawing). [size]/[bitmap] then answer from memory.
 */
interface ImageSource {
    suspend fun measure(hrefs: Collection<String>)
    suspend fun prepare(hrefs: Collection<String>)
    fun size(href: String): Size?
    fun bitmap(href: String): Bitmap?
}
