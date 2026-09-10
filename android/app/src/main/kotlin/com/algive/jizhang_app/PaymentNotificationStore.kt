package com.algive.jizhang_app

import android.content.Context
import org.json.JSONArray
import org.json.JSONObject

object PaymentNotificationStore {
    const val PREFS_NAME = "payment_notifications"
    private const val KEY_PENDING = "pending"
    private const val MAX_PENDING = 100

    @Synchronized
    fun append(context: Context, item: JSONObject) {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val existing = readArray(prefs.getString(KEY_PENDING, "[]"))
        val id = item.optString("id")
        if (id.isEmpty() || (0 until existing.length()).any { existing.optJSONObject(it)?.optString("id") == id }) return
        existing.put(item)
        while (existing.length() > MAX_PENDING) existing.remove(0)
        prefs.edit().putString(KEY_PENDING, existing.toString()).apply()
    }

    @Synchronized
    fun read(context: Context): List<Map<String, String>> {
        val prefs = context.getSharedPreferences(PREFS_NAME, Context.MODE_PRIVATE)
        val array = readArray(prefs.getString(KEY_PENDING, "[]"))
        return (0 until array.length()).mapNotNull { index ->
            val item = array.optJSONObject(index) ?: return@mapNotNull null
            mapOf(
                "id" to item.optString("id"),
                "packageName" to item.optString("packageName"),
                "title" to item.optString("title"),
                "text" to item.optString("text"),
                "postedAt" to item.optString("postedAt"),
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

    private fun readArray(raw: String?): JSONArray = try {
        JSONArray(raw ?: "[]")
    } catch (_: Exception) {
        JSONArray()
    }
}
