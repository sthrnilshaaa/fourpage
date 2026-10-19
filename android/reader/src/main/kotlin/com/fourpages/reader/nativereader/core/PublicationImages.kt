package com.fourpages.reader.nativereader.core

import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.util.LruCache
import android.util.Size
import com.fourpages.reader.nativereader.engine.render.ImageSource
import com.fourpages.reader.nativereader.publication.readBytes
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.util.Url
import java.util.concurrent.ConcurrentHashMap

/** Publication images: sizes (bounds-only decode) for the whole book, pixels in a small LRU. */
class PublicationImages(private val publication: Publication, private val maxSidePx: Int = 2048) : ImageSource {
    private val sizes = ConcurrentHashMap<String, Size>()
    private val missing = ConcurrentHashMap.newKeySet<String>()
    private val bitmaps = object : LruCache<String, Bitmap>(24 * 1024 * 1024) {
        override fun sizeOf(key: String, value: Bitmap) = value.byteCount
    }

    override suspend fun measure(hrefs: Collection<String>) {
        for (href in hrefs) {
            if (sizes.containsKey(href) || href in missing) continue
            val bytes = read(href) ?: continue
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            if (bounds.outWidth <= 0 || bounds.outHeight <= 0) missing += href
            else sizes[href] = Size(bounds.outWidth, bounds.outHeight)
        }
    }

    override suspend fun prepare(hrefs: Collection<String>) {
        measure(hrefs)
        for (href in hrefs) {
            if (bitmaps.get(href) != null || href in missing) continue
            val size = sizes[href] ?: continue
            val bytes = read(href) ?: continue
            var sample = 1
            while (maxOf(size.width, size.height) / sample > maxSidePx) sample *= 2
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, BitmapFactory.Options().apply { inSampleSize = sample })
                ?.let { bitmaps.put(href, it) }
        }
    }

    override fun size(href: String): Size? = sizes[href]
    override fun bitmap(href: String): Bitmap? = bitmaps.get(href)

    private suspend fun read(href: String): ByteArray? =
        Url(href)?.let { publication.readBytes(it) }.also { if (it == null) missing += href }
}
