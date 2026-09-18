package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.model.*
import com.algive.jizhang_app.autobookkeeping.rules.PaymentRule
import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import java.math.BigDecimal

class WeChatPaymentParser(val rule: PaymentRule = PaymentRule()) {
    fun parse(nodes: List<ScreenNode>, timestamp: Long = System.currentTimeMillis()): PaymentCandidate? {
        val labels = nodes.map { it.label }.filter { it.isNotBlank() }
        // Exact status nodes: quoted chat messages containing these words are not status nodes.
        if (labels.none { it in rule.keywords }) return null
        fun field(keys: Set<String>): String? {
            labels.forEachIndexed { index, text ->
                keys.sortedByDescending { it.length }.forEach { key ->
                    if (text == key) return labels.getOrNull(index + 1)?.takeIf { it.length <= 100 }
                    if (text.startsWith("$key：") || text.startsWith("$key:")) return text.substring(key.length + 1).trim()
                }
            }
            return null
        }
        val merchant = (field(rule.merchantPatterns) ?: fallbackMerchant(labels))
            ?.takeIf { value -> value.isNotBlank() && value !in rule.keywords && rule.methodLabels.none { value.contains(it) } }
            ?: return null
        val method = field(rule.methodLabels)?.takeIf { it.isNotBlank() && it !in rule.keywords } ?: "UNKNOWN"
        val amounts = mutableListOf<Pair<Long, Int>>()
        labels.forEachIndexed { index, label ->
            val previous = labels.getOrNull(index - 1).orEmpty()
            if (rule.excludedKeywords.any { label.contains(it) }) return@forEachIndexed
            val explicit = rule.amountLabels.any { label.startsWith(it) || previous == it }
            if (!explicit && rule.excludedKeywords.any { previous.contains(it) }) return@forEachIndexed
            val matches = rule.amountPatterns.flatMap { it.findAll(label).map { m -> m.groupValues[1] }.toList() }.distinct()
            val raw = if (matches.isEmpty() && explicit && label.matches(Regex("[0-9]+(?:\\.[0-9]{1,2})?"))) listOf(label) else matches
            raw.forEach { value ->
                val cents = value.toBigDecimalOrNull()?.multiply(BigDecimal(100))?.let { runCatching { it.longValueExact() }.getOrNull() }
                if (cents != null && cents in 1..99999999999L) amounts.add(cents to if (explicit) 3 else 1)
            }
        }
        val best = amounts.maxOfOrNull { it.second } ?: return null
        val winners = amounts.filter { it.second == best }.map { it.first }.distinct()
        if (winners.size != 1) return null // Ambiguous amounts require a better rule, never guess.
        return PaymentCandidate(winners.single(), merchant.take(80), MerchantNormalizer.normalize(merchant), method.take(80), timestamp, PaymentScene(confidence = if (method != "UNKNOWN") .98 else .9), if (best == 3) 1.0 else .92, .92)
    }

    private fun fallbackMerchant(labels: List<String>): String? {
        val genericLabels = setOf(
            "微信",
            "微信支付",
            "转账",
            "红包",
            "扫一扫",
            "完成",
            "返回",
            "更多",
            "查看账单",
            "账单详情",
        )
        return labels.firstOrNull { label ->
            label.length in 2..80 &&
                label !in genericLabels &&
                label !in rule.keywords &&
                label !in rule.amountLabels &&
                label !in rule.methodLabels &&
                rule.excludedKeywords.none { label == it } &&
                rule.amountPatterns.none { it.containsMatchIn(label) }
        }
    }
}
