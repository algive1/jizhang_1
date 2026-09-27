package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode

/** Ordered reconstruction of the three Pinduoduo page parsers in Qianji 4.5.3b7. */
internal class QianjiPddPageParser : QianjiAppPageParser {
    override val packageName: String = "com.xunmeng.pinduoduo"
    override val registeredPageTypes: List<String> = listOf(
        PDD_ORDER_DETAIL,
        PDD_PAY_FIRST_DIALOG,
        PDD_WALLET_BILL_DETAIL,
    )

    override fun parse(nodes: List<ScreenNode>, observedAt: Long): QianjiPageParseResult = when {
        isOrderDetail(nodes) -> parseOrderDetail(nodes, observedAt)
        isPayFirstDialog(nodes) -> parsePayFirstDialog(nodes, observedAt)
        isWalletBillDetail(nodes) -> parseWalletBillDetail(nodes, observedAt)
        else -> QianjiPageParseResult.NoMatch
    }

    private fun isOrderDetail(nodes: List<ScreenNode>): Boolean =
        QianjiPddDouyinSupport.hasPrefixAny(nodes, ORDER_TIME_LABELS) &&
            QianjiPddDouyinSupport.hasAny(nodes, *ORDER_STATES.toTypedArray()) &&
            QianjiPddDouyinSupport.hasAny(nodes, *ORDER_ACTIONS.toTypedArray()) &&
            QianjiPddDouyinSupport.hasPrefix(nodes, "商品名称：", "商品名称:") &&
            QianjiPddDouyinSupport.hasStandaloneAmount(nodes)

    private fun parseOrderDetail(
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        val extracted = QianjiPddDouyinSupport.pddOrderAmount(nodes)
            ?: return rejected(PDD_ORDER_DETAIL, "NO_UNAMBIGUOUS_ORDER_AMOUNT")
        val product = QianjiPddDouyinSupport.firstValueAfter(
            nodes,
            setOf("商品名称", "商品名称：", "商品名称:"),
            maxLookAhead = 2,
        )?.takeIf(QianjiPddDouyinSupport::isPlausibleNote)
        val status = QianjiPageSupport.labels(nodes).firstOrNull { label ->
            ORDER_STATES.any(label::contains)
        }
        val note = listOfNotNull(
            product,
            status?.takeIf { it.contains("待") || it.contains("发货") || it.contains("收货") || it.contains("拼团") },
        ).distinct().joinToString("；").ifBlank { null }

        // Qianji's PDD order parser leaves merchant unset. The local candidate model requires one.
        return candidateResult(
            pageType = PDD_ORDER_DETAIL,
            amount = extracted.amount,
            merchant = QianjiPddDouyinSupport.firstValueAfter(
                nodes,
                MERCHANT_LABELS,
                maxLookAhead = 2,
            )?.takeIf(QianjiPddDouyinSupport::isPlausibleMerchant) ?: "拼多多",
            observedAt = observedAt,
            transactionAt = QianjiPageSupport.timestampAfter(nodes, ORDER_TIME_LABELS.toSet(), observedAt),
            paymentMethod = QianjiPddDouyinSupport.firstValueAfter(
                nodes,
                PAYMENT_METHOD_LABELS,
                maxLookAhead = 2,
            ) ?: "UNKNOWN",
            note = note,
            orderId = QianjiPddDouyinSupport.firstValueAfter(nodes, ORDER_ID_LABELS, 2),
            originalAmount = extracted.originalAmount,
            discountAmount = extracted.discountAmount,
        )
    }

    private fun isPayFirstDialog(nodes: List<ScreenNode>): Boolean =
        QianjiPddDouyinSupport.hasAll(
            nodes,
            "使用“先用后付”下单成功",
            "等待收货",
            "知道了",
            "查看订单",
        ) && QianjiPddDouyinSupport.hasPrefix(nodes, "先用后付下单，实付") &&
            QianjiPddDouyinSupport.hasAny(nodes, "确认收货后，自动付款¥", "确认收货后，自动付款￥")

