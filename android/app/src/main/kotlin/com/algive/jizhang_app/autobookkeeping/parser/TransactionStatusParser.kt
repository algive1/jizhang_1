package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry
import java.math.BigDecimal

/**
 * Conservative accessibility parser for completed non-purchase transaction
 * states. A detected TRANSFER is only a scene signal; the Flutter confirmation
 * layer decides whether it is an external expense or an internal account move.
 */
class TransactionStatusParser(
    private val registry: AutoBookkeepingRuleRegistry =
        AutoBookkeepingRuleRegistry.builtIn(),
) {
    fun parse(
        packageName: String,
        nodes: List<ScreenNode>,
        timestamp: Long,
    ): PaymentCandidate? {
        val sourceApp = registry.ruleFor(packageName)?.sourceApp ?: return null
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        if (labels.isEmpty()) return null

        val hasRefund = labels.any(::isRefundStatus)
        val hasIncome = labels.any(::isIncomeStatus)
        val hasRepayment = labels.any(::isRepaymentStatus)
        val hasTransfer =
            labels.any(::isTransferStatus) ||
                isWeChatTransferConfirmation(sourceApp, labels)
        if (listOf(hasRefund, hasIncome, hasRepayment, hasTransfer).count { it } != 1) {
            return null
        }

        val transactionType = when {
            hasRefund -> "REFUND"
            hasIncome -> "INCOME"
            hasRepayment -> "REPAYMENT"
            else -> "TRANSFER"
        }
        val counterparty = when (transactionType) {
            "REFUND" -> explicitValue(
                labels,
                setOf("退款方", "退款商户", "商户", "商家", "店铺", "门店", "对方"),
                setOf("退款方", "退款商户", "来自", "对方"),
            )
            "INCOME" -> explicitValue(
                labels,
                setOf("付款方", "付款人", "对方"),
                setOf("来自", "付款方", "付款人", "对方"),
            )
            "REPAYMENT" ->
                CandidateFieldExtractor.repaymentTargetAccountHint(labels)
                    ?: explicitValue(
                        labels,
                        setOf("还款对象", "债务账户", "账单账户"),
                        setOf("还款至", "还款对象"),
                    )
                    ?: "信用卡还款"
            else -> transferCounterparty(labels)
        } ?: return null

        val amountKeys = when (transactionType) {
            "REFUND" -> setOf("退款金额", "到账金额", "退款")
            "INCOME" -> setOf("收款金额", "到账金额", "收入金额", "收款")
            "REPAYMENT" -> setOf("还款金额", "本次还款", "还款")
            else -> setOf("转账金额", "转出金额", "付款金额", "金额")
        }
        val amount = uniqueAmount(labels, amountKeys) ?: return null

        val methodKeys = when (transactionType) {
            "TRANSFER" -> setOf("转出方式", "付款方式", "支付方式", "转出账户")
            "REPAYMENT" -> setOf("扣款账户", "还款资金来源", "付款方式", "支付方式")
            "REFUND" -> setOf("退款方式", "支付方式", "付款方式")
            else -> setOf("收款方式", "支付方式", "付款方式")
        }
        val method = CandidateFieldExtractor
            .field(labels, methodKeys)
            ?.takeIf { it.isNotBlank() }
            ?: "UNKNOWN"

        val targetAccountHint = when (transactionType) {
            "TRANSFER" -> CandidateFieldExtractor.targetAccountHint(labels)
            "REPAYMENT" -> CandidateFieldExtractor.repaymentTargetAccountHint(labels)
            else -> null
        }
        val targetIdentifierSuffix = when (transactionType) {
            "TRANSFER" -> CandidateFieldExtractor.targetIdentifierSuffix(labels)
            "REPAYMENT" -> CandidateFieldExtractor.repaymentTargetIdentifierSuffix(labels)
            else -> null
        }
        val sourceIdentifierSuffix =
            if (transactionType == "TRANSFER" || transactionType == "REPAYMENT") {
                CandidateFieldExtractor.identifierSuffix(method, emptyList())
            } else {
                CandidateFieldExtractor.identifierSuffix(method, labels)
            }

        return PaymentCandidate(
            amountInCents = amount,
            merchantRaw = counterparty.take(80),
            merchantNormalized = MerchantNormalizer.normalize(counterparty).take(80),
            paymentMethod = method.take(80),
            timestamp = timestamp,
            scene = PaymentScene(
                sourceApp = sourceApp,
                scene = when (transactionType) {
                    "REFUND" -> "${sourceApp}_REFUND_SUCCESS"
                    "INCOME" -> "${sourceApp}_INCOME_SUCCESS"
                    "REPAYMENT" -> "${sourceApp}_REPAYMENT_SUCCESS"
                    else -> "${sourceApp}_TRANSFER_SUCCESS"
                },
                confidence = if (method == "UNKNOWN") .92 else .96,
            ),
            amountConfidence = 1.0,
            merchantConfidence = .94,
            sourceApp = sourceApp,
            transactionType = transactionType,
            orderId = CandidateFieldExtractor.orderId(labels),
            note = CandidateFieldExtractor.note(labels),
            identifierSuffix = sourceIdentifierSuffix,
            targetIdentifierSuffix = targetIdentifierSuffix,
            targetAccountHint = targetAccountHint,
        )
    }

    fun rejectionReason(
        packageName: String,
        nodes: List<ScreenNode>,
    ): String? {
        val sourceApp = registry.ruleFor(packageName)?.sourceApp ?: return null
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        val hasRefund = labels.any(::isRefundStatus)
        val hasIncome = labels.any(::isIncomeStatus)
        val hasRepayment = labels.any(::isRepaymentStatus)
        val hasTransfer =
            labels.any(::isTransferStatus) ||
                isWeChatTransferConfirmation(sourceApp, labels)
        val matchCount = listOf(hasRefund, hasIncome, hasRepayment, hasTransfer).count { it }
        if (matchCount == 0) return null
        if (matchCount != 1) return "AMBIGUOUS_TRANSACTION_STATUS"

        val type = when {
            hasRefund -> "REFUND"
            hasIncome -> "INCOME"
            hasRepayment -> "REPAYMENT"
            else -> "TRANSFER"
        }
        val counterparty = when (type) {
            "REFUND" -> explicitValue(
                labels,
                setOf("退款方", "退款商户", "商户", "商家", "店铺", "门店", "对方"),
                setOf("退款方", "退款商户", "来自", "对方"),
            )
            "INCOME" -> explicitValue(
                labels,
                setOf("付款方", "付款人", "对方"),
                setOf("来自", "付款方", "付款人", "对方"),
            )
            "REPAYMENT" ->
                CandidateFieldExtractor.repaymentTargetAccountHint(labels)
                    ?: "信用卡还款"
            else -> transferCounterparty(labels)
        }
        if (counterparty == null) return "NO_COUNTERPARTY"

        val amount = uniqueAmount(
            labels,
            when (type) {
                "REFUND" -> setOf("退款金额", "到账金额", "退款")
                "INCOME" -> setOf("收款金额", "到账金额", "收入金额", "收款")
                "REPAYMENT" -> setOf("还款金额", "本次还款", "还款")
                else -> setOf("转账金额", "转出金额", "付款金额", "金额")
            },
        )
        if (amount == null) return "NO_UNIQUE_TRANSACTION_AMOUNT"
        return "UNSUPPORTED_TRANSACTION_LAYOUT"
    }

    private fun isRefundStatus(label: String): Boolean =
        REFUND_STATUSES.any { label == it || label.startsWith(it) }

    private fun isIncomeStatus(label: String): Boolean =
        INCOME_STATUSES.any { label == it || label.startsWith(it) }

    private fun isRepaymentStatus(label: String): Boolean =
        REPAYMENT_STATUSES.any { label == it || label.startsWith(it) }

    private fun isTransferStatus(label: String): Boolean =
        TRANSFER_STATUSES.any { label == it || label.startsWith(it) }

    private fun isWeChatTransferConfirmation(
        sourceApp: String,
        labels: List<String>,
    ): Boolean =
        sourceApp == "WECHAT" &&
            labels.any { label ->
                PAYMENT_SUCCESS_STATUSES.any { status ->
                    label == status || label.startsWith(status)
                }
            } &&
            labels.any {
                it.contains("确认收款") ||
                    it.startsWith("转给") ||
                    it.startsWith("转账给")
            }

    private fun transferCounterparty(labels: List<String>): String? {
        explicitValue(
            labels,
            setOf("收款人", "收款方", "对方", "转账对象"),
            setOf("收款人", "收款方", "对方", "转给", "转账给"),
        )?.let { return it }

        return labels.firstNotNullOfOrNull { label ->
            if (!label.contains("确认收款")) return@firstNotNullOfOrNull null
            label.substringBeforeLast("确认收款")
                .trim()
                .removePrefix("等待")
                .removePrefix("待")
                .trim()
                .trimEnd('-', '—', ' ')
                .takeIf(::validCounterparty)
        }
    }

    private fun explicitValue(
        labels: List<String>,
        keys: Set<String>,
        prefixes: Set<String>,
    ): String? {
        CandidateFieldExtractor.field(labels, keys)?.let { value ->
            if (validCounterparty(value)) return value
        }
        for (label in labels) {
            for (prefix in prefixes.sortedByDescending { it.length }) {
                val value = when {
                    label.startsWith("$prefix：") ||
                        label.startsWith("$prefix:") ->
                        label.substring(prefix.length + 1).trim()
                    label.startsWith(prefix) && label.length > prefix.length ->
                        label.substring(prefix.length).trim()
                    else -> null
                }
                if (value != null && validCounterparty(value)) return value
            }
        }
        return null
    }

    private fun validCounterparty(value: String): Boolean =
        value.length in 2..80 &&
            !value.contains("金额") &&
            !value.contains("时间") &&
            !CURRENCY_PATTERN.containsMatchIn(value)

    private fun uniqueAmount(labels: List<String>, keys: Set<String>): Long? {
        CandidateFieldExtractor.labeledAmount(labels, keys)?.let { return it }

        val candidates = labels
            .filterNot { label ->
                label.contains("订单") ||
                    label.contains("原价") ||
                    label.contains("优惠") ||
                    label.contains("余额") ||
                    label.contains("尾号")
            }
            .flatMap { label ->
                CURRENCY_PATTERN.findAll(label)
                    .mapNotNull { match -> toCents(match.groupValues[1]) }
                    .toList()
            }
            .toSet()
        return candidates.singleOrNull()
    }

    private fun toCents(raw: String): Long? =
        raw.toBigDecimalOrNull()
            ?.multiply(BigDecimal(100))
            ?.let { runCatching { it.longValueExact() }.getOrNull() }
            ?.takeIf { it in 1..99_999_999_999L }

    private companion object {
        val REFUND_STATUSES = setOf(
            "退款成功",
            "退款到账",
            "退款已到账",
            "已退款",
            "退款完成",
        )
        val INCOME_STATUSES = setOf(
            "收款到账",
            "收款成功",
            "收款已到账",
            "收入到账",
        )
        val REPAYMENT_STATUSES = setOf(
            "信用卡还款成功",
            "还款成功",
            "还款已成功",
            "还款完成",
            "已还款",
            "账单已还清",
            "本期账单已还清",
        )
        val TRANSFER_STATUSES = setOf(
            "转账成功",
            "转账已成功",
            "转出成功",
            "转账完成",
            "转出完成",
            "已转账",
        )
        val PAYMENT_SUCCESS_STATUSES = setOf(
            "支付成功",
            "付款成功",
            "支付完成",
            "付款完成",
        )
        val CURRENCY_PATTERN = Regex(
            "[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)(?![0-9.])",
        )
    }
}
