package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry
import com.algive.jizhang_app.autobookkeeping.rules.PaymentParserKind
import java.math.BigDecimal

/**
 * Native counterpart of the Flutter payment-notification parser.
 *
 * It exists so NotificationListenerService can provide a real-time fallback
 * while another app is in the foreground. The Flutter parser remains the
 * foreground recovery path for raw notifications already persisted on disk.
 */
class PaymentNotificationCandidateParser(
    private val registry: AutoBookkeepingRuleRegistry =
        AutoBookkeepingRuleRegistry.builtIn(),
) {
    fun parse(
        packageName: String,
        title: String,
        text: String,
        timestamp: Long,
    ): PaymentCandidate? {
        val rule = registry.ruleFor(packageName) ?: return null
        val source = rule.sourceApp
        val content = "$title $text".trim()
        if (content.isBlank()) return null

        val transactionType = when {
            REFUND_PATTERN.containsMatchIn(content) -> "REFUND"
            REIMBURSEMENT_PATTERN.containsMatchIn(content) -> "REIMBURSEMENT"
            INCOME_PATTERN.containsMatchIn(content) -> "INCOME"
            REPAYMENT_PATTERN.containsMatchIn(content) -> "REPAYMENT"
            TRANSFER_PATTERN.containsMatchIn(content) -> "TRANSFER"
            else -> "EXPENSE"
        }

        if (
            packageName == WECHAT_PACKAGE &&
            transactionType != "EXPENSE" &&
            !WECHAT_CONTEXT_PATTERN.containsMatchIn(content)
        ) {
            return null
        }

        if (transactionType == "EXPENSE") {
            if (REJECT_PATTERN.containsMatchIn(content)) return null
            val hasStrongSuccess = SUCCESS_PATTERN.containsMatchIn(content)
            val hasWalletDebit = DEBIT_PATTERN.containsMatchIn(content)
            val hasNonTransactionSignal =
                NON_TRANSACTION_PATTERN.containsMatchIn(content)

            if (
                packageName == WECHAT_PACKAGE &&
                hasStrongSuccess &&
                !WECHAT_CONTEXT_PATTERN.containsMatchIn(content)
            ) {
                return null
            }

            if (
                rule.parserKind == PaymentParserKind.MEITUAN ||
                source in MARKETPLACE_SOURCES
            ) {
                if (!hasStrongSuccess) return null
            } else if (!hasStrongSuccess && (!hasWalletDebit || hasNonTransactionSignal)) {
                return null
            }
        }

        val amount = amountInCents(content) ?: return null
        val merchant =
            merchant(content)
                ?: counterparty(content)
                ?: if (transactionType == "REPAYMENT") targetAccountHint(content)
                else null
                ?: when (transactionType) {
                    "REPAYMENT" -> "信用卡还款"
                    "REIMBURSEMENT" -> "报销回款"
                    else -> null
                }
                ?: return null
        val paymentMethod =
            explicitPaymentMethod(content)
                ?: PAYMENT_METHODS[packageName]
                ?: "支付应用"
        val originalAmount = labeledAmount(content, ORIGINAL_AMOUNT_PATTERN)
        val discountAmount = labeledAmount(content, DISCOUNT_AMOUNT_PATTERN)
        val normalizedBreakdown = normalizeBreakdown(
            paidAmount = amount,
            originalAmount = originalAmount,
            discountAmount = discountAmount,
        )

        return PaymentCandidate(
            amountInCents = amount,
            merchantRaw = merchant,
            merchantNormalized = MerchantNormalizer.normalize(merchant).take(80),
            paymentMethod = paymentMethod,
            timestamp = timestamp,
            scene = PaymentScene(
                sourceApp = source,
                scene = when (transactionType) {
                    "REFUND" -> "PAYMENT_NOTIFICATION_REFUND"
                    "INCOME" -> "PAYMENT_NOTIFICATION_INCOME"
                    "REIMBURSEMENT" -> "PAYMENT_NOTIFICATION_REIMBURSEMENT"
                    "TRANSFER" -> "PAYMENT_NOTIFICATION_TRANSFER"
                    "REPAYMENT" -> "PAYMENT_NOTIFICATION_REPAYMENT"
                    else -> "PAYMENT_NOTIFICATION"
                },
                confidence = .90,
            ),
            amountConfidence = .95,
            merchantConfidence = .90,
            sourceApp = source,
            transactionType = transactionType,
            orderId = ORDER_ID_PATTERN.find(content)?.groupValues?.getOrNull(1),
            note = NOTE_PATTERN.find(content)
                ?.groupValues
                ?.getOrNull(1)
                ?.trim()
                ?.takeIf { it.isNotBlank() }
                ?.take(160),
            originalAmountInCents = normalizedBreakdown.first,
            discountAmountInCents = normalizedBreakdown.second,
            identifierSuffix = identifierSuffix(
                if (transactionType == "TRANSFER" || transactionType == "REPAYMENT") {
                    paymentMethod
                } else {
                    content
                },
            ),
            targetIdentifierSuffix =
                if (transactionType == "TRANSFER" || transactionType == "REPAYMENT") {
                    targetAccountHint(content)?.let(::identifierSuffix)
                } else {
                    null
                },
            targetAccountHint =
                if (transactionType == "TRANSFER" || transactionType == "REPAYMENT") {
                    targetAccountHint(content)
                } else {
                    null
                },
        )
    }

    private fun amountInCents(content: String): Long? {
        val explicit = EXPLICIT_AMOUNT_PATTERN.findAll(content)
            .mapNotNull { amountToCents(it.groupValues[1]) }
            .toSet()
        if (explicit.size == 1) return explicit.single()
        if (explicit.size > 1) return null

        val status = STATUS_AMOUNT_PATTERN.findAll(content)
            .mapNotNull { amountToCents(it.groupValues[1]) }
            .toSet()
        if (status.size == 1) return status.single()
        if (status.size > 1) return null

        val currency = CURRENCY_AMOUNT_PATTERN.findAll(content)
            .mapNotNull { amountToCents(it.groupValues[1]) }
            .toSet()
        return currency.singleOrNull()
    }

    private fun labeledAmount(content: String, pattern: Regex): Long? {
        val values = pattern.findAll(content)
            .mapNotNull { amountToCents(it.groupValues[1]) }
            .toSet()
        return values.singleOrNull()
    }

    private fun normalizeBreakdown(
        paidAmount: Long,
        originalAmount: Long?,
        discountAmount: Long?,
    ): Pair<Long?, Long?> {
        var original = originalAmount?.takeIf { it >= paidAmount }
        var discount = discountAmount?.takeIf { it >= 0L }
        if (original != null && discount == null) {
            (original - paidAmount).takeIf { it > 0L }?.let { discount = it }
        }
        if (discount != null && original == null) {
            original = paidAmount + discount
        }
        if (
            original != null &&
            discount != null &&
            original - discount != paidAmount
        ) {
            return null to null
        }
        return original to discount
    }

    private fun amountToCents(raw: String): Long? {
        val decimal = raw.replace(',', '.').toBigDecimalOrNull() ?: return null
        return decimal.multiply(BigDecimal(100))
            .let { runCatching { it.longValueExact() }.getOrNull() }
            ?.takeIf { it in 1..99_999_999_999L }
    }

    private fun explicitPaymentMethod(content: String): String? =
        PAYMENT_METHOD_PATTERN.find(content)
            ?.groupValues
            ?.getOrNull(1)
            ?.trim()
            ?.take(40)
            ?.takeIf { it.isNotBlank() }

    private fun identifierSuffix(content: String): String? =
        IDENTIFIER_SUFFIX_PATTERN.find(content)?.let { match ->
            match.groupValues.getOrNull(1)?.takeIf { it.isNotBlank() }
                ?: match.groupValues.getOrNull(2)?.takeIf { it.isNotBlank() }
        }

    private fun targetAccountHint(content: String): String? =
        TARGET_ACCOUNT_PATTERN.find(content)
            ?.groupValues
            ?.getOrNull(1)
            ?.trim()
            ?.take(120)
            ?.takeIf { it.isNotBlank() }

    private fun counterparty(content: String): String? {
        val match = COUNTERPARTY_PATTERN.find(content)
        val value = match?.groupValues?.getOrNull(1)?.trim()?.take(80)
        if (value.isNullOrBlank()) return null
        if (INVALID_MERCHANT_PATTERN.containsMatchIn(value)) return null
        return value
    }

    private fun merchant(content: String): String? {
        val explicit = EXPLICIT_MERCHANT_PATTERN.find(content)?.groupValues?.get(1)
        val directional = DIRECTIONAL_MERCHANT_PATTERN.find(content)?.groupValues?.get(1)
        val value = (explicit ?: directional)?.trim()?.take(80) ?: return null
        if (value.isBlank()) return null
        if (INVALID_MERCHANT_PATTERN.containsMatchIn(value)) return null
        return value
    }

    private companion object {
        const val WECHAT_PACKAGE = "com.tencent.mm"

        val MARKETPLACE_SOURCES = setOf(
            "MEITUAN",
            "JD",
            "PINDUODUO",
            "DOUYIN",
        )

        val PAYMENT_METHODS = mapOf(
            WECHAT_PACKAGE to "微信支付",
            "com.eg.android.AlipayGphone" to "支付宝",
            "com.unionpay" to "云闪付",
            "com.sankuai.meituan" to "美团支付",
            "com.sankuai.meituan.takeout" to "美团支付",
            "com.jingdong.app.mall" to "京东支付",
            "com.xunmeng.pinduoduo" to "拼多多支付",
            "com.ss.android.ugc.aweme" to "抖音支付",
            "com.ss.android.ugc.aweme.mobile" to "抖音支付",
        )

        val REJECT_PATTERN = Regex(
            "转入提醒|入账提醒|到账提醒|退回失败|" +
                "待支付|待付款|去支付|去付款|未支付|未付款|" +
                "支付失败|付款失败|交易失败|支付取消|付款取消|" +
                "取消支付|重新支付|支付提醒|请支付",
        )
        val REFUND_PATTERN = Regex(
            "退款成功|退款到账|退款已到账|已退款|退款完成",
        )
        val REIMBURSEMENT_PATTERN = Regex(
            "报销到账|报销款到账|费用报销到账|报销成功|费用报销成功",
        )
        val INCOME_PATTERN = Regex(
            "收款到账|收款成功|收款已到账|收入到账",
        )
        val REPAYMENT_PATTERN = Regex(
            "信用卡还款成功|还款成功|还款已成功|还款完成|已还款|账单已还清|本期账单已还清",
        )
        val TRANSFER_PATTERN = Regex(
            "转账成功|转账已成功|转出成功|转账完成|转出完成|已转账",
        )
        val SUCCESS_PATTERN = Regex(
            "支付成功|付款成功|交易成功|扣款成功|消费成功|" +
                "已支付|已付款|支付完成|付款完成|订单支付成功|" +
                "订单已支付|订单支付完成|支付已完成|付款已完成|交易已完成",
        )
        val DEBIT_PATTERN = Regex("消费|扣款|支出")
        val NON_TRANSACTION_PATTERN = Regex("优惠券|消费券|立减券|活动提醒|付款码|收款码")
        val WECHAT_CONTEXT_PATTERN = Regex("微信支付|支付凭证|付款凭证|服务通知")

        val EXPLICIT_AMOUNT_PATTERN = Regex(
            "(?:实付金额?|实际支付|付款金额|支付金额|消费金额|扣款金额|" +
                "退款金额|收款金额|到账金额|收入金额|报销金额|报销款|" +
                "转账金额|转出金额|还款金额|本次还款)" +
                "[^0-9]{0,10}(?:¥|￥)?\\s*([0-9]{1,9}(?:[.,][0-9]{1,2})?)",
        )
        val STATUS_AMOUNT_PATTERN = Regex(
            "(?:支付成功|付款成功|交易成功|扣款成功|消费成功|已支付|已付款|" +
                "支付完成|付款完成|订单支付成功|订单已支付|订单支付完成|" +
                "支付已完成|付款已完成|交易已完成|转账成功|转出成功|" +
                "转账完成|转出完成|已转账|报销到账|报销款到账|" +
                "报销成功|信用卡还款成功|还款成功|还款完成|已还款|" +
                "消费|扣款|支出)" +
                "[^0-9]{0,12}(?:¥|￥)?\\s*" +
                "([0-9]{1,9}(?:[.,][0-9]{1,2})?)",
        )
        val CURRENCY_AMOUNT_PATTERN = Regex("[¥￥]\\s*([0-9]+(?:[.,][0-9]{1,2})?)")

        val PAYMENT_METHOD_PATTERN = Regex(
            "(?:支付方式|付款方式|支付渠道|扣款账户|还款资金来源)[：:\\s]*([^，。；;\\n]{2,40})",
        )
        val ORDER_ID_PATTERN = Regex(
            "(?:订单号|交易单号|交易号|流水号|支付单号)[：:\\s]*([A-Za-z0-9_-]{6,64})",
        )
        val TARGET_ACCOUNT_PATTERN = Regex(
            "(?:转入账户|收款账户|到账账户|收款银行卡|转入银行卡|" +
                "还款至|还款信用卡|债务账户|账单账户|还款对象)" +
                "[：:\\s]*([^，。；;\\n]{2,120})",
        )
        val IDENTIFIER_SUFFIX_PATTERN = Regex(
            "(?:尾号|后四位|卡号后四位|手机号后四位)[^0-9]{0,8}([0-9]{4})|" +
                "(?:银行卡|信用卡|储蓄卡)[^0-9]{0,8}([0-9]{4})(?![0-9])",
        )
        val NOTE_PATTERN = Regex(
            "(?:备注|订单备注|付款备注)[：:\\s]+([^，。；;\\n]{2,80})",
        )
        val ORIGINAL_AMOUNT_PATTERN = Regex(
            "(?:原价|订单金额|商品金额|合计|应付金额)[^0-9]{0,8}(?:¥|￥)?\\s*" +
                "([0-9]{1,9}(?:[.,][0-9]{1,2})?)",
        )
        val DISCOUNT_AMOUNT_PATTERN = Regex(
            "(?:优惠金额|优惠|立减|红包|优惠券)[^0-9]{0,8}(?:¥|￥)?\\s*" +
                "([0-9]{1,9}(?:[.,][0-9]{1,2})?)",
        )

        val COUNTERPARTY_PATTERN = Regex(
            "(?:来自|付款方|付款人|退款方|报销方|收款人|收款方|对方|还款对象)[：:\\s]*([^，。；;\\n]{2,32})",
        )
        val EXPLICIT_MERCHANT_PATTERN = Regex(
            "(?:商户名称|商户|商家名称|商家|店铺名称|店铺|门店|收款方)" +
                "[：:\\s]+([^，。；;\\n]{2,32})",
        )
        val DIRECTIONAL_MERCHANT_PATTERN = Regex(
            "(?:向|在)\\s*([^，。；;\\n]{2,32}?)(?:支付|付款|消费)",
        )
        val INVALID_MERCHANT_PATTERN = Regex(
            "[¥￥]|支付成功|付款成功|交易成功|实付金额|支付金额",
        )
    }
}