    private fun parsePayFirstDialog(
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        val amount = QianjiPddDouyinSupport.amountAfterMarker(
            nodes,
            listOf("确认收货后，自动付款¥", "确认收货后，自动付款￥", "确认收货后，自动付款"),
        ) ?: return rejected(PDD_PAY_FIRST_DIALOG, "DEFERRED_PAYMENT_AMOUNT_UNREADABLE")
        val immediate = QianjiPddDouyinSupport.amountAfterMarker(
            nodes,
            listOf("先用后付下单，实付", "实付"),
        )
        val product = QianjiPddDouyinSupport.firstValueAfter(
            nodes,
            setOf("商品名称", "商品名称：", "商品名称:"),
            2,
        )?.takeIf(QianjiPddDouyinSupport::isPlausibleNote)
        val note = listOfNotNull(
            "先用后付；等待收货后自动扣款",
            product,
            immediate?.takeIf { it != amount }?.let { "下单实付金额 ${QianjiPddDouyinSupport.formatCents(it)}" },
        ).joinToString("；")

        // Qianji builds a BillInfo from the future auto-payment amount; keep it a review candidate.
        return candidateResult(
            pageType = PDD_PAY_FIRST_DIALOG,
            amount = amount,
            merchant = "拼多多",
            observedAt = observedAt,
            note = note,
        )
    }

    private fun isWalletBillDetail(nodes: List<ScreenNode>): Boolean =
        QianjiPddDouyinSupport.hasAll(
            nodes,
            "账单详情",
            "当前状态",
            "支付成功",
            "商品详情",
            "支付时间",
            "支付方式",
            "交易单号",
            "商户单号",
        ) && QianjiPddDouyinSupport.hasStandaloneAmount(nodes, requireTwoFractionDigits = true)

    private fun parseWalletBillDetail(
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        val amount = QianjiPddDouyinSupport.uniqueVisibleAmount(
            nodes,
            excludedByPreviousLabel = listOf("优惠", "退款", "手续费"),
            requireTwoFractionDigits = true,
        ) ?: return rejected(PDD_WALLET_BILL_DETAIL, "NO_UNAMBIGUOUS_PAID_AMOUNT")
        val merchant = QianjiPddDouyinSupport.valueBeforeFirstAmount(
            nodes,
            excludedByPreviousLabel = listOf("优惠", "退款", "手续费"),
        )?.takeIf(QianjiPddDouyinSupport::isPlausibleMerchant) ?: "拼多多"
        val discount = QianjiPddDouyinSupport.firstLabeledAmount(nodes, listOf("优惠"))
            ?.takeIf { it < amount }

        return candidateResult(
            pageType = PDD_WALLET_BILL_DETAIL,
            amount = amount,
            merchant = merchant,
            observedAt = observedAt,
            transactionAt = QianjiPageSupport.timestampAfter(nodes, setOf("支付时间"), observedAt),
            paymentMethod = QianjiPddDouyinSupport.firstValueAfter(
                nodes,
                PAYMENT_METHOD_LABELS,
                maxLookAhead = 2,
            ) ?: "UNKNOWN",
            note = QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("商品详情"), 2)
                ?.takeIf(QianjiPddDouyinSupport::isPlausibleNote),
            orderId = QianjiPddDouyinSupport.firstValueAfter(nodes, ORDER_ID_LABELS, 2),
            originalAmount = discount?.let { amount + it },
            discountAmount = discount,
        )
    }

    private fun candidateResult(
        pageType: String,
        amount: Long,
        merchant: String,
        observedAt: Long,
        transactionAt: Long = observedAt,
        paymentMethod: String = "UNKNOWN",
        note: String? = null,
        orderId: String? = null,
        originalAmount: Long? = null,
        discountAmount: Long? = null,
    ): QianjiPageParseResult {
        val candidate = QianjiPageSupport.candidate(
            sourceApp = "PINDUODUO",
            pageType = pageType,
            amountInCents = amount,
            merchant = merchant,
            paymentMethod = paymentMethod,
            observedAt = observedAt,
            transactionAt = transactionAt,
            transactionType = "EXPENSE", // all three parsers leave raw billType at Qianji's default 0
            note = note,
            orderId = orderId,
            originalAmountInCents = originalAmount,
            discountAmountInCents = discountAmount,
        ) ?: return rejected(pageType, "INVALID_CANDIDATE_FIELDS")
        return QianjiPageParseResult(pageType, candidate)
    }

    private fun rejected(pageType: String, reason: String) = QianjiPageParseResult.rejected(pageType, reason)

    private companion object {
        const val PDD_ORDER_DETAIL = "PddOrderDetail"
        const val PDD_PAY_FIRST_DIALOG = "PddPayFirstDialog"
        const val PDD_WALLET_BILL_DETAIL = "PddWalletBillDetail"
        val ORDER_TIME_LABELS = listOf("下单时间：", "拼单时间：", "成交时间：", "下单时间:", "拼单时间:", "成交时间:")
        val ORDER_STATES = listOf(
            "交易成功", "商家已发货", "已发货", "拼团中", "待收货", "拼团中 拼成", "拼团中 预计",
            "打包中", "待发货", "打包完成｜快递即将发出", "运输中", "已签收", "充值到账",
        )
        val ORDER_ACTIONS = listOf("申请退款", "取消订单", "申请售后", "售后详情", "联系商家")
        val MERCHANT_LABELS = setOf("商家名称", "店铺名称", "商户名称", "收款方", "店铺", "商家", "商户")
        val PAYMENT_METHOD_LABELS = setOf("支付方式", "付款方式")
        val ORDER_ID_LABELS = setOf("交易单号", "商户单号", "订单编号", "订单号")
    }
}

