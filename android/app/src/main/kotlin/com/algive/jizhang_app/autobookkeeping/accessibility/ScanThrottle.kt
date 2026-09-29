package com.algive.jizhang_app.autobookkeeping.accessibility

/** One outstanding scan; subsequent events never postpone its deadline. */
internal class ScanThrottle {
    var pending = false
        private set

    fun request(): Boolean {
        if (pending) return false
        pending = true
        return true
    }

    fun consumed() { pending = false }
}
