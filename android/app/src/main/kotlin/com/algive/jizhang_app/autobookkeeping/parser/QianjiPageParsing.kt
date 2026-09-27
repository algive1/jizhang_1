package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import java.math.BigDecimal
import java.util.Calendar

/** Result distinguishes an unsupported package, no page match, and a matched page rejected by its parser. */
internal data class QianjiPageParseResult(
    val pageType: String? = null,
    val candidate: PaymentCandidate? = null,
    val rejectionReason: String? = null,
    val profileGateRejected: Boolean = false,
) {
    val matchedPage: Boolean get() = pageType != null
    val blocksLegacyFallback: Boolean get() = matchedPage || profileGateRejected

    companion object {
        val NoMatch = QianjiPageParseResult()

        fun rejected(pageType: String, reason: String) =
            QianjiPageParseResult(pageType, null, reason)

        fun rejectedProfileGate(reason: String) =
            QianjiPageParseResult(rejectionReason = reason, profileGateRejected = true)
    }
}

/** One exact package profile with recognizers evaluated in registration order. */
internal interface QianjiAppPageParser {
    val packageName: String
    val registeredPageTypes: List<String>

    fun acceptsActivity(activityClassName: String?): Boolean = true

    fun parse(
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult
}

/** Audited profile registry order from 钱迹 4.5.3b7; some registered rules are shadowed. */
internal object QianjiPageCatalog {
    val pageTypesByPackage: Map<String, List<String>> = linkedMapOf(
        "com.tencent.mm" to listOf(
            "WechatPersonalRedPacketSend",
            "WechatGroupRedPacketDetail",
            "WechatPersonalRedPacketReceive",
            "WechatPersonalRedPacketReceive2",
            "WeChatTransferDetail",
            "WeChatTransferInDetail",
            "WeChatBillDetail",
            "WeChatTransferDetailWaiting",
            "WechatWithdrawSuccess",
            "WechatWithdrawDetail",
            "WechatChargeDetail",
            "WeChatPaySuccess",
        ),
        "com.eg.android.AlipayGphone" to listOf(
            "AlipayBillDetail",
            "AlipayPaySuccess",
            "AlipayTransfer",
            "AlipayTransferOut",
            "AlipayTransferIn",
            "AlipayCharge",
            "AlipayChargeDetail",
            "AlipayWithdraw",
            "AlipayWithdrawDetail",
            "AlipaySendRedPacket",
            "AlipayQRCodeReceiveDetail",
            "AlipayYuLiBaoIncomeDetail",
            "AlipayYuLiBaoTransferOutSuccess",
            "AlipayYuLiBaoTransferOutDetail",
            "AlipayYuLiBaoTransferInDetail",
            "AlipayYuLiBaoTransferInSuccess",
        ),
        "com.xunmeng.pinduoduo" to listOf(
            "PddOrderDetail",
            "PddPayFirstDialog",
            "PddWalletBillDetail",
        ),
        "com.unionpay" to listOf(
            "UnionpayBillDetail",
            "UnionpayPaySuccess",
            "UnionpayTransferSuccess",
            "UnionpayTransferDetail",
            "UnionpayMessageOrderDetail",
        ),
        "com.jingdong.app.mall" to listOf(
            "JingDongWalletBillDetail",
            "JingDongWalletBillDetailV2",
            "JingDongAihuishouOrderDetail",
            "JingDongOrderDetail",
            "JingDongOrderWeb",
            "JingDongPaySuccess",
        ),
        "com.sankuai.meituan" to listOf(
            "MeiTuanOrderDetail",
            "MeiTuanVoucherDetail",
            "MeiTuanVoucherSuccessDetail",
            "MeiTuanGrouponDetail",
            "MeiTuanMovieDetail",
            "MeiTuanChargeOrderDetail",
            "MeiTuanBikeOrderDetail",
            "MeiTuanPaySuccess",
            "MeiTuanWalletBillDetail",
            "MeiTuanDeliveryDetail",
        ),
        "com.ss.android.ugc.aweme" to listOf(
            "DouyingTransferWaiting",
            "DouyingTransferReceived",
            "DouyingWalletBillDetail",
            "DouyingPaySuccess",
        ),
    )
}

/** Lookup for the seven packages actually present in Qianji 4.5.3b7's profile registry. */
internal class QianjiProfilePageParserRegistry(
    parsers: List<QianjiAppPageParser>,
) {
    private val byPackage = parsers.associateBy(QianjiAppPageParser::packageName)

    init {
        require(byPackage.size == parsers.size) { "Duplicate Qianji profile package" }
        require(byPackage.keys == QianjiPageCatalog.pageTypesByPackage.keys) {
            "Qianji profile registry must match the seven audited package gates"
        }
        require(parsers.sumOf { it.registeredPageTypes.size } == 56) {
            "Qianji page registry must cover all 56 audited page types"
        }
        val pageTypes = parsers.flatMap(QianjiAppPageParser::registeredPageTypes)
        require(pageTypes.size == pageTypes.toSet().size) {
            "Duplicate Qianji page type"
        }
        parsers.forEach { parser ->
            require(parser.registeredPageTypes == QianjiPageCatalog.pageTypesByPackage[parser.packageName]) {
                "${parser.packageName} page types must match the audited page order"
            }
        }
    }

    val supportedPackages: Set<String> get() = byPackage.keys

    fun inspect(
        packageName: String,
        nodes: List<ScreenNode>,
        observedAt: Long,
        activityClassName: String? = null,
    ): QianjiPageParseResult? {
        val parser = byPackage[packageName] ?: return null
        if (!parser.acceptsActivity(activityClassName)) {
            return QianjiPageParseResult.rejectedProfileGate("PROFILE_ACTIVITY_REJECTED")
        }
        return parser.parse(nodes, observedAt)
    }
}

/** Shared, local-only extraction helpers for the page-specific parsers. */
internal object QianjiPageSupport {
    private val moneyPattern = Regex(
        "(?<![0-9.])(?:[¥￥]\\s*[+-]?\\s*|[+-]\\s*(?:[¥￥]\\s*)?)?([0-9][0-9,]*(?:\\.[0-9]{1,2})?)(?:\\s*元)?(?![0-9.])",
    )
    private val dateTimePattern = Regex(
        "(?<![0-9])(20[0-9]{2})[-./年]\\s*([0-9]{1,2})[-./月]\\s*([0-9]{1,2})日?(?:\\s+([0-9]{1,2}):([0-9]{2})(?::([0-9]{2}))?)?",
    )
    fun labels(nodes: List<ScreenNode>): List<String> =
        nodes.map(ScreenNode::label).filter(String::isNotBlank)