/** Ordered reconstruction of the four Douyin page parsers in Qianji 4.5.3b7. */
internal class QianjiDouyinPageParser : QianjiAppPageParser {
    override val packageName: String = "com.ss.android.ugc.aweme"
    override val registeredPageTypes: List<String> = listOf(
        DOUYIN_TRANSFER_WAITING,
        DOUYIN_TRANSFER_RECEIVED,
        DOUYIN_WALLET_BILL_DETAIL,
        DOUYIN_PAY_SUCCESS,
    )

    override fun parse(nodes: List<ScreenNode>, observedAt: Long): QianjiPageParseResult = when {
        isTransferWaiting(nodes) -> parseTransferWaiting(nodes, observedAt)
        isTransferReceived(nodes) -> parseTransferReceived(nodes, observedAt)
        isWalletBillDetail(nodes) -> parseWalletBillDetail(nodes, observedAt)
        isPaySuccess(nodes) -> parsePaySuccess(nodes, observedAt)
        else -> QianjiPageParseResult.NoMatch
    }

    private fun isTransferWaiting(nodes: List<ScreenNode>): Boolean =
        QianjiPddDouyinSupport.hasAll(
            nodes,
            "转账详情",
            "转账时间",
            "转账附言",
            "提醒对方收款",
            "24小时内对方未收款，将退还给你",
        ) && QianjiPddDouyinSupport.waitingRecipient(nodes) != null &&
            QianjiPddDouyinSupport.hasStandaloneAmount(nodes)

