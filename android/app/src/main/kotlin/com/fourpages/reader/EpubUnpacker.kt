package com.fourpages.reader

import android.os.Handler
import android.os.Looper
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.util.concurrent.Executors
import java.util.zip.ZipFile

/**
 * Unpacks EPUBs for the reader.
 *
 * The reader used to receive each book as one base64 string over the
 * JavaScript bridge and unzip all of it in JavaScript before showing a page.
 * Instead, a book is extracted here once (native zip, background thread)
 * into app storage, and the WebView's asset loader serves its files
 * directly, so epub.js only fetches the chapters it needs.
 *
 * Channel `fourpages/epub`:
 *  - `unpack {zipPath, outDir}` -> outDir, once the book is there. A marker
 *    file records which copy of the EPUB was extracted, so a replaced book
 *    is extracted again and an unchanged one is not.
 *  - `remove {outDir}` deletes an unpacked book.
 */
class EpubUnpacker(messenger: BinaryMessenger) {
    private val executor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    init {
        MethodChannel(messenger, "fourpages/epub").setMethodCallHandler { call, result ->
            fun reply(block: () -> Any?) = executor.execute {
                try {
                    val value = block()
                    mainHandler.post { result.success(value) }
                } catch (e: Exception) {
                    mainHandler.post { result.error("epub", e.message, null) }
                }
            }
            when (call.method) {
                "unpack" -> reply {
                    unpack(File(call.argument<String>("zipPath")!!), File(call.argument<String>("outDir")!!))
                }
                "remove" -> reply {
                    File(call.argument<String>("outDir")!!).deleteRecursively()
                    null
                }
                else -> result.notImplemented()
            }
        }
    }

    private fun unpack(zip: File, outDir: File): String {
        val stamp = "${zip.length()}:${zip.lastModified()}"
        val marker = File(outDir, MARKER)
        if (marker.exists() && marker.readText() == stamp) return outDir.path

        // Extract next to the target and swap in, so a reader never sees a
        // half-written book (and a crash mid-way leaves no broken copy).
        val temp = File(outDir.parentFile, "${outDir.name}.partial")
        temp.deleteRecursively()
        temp.mkdirs()
        val root = temp.canonicalPath + File.separator
        ZipFile(zip).use { archive ->
            val entries = archive.entries()
            while (entries.hasMoreElements()) {
                val entry = entries.nextElement()
                val target = File(temp, entry.name)
                // Zip-slip guard: entries must stay inside the book folder.
                if (!target.canonicalPath.startsWith(root)) continue
                if (entry.isDirectory) {
                    target.mkdirs()
                    continue
                }
                target.parentFile?.mkdirs()
                archive.getInputStream(entry).use { input ->
                    target.outputStream().buffered(64 * 1024).use { output -> input.copyTo(output, 64 * 1024) }
                }
            }
        }
        File(temp, MARKER).writeText(stamp)
        outDir.deleteRecursively()
        if (!temp.renameTo(outDir)) {
            temp.copyRecursively(outDir, overwrite = true)
            temp.deleteRecursively()
        }
        return outDir.path
    }

    companion object {
        private const val MARKER = ".aread-unpacked"
    }
}
