package com.fourpages.reader.nativereader.spike

import android.util.Log

/** Poor man's profiler: samples stacks of threads running Readium code and logs the hottest frames. */
class StackSampler(private val intervalMs: Long = 10) {
    private val counts = HashMap<String, Int>()
    @Volatile private var running = true
    private var samples = 0
    private val thread = Thread {
        while (running) {
            for ((_, stack) in Thread.getAllStackTraces()) {
                if (stack.none { it.className.startsWith("org.readium") }) continue
                samples++
                // Count each distinct frame once per sample ("inclusive" time).
                stack.take(40).map { "${it.className}.${it.methodName}" }.toSet().forEach { counts[it] = (counts[it] ?: 0) + 1 }
            }
            Thread.sleep(intervalMs)
        }
    }.apply { isDaemon = true; start() }

    fun stop(top: Int = 40) {
        running = false
        thread.join()
        Log.i(SpikeLog.TAG, "profile samples=$samples")
        counts.entries.sortedByDescending { it.value }.take(top).forEach { Log.i(SpikeLog.TAG, "profile ${it.value} ${it.key}") }
    }
}