    private fun parseTransferWaiting(
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        val recipient = QianjiPddDouyinSupport.waitingRecipient(nodes)
            ?.takeIf(QianjiPddDouyinSupport::isPlausibleMerchant)
            ?: return rejected(DOUYIN_TRANSFER_WAITING, "NO_TRANSFER_COUNTERPARTY")
        val amount = QianjiPddDouyinSupport.uniqueVisibleAmount(nodes)
            ?: return rejected(DOUYIN_TRANSFER_WAITING, "NO_UNAMBIGUOUS_TRANSFER_AMOUNT")
        val time = QianjiPageSupport.timestampAfter(nodes, setOf("转账时间"), observedAt)
        val transferNote = QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("转账附言"), 2)
            ?.takeIf(QianjiPddDouyinSupport::isPlausibleNote)
        val note = listOfNotNull(
            "待对方收款；24小时内未收款将退款",
            transferNote ?: "转账给$recipient",
        ).joinToString("；")
        return candidateResult(
            pageType = DOUYIN_TRANSFER_WAITING,
            amount = amount,
            merchant = recipient,
            observedAt = observedAt,
            transactionAt = time,
            note = note,
            orderId = QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("转账单号", "交易单号"), 2),
        )
    }

    private fun isTransferReceived(nodes: List<ScreenNode>): Boolean =
        QianjiPddDouyinSupport.hasAny(nodes, "转账详情") &&
            QianjiPddDouyinSupport.hasReceivedRecipient(nodes) &&
            QianjiPddDouyinSupport.hasAll(nodes, "收款时间", "转账时间", "转账附言") &&
            QianjiPddDouyinSupport.hasStandaloneAmount(nodes)

    private fun parseTransferReceived(
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        val recipient = QianjiPddDouyinSupport.receivedRecipient(nodes)
            ?.takeIf(QianjiPddDouyinSupport::isPlausibleMerchant)
            ?: return rejected(DOUYIN_TRANSFER_RECEIVED, "NO_TRANSFER_COUNTERPARTY")
        val amount = QianjiPddDouyinSupport.uniqueVisibleAmount(nodes)
            ?: return rejected(DOUYIN_TRANSFER_RECEIVED, "NO_UNAMBIGUOUS_TRANSFER_AMOUNT")
        val receiveAt = QianjiPageSupport.timestampFromText(
            QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("收款时间"), 2),
        )
        val transferAt = QianjiPageSupport.timestampFromText(
            QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("转账时间"), 2),
        )
        val transferNote = QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("转账附言"), 2)
            ?.takeIf(QianjiPddDouyinSupport::isPlausibleNote)
            ?.takeUnless { it == "请收款" }
        val note = listOfNotNull("对方已收款", transferNote ?: "转账给$recipient").joinToString("；")
        return candidateResult(
            pageType = DOUYIN_TRANSFER_RECEIVED,
            amount = amount,
            merchant = recipient,
            observedAt = observedAt,
            transactionAt = receiveAt ?: transferAt ?: observedAt,
            note = note,
            orderId = QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("转账单号", "交易单号"), 2),
        )
    }

    private fun isWalletBillDetail(nodes: List<ScreenNode>): Boolean =
        QianjiPddDouyinSupport.hasDouyinWalletStructure(nodes) &&
            QianjiPddDouyinSupport.hasAll(
                nodes,
                "申请电子交易凭证",
                "支付成功",
                "支付时间",
                "支付方式",
                "交易单号",
            ) && QianjiPddDouyinSupport.hasButtonText(nodes, "点击展开") &&
            QianjiPddDouyinSupport.hasStandaloneAmount(nodes, requireTwoFractionDigits = true)

    private fun parseWalletBillDetail(
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        val amount = QianjiPddDouyinSupport.uniqueVisibleAmount(
            nodes,
            excludedByPreviousLabel = listOf("抖音支付优惠", "优惠", "退款"),
            requireTwoFractionDigits = true,
        ) ?: return rejected(DOUYIN_WALLET_BILL_DETAIL, "NO_UNAMBIGUOUS_PAID_AMOUNT")
        val merchant = QianjiPddDouyinSupport.valueBeforeFirstAmount(
            nodes,
            skipImageNodes = true,
            excludedByPreviousLabel = listOf("抖音支付优惠", "优惠", "退款"),
        )?.takeIf(QianjiPddDouyinSupport::isPlausibleMerchant) ?: "抖音购物"
        val method = QianjiPddDouyinSupport.normalizeDouyinPaymentMethod(
            QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("支付方式", "付款方式"), 2),
        ) ?: "UNKNOWN"
        val discount = QianjiPddDouyinSupport.firstLabeledAmount(
            nodes,
            listOf("抖音支付优惠", "优惠"),
        )?.takeIf { it < amount }
        val rawNote = QianjiPddDouyinSupport.firstValueAfter(nodes, setOf("商品订单"), 2)
            ?.takeIf(QianjiPddDouyinSupport::isPlausibleNote)
        val note = rawNote?.removePrefix("聊天转账-")?.takeIf(String::isNotBlank) ?: merchant

        return candidateResult(
            pageType = DOUYIN_WALLET_BILL_DETAIL,
            amount = amount,
            merchant = merchant,
            observedAt = observedAt,
            transactionAt = QianjiPageSupport.timestampAfter(nodes, setOf("支付时间"), observedAt),
            paymentMethod = method,
            note = note,
            orderId = QianjiPddDouyinSupport.firstValueAfter(nodes, listOf("交易单号"), 2),
            originalAmount = discount?.let { amount + it },
            discountAmount = discount,
        )
    }

    private fun isPaySuccess(nodes: List<ScreenNode>): Boolean {
        val flatten = QianjiPddDouyinSupport::hasFlattenText
        val controls = flatten(nodes, "支付方式") && flatten(nodes, "支付时间") && flatten(nodes, "完成")
        return controls && flatten(nodes, "支付成功") &&
            QianjiPddDouyinSupport.hasStandaloneAmount(nodes, className = FLATTEN_UI_TEXT)
    }

    private fun parsePaySuccess(
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        val amount = QianjiPddDouyinSupport.uniqueVisibleAmount(
            nodes,
            className = FLATTEN_UI_TEXT,
        ) ?: return rejected(DOUYIN_PAY_SUCCESS, "NO_UNAMBIGUOUS_PAID_AMOUNT")
        val method = QianjiPddDouyinSupport.normalizeDouyinPaymentMethod(
            QianjiPddDouyinSupport.firstValueAfter(nodes, listOf("支付方式"), 2),
        )?.replace("\u200b", "") ?: "UNKNOWN"
        return candidateResult(
            pageType = DOUYIN_PAY_SUCCESS,
            amount = amount,
            merchant = "抖音购物",
            observedAt = observedAt,
            transactionAt = QianjiPageSupport.timestampAfter(nodes, setOf("支付时间"), observedAt),
            paymentMethod = method,
            note = "抖音购物",
        )
    }

    private fun candidateResult(
        pageType: String,
        amount: Long,
        merchant: String,
        observedAt: Long,
        transactionAt: Long = observedAt,
        paymentMethod: String = "UNKNOWN",
        note: String? = null,
        orderId: String? = null,
        originalAmount: Long? = null,
        discountAmount: Long? = null,
    ): QianjiPageParseResult {
        val candidate = QianjiPageSupport.candidate(
            sourceApp = "DOUYIN",
            pageType = pageType,
            amountInCents = amount,
            merchant = merchant,
            paymentMethod = paymentMethod,
            observedAt = observedAt,
            transactionAt = transactionAt,
            transactionType = "EXPENSE", // all four parsers leave raw billType at Qianji's default 0
            note = note,
            orderId = orderId,
            originalAmountInCents = originalAmount,
            discountAmountInCents = discountAmount,
        ) ?: return rejected(pageType, "INVALID_CANDIDATE_FIELDS")
        return QianjiPageParseResult(pageType, candidate)
    }

    private fun rejected(pageType: String, reason: String) = QianjiPageParseResult.rejected(pageType, reason)

    private companion object {
        const val DOUYIN_TRANSFER_WAITING = "DouyingTransferWaiting"
        const val DOUYIN_TRANSFER_RECEIVED = "DouyingTransferReceived"
        const val DOUYIN_WALLET_BILL_DETAIL = "DouyingWalletBillDetail"
        const val DOUYIN_PAY_SUCCESS = "DouyingPaySuccess"
        const val FLATTEN_UI_TEXT = "com.lynx.tasm.behavior.ui.text.FlattenUIText"
    }
}

