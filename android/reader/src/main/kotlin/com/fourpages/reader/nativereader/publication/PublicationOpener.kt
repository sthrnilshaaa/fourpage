package com.fourpages.reader.nativereader.publication

import android.content.Context
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject
import org.readium.r2.shared.publication.Manifest
import org.readium.r2.shared.publication.Publication
import org.readium.r2.shared.publication.encryption.encryption
import org.readium.r2.shared.util.asset.ContainerAsset
import org.readium.r2.shared.util.asset.AssetRetriever
import org.readium.r2.shared.util.getOrElse
import org.readium.r2.shared.util.http.DefaultHttpClient
import org.readium.r2.streamer.PublicationOpener
import org.readium.r2.streamer.parser.DefaultPublicationParser
import java.io.File

/**
 * Opens EPUB files with Readium's streamer (parsing only; rendering is ours).
 *
 * With [manifestCache], the parsed manifest is saved as JSON after the first open and later opens
 * rebuild the publication from it plus the zip, skipping OPF/NCX parsing (over a second for books
 * with a long NCX page-list). Books with encrypted resources (obfuscated fonts) always take the
 * full parse, since the cached path doesn't set up Readium's deobfuscation.
 */
class BookOpener(context: Context, private val manifestCache: File? = null) {
    private val http = DefaultHttpClient()
    private val retriever = AssetRetriever(context.contentResolver, http)
    private val opener = PublicationOpener(
        publicationParser = DefaultPublicationParser(
            context, httpClient = http, assetRetriever = retriever, pdfFactory = null,
        ),
    )

    /** Whether the last [open] came from the manifest cache. */
    @Volatile var lastOpenFromCache: Boolean = false
        private set

    /** Throws [IllegalStateException] with Readium's message when the book can't be opened. */
    suspend fun open(file: File): Publication = withContext(Dispatchers.IO) {
        val asset = retriever.retrieve(file).getOrElse { throw IllegalStateException("Can't read ${file.name}: ${it.message}") }
        val cached = manifestFile(file)?.let { readManifest(it) }
        if (cached != null && asset is ContainerAsset) {
            lastOpenFromCache = true
            return@withContext Publication(cached, asset.container)
        }
        lastOpenFromCache = false
        val pub = opener.open(asset, allowUserInteraction = false)
            .getOrElse { throw IllegalStateException("Can't open ${file.name}: ${it.message}") }
        manifestFile(file)?.let { f -> if (!hasEncryption(pub.manifest)) writeManifest(f, pub.manifest) }
        pub
    }

    private fun manifestFile(file: File): File? = manifestCache?.let {
        File(it, "${file.name.hashCode().toUInt().toString(16)}-${file.length()}-${file.lastModified()}.json")
    }

    private fun readManifest(f: File): Manifest? = try {
        if (f.isFile) Manifest.fromJSON(JSONObject(f.readText()), warnings = null) else null
    } catch (_: Exception) {
        null
    }

    private fun writeManifest(f: File, manifest: Manifest) {
        try {
            f.parentFile?.mkdirs()
            val tmp = File(f.path + ".tmp")
            tmp.writeText(manifest.toJSON().toString())
            tmp.renameTo(f)
        } catch (_: Exception) {
            // A failed cache write only costs the next open a full parse.
        }
    }

    private fun hasEncryption(m: Manifest): Boolean =
        (m.readingOrder + m.resources).any { it.properties.encryption != null }

    companion object {
        /** Identifies one version of a book file for the layout cache. */
        fun bookKey(file: File, publication: Publication): String =
            "${file.length()}|${file.lastModified()}|${publication.metadata.identifier}".hashCode().toUInt().toString(16)
    }
}
