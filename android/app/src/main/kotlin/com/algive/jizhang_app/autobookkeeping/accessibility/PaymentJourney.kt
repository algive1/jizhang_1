package com.algive.jizhang_app.autobookkeeping.accessibility

import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import kotlin.math.abs

/** Links a marketplace -> WeChat success -> marketplace return, never amount alone. */
internal class PaymentJourney {
    private val marketplaces = mapOf("com.sankuai.meituan" to "MEITUAN", "com.sankuai.meituan.takeoutnew" to "MEITUAN")
    private var foreground: String? = null
    private var origin: String? = null
    private var enteredAt = 0L
    private var payment: PaymentCandidate? = null
    private var session: String? = null
    private var marketplaceOrder: String? = null
    private var sequence = 0

    fun foreground(packageName: String, now: Long, newPaymentPage: Boolean = false) {
        if (packageName == "com.algive.jizhang_app") return
        if (packageName == foreground) {
            if (packageName == "com.tencent.mm" && newPaymentPage && payment != null) { origin = null; payment = null }
            return
        }
        if (packageName == "com.tencent.mm") {
            origin = marketplaces[foreground]
            enteredAt = now
            payment = null
            session = null
            marketplaceOrder = null
        } else if (marketplaces[packageName] != origin) {
            origin = null
            payment = null
        }
        foreground = packageName
    }

    fun associate(candidate: PaymentCandidate, now: Long): PaymentCandidate {
        val origin = origin ?: return candidate
        if (candidate.transactionType != "EXPENSE" || now - enteredAt !in 0..120_000) return candidate
        if (candidate.sourceApp == "WECHAT" &&
            (candidate.scene.scene.endsWith("WeChatPaySuccess") || candidate.scene.scene == "PAYMENT_SUCCESS")) {
            if (payment == null) {
                payment = candidate
                session = "$enteredAt-${++sequence}"
            }
        } else {
            val paid = payment ?: return candidate
            if (candidate.sourceApp != origin || foreground?.let(marketplaces::get) != origin ||
                candidate.amountInCents != paid.amountInCents ||
                (marketplaceOrder != null && !candidate.orderId.isNullOrBlank() && candidate.orderId != marketplaceOrder) ||
                (candidate.transactionTimeKnown && abs(candidate.timestamp - paid.timestamp) > 10_000) ||
                (!candidate.paymentMethod.contains("微信") && !candidate.scene.scene.endsWith("PaySuccess"))) return candidate
            candidate.orderId?.takeIf(String::isNotBlank)?.let { marketplaceOrder = it }
        }
        return candidate.copy(paymentSessionId = session, paymentOriginApp = origin)
    }
}