private object QianjiPddDouyinSupport {
    private val MONEY_TOKEN = Regex(
        "^(?:(?:已支付|支出|收入)\\s*)?(?:[-+][¥￥]|[¥￥][-+]|[-+]|[¥￥])?(?:\\d{1,3}(?:,\\d{3}){0,2}|\\d{1,9})(?:\\.\\d{1,2})?(?:元)?$",
    )
    private val AMOUNT_EVIDENCE = Regex("[¥￥]|\\.\\d{1,2}|元$")
    private val WAITING_RECIPIENT = Regex("^待\\s*(.+)收款$")
    private val WAITING_RECIPIENT_ALT = Regex("^待\\s+(.+)$")
    private val RECEIVED_RECIPIENT = Regex("^(.+)已收款$")
    private val DOYIN_PAYMENT_METHOD = Regex("^抖音支付[（(](.+)[）)]$")
    private val IMAGE_CLASSES = setOf("android.widget.Image", "android.widget.ImageView")
    private val BLOCKED_MERCHANT_LABELS = setOf(
        "支付成功", "支付失败", "交易成功", "当前状态", "账单详情", "商品详情", "商品订单",
        "支付时间", "支付方式", "交易单号", "商户单号", "收款时间", "转账时间", "转账详情",
    )
    private val BLOCKED_NOTE_LABELS = BLOCKED_MERCHANT_LABELS + setOf(
        "完成", "知道了", "查看订单", "申请退款", "取消订单", "等待收货",
    )

    fun hasAll(nodes: List<ScreenNode>, vararg fragments: String): Boolean =
        QianjiPageSupport.hasAll(nodes, *fragments)

    fun hasAny(nodes: List<ScreenNode>, vararg fragments: String): Boolean =
        QianjiPageSupport.hasAny(nodes, *fragments)

