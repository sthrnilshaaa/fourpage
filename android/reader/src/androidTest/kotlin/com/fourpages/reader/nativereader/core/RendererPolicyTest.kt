package com.fourpages.reader.nativereader.core

import androidx.test.ext.junit.runners.AndroidJUnit4
import androidx.test.platform.app.InstrumentationRegistry
import com.fourpages.reader.nativereader.publication.BookOpener
import kotlinx.coroutines.runBlocking
import org.junit.Assert.assertEquals
import org.junit.Test
import org.junit.runner.RunWith
import java.io.File
import java.util.zip.CRC32
import java.util.zip.ZipEntry
import java.util.zip.ZipOutputStream

@RunWith(AndroidJUnit4::class)
class RendererPolicyTest {
    private val ctx = InstrumentationRegistry.getInstrumentation().targetContext

    /** A minimal EPUB 3: [opfMeta] goes in <metadata>, [chapter] is the body of the only chapter. */
    private fun epub(name: String, opfMeta: String, chapter: String): File {
        val out = File(ctx.cacheDir, "policy/$name.epub").apply { parentFile!!.mkdirs(); delete() }
        ZipOutputStream(out.outputStream()).use { zip ->
            val mime = "application/epub+zip".toByteArray()
            zip.putNextEntry(ZipEntry("mimetype").apply {
                method = ZipEntry.STORED; size = mime.size.toLong(); crc = CRC32().apply { update(mime) }.value
            })
            zip.write(mime); zip.closeEntry()
            fun put(path: String, text: String) { zip.putNextEntry(ZipEntry(path)); zip.write(text.toByteArray()); zip.closeEntry() }
            put("META-INF/container.xml", """<?xml version="1.0"?><container version="1.0" xmlns="urn:oasis:names:tc:opendocument:xmlns:container"><rootfiles><rootfile full-path="OEBPS/content.opf" media-type="application/oebps-package+xml"/></rootfiles></container>""")
            put("OEBPS/content.opf", """<?xml version="1.0"?><package xmlns="http://www.idpf.org/2007/opf" version="3.0" unique-identifier="id"><metadata xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:identifier id="id">$name</dc:identifier><dc:title>$name</dc:title><dc:language>en</dc:language>$opfMeta</metadata><manifest><item id="nav" href="nav.xhtml" media-type="application/xhtml+xml" properties="nav"/><item id="c1" href="c1.xhtml" media-type="application/xhtml+xml"/></manifest><spine><itemref idref="c1"/></spine></package>""")
            put("OEBPS/nav.xhtml", """<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml" xmlns:epub="http://www.idpf.org/2007/ops"><body><nav epub:type="toc"><ol><li><a href="c1.xhtml">One</a></li></ol></nav></body></html>""")
            put("OEBPS/c1.xhtml", """<?xml version="1.0"?><html xmlns="http://www.w3.org/1999/xhtml"><head><title>c</title></head><body>$chapter</body></html>""")
        }
        return out
    }

    private fun decide(file: File) = runBlocking { RendererPolicy.decide(BookOpener(ctx).open(file)) }

    @Test fun policy_novel_native() {
        assertEquals(RendererDecision.NATIVE, decide(TestBooks.copy(ctx, "pride.epub")).renderer)
        assertEquals(RendererDecision.NATIVE, decide(epub("plain", "", "<p>Just text.</p>")).renderer)
    }

    @Test fun policy_fixedLayout_original() {
        val d = decide(epub("fxl", """<meta property="rendition:layout">pre-paginated</meta>""", "<p>Page</p>"))
        assertEquals(RendererDecision.ORIGINAL, d.renderer)
        assertEquals("fixed layout", d.reason)
    }

    @Test fun policy_mathml_original() {
        val d = decide(epub("math", "", """<p>x</p><math xmlns="http://www.w3.org/1998/Math/MathML"><mi>x</mi></math>"""))
        assertEquals(RendererDecision.ORIGINAL, d.renderer)
        assertEquals("MathML", d.reason)
    }

    @Test fun policy_verticalText_original() {
        val d = decide(epub("vert", "", """<p style="writing-mode: vertical-rl">縦書き</p>"""))
        assertEquals(RendererDecision.ORIGINAL, d.renderer)
    }
}
