package com.algive.jizhang_app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object PaymentNotificationStore {
    const val PREFS_NAME = "payment_notifications"
    private const val KEY_PENDING = "pending"
    private const val MAX_PENDING = 100
    private const val RECOVERY_TTL_MILLIS = 30 * 60 * 1000L

    @Synchronized
    fun append(context: Context, item: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = pruneExpired(
            readArray(prefs.getString(KEY_PENDING, "[]")),
            System.currentTimeMillis(),
        )
        val id = item.optString("id")
        if (
            id.isEmpty() ||
            (0 until existing.length()).any {
                existing.optJSONObject(it)?.optString("id") == id
            }
        ) {
            return
        }
        existing.put(item)
        while (existing.length() > MAX_PENDING) existing.remove(0)
        prefs.edit().putString(KEY_PENDING, existing.toString()).apply()
    }

    @Synchronized
    fun read(context: Context): List<Map<String, String>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val original = readArray(prefs.getString(KEY_PENDING, "[]"))
        val array = pruneExpired(original, System.currentTimeMillis())
        if (array.length() != original.length()) {
            prefs.edit().putString(KEY_PENDING, array.toString()).apply()
        }
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            mapOf(
                "id" to item.optString("id"),
                "packageName" to item.optString("packageName"),
                "title" to item.optString("title"),
                "text" to item.optString("text"),
                "postedAt" to item.optString("postedAt"),
                "postedAtMillis" to item.optLong("postedAtMillis", 0L).toString(),
            )
        }
    }

    @Synchronized
    fun acknowledge(context: Context, ids: List<String>) {
        if (ids.isEmpty()) return
        val idSet = ids.toSet()
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = readArray(prefs.getString(KEY_PENDING, "[]"))
        val retained = JSONArray()
        for (index in 0 until existing.length()) {
            val item = existing.optJSONObject(index) ?: continue
            if (item.optString("id") !in idSet) retained.put(item)
        }
        prefs.edit().putString(KEY_PENDING, retained.toString()).apply()
    }

    private fun pruneExpired(array: JSONArray, now: Long): JSONArray {
        val retained = JSONArray()
        for (index in 0 until array.length()) {
            val item = array.optJSONObject(index) ?: continue
            val postedAtMillis = item.optLong("postedAtMillis", 0L)
            if (
                postedAtMillis > 0L &&
                (postedAtMillis > now + 5 * 60 * 1000L ||
                    now - postedAtMillis > RECOVERY_TTL_MILLIS)
            ) {
                continue
            }
            retained.put(item)
        }
        return retained
    }

    private fun readArray(raw: String?): JSONArray = try {
        JSONArray(raw ?: "[]")
    } catch (_: Exception) {
        JSONArray()
    }
}