    fun hasAny(nodes: List<ScreenNode>, vararg fragments: String): Boolean =
        nodes.any { node -> fragments.any { node.label.contains(it, ignoreCase = false) } }

    fun hasAll(nodes: List<ScreenNode>, vararg fragments: String): Boolean =
        fragments.all { fragment -> nodes.any { it.label.contains(fragment) } }

    fun hasOneOfEach(nodes: List<ScreenNode>, groups: List<Set<String>>): Boolean =
        groups.all { group -> group.isNotEmpty() && hasAny(nodes, *group.toTypedArray()) }

    fun firstValueAfter(
        nodes: List<ScreenNode>,
        keys: Set<String>,
        maxLookAhead: Int = 3,
    ): String? {
        if (keys.isEmpty()) return null
        for (index in nodes.indices) {
            val label = nodes[index].label.trim()
            val key = keys.sortedByDescending(String::length).firstOrNull { candidate ->
                label == candidate ||
                    label.startsWith("$candidate：") ||
                    label.startsWith("$candidate:") ||
                    ((candidate.endsWith('：') || candidate.endsWith(':')) &&
                        label.startsWith(candidate)) ||
                    label.startsWith(candidate) && label.length > candidate.length &&
                    label[candidate.length].isWhitespace()
            } ?: continue

            val inline = label.substring(key.length).trimStart(' ', '：', ':', '￥', '¥')
            if (inline.isNotBlank()) return inline
            val end = (index + maxLookAhead + 1).coerceAtMost(nodes.size)
            for (next in index + 1 until end) {
                nodes[next].label.trim().takeIf(String::isNotBlank)?.let { return it }
            }
        }
        return null
    }

