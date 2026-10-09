package com.algive.jizhang_app.autobookkeeping

import android.app.Activity
import android.app.Instrumentation
import android.app.UiAutomation
import android.content.Context
import android.content.ContextWrapper
import android.content.Intent
import android.content.SharedPreferences
import android.graphics.Bitmap
import android.os.Bundle
import android.os.Build
import android.os.SystemClock
import com.algive.jizhang_app.MainActivity
import com.algive.jizhang_app.autobookkeeping.overlay.AutoBillOverlayService
import java.io.File
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore as Store
import com.algive.jizhang_app.autobookkeeping.repository.PendingEnqueueDecision as Decision
import org.json.JSONArray
import org.json.JSONObject
import java.io.StringWriter
import java.io.PrintWriter

/** Runs against Android's real JSON and preferences, in an isolated preference namespace. */
class PaymentReviewInstrumentation : Instrumentation() {
    private var mode = ""
    private var fixtureIds = emptyList<String>()
    override fun onCreate(arguments: Bundle?) {
        mode = arguments?.getString("mode").orEmpty()
        fixtureIds = arguments?.getString("fixtures").orEmpty().split(',').filter { it.isNotBlank() }
        super.onCreate(arguments)
        start()
    }
    override fun onStart() {
        val result = Bundle()
        try {
            if (mode.equals("snapshot")) {
                InboxSnapshotInstrumentation.snapshot(targetContext)
                result.putString("stream", "PASS: inbox preferences snapshot saved\n")
                finish(Activity.RESULT_OK, result)
                return
            }
            if (mode == "ui") {
                result.putString("stream", runUi())
                finish(Activity.RESULT_OK, result)
                return
            }
            if (mode == "save-ui") {
                result.putString("stream", ConfirmSaveDeviceCheck(this).run())
                finish(Activity.RESULT_OK, result)
                return
            }
            if (mode == "cleanup-ui") {
                result.putString("stream", ConfirmSaveDeviceCheck(this).cleanup(fixtureIds))
                finish(Activity.RESULT_OK, result)
                return
            }
            if (mode == "dedup") {
                result.putString("stream", runDedup())
                finish(Activity.RESULT_OK, result)
                return
            }
            val prefix = "review-test-${System.nanoTime()}"
            val context = object : ContextWrapper(targetContext) {
                override fun getSharedPreferences(name: String, mode: Int): SharedPreferences =
                    super.getSharedPreferences("$prefix-$name", mode)
            }
            val first = candidate("ORDER-1", 1000)
            val second = candidate("ORDER-2", 1000)
            check(Store.enqueueDecision(context, first) == Decision.ACCEPTED)
            check(Store.enqueueDecision(context, second) == Decision.QUEUED)
            check(Store.pendingCount(context) == 2)
            check(Store.read(context)?.get("orderId") == "ORDER-1")
            Store.deferCurrent(context)
            check(Store.read(context) == null && Store.pendingCount(context) == 2)
            check(Store.enqueueDecision(context, first) == Decision.DUPLICATE)
            val firstId = Store.inbox(context).first { it["orderId"] == "ORDER-1" }["fingerprint"] as String
            check(Store.ignore(context, firstId))
            check(Store.pendingCount(context) == 1 && Store.inbox(context).size == 2)
            check(Store.select(context, firstId))
            check(Store.pendingCount(context) == 2)
            Store.complete(context)
            check(Store.pendingCount(context) == 1)
            check(Store.enqueueDecision(context, first) == Decision.DUPLICATE)
            val secondId = Store.inbox(context).single()["fingerprint"] as String
            check(Store.select(context, secondId))
            Store.complete(context)
            check(Store.pendingCount(context) == 0)
            check(Store.enqueueDecision(context, first) == Decision.DUPLICATE)
            check(Store.enqueueDecision(context, second) == Decision.DUPLICATE)
            val automaticFirst = candidate("AUTO-1", 3100)
            val automaticSecond = candidate("AUTO-2", 4200)
            check(Store.enqueueDecision(context, automaticFirst) == Decision.ACCEPTED)
            check(Store.enqueueDecision(context, automaticSecond) == Decision.QUEUED)
            Store.deferCurrent(context)
            val automaticNext = requireNotNull(Store.selectNextAutomatic(context))
            check(automaticNext.orderId == "AUTO-2")
            check(automaticNext.amountConfidence == automaticSecond.amountConfidence)
            check(automaticNext.merchantConfidence == automaticSecond.merchantConfidence)
            check(automaticNext.scene.confidence == automaticSecond.scene.confidence)
            Store.complete(context)
            check(Store.selectNextAutomatic(context) == null) // A user-deferred bill stays pending.
            check(Store.ignore(context, Store.inbox(context).single()["fingerprint"] as String))
            val unordered = candidate("", 2000).copy(orderId = null)
            check(Store.enqueueDecision(context, unordered) == Decision.ACCEPTED)
            check(Store.enqueueDecision(context, unordered) == Decision.DUPLICATE)
            Store.deferCurrent(context)
            check(Store.enqueueDecision(context, unordered) == Decision.DUPLICATE)
            check(Store.enqueueDecision(context, unordered.copy(timestamp = unordered.timestamp + 1)) == Decision.ACCEPTED)
            context.getSharedPreferences("autobookkeeping.pending", Context.MODE_PRIVATE).edit().clear().commit()
            result.putString("stream", "PASS: queue, close, deduplication, ignore, recovery and multiple saved fingerprints\n")
            finish(Activity.RESULT_OK, result)
        } catch (error: Throwable) {
            val trace = StringWriter()
            error.printStackTrace(PrintWriter(trace))
            result.putString("stream", "FAIL: $trace\n")
            finish(Activity.RESULT_CANCELED, result)
        }
    }

