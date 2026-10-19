package com.fourpages.reader.nativereader.engine.layout

import java.io.DataInputStream
import java.io.DataOutputStream
import java.io.File

/** Page-start offsets per (book, layout key, chapter) on disk. Reads never throw: any problem is a miss. */
class LayoutCache(private val dir: File) {
    private fun file(bookKey: String, layoutKey: String, resourceIndex: Int) =
        File(dir, "$bookKey/$layoutKey/$resourceIndex.pages")

    fun read(bookKey: String, layoutKey: String, resourceIndex: Int): IntArray? = try {
        val f = file(bookKey, layoutKey, resourceIndex)
        if (!f.isFile) null else DataInputStream(f.inputStream().buffered()).use { input ->
            if (input.readInt() != MAGIC) return null
            val n = input.readInt()
            if (n <= 0 || n > 100_000) return null
            IntArray(n) { input.readInt() }
        }
    } catch (_: Exception) {
        null
    }

    /** Best effort: a failed write (full disk, unwritable dir) only costs a later re-layout. */
    fun write(bookKey: String, layoutKey: String, resourceIndex: Int, pageStarts: IntArray) {
        try {
            val f = file(bookKey, layoutKey, resourceIndex)
            f.parentFile?.mkdirs()
            val tmp = File(f.path + ".tmp")
            DataOutputStream(tmp.outputStream().buffered()).use { out ->
                out.writeInt(MAGIC)
                out.writeInt(pageStarts.size)
                pageStarts.forEach { out.writeInt(it) }
            }
            tmp.renameTo(f)
        } catch (_: Exception) {
        }
    }

    private companion object {
        const val MAGIC = 0x41524431 // "ARD1"
    }
}
