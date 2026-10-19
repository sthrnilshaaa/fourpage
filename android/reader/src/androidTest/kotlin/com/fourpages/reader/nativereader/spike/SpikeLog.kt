package com.fourpages.reader.nativereader.spike

import android.os.Build
import android.os.SystemClock
import android.os.Trace
import android.util.Log
import java.util.concurrent.ConcurrentHashMap

/** Spike timings: logcat lines "ARead-Spike: <event> <ms>" plus async trace sections "spike:<name>". */
object SpikeLog {
    const val TAG = "ARead-Spike"
    private val marks = ConcurrentHashMap<String, Long>()
    private val cookies = ConcurrentHashMap<String, Int>()
    private var nextCookie = 1

    fun mark(name: String) {
        marks[name] = SystemClock.elapsedRealtimeNanos()
        if (Build.VERSION.SDK_INT >= 29) {
            val c = nextCookie++
            cookies[name] = c
            Trace.beginAsyncSection("spike:$name", c)
        }
    }

    /** Logs ms since [mark] of [name] as [event] (defaults to [name]) and ends its trace section. */
    fun since(name: String, event: String = name): Double? {
        val start = marks.remove(name) ?: return null
        val ms = (SystemClock.elapsedRealtimeNanos() - start) / 1e6
        if (Build.VERSION.SDK_INT >= 29) cookies.remove(name)?.let { Trace.endAsyncSection("spike:$name", it) }
        Log.i(TAG, "%s %.1f".format(event, ms))
        return ms
    }

    fun info(msg: String) = Log.i(TAG, msg)
}
