package com.algive.jizhang_app.autobookkeeping.accessibility

/** The WeChat payment review starts only after the user presses Complete. */
internal class PaymentCompletionGate {
    var waiting = false; private set
    var clicked = false; private set
    var heldResult = false; private set

    fun begin() { if (!waiting) { waiting = true; clicked = false; heldResult = false } }
    fun defer(source: String, type: String, scene: String = "QIANJI_WeChatPaySuccess"): Boolean {
        if (!waiting || source != "WECHAT" || type != "EXPENSE") return false
        if (scene != "QIANJI_WeChatPaySuccess" && scene != "PAYMENT_SUCCESS" && !scene.startsWith("PAYMENT_NOTIFICATION")) return false
        heldResult = true
        return true
    }
    fun complete(packageName: String?, label: String): Boolean {
        if (!waiting || !heldResult || clicked || packageName != "com.tencent.mm" || label.trim() != "完成") return false
        clicked = true
        return true
    }
    fun release() { waiting = false; clicked = false; heldResult = false }
}
