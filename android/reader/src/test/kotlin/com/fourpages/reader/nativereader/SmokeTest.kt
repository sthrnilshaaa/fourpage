package com.fourpages.reader.nativereader

import org.jsoup.Jsoup
import org.junit.Assert.assertEquals
import org.junit.Test

class SmokeTest {
    @Test
    fun smoke_jsoupParses() {
        assertEquals("Hi", Jsoup.parse("<p>Hi</p>").select("p").text())
    }
}