    private fun runDedup(): String {
        val prefix = "inbox-dedup-${System.nanoTime()}"
        val context = object : ContextWrapper(targetContext) {
            override fun getSharedPreferences(name: String, mode: Int): SharedPreferences =
                super.getSharedPreferences("$prefix-$name", mode)
        }
        val prefs = context.getSharedPreferences("autobookkeeping.pending", Context.MODE_PRIVATE)
        val time = System.currentTimeMillis() / 1000 * 1000
        val success = candidate("", 18).copy(orderId = null, sourceApp = "WECHAT", timestamp = time + 321,
            scene = PaymentScene("WECHAT", "QIANJI_WeChatPaySuccess", 1.0))
        val detail = success.copy(orderId = "ORDER-DUP-1", timestamp = time, transactionTimeKnown = true,
            paymentMethod = "零钱", scene = PaymentScene("WECHAT", "QIANJI_WeChatBillDetail", 1.0))
        try {
            check(Store.enqueueDecision(context, success) == Decision.ACCEPTED)
            val identity = Store.read(context)!!["fingerprint"]
            Store.deferCurrent(context)
            check(Store.enqueueDecision(context, detail) == Decision.DUPLICATE)
            check(Store.inbox(context).single()["orderId"] == "ORDER-DUP-1")
            check(Store.inbox(context).single()["fingerprint"] == identity)
            check(Store.select(context, identity as String))
            check(Store.readCandidate(context)!!.transactionTimeKnown)
            Store.complete(context)
            prefs.edit().remove("handled_history").remove("handled_payload").putLong("handled_at", 0L).commit()
            check(Store.enqueueDecision(context, detail) == Decision.DUPLICATE) // durable identity, no ten-minute cache
            check(Store.enqueueDecision(context, detail.copy(orderId = "ORDER-DUP-2")) == Decision.ACCEPTED)
            Store.complete(context)
            prefs.edit().clear().commit()
            fun row(value: PaymentCandidate, id: String, ignored: Boolean = false) = JSONObject(value.toMap())
                .put("fingerprint", id).put("created_at", time + 20_000).put("status", if (ignored) "ignored" else "pending")
            prefs.edit().putString("inbox", JSONArray(listOf(row(detail, "old-1", true), row(detail, "old-2"))).toString()).commit()
            check(Store.inbox(context).size == 1 && Store.pendingCount(context) == 0)
            check(Store.inbox(context).single()["status"] == "ignored")
            check(Store.select(context, Store.inbox(context).single()["fingerprint"] as String))
            Store.complete(context)
            check(Store.inbox(context).isEmpty())
            prefs.edit().clear().commit()
            check(Store.enqueueDecision(context, success) == Decision.ACCEPTED)
            val next = success.copy(timestamp = time + 3_321)
            check(Store.enqueueDecision(context, next) == Decision.QUEUED)
            check(Store.enqueueDecision(context, detail) == Decision.QUEUED)
            check(Store.pendingCount(context) == 3) // ambiguous same-amount payments remain separate
            prefs.edit().clear().commit()
            check(Store.enqueueDecision(context, success) == Decision.ACCEPTED)
            prefs.edit().putString("inbox", JSONArray(listOf(row(detail, "old-detail"))).toString()).commit()
            check(Store.inbox(context).size == 1)
            check(Store.read(context)!!["fingerprint"] == identity)
            check(Store.read(context)!!["orderId"] == "ORDER-DUP-1")
            Store.complete(context)
            check(Store.inbox(context).isEmpty())
            prefs.edit().clear().commit()
            check(Store.enqueueDecision(context, success) == Decision.ACCEPTED)
            val savedIdentity = Store.read(context)!!["fingerprint"] as String
            Store.deferCurrent(context) // Host closes while the ledger commit finishes.
            val other = detail.copy(orderId = "ORDER-DUP-2", timestamp = time + 60_000)
            check(Store.enqueueDecision(context, other) == Decision.ACCEPTED)
            Store.complete(context, fingerprint = savedIdentity)
            check(Store.read(context)!!["orderId"] == "ORDER-DUP-2")
            check(Store.inbox(context).size == 1)
            check(Store.enqueueDecision(context, success) == Decision.DUPLICATE)
            Store.complete(context, fingerprint = "already-reconciled")
            check(Store.read(context)!!["orderId"] == "ORDER-DUP-2")
            return "PASS: isolated Android inbox: enrichment, historical merge, ignored status, durable handled identity, distinct orders, ambiguity, active review identity and completion after defer preserving another active order\n"
        } finally {
            prefs.edit().clear().commit()
        }
    }