    fun firstValueBefore(
        nodes: List<ScreenNode>,
        keys: Set<String>,
        maxLookBehind: Int = 2,
    ): String? {
        if (keys.isEmpty()) return null
        for (index in nodes.indices) {
            val label = nodes[index].label.trim()
            if (keys.none { key -> label == key || label.startsWith("$key：") || label.startsWith("$key:") }) {
                continue
            }
            val end = (index - maxLookBehind).coerceAtLeast(0)
            for (previous in index - 1 downTo end) {
                nodes[previous].label.trim().takeIf(String::isNotBlank)?.let { return it }
            }
        }
        return null
    }

    fun firstRegexValue(nodes: List<ScreenNode>, regex: Regex, group: Int = 1): String? =
        nodes.firstNotNullOfOrNull { node ->
            regex.find(node.label)?.groups?.get(group)?.value?.trim()?.takeIf(String::isNotBlank)
        }

    fun moneyValues(text: String): List<Long> {
        val withoutDate = dateTimePattern.replace(text, " ").trim()
        if (
            withoutDate.none { it == '¥' || it == '￥' || it == '元' || it == '.' } &&
            !withoutDate.matches(Regex("[+-]?[0-9][0-9,]*"))
        ) return emptyList()
        return moneyPattern.findAll(withoutDate)
            .mapNotNull { match -> toCents(match.groupValues[1]) }
            .toList()
    }

    fun uniqueMoneyAfter(
        nodes: List<ScreenNode>,
        keys: Set<String>,
        maxLookAhead: Int = 3,
    ): Long? {
        if (keys.isEmpty()) return null
        val amounts = linkedSetOf<Long>()
        for (index in nodes.indices) {
            val label = nodes[index].label.trim()
            val key = keys.sortedByDescending(String::length).firstOrNull { candidate ->
                label == candidate || label.startsWith("$candidate：") ||
                    label.startsWith("$candidate:") ||
                    ((candidate.endsWith('：') || candidate.endsWith(':')) &&
                        label.startsWith(candidate)) ||
                    (label.startsWith(candidate) && label.length > candidate.length &&
                        label[candidate.length] in "¥￥+-") ||
                    (label.startsWith(candidate) && label.length > candidate.length &&
                        label[candidate.length].isWhitespace())
            } ?: continue

            val inline = label.substring(key.length)
            val inlineAmounts = moneyValues(inline)
            if (inlineAmounts.isNotEmpty()) {
                amounts.addAll(inlineAmounts)
                continue
            }
            val end = (index + maxLookAhead + 1).coerceAtMost(nodes.size)
            for (next in index + 1 until end) {
                val value = nodes[next].label.trim()
                if (value.isBlank()) continue
                val adjacent = moneyValues(value)
                if (adjacent.isNotEmpty()) amounts.addAll(adjacent)
                break
            }
        }
        return amounts.singleOrNull()
    }

    fun uniqueVisibleMoney(nodes: List<ScreenNode>, excluded: Set<String> = emptySet()): Long? {
        val amounts = nodes.asSequence()
            .map(ScreenNode::label)
            .filter { text -> excluded.none(text::contains) }
            .flatMap { moneyValues(it).asSequence() }
            .toSet()
        return amounts.singleOrNull()
    }

