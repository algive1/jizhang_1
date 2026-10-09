package com.algive.jizhang_app.autobookkeeping.dedup

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import kotlin.math.abs

/** One transaction can have several observations; nearby purchases are not identities. */
object PaymentInboxDedup {
    enum class Match(val strong: Boolean) {
        FINGERPRINT(true), ORDER(true), PAYMENT_SESSION(true), TRANSACTION_TIME(true), NOTIFICATION(false), SUCCESS_DETAIL(false),
    }

    fun match(a: Map<String, Any>, b: Map<String, Any>): Match? {
        if (a.text("fingerprint").isNotBlank() && a.text("fingerprint") == b.text("fingerprint")) return Match.FINGERPRINT
        val cross = a.notification() != b.notification()
        if (!typesCompatible(a.text("transactionType", "EXPENSE"), b.text("transactionType", "EXPENSE"), cross)) return null
        if (a.number("amountInCents") != b.number("amountInCents")) return null
        val sameSource = a.text("sourceApp") == b.text("sourceApp")
        if (!sameSource && a.text("paymentSessionId").isNotBlank() &&
            a.text("paymentSessionId") == b.text("paymentSessionId") &&
            a.text("paymentOriginApp") == "MEITUAN" && b.text("paymentOriginApp") == "MEITUAN" &&
            setOf(a.text("sourceApp"), b.text("sourceApp")) == setOf("WECHAT", "MEITUAN")) return Match.PAYMENT_SESSION
        BillFingerprint.matchingOrder(a.text("orderId"), b.text("orderId"))?.let {
            return if (it && sameSource) Match.ORDER else null
        }
        val sameMerchant = a.text("merchant").isNotBlank() &&
            MerchantNormalizer.normalize(a.text("merchant")) == MerchantNormalizer.normalize(b.text("merchant"))
        val at = a.number("timestamp")
        val bt = b.number("timestamp")
        if (at <= 0 || bt <= 0) return null
        if (a["transactionTimeKnown"] == true && b["transactionTimeKnown"] == true) {
            return if (at == bt && sameSource && sameMerchant) Match.TRANSACTION_TIME else null
        }
        if (abs(at - bt) > 10_000) return null
        // Once paired, another notification/success observation belongs to a new payment.
        for (key in listOf("notificationAt", "successAt")) {
            val first = a.captureAt(key)
            val second = b.captureAt(key)
            if (first > 0 && second > 0 && first != second) return null
        }
        if (cross && sameMerchant && (sameSource || railMatches(a, b) || railMatches(b, a))) return Match.NOTIFICATION
        val success = when { a.success() -> a; b.success() -> b; else -> return null }
        val detail = if (success === a) b else a
        if (!sameSource || !sameMerchant || !detail.text("scene").endsWith("BillDetail")) return null
        if (detail["transactionTimeKnown"] != true || detail.number("created_at") < success.number("created_at")) return null
        return Match.SUCCESS_DETAIL
    }

    /** Weak evidence must identify exactly one candidate, never the first of several. */
    fun find(values: List<Map<String, Any>>, candidate: Map<String, Any>,
             observations: List<Map<String, Any>> = values + candidate): Int? {
        val matches = values.mapIndexedNotNull { i, value -> match(value, candidate)?.let { i to it } }
        matches.firstOrNull { it.second == Match.FINGERPRINT || it.second == Match.ORDER }?.let { return it.first }
        matches.filter { it.second.strong }.singleOrNull()?.let { return it.first }
        val index = matches.singleOrNull()?.first ?: return null
        return index.takeIf { observations.filter {
            it.channel() == candidate.channel() && match(values[index], it) != null
        }.distinctBy { it["fingerprint"] }.size == 1 }
    }

    fun collapse(values: List<Map<String, Any>>, observations: List<Map<String, Any>> = values): List<Map<String, Any>> {
        val result = mutableListOf<Map<String, Any>>()
        // Ordered/timed anchors first, so an unanchored observation cannot bridge distinct orders.
        for (value in values.sortedByDescending(::quality)) {
            val index = find(result, value, observations)
            if (index == null) result.add(value) else {
                val ignored = result[index]["status"] == "ignored" || value["status"] == "ignored"
                result[index] = merge(result[index], value).let { if (ignored) it + ("status" to "ignored") else it }
            }
        }
        return result
    }