    fun hasPrefix(nodes: List<ScreenNode>, vararg prefixes: String): Boolean =
        nodes.any { node -> prefixes.any { node.label.startsWith(it) } }

    fun hasPrefixAny(nodes: List<ScreenNode>, prefixes: List<String>): Boolean =
        nodes.any { node -> prefixes.any(node.label::startsWith) }

    fun hasStandaloneAmount(
        nodes: List<ScreenNode>,
        requireTwoFractionDigits: Boolean = false,
        className: String? = null,
    ): Boolean = nodes.any { node ->
        val label = node.label.trim()
        (className == null || node.className == className) &&
            MONEY_TOKEN.matches(label) &&
            AMOUNT_EVIDENCE.containsMatchIn(label) &&
            (!requireTwoFractionDigits || Regex(".*\\.\\d{2}(?:元)?$").matches(label)) &&
            QianjiPageSupport.moneyValues(label).singleOrNull() != null
    }

    fun hasFlattenText(nodes: List<ScreenNode>, text: String): Boolean =
        nodes.any { it.className == FLATTEN_UI_TEXT && it.label == text }

    fun hasButtonText(nodes: List<ScreenNode>, text: String): Boolean =
        nodes.any { it.className == "android.widget.Button" && it.label == text }

    fun hasDouyinWalletStructure(nodes: List<ScreenNode>): Boolean =
        nodes.any { it.className == "android.webkit.WebView" && it.label == "详情页" }

    fun waitingRecipient(nodes: List<ScreenNode>): String? = nodes.firstNotNullOfOrNull { node ->
        val label = node.label.trim()
        val first = WAITING_RECIPIENT.matchEntire(label)?.groupValues?.getOrNull(1)
        val alternate = WAITING_RECIPIENT_ALT.matchEntire(label)?.groupValues?.getOrNull(1)
        (first ?: alternate)?.trim()?.takeIf(String::isNotBlank)
    }

    fun hasReceivedRecipient(nodes: List<ScreenNode>): Boolean = nodes.any { node ->
        node.label.trim() == "已收款" ||
            (node.className == "android.widget.LinearLayout" && RECEIVED_RECIPIENT.matches(node.label.trim()))
    }

    fun receivedRecipient(nodes: List<ScreenNode>): String? {
        val inline = nodes.firstNotNullOfOrNull { node ->
            if (node.className != "android.widget.LinearLayout") return@firstNotNullOfOrNull null
            RECEIVED_RECIPIENT.matchEntire(node.label.trim())?.groupValues?.getOrNull(1)
        }?.trim()?.takeIf(String::isNotBlank)
        if (inline != null) return inline
        val index = nodes.indexOfFirst { it.label.trim() == "已收款" }
        if (index <= 0) return null
        return nodes[index - 1].label.trim().takeIf(String::isNotBlank)
    }

    fun firstValueAfter(nodes: List<ScreenNode>, keys: Set<String>, maxLookAhead: Int = 3): String? =
        QianjiPageSupport.firstValueAfter(nodes, keys, maxLookAhead)

    fun firstValueAfter(nodes: List<ScreenNode>, keys: List<String>, maxLookAhead: Int): String? =
        QianjiPageSupport.firstValueAfter(nodes, keys.toSet(), maxLookAhead)

    fun firstLabeledAmount(nodes: List<ScreenNode>, markers: List<String>): Long? {
        val values = markers.mapNotNull { marker -> amountAfterMarker(nodes, listOf(marker)) }.distinct()
        return values.singleOrNull()
    }

    fun amountAfterMarker(nodes: List<ScreenNode>, markers: List<String>): Long? {
        for (index in nodes.indices) {
            val label = nodes[index].label.trim()
            val marker = markers.sortedByDescending(String::length).firstOrNull(label::contains) ?: continue
            val markerIndex = label.indexOf(marker)
            val inline = QianjiPageSupport.moneyValues(label.substring(markerIndex + marker.length))
            if (inline.isNotEmpty()) return inline.last()
            for (next in index + 1 until (index + 4).coerceAtMost(nodes.size)) {
                val nextLabel = nodes[next].label.trim()
                val nextAmounts = QianjiPageSupport.moneyValues(nextLabel)
                if (nextAmounts.isNotEmpty()) return nextAmounts.last()
            }
        }
        return null
    }

