package com.algive.jizhang_app.autobookkeeping.overlay

/** A user edit, including clearing/reverting the text, wins over late parsing. */
internal class ReviewNote(initial: String) {
    var value = initial
        private set
    private var edited = false

    fun edit(text: String) { value = text; edited = true }

    fun enrich(text: String): Boolean {
        if (edited || text.isBlank() || text == value) return false
        value = text
        return true
    }
}
