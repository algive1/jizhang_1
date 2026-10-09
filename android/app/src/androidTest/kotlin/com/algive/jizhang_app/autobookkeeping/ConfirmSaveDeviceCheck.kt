package com.algive.jizhang_app.autobookkeeping

import android.app.Instrumentation
import android.app.UiAutomation
import android.accessibilityservice.AccessibilityService
import android.content.Intent
import android.graphics.Bitmap
import android.os.SystemClock
import android.view.accessibility.AccessibilityNodeInfo
import com.algive.jizhang_app.MainActivity
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore as Store
import java.io.File
import org.json.JSONArray

/** Uses a labeled one-cent fixture; existing pending bills remain in the durable inbox. */
class ConfirmSaveDeviceCheck(private val runner: Instrumentation) {
    fun cleanup(ids: List<String>): String {
        val context = runner.targetContext
        val ui = runner.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
        val activity = runner.startActivitySync(Intent(context, MainActivity::class.java)
            .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        for (id in ids) {
            check(id.startsWith("auto-"))
            runner.runOnMainSync { activity.startActivity(Intent(context, MainActivity::class.java)
                .putExtra("route", "/transactions/$id")) }
            waitFor { findLabel(ui.rootInActiveWindow, "确认页回归测试") != null }
            for (label in listOf("更多操作", "删除流水", "确认删除")) {
                waitFor { findLabel(ui.rootInActiveWindow, label, true) != null }
                check(findLabel(ui.rootInActiveWindow, label, true)!!
                    .performAction(AccessibilityNodeInfo.ACTION_CLICK))
                Thread.sleep(200)
            }
            waitFor { findLabel(ui.rootInActiveWindow, "交易详情") == null }
        }
        val prefs = context.getSharedPreferences("autobookkeeping.pending", 0)
        val inbox = JSONArray(prefs.getString("inbox", "[]"))
        val retained = JSONArray()
        for (index in 0 until inbox.length()) {
            val row = inbox.getJSONObject(index)
            if (!row.optString("orderId").startsWith("CONFIRM-REPAIR-")) retained.put(row)
        }
        prefs.edit().putString("inbox", retained.toString()).commit()
        return "PASS: deleted ${ids.size} labeled fixture transactions and reverted their balance effects; test inbox rows removed\n"
    }

    private fun findLabel(node: AccessibilityNodeInfo?, label: String,
        clickable: Boolean = false): AccessibilityNodeInfo? {
        if (node == null) return null
        if ((!clickable || node.isClickable) &&
            (node.text?.toString().orEmpty() + node.contentDescription?.toString().orEmpty()).contains(label)) return node
        for (index in 0 until node.childCount) findLabel(node.getChild(index), label, clickable)?.let { return it }
        return null
    }

    fun run(): String {
        val context = runner.targetContext
        val ui = runner.getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
        val original = Store.read(context)?.get("fingerprint") as? String
        val count = Store.pendingCount(context)
        val started = System.currentTimeMillis()
        val payment = PaymentCandidate(amountInCents = 1, merchantRaw = "确认页回归测试",
            merchantNormalized = "确认页回归测试", paymentMethod = "支付宝", timestamp = started,
            sourceApp = "ALIPAY", scene = PaymentScene("ALIPAY", "ALIPAY_PAYMENT_SUCCESS", 1.0),
            amountConfidence = 1.0, merchantConfidence = 1.0, orderId = "CONFIRM-REPAIR-$started")
        var identity: String? = null
        try {
            val activity = runner.startActivitySync(Intent(context, MainActivity::class.java)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
            check(AutoBookkeepingSettings.enabled(context)) { "Automatic bookkeeping must already be enabled" }
            runner.runOnMainSync { activity.startForegroundService(Intent(activity, AutoBillOverlayService::class.java)) }
            waitFor { AutoBookkeepingLogStore.read(context).any {
                it["stage"] == "confirmation_engine_ready" && (it["timestamp"] as Long) >= started } }
            check(ui.performGlobalAction(AccessibilityService.GLOBAL_ACTION_HOME))
            Thread.sleep(500)
            runner.runOnMainSync {
                Store.deferCurrent(context)
                Store.enqueueDecision(context, payment)
                identity = Store.inbox(context).single { it["orderId"] == payment.orderId }["fingerprint"] as String
                check(Store.select(context, identity!!))
                check(AutoBillOverlayService.instance!!.offer(payment))
            }
            waitFor { AutoBookkeepingConfirmActivity.instance?.hasWindowFocus() == true }
            Thread.sleep(2200) // Let the identification notice leave the category grid.
            screenshot(ui, "confirm-before.png")
            val complete = findComplete(ui.rootInActiveWindow)
            check(complete?.performAction(AccessibilityNodeInfo.ACTION_CLICK) == true) { "Completion button unavailable" }
            val clicked = SystemClock.elapsedRealtime()
            waitFor(6000) { AutoBookkeepingConfirmActivity.instance == null }
            check(Store.pendingCount(context) == count) { "The fixture was not completed" }
            check(AutoBookkeepingLogStore.read(context).any {
                it["stage"] == "confirmation_save_succeeded" && it["detail"].toString().contains("auto-$identity") })
            screenshot(ui, "confirm-after.png")
            return "PASS: saved once, host closed in ${SystemClock.elapsedRealtime() - clicked} ms; fixture=auto-$identity\n"
        } finally {
            runner.runOnMainSync {
                AutoBillOverlayService.instance?.closeConfirmation("test_finished")
                identity?.let { Store.ignore(context, it) }
                original?.let { Store.select(context, it) }
            }
        }
    }

    private fun waitFor(timeout: Long = 25000, condition: () -> Boolean) {
        val deadline = SystemClock.elapsedRealtime() + timeout
        while (!condition()) {
            check(SystemClock.elapsedRealtime() < deadline) { "Device confirmation timed out" }
            Thread.sleep(80)
        }
    }
    private fun findComplete(node: AccessibilityNodeInfo?): AccessibilityNodeInfo? {
        if (node == null) return null
        if (node.isClickable && (node.text?.toString() == "完成" || node.contentDescription?.toString() == "完成")) return node
        for (index in 0 until node.childCount) findComplete(node.getChild(index))?.let { return it }
        return null
    }
    private fun screenshot(ui: UiAutomation, name: String) {
        val bitmap = ui.takeScreenshot()
        File(runner.targetContext.getExternalFilesDir(null), name).outputStream().use {
            bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
        }
        bitmap.recycle()
    }
}
