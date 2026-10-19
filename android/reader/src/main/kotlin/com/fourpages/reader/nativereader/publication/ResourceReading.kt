package com.fourpages.reader.nativereader.publication

import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.util.Url

/** Reads a whole publication resource, or null if it's missing or unreadable. */
suspend fun Publication.readBytes(url: Url): ByteArray? {
    val resource = get(url) ?: return null
    return try {
        resource.read().getOrNull()
    } finally {
        resource.close()
    }
}
