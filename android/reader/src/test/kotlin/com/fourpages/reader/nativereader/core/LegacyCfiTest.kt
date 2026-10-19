package com.fourpages.reader.nativereader.core

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class LegacyCfiTest {
    @Test fun cfiSpine_parses() {
        assertEquals(6, LegacyCfi.spineIndex("epubcfi(/6/14!/4/2/1:0)"))
        assertEquals(0, LegacyCfi.spineIndex("epubcfi(/6/2!/4)"))
        assertNull(LegacyCfi.spineIndex("chapter.xhtml"))
        assertNull(LegacyCfi.spineIndex(null))
    }

    private val doc = org.jsoup.Jsoup.parse(
        "<html><head><title>t</title></head><body><p>Hello world</p><p>Second <b>bold</b> text</p></body></html>"
    )

    @Test fun visibleChars_textStepWithOffset() {
        assertEquals(13, LegacyCfi.visibleCharsBefore(doc, "epubcfi(/6/2!/4/4/1:3)"))
    }

    @Test fun visibleChars_elementStep() {
        assertEquals(10, LegacyCfi.visibleCharsBefore(doc, "epubcfi(/6/2!/4/4)"))
        assertEquals(16, LegacyCfi.visibleCharsBefore(doc, "epubcfi(/6/2!/4/4/2)")) // <b>
    }

    @Test fun visibleChars_rangeUsesStart() {
        assertEquals(10, LegacyCfi.visibleCharsBefore(doc, "epubcfi(/6/2!/4/4,/1:0,/1:5)"))
    }

    @Test fun visibleChars_badPath_null() {
        assertNull(LegacyCfi.visibleCharsBefore(doc, "epubcfi(/6/2!/4/40)"))
        assertNull(LegacyCfi.visibleCharsBefore(doc, "epubcfi(/6/2)"))
    }

    @Test fun cfiFor_textInSecondParagraph() {
        assertEquals("epubcfi(/6/2!/4/4/1:3)", LegacyCfi.cfiFor(doc, 2, 13))
        assertEquals("epubcfi(/6/2!/4/2/1:0)", LegacyCfi.cfiFor(doc, 2, 0))
    }

    @Test fun cfiFor_roundTripsWithVisibleChars() {
        val total = "HelloworldSecondboldtext".length
        for (n in 0..total) {
            val cfi = LegacyCfi.cfiFor(doc, 2, n)!!
            assertEquals("n=$n cfi=$cfi", n.coerceAtMost(total), LegacyCfi.visibleCharsBefore(doc, cfi))
        }
    }

    @Test fun cfiRange_commonParent() {
        // "Hello" in the first paragraph, and a range across both paragraphs.
        assertEquals("epubcfi(/6/2!/4/2/1,:0,:5)", LegacyCfi.cfiRange(doc, 2, 0, 5))
        val across = LegacyCfi.cfiRange(doc, 2, 5, 13)!!
        assertEquals("epubcfi(/6/2!/4,/2/1:6,/4/1:3)", across)
        assertEquals(5, LegacyCfi.visibleCharsBefore(doc, across))
    }
}