    /** Run only on the dedicated test emulator; never on a user's ledger. */
    private fun runUi(): String {
        check(Build.HARDWARE in setOf("ranchu", "goldfish")) { "UI smoke test requires an emulator" }
        val previous = Store.inbox(targetContext)
        check(previous.all { it["orderId"].toString().startsWith("UI-SMOKE-") }) { "Emulator has non-test pending payments" }
        previous.forEach {
            check(Store.select(targetContext, it["fingerprint"] as String))
            Store.complete(targetContext, remember = false)
        }
        AutoBookkeepingLogStore.clear(targetContext)
        getUiAutomation(UiAutomation.FLAG_DONT_SUPPRESS_ACCESSIBILITY_SERVICES)
        val activity = startActivitySync(Intent(targetContext, MainActivity::class.java).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        runOnMainSync {
            AutoBookkeepingSettings.setEnabled(targetContext, true)
            activity.startForegroundService(Intent(activity, AutoBillOverlayService::class.java))
        }
        waitFor { AutoBookkeepingLogStore.read(targetContext).any { it["stage"] == "confirmation_engine_ready" } }
        targetContext.startActivity(Intent(android.provider.Settings.ACTION_SETTINGS).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK))
        Thread.sleep(700)
        val payment = candidate("UI-SMOKE-${System.nanoTime()}", 1234)
        val times = mutableListOf<String>()
        repeat(2) { round ->
            AutoBookkeepingLogStore.clear(targetContext)
            runOnMainSync {
                if (round == 0) check(Store.enqueueDecision(targetContext, payment) == Decision.ACCEPTED)
                else check(Store.select(targetContext, Store.inbox(targetContext).single()["fingerprint"] as String))
                check(AutoBillOverlayService.instance!!.offer(payment))
            }
            waitFor { AutoBookkeepingLogStore.read(targetContext).any { it["stage"] == "confirmation_content_frame" } }
            Thread.sleep(600)
            uiAutomation.takeScreenshot().also { bitmap ->
                File(targetContext.getExternalFilesDir(null), "payment-review-$round.png").outputStream().use {
                    bitmap.compress(Bitmap.CompressFormat.PNG, 100, it)
                }
                bitmap.recycle()
            }
            val timing = AutoBookkeepingLogStore.read(targetContext).first { it["stage"] == "confirmation_content_frame" }
            times.add(timing["detail"].toString())
            File(targetContext.getExternalFilesDir(null), "payment-timings.txt").writeText(times.joinToString())
            check(AutoBookkeepingConfirmActivity.instance != null)
            runOnMainSync { AutoBillOverlayService.instance!!.closeConfirmation() }
            waitFor { AutoBookkeepingConfirmActivity.instance == null }
            check(Store.pendingCount(targetContext) == 1)
        }
        return "PASS: full confirmation frames ${times.joinToString()}, repeated host and durable unsaved dismissal\n"
    }

    private fun waitFor(condition: () -> Boolean) {
        val deadline = SystemClock.elapsedRealtime() + 20000
        while (!condition()) {
            check(SystemClock.elapsedRealtime() < deadline) { "Timed out waiting for confirmation UI" }
            Thread.sleep(80)
        }
    }

    private fun candidate(order: String, amount: Long) = PaymentCandidate(
        amountInCents = amount, merchantRaw = "测试商户", merchantNormalized = "测试商户",
        paymentMethod = "支付宝", timestamp = System.currentTimeMillis(), sourceApp = "ALIPAY",
        scene = PaymentScene("ALIPAY", "ALIPAY_PAYMENT_SUCCESS", 1.0),
        amountConfidence = 1.0, merchantConfidence = 1.0, orderId = order,
    )
}
