package com.fourpages.reader.nativereader.core

import android.content.Context
import androidx.test.platform.app.InstrumentationRegistry
import java.io.File

/** Sample EPUBs bundled from repo-root test-books/ (and test-books/private/ when present). */
object TestBooks {
    private val assets get() = InstrumentationRegistry.getInstrumentation().context.assets

    fun all(@Suppress("UNUSED_PARAMETER") context: Context): List<String> {
        val root = assets.list("").orEmpty().filter { it.endsWith(".epub") }
        val private = assets.list("private").orEmpty().filter { it.endsWith(".epub") }.map { "private/$it" }
        return root + private
    }

    fun copy(context: Context, name: String): File {
        val out = File(context.cacheDir, "books/$name")
        if (!out.exists()) {
            out.parentFile!!.mkdirs()
            assets.open(name).use { input -> out.outputStream().use { input.copyTo(it) } }
        }
        return out
    }
}