    fun merge(existing: Map<String, Any>, incoming: Map<String, Any>): Map<String, Any> {
        val preferred = if (quality(incoming) > quality(existing)) incoming else existing
        val fallback = if (preferred === existing) incoming else existing
        val result = preferred.toMutableMap()
        for ((key, value) in fallback) {
            if (result[key] == null || result[key] == "" || result[key] == "UNKNOWN") result[key] = value
        }
        // Keep the review identity, user choice and its original screenshot stable.
        for (key in listOf("fingerprint", "created_at", "status", "screenshotPath")) {
            existing[key]?.takeIf { it != "" }?.let { result[key] = it }
        }
        for (key in listOf("notificationAt", "successAt")) {
            maxOf(existing.captureAt(key), incoming.captureAt(key)).takeIf { it > 0 }?.let { result[key] = it }
        }
        return result
    }

    fun handledKeys(value: Map<String, Any>): Set<String> = buildSet {
        value.text("fingerprint").takeIf(String::isNotBlank)?.let { add(it) }
        val prefix = "${value.text("sourceApp")}|${value.text("transactionType", "EXPENSE")}|"
        value.text("paymentSessionId").takeIf(String::isNotBlank)?.let {
            add(BillFingerprint.hash("session|$it|${value.text("transactionType", "EXPENSE")}|${value.number("amountInCents")}"))
        }
        val order = value.text("orderId")
        order.takeIf(String::isNotBlank)?.let { add(BillFingerprint.hash(prefix + "order|" + it)) }
        if (order.isBlank() && value["transactionTimeKnown"] == true && value.number("timestamp") > 0) {
            add(BillFingerprint.hash(prefix + "time|${value.number("timestamp")}|${value.number("amountInCents")}|${MerchantNormalizer.normalize(value.text("merchant"))}"))
        }
    }

    /** Old detailed pages parsed seconds but did not store the precision flag. */
    fun legacyTransactionTimeKnown(value: Map<String, Any>): Boolean {
        val at = value.number("timestamp")
        return !value.containsKey("transactionTimeKnown") && value.text("scene").endsWith("BillDetail") &&
            value.text("orderId").isNotBlank() && at > 0 && at % 1000 == 0L && at % 60_000 != 0L &&
            value.number("created_at") - at >= 1000
    }

    fun typesCompatible(first: String, second: String, cross: Boolean): Boolean = first == second ||
        (cross && setOf(first, second) == setOf("EXPENSE", "TRANSFER"))

    private fun quality(value: Map<String, Any>): Int =
        (if (value.notification()) 0 else 100) +
            (if (value.text("orderId").isBlank()) 0 else 10) +
            (if (value["transactionTimeKnown"] == true) 5 else 0) +
            (if (value.text("scene").endsWith("BillDetail")) 2 else 0)

    private fun Map<String, Any>.notification() = text("scene").startsWith("PAYMENT_NOTIFICATION")
    private fun Map<String, Any>.success() = text("scene").endsWith("PaySuccess") || text("scene").endsWith("PAYMENT_SUCCESS")
    private fun Map<String, Any>.channel() = when { notification() -> "notification"; success() -> "success"; else -> text("scene") }
    private fun Map<String, Any>.captureAt(key: String): Long = number(key).takeIf { it > 0 }
        ?: if (key == "notificationAt" && notification() || key == "successAt" && success()) number("timestamp") else 0
    private fun Map<String, Any>.text(key: String, default: String = "") = (this[key] as? String)?.trim() ?: default
    private fun Map<String, Any>.number(key: String) = (this[key] as? Number)?.toLong() ?: 0L
    private fun railMatches(page: Map<String, Any>, other: Map<String, Any>): Boolean = when (other.text("sourceApp")) {
        "ALIPAY" -> page.text("paymentMethod").contains("支付宝")
        "WECHAT" -> page.text("paymentMethod").contains("微信")
        "UNIONPAY" -> listOf("云闪付", "银行卡", "信用卡", "储蓄卡").any(page.text("paymentMethod")::contains)
        else -> false
    }
}
