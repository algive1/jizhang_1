package com.algive.jizhang_app.autobookkeeping.parser

import java.math.BigDecimal

internal object CandidateFieldExtractor {
    private val currencyPatterns = listOf(
        Regex("[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)(?![0-9.])"),
        Regex("(?<![0-9.])([0-9]+(?:\\.[0-9]{1,2})?)\\s*元"),
    )

    fun field(labels: List<String>, keys: Set<String>, maxLength: Int = 160): String? {
        labels.forEachIndexed { index, raw ->
            val text = raw.trim()
            keys.sortedByDescending { it.length }.forEach { key ->
                if (text == key) {
                    return labels.getOrNull(index + 1)
                        ?.trim()
                        ?.takeIf { it.isNotBlank() && it.length <= maxLength }
                }
                if (text.startsWith("$key：") || text.startsWith("$key:")) {
                    return text.substring(key.length + 1)
                        .trim()
                        .takeIf { it.isNotBlank() }
                        ?.take(maxLength)
                }
            }
        }
        return null
    }

    fun labeledAmount(labels: List<String>, keys: Set<String>): Long? {
        val values = mutableSetOf<Long>()
        labels.forEachIndexed { index, raw ->
            val label = raw.trim()
            val previous = labels.getOrNull(index - 1)?.trim().orEmpty()
            val explicit = keys.any { key ->
                label == key ||
                    label.startsWith("$key：") ||
                    label.startsWith("$key:") ||
                    previous == key
            }
            if (!explicit) return@forEachIndexed
            val rawValues = currencyPatterns
                .flatMap { pattern -> pattern.findAll(label).map { it.groupValues[1] }.toList() }
                .ifEmpty {
                    if (label.matches(Regex("[0-9]+(?:\\.[0-9]{1,2})?"))) listOf(label)
                    else emptyList()
                }
            rawValues.mapNotNullTo(values, ::toCents)
        }
        return values.singleOrNull()
    }

    fun firstCurrencyAmount(text: String): Long? =
        currencyPatterns.asSequence()
            .mapNotNull { pattern -> pattern.find(text)?.groupValues?.getOrNull(1) }
            .mapNotNull(::toCents)
            .firstOrNull()

    fun orderId(labels: List<String>): String? {
        val explicit = field(
            labels,
            setOf("订单号", "交易单号", "交易号", "流水号", "支付单号"),
            maxLength = 80,
        )
        if (explicit != null) {
            return Regex("[A-Za-z0-9_-]{6,64}").find(explicit)?.value
        }
        val pattern = Regex(
            "(?:订单号|交易单号|交易号|流水号|支付单号)[：:\\s]*([A-Za-z0-9_-]{6,64})",
        )
        return labels.firstNotNullOfOrNull { pattern.find(it)?.groupValues?.getOrNull(1) }
    }

    fun note(labels: List<String>): String? =
        field(labels, setOf("备注", "订单备注", "付款备注"), maxLength = 160)
            ?.takeIf { value ->
                value.length >= 2 &&
                    !value.contains("无备注") &&
                    !value.contains("暂无")
            }

    fun targetAccountHint(labels: List<String>): String? =
        field(
            labels,
            setOf(
                "转入账户",
                "收款账户",
                "到账账户",
                "收款银行卡",
                "转入银行卡",
            ),
            maxLength = 120,
        )

    fun repaymentTargetAccountHint(labels: List<String>): String? =
        field(
            labels,
            setOf(
                "还款至",
                "还款信用卡",
                "信用卡",
                "债务账户",
                "账单账户",
                "还款对象",
            ),
            maxLength = 120,
        )

    fun repaymentTargetIdentifierSuffix(labels: List<String>): String? {
        val hint = repaymentTargetAccountHint(labels) ?: return null
        return accountSuffix(hint)
    }

    fun targetIdentifierSuffix(labels: List<String>): String? {
        val hint = targetAccountHint(labels) ?: return null
        return accountSuffix(hint)
    }

    fun identifierSuffix(paymentMethod: String, labels: List<String>): String? {
        val joined = buildString {
            append(paymentMethod)
            append(' ')
            labels.forEach {
                append(it)
                append(' ')
            }
        }
        return Regex(
            "(?:尾号|后四位|卡号后四位|手机号后四位)[^0-9]{0,8}([0-9]{4})|" +
                "(?:银行卡|信用卡|储蓄卡)[^0-9]{0,8}([0-9]{4})(?![0-9])",
        ).find(joined)?.let { match ->
            match.groupValues.getOrNull(1)?.takeIf { it.isNotBlank() }
                ?: match.groupValues.getOrNull(2)?.takeIf { it.isNotBlank() }
        }
    }

    fun amountBreakdown(
        labels: List<String>,
        paidAmountInCents: Long,
        originalKeys: Set<String> = setOf("原价", "订单金额", "商品金额", "合计", "应付金额"),
        discountKeys: Set<String> = setOf("优惠", "优惠金额", "立减", "红包", "优惠券"),
    ): Pair<Long?, Long?> {
        var original = labeledAmount(labels, originalKeys)
        var discount = labeledAmount(labels, discountKeys)

        if (original != null && original < paidAmountInCents) original = null
        if (discount != null && discount < 0) discount = null

        if (original != null && discount == null) {
            val delta = original - paidAmountInCents
            if (delta > 0) discount = delta
        }
        if (discount != null && original == null) {
            val candidate = paidAmountInCents + discount
            if (candidate >= paidAmountInCents) original = candidate
        }
        if (
            original != null &&
            discount != null &&
            original - discount != paidAmountInCents
        ) {
            // Keep the paid amount authoritative; inconsistent auxiliary
            // values are discarded instead of contaminating the candidate.
            return null to null
        }
        return original to discount
    }

    private fun accountSuffix(value: String): String? =
        Regex(
            "(?:尾号|后四位|卡号后四位)[^0-9]{0,8}([0-9]{4})(?![0-9])|" +
                "(?:银行卡|信用卡|储蓄卡)[^0-9]{0,8}([0-9]{4})(?![0-9])",
        ).find(value)?.let { match ->
            match.groupValues.getOrNull(1)?.takeIf { it.isNotBlank() }
                ?: match.groupValues.getOrNull(2)?.takeIf { it.isNotBlank() }
        }

    private fun toCents(value: String): Long? =
        value.toBigDecimalOrNull()
            ?.multiply(BigDecimal(100))
            ?.let { runCatching { it.longValueExact() }.getOrNull() }
            ?.takeIf { it in 1..99_999_999_999L }
}
