package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import java.math.BigDecimal

/**
 * Native counterpart of the Flutter payment-notification parser.
 *
 * It exists so NotificationListenerService can provide a real-time fallback
 * while another app is in the foreground. The Flutter parser remains the
 * foreground recovery path for raw notifications already persisted on disk.
 */
class PaymentNotificationCandidateParser {
    fun parse(
        packageName: String,
        title: String,
        text: String,
        timestamp: Long,
    ): PaymentCandidate? {
        val source = SOURCES[packageName] ?: return null
        val content = "$title $text".trim()
        if (content.isBlank()) return null
        if (REJECT_PATTERN.containsMatchIn(content)) return null

        val hasStrongSuccess = SUCCESS_PATTERN.containsMatchIn(content)
        val hasWalletDebit = DEBIT_PATTERN.containsMatchIn(content)
        val hasNonTransactionSignal = NON_TRANSACTION_PATTERN.containsMatchIn(content)

        if (
            packageName == WECHAT_PACKAGE &&
            hasStrongSuccess &&
            !WECHAT_CONTEXT_PATTERN.containsMatchIn(content)
        ) {
            return null
        }

        if (packageName in MARKETPLACE_PACKAGES) {
            if (!hasStrongSuccess) return null
        } else if (!hasStrongSuccess && (!hasWalletDebit || hasNonTransactionSignal)) {
            return null
        }

        val amount = amountInCents(content) ?: return null
        val merchant = merchant(content) ?: return null
        val paymentMethod = PAYMENT_METHODS[packageName] ?: "支付应用"

        return PaymentCandidate(
            amountInCents = amount,
            merchantRaw = merchant,
            merchantNormalized = MerchantNormalizer.normalize(merchant).take(80),
            paymentMethod = paymentMethod,
            timestamp = timestamp,
            scene = PaymentScene(
                sourceApp = source,
                scene = "PAYMENT_NOTIFICATION",
                confidence = .90,
            ),
            amountConfidence = .95,
            merchantConfidence = .90,
            sourceApp = source,
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

    private fun amountToCents(raw: String): Long? {
        val decimal = raw.replace(',', '.').toBigDecimalOrNull() ?: return null
        return decimal.multiply(BigDecimal(100))
            .let { runCatching { it.longValueExact() }.getOrNull() }
            ?.takeIf { it in 1..99_999_999_999L }
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

        val MARKETPLACE_PACKAGES = setOf(
            "com.sankuai.meituan",
            "com.sankuai.meituan.takeout",
            "com.jingdong.app.mall",
            "com.xunmeng.pinduoduo",
            "com.ss.android.ugc.aweme",
            "com.ss.android.ugc.aweme.mobile",
        )

        val SOURCES = mapOf(
            WECHAT_PACKAGE to "WECHAT",
            "com.eg.android.AlipayGphone" to "ALIPAY",
            "com.unionpay" to "UNIONPAY",
            "com.sankuai.meituan" to "MEITUAN",
            "com.sankuai.meituan.takeout" to "MEITUAN",
            "com.jingdong.app.mall" to "JD",
            "com.xunmeng.pinduoduo" to "PINDUODUO",
            "com.ss.android.ugc.aweme" to "DOUYIN",
            "com.ss.android.ugc.aweme.mobile" to "DOUYIN",
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
            "收款到账|收款成功|转入|入账|到账|退款|退回|" +
                "待支付|待付款|去支付|去付款|未支付|未付款|" +
                "支付失败|付款失败|交易失败|支付取消|付款取消|" +
                "取消支付|重新支付|支付提醒|请支付",
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
            "(?:实付金额?|实际支付|付款金额|支付金额|消费金额|扣款金额)" +
                "[^0-9]{0,10}(?:¥|￥)?\\s*([0-9]{1,9}(?:[.,][0-9]{1,2})?)",
        )
        val STATUS_AMOUNT_PATTERN = Regex(
            "(?:支付|付款|消费|扣款)[^0-9]{0,12}(?:¥|￥)?\\s*" +
                "([0-9]{1,9}(?:[.,][0-9]{1,2})?)",
        )
        val CURRENCY_AMOUNT_PATTERN = Regex("[¥￥]\\s*([0-9]+(?:[.,][0-9]{1,2})?)")

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
