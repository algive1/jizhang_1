package com.algive.jizhang_app.autobookkeeping

import android.content.Context
import android.os.Handler
import android.os.HandlerThread
import com.algive.jizhang_app.BuildConfig

/** Local ring buffer for the automatic bookkeeping flow. Detailed records are debug-only. */
object AutoBookkeepingLogStore {
    private const val PREFS = "autobookkeeping_logs"
    private const val KEY_LINES = "lines"
    private const val MAX_LINES = 500
    private const val MAX_DETAIL_CHARS = 2_000
    private const val MAX_SUMMARY_CHARS = 160
    private const val FLUSH_BATCH_SIZE = 32
    private const val FLUSH_DELAY_MS = 1500L
    private val lock = Any()
    private val pending = ArrayDeque<String>()
    private val workerThread = HandlerThread("AutoBookkeepingLogs").apply { start() }
    private val handler = Handler(workerThread.looper)
    private var appContext: Context? = null
    private var flushScheduled = false
    @Volatile private var releaseDetailsCleared = BuildConfig.DEBUG
    private val flushTask = Runnable {
        synchronized(lock) { appContext?.let(::flushLocked) }
    }

    fun record(context: Context, stage: String, detail: String) {
        clearPreviouslyStoredDetails(context)
        enqueue(context, stage, detail, MAX_SUMMARY_CHARS)
    }

    fun recordDetailed(context: Context, stage: String, detail: String) {
        if (!BuildConfig.DEBUG) {
            clearPreviouslyStoredDetails(context)
            return
        }
        enqueue(context, "debug:${stage.take(34)}", detail, MAX_DETAIL_CHARS)
    }

    fun clearDetailed(context: Context) {
        clearPreviouslyStoredDetails(context)
    }

    private fun enqueue(context: Context, stage: String, detail: String, maxChars: Int) {
        val safeDetail = detail
            .replace('|', '\uFF5C')
            .replace('\r', ' ')
            .replace('\n', '\u21B5')
            .take(maxChars)
        val line = "${System.currentTimeMillis()}|${stage.take(40)}|$safeDetail"
        synchronized(lock) {
            appContext = context.applicationContext
            pending.addLast(line)
            if (!flushScheduled) {
                flushScheduled = true
                handler.postDelayed(flushTask, if (pending.size >= FLUSH_BATCH_SIZE) 0L else FLUSH_DELAY_MS)
            } else if (pending.size >= FLUSH_BATCH_SIZE) {
                handler.removeCallbacks(flushTask)
                handler.post(flushTask)
            }
        }
    }

    fun read(context: Context): List<Map<String, Any>> {
        clearPreviouslyStoredDetails(context)
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
                    "stage" to parts[1].removePrefix("debug:"),
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
            handler.removeCallbacksAndMessages(null)
            context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
                .edit()
                .remove(KEY_LINES)
                .apply()
            releaseDetailsCleared = true
        }
    }

    private fun clearPreviouslyStoredDetails(context: Context) {
        if (BuildConfig.DEBUG || releaseDetailsCleared) return
        synchronized(lock) {
            if (releaseDetailsCleared) return
            val preferences = context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            val lines = preferences.getString(KEY_LINES, "").orEmpty()
                .lineSequence()
                .filter(String::isNotBlank)
                .filterNot { line ->
                    line.split('|', limit = 3).getOrNull(1).orEmpty().startsWith("debug:")
                }
                .joinToString("\n")
            preferences.edit().putString(KEY_LINES, lines).apply()
            releaseDetailsCleared = true
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
