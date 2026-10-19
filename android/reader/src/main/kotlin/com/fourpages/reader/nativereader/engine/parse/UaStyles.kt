package com.fourpages.reader.nativereader.engine.parse

import org.jsoup.nodes.Element

/** Built-in user-agent defaults only (publisher styles off). */
object UaStyles {
    private val resolver = ThreadLocal.withInitial { StyleResolver(emptyList(), publisherStyles = false) }
    fun of(e: Element): BlockStyle = resolver.get()!!.of(e)
}