    fun toCents(raw: String): Long? = raw.trim()
        .replace(",", "")
        .toBigDecimalOrNull()
        ?.abs()
        ?.multiply(BigDecimal(100))
        ?.let { runCatching { it.longValueExact() }.getOrNull() }
        ?.takeIf { it in 1..99_999_999_999L }

    fun timestampFromText(text: String?): Long? {
        if (text.isNullOrBlank()) return null
        val match = dateTimePattern.find(text) ?: return null
        val year = match.groupValues[1].toIntOrNull() ?: return null
        val month = match.groupValues[2].toIntOrNull() ?: return null
        val day = match.groupValues[3].toIntOrNull() ?: return null
        val hour = match.groupValues[4].toIntOrNull() ?: 0
        val minute = match.groupValues[5].toIntOrNull() ?: 0
        val second = match.groupValues[6].toIntOrNull() ?: 0
        val calendar = Calendar.getInstance().apply {
            isLenient = false
            clear()
            set(year, month - 1, day, hour, minute, second)
            set(Calendar.MILLISECOND, 0)
        }
        return runCatching { calendar.timeInMillis }.getOrNull()
    }

    fun timestampAfter(
        nodes: List<ScreenNode>,
        keys: Set<String>,
        observedAt: Long,
    ): Long = timestampFromText(firstValueAfter(nodes, keys)) ?: observedAt

    fun candidate(
        sourceApp: String,
        pageType: String,
        amountInCents: Long,
        merchant: String,
        paymentMethod: String = "UNKNOWN",
        observedAt: Long,
        transactionAt: Long? = null,
        transactionType: String = "EXPENSE",
        note: String? = null,
        orderId: String? = null,
        originalAmountInCents: Long? = null,
        discountAmountInCents: Long? = null,
        identifierSuffix: String? = null,
        targetIdentifierSuffix: String? = null,
        targetAccountHint: String? = null,
    ): PaymentCandidate? {
        val cleanMerchant = merchant.trim().take(80)
        if (
            amountInCents !in 1..99_999_999_999L ||
            cleanMerchant.isBlank() ||
            sourceApp !in SUPPORTED_SOURCE_APPS ||
            transactionType !in SUPPORTED_TRANSACTION_TYPES ||
            pageType.isBlank()
        ) return null

        return PaymentCandidate(
            amountInCents = amountInCents,
            merchantRaw = cleanMerchant,
            merchantNormalized = MerchantNormalizer.normalize(cleanMerchant).take(80),
            paymentMethod = paymentMethod.trim().take(80).ifBlank { "UNKNOWN" },
            timestamp = transactionAt?.takeIf { it > 0L } ?: observedAt,
            scene = PaymentScene(
                sourceApp = sourceApp,
                scene = "QIANJI_$pageType",
                confidence = .96,
            ),
            amountConfidence = 1.0,
            merchantConfidence = .94,
            sourceApp = sourceApp,
            transactionType = transactionType,
            orderId = orderId?.trim()?.takeIf(String::isNotBlank)?.take(64),
            note = note?.trim()?.takeIf(String::isNotBlank)?.take(160),
            originalAmountInCents = originalAmountInCents,
            discountAmountInCents = discountAmountInCents,
            identifierSuffix = identifierSuffix?.takeIf { it.matches(Regex("\\d{4}")) },
            targetIdentifierSuffix = targetIdentifierSuffix?.takeIf { it.matches(Regex("\\d{4}")) },
            targetAccountHint = targetAccountHint?.trim()?.takeIf(String::isNotBlank)?.take(120),
        )
    }

    private val SUPPORTED_SOURCE_APPS = setOf(
        "WECHAT", "ALIPAY", "PINDUODUO", "UNIONPAY", "JD", "MEITUAN", "DOUYIN",
    )
    private val SUPPORTED_TRANSACTION_TYPES = setOf(
        "EXPENSE", "INCOME", "TRANSFER", "REFUND",
    )
}