    data class PddOrderAmount(val amount: Long, val originalAmount: Long?, val discountAmount: Long?)

    fun pddOrderAmount(nodes: List<ScreenNode>): PddOrderAmount? {
        val discountValues = listOf("平台优惠", "店铺优惠")
            .mapNotNull { amountAfterMarker(nodes, listOf(it)) }
            .distinct()
        val discount = discountValues.takeIf { it.isNotEmpty() }?.sum()
        val pay = amountAfterMarker(nodes, listOf("确认收货后自动付款", "确认收货后，自动付款"))
            ?: amountAfterMarker(nodes, listOf("实付金额", "实付"))
        if (pay != null) {
            val original = discount?.let { pay + it }
            return PddOrderAmount(pay, original, discount)
        }
        val group = amountAfterMarker(nodes, listOf("拼单价"))
        if (group != null) {
            val net = (group - (discount ?: 0L)).takeIf { it > 0L } ?: return null
            return PddOrderAmount(net, group, discount)
        }
        val visible = uniqueVisibleAmount(nodes)
        return visible?.let { PddOrderAmount(it, null, null) }
    }

    fun uniqueVisibleAmount(
        nodes: List<ScreenNode>,
        excludedByPreviousLabel: List<String> = emptyList(),
        requireTwoFractionDigits: Boolean = false,
        className: String? = null,
    ): Long? {
        val values = nodes.mapIndexedNotNull { index, node ->
            val label = node.label.trim()
            val previous = nodes.getOrNull(index - 1)?.label.orEmpty()
            if (
                className != null && node.className != className ||
                excludedByPreviousLabel.any { label.contains(it) || previous.contains(it) } ||
                !MONEY_TOKEN.matches(label) ||
                !AMOUNT_EVIDENCE.containsMatchIn(label) ||
                requireTwoFractionDigits && !Regex(".*\\.\\d{2}(?:元)?$").matches(label)
            ) return@mapIndexedNotNull null
            QianjiPageSupport.moneyValues(label).singleOrNull()
        }.distinct()
        return values.singleOrNull()
    }

    fun valueBeforeFirstAmount(
        nodes: List<ScreenNode>,
        skipImageNodes: Boolean = false,
        excludedByPreviousLabel: List<String> = emptyList(),
    ): String? {
        val amountIndex = nodes.indices.firstOrNull { index ->
            val node = nodes[index]
            val label = node.label.trim()
            val previous = nodes.getOrNull(index - 1)?.label.orEmpty()
            MONEY_TOKEN.matches(label) && AMOUNT_EVIDENCE.containsMatchIn(label) &&
                excludedByPreviousLabel.none { label.contains(it) || previous.contains(it) }
        } ?: -1
        if (amountIndex <= 0) return null
        for (index in amountIndex - 1 downTo 0) {
            val node = nodes[index]
            if (node.label.isBlank()) continue
            if (skipImageNodes && node.className in IMAGE_CLASSES) continue
            return node.label.trim()
        }
        return null
    }

    fun isPlausibleMerchant(value: String): Boolean {
        val merchant = value.trim()
        return merchant.isNotBlank() && merchant.length <= 80 &&
            merchant !in BLOCKED_MERCHANT_LABELS &&
            !MONEY_TOKEN.matches(merchant) &&
            QianjiPageSupport.timestampFromText(merchant) == null &&
            !merchant.matches(Regex("[A-Za-z0-9_-]{8,}"))
    }

    fun isPlausibleNote(value: String): Boolean = value.trim().let { note ->
        note.isNotBlank() && note.length <= 160 && note !in BLOCKED_NOTE_LABELS && !MONEY_TOKEN.matches(note)
    }

    fun normalizeDouyinPaymentMethod(value: String?): String? {
        val method = value?.trim()?.takeIf(String::isNotBlank) ?: return null
        val wrapped = DOYIN_PAYMENT_METHOD.matchEntire(method)?.groupValues?.getOrNull(1)
        return (wrapped ?: method).replace("\u200b", "").trim().takeIf(String::isNotBlank)
    }

    fun formatCents(cents: Long): String = "${cents / 100}.${(cents % 100).toString().padStart(2, '0')}元"

    private const val FLATTEN_UI_TEXT = "com.lynx.tasm.behavior.ui.text.FlattenUIText"
}
