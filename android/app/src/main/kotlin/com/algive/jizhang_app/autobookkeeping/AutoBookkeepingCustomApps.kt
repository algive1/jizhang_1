package com.algive.jizhang_app.autobookkeeping

import android.content.Context

/**
 * Package names the user added themselves.
 *
 * This is what gives auto bookkeeping reach beyond the packaged rule set without
 * shipping a new build: every added package joins the accessibility service's
 * runtime whitelist and resolves to the generic rule template, so an app no rule
 * covers can still be recognised when its result page carries the usual
 * "payment succeeded / amount / merchant" shape.
 *
 * Storage is a plain `SharedPreferences` string set — the list is a handful of
 * package names, carries no personal data, and must be readable from the
 * accessibility service and from a background entry point without a database.
 */
object AutoBookkeepingCustomApps {
    private const val PREFS = "autobookkeeping"
    private const val KEY = "custom_apps_v1"

    /** Enough for any realistic set; also bounds the runtime whitelist. */
    const val MAX_APPS = 32

    fun all(context: Context): Set<String> =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .getStringSet(KEY, emptySet())
            .orEmpty()
            .filter { isValidPackage(it) }
            .take(MAX_APPS)
            .toSet()

    fun contains(context: Context, packageName: String): Boolean =
        packageName.trim() in all(context)

    /** Returns false when the name is not a usable package id. */
    fun add(context: Context, packageName: String): Boolean {
        val candidate = packageName.trim()
        if (!isValidPackage(candidate)) return false
        if (candidate == context.packageName) return false
        write(context, (all(context) + candidate).take(MAX_APPS).toSet())
        return true
    }

    fun remove(context: Context, packageName: String) {
        write(context, all(context) - packageName.trim())
    }

    private fun write(context: Context, value: Set<String>) {
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)
            .edit()
            // Defensive copy: SharedPreferences holds the set by reference and
            // the docs require callers not to mutate it afterwards.
            .putStringSet(KEY, HashSet(value))
            .apply()
    }

    /**
     * Conservative Android package-id shape check: at least two ASCII segments,
     * each starting with a letter. Rejects anything that could not be a real
     * application id, so a typo cannot silently widen the whitelist.
     */
    fun isValidPackage(value: String): Boolean {
        if (value.length !in 3..255) return false
        val segments = value.split('.')
        if (segments.size < 2) return false
        return segments.all { segment ->
            segment.isNotEmpty() &&
                (segment.first() in 'a'..'z' || segment.first() in 'A'..'Z') &&
                segment.all {
                    it in 'a'..'z' || it in 'A'..'Z' || it in '0'..'9' || it == '_'
                }
        }
    }
}
