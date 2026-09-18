package com.algive.jizhang_app.autobookkeeping

import android.content.Context
import android.os.Handler
import android.os.Looper

/** Small, redacted ring buffer for diagnosing the automatic bookkeeping flow. */
object AutoBookkeepingLogStore {
    private const val PREFS = "autobookkeeping_logs"
    private const val KEY_LINES = "lines"
    private const val MAX_LINES = 120
    private const val FLUSH_DELAY_MS = 1500L
    private val lock = Any()
    private val pending = ArrayDeque<String>()
    private val handler = Handler(Looper.getMainLooper())
    private var flushScheduled = false

    fun record(context: Context, stage: String, detail: String) {
        val line = "${System.currentTimeMillis()}|${stage.take(40)}|${detail.replace('|', '/').take(160)}"
        synchronized(lock) {
            pending.addLast(line)
            if (pending.size >= 8) {
                flushLocked(context.applicationContext)
            } else if (!flushScheduled) {
                flushScheduled = true
                handler.postDelayed({
                    synchronized(lock) {
                        flushLocked(context.applicationContext)
                    }
                }, FLUSH_DELAY_MS)
            }
        }
    }

    fun read(context: Context): List<Map<String, Any>> {
        flushPending(context.applicationContext)
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_LINES, "")
            .orEmpty()
            .lineSequence()
            .mapNotNull { line ->
                val parts = line.split('|', limit = 3)
                if (parts.size != 3) return@mapNotNull null
                mapOf(
                    "timestamp" to (parts[0].toLongOrNull() ?: return@mapNotNull null),
                    "stage" to parts[1],
                    "detail" to parts[2],
                )
            }
            .toList()
            .asReversed()
    }

    fun clear(context: Context) {
        synchronized(lock) {
            pending.clear()
            flushScheduled = false
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_LINES)
                .apply()
        }
    }

    private fun flushPending(context: Context) {
        synchronized(lock) { flushLocked(context) }
    }

    private fun flushLocked(context: Context) {
        if (pending.isEmpty()) {
            flushScheduled = false
            return
        }
        val existing = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getString(KEY_LINES, "")
            .orEmpty()
            .lineSequence()
            .filter(String::isNotBlank)
            .toMutableList()
        while (pending.isNotEmpty()) existing.add(pending.removeFirst())
        val retained = existing.takeLast(MAX_LINES).joinToString("\n")
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            .putString(KEY_LINES, retained)
            .apply()
        flushScheduled = false
    }
}
