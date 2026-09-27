package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode

/** One exact Qianji profile per package; the shared engine preserves each profile's order. */
internal class QianjiUnionpayPageParser : QianjiAppPageParser {
    override val packageName: String = "com.unionpay"
    override val registeredPageTypes: List<String> = QianjiUnionpayJdMeituanPages.pageTypes("Unionpay")

    override fun acceptsActivity(activityClassName: String?): Boolean =
        activityClassName.isNullOrBlank() ||
            activityClassName.startsWith("com.unionpay") &&
            activityClassName != "com.unionpay.activity.UPActivityMain"

    override fun parse(nodes: List<ScreenNode>, observedAt: Long) =
        QianjiUnionpayJdMeituanPages.parse("Unionpay", nodes, observedAt)
}

internal class QianjiJingDongPageParser : QianjiAppPageParser {
    override val packageName: String = "com.jingdong.app.mall"
    override val registeredPageTypes: List<String> = QianjiUnionpayJdMeituanPages.pageTypes("JingDong")
    override fun parse(nodes: List<ScreenNode>, observedAt: Long) =
        QianjiUnionpayJdMeituanPages.parse("JingDong", nodes, observedAt)
}

internal class QianjiMeituanPageParser : QianjiAppPageParser {
    override val packageName: String = "com.sankuai.meituan"
    override val registeredPageTypes: List<String> = QianjiUnionpayJdMeituanPages.pageTypes("MeiTuan")
    override fun parse(nodes: List<ScreenNode>, observedAt: Long) =
        QianjiUnionpayJdMeituanPages.parse("MeiTuan", nodes, observedAt)
}

private object QianjiUnionpayJdMeituanPages {
    private val pageTypesInRegistryOrder = listOf(
        "UnionpayBillDetail",
        "UnionpayPaySuccess",
        "UnionpayTransferSuccess",
        "UnionpayTransferDetail",
        "UnionpayMessageOrderDetail",
        "JingDongWalletBillDetail",
        "JingDongWalletBillDetailV2",
        "JingDongAihuishouOrderDetail",
        "JingDongOrderDetail",
        "JingDongOrderWeb",
        "JingDongPaySuccess",
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
    )

    fun pageTypes(profilePrefix: String): List<String> =
        pageTypesInRegistryOrder.filter { it.startsWith(profilePrefix) }

    fun parse(
        profilePrefix: String,
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        if (nodes.isEmpty()) return QianjiPageParseResult.NoMatch
        val recognizersByPage = recognizers.toMap()
        for (pageType in pageTypes(profilePrefix)) {
            val recognizer = requireNotNull(recognizersByPage[pageType]) {
                "Missing recognizer for $pageType"
            }
            if (recognizer(nodes)) return parseMatchedPage(pageType, nodes, observedAt)
        }
        return QianjiPageParseResult.NoMatch
    }

    private fun parseMatchedPage(
        pageType: String,
        nodes: List<ScreenNode>,
        observedAt: Long,
    ): QianjiPageParseResult {
        val text = QianjiPageSupport.labels(nodes).joinToString(" ")

        when (pageType) {
            "UnionpayBillDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("订单金额"),
                    merchantKeys = MERCHANT_KEYS + "订单描述",
                    paymentKeys = listOf("付款方式"),
                    timeKeys = listOf("订单时间"),
                    noteKeys = listOf("订单描述", "附言"),
                    fallbackMerchant = "云闪付",
                    discountKeys = listOf("优惠信息"),
                )
            }
            "UnionpayPaySuccess" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("支付成功", "订单金额", "交易金额"),
                    merchantKeys = MERCHANT_KEYS,
                    paymentKeys = listOf("付款方式"),
                    timeKeys = listOf("订单时间", "交易时间"),
                    fallbackMerchant = "云闪付",
                    defaultNote = "支付成功",
                )
            }
            "UnionpayTransferSuccess" -> {
                return transfer(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("转账金额", "转账成功", "交易金额"),
                    timeKeys = listOf("订单时间", "交易时间"),
                    explicitPartyKeys = TRANSFER_PARTY_KEYS,
                    accountKeys = listOf("转入账户", "收款方式", "转账到"),
                    fallbackParty = "云闪付转账",
                )
            }
            "UnionpayTransferDetail" -> {
                return transfer(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("转账金额"),
                    timeKeys = listOf("订单时间"),
                    explicitPartyKeys = TRANSFER_PARTY_KEYS,
                    accountKeys = listOf("收款方式", "转账到", "转入账户"),
                    paymentKeys = listOf("付款方式"),
                    noteKeys = listOf("附言"),
                    fallbackParty = "云闪付转账",
                )
            }
            "UnionpayMessageOrderDetail" -> {
                val kind = valueAfter(nodes, listOf("交易类别"))
                    ?: return rejected(pageType, "UNIONPAY_TRANSACTION_KIND_MISSING")
                val type = when {
                    kind.contains("消费") -> "EXPENSE"
                    kind.contains("入账") -> "INCOME"
                    // Qianji sets raw billType=2 for "取款"; its downstream editor maps raw 2 to transfer.
                    kind.contains("取款") -> "TRANSFER"
                    else -> return rejected(pageType, "UNIONPAY_TRANSACTION_KIND_UNSUPPORTED")
                }
                val amount = amount(nodes, listOf("交易金额", "消费金额", "入账金额"))
                    ?: visibleAmount(nodes)
                    ?: return rejected(pageType, "AMOUNT_MISSING_OR_AMBIGUOUS")
                val party = valueAfter(nodes, listOf("收款方", "商户名称", "商户", "收款人"))
                    ?: valueAfter(nodes, listOf("交易详情", "银联交易详情"))
                    ?: return rejected(pageType, "COUNTERPARTY_MISSING")
                return accepted(
                    pageType = pageType,
                    amount = amount,
                    merchant = party,
                    paymentMethod = "UNKNOWN",
                    observedAt = observedAt,
                    transactionAt = timestamp(nodes, listOf("交易时间"), observedAt),
                    transactionType = type,
                    note = valueAfter(nodes, listOf("附言", "分类")),
                    orderId = orderId(nodes),
                )
            }
            "JingDongWalletBillDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("已退款(", "交易成功", "交易金额", "账单金额"),
                    merchantKeys = MERCHANT_KEYS + "京东平台商户",
                    paymentKeys = listOf("支付方式", "付款方式"),
                    timeKeys = listOf("创建时间"),
                    noteKeys = listOf("交易成功", "账单详情"),
                    fallbackMerchant = "京东",
                )
            }
            "JingDongWalletBillDetailV2" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("已退款(", "交易成功", "京东平台商户", "交易金额"),
                    merchantKeys = MERCHANT_KEYS + "京东平台商户",
                    paymentKeys = listOf("支付方式"),
                    timeKeys = listOf("创建时间"),
                    noteKeys = listOf("服务详情"),
                    fallbackMerchant = "京东",
                    discountKeys = listOf("支付立减"),
                )
            }
            "JingDongAihuishouOrderDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("合计收款"),
                    merchantKeys = listOf("收款方", "回收商家"),
                    paymentKeys = listOf("收款银行", "收款方式"),
                    timeKeys = listOf("订单时间", "支付时间"),
                    noteKeys = listOf("旧机信息", "机型"),
                    fallbackMerchant = "爱回收",
                    transactionType = "INCOME",
                )
            }
            "JingDongOrderDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("实付款", "合计"),
                    merchantKeys = JD_MERCHANT_KEYS,
                    paymentKeys = listOf("支付方式", "付款方式"),
                    timeKeys = listOf("支付时间", "下单时间"),
                    noteKeys = listOf("商品名称", "商品标题", "到手"),
                    fallbackMerchant = "京东",
                    discountKeys = listOf("共减"),
                    orderId = orderId(nodes),
                )
            }
            "JingDongOrderWeb" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("实付款：", "实付款", "商品总额"),
                    merchantKeys = JD_MERCHANT_KEYS,
                    paymentKeys = listOf("支付方式：", "支付方式"),
                    timeKeys = listOf("支付时间：", "支付时间", "下单时间：", "下单时间"),
                    noteKeys = listOf("商品名称", "商品标题"),
                    fallbackMerchant = "京东",
                    orderId = orderId(nodes),
                    noteOverride = QianjiPageSupport.firstValueBefore(nodes, setOf("实付款：", "实付款")),
                )
            }
            "JingDongPaySuccess" -> {
                val paymentText = QianjiPageSupport.labels(nodes)
                    .firstOrNull(jdPayPattern::matches)
                    ?: return rejected(pageType, "JD_PAYMENT_AMOUNT_LINE_MISSING")
                val match = jdPayPattern.matchEntire(paymentText)
                    ?: return rejected(pageType, "JD_PAYMENT_AMOUNT_LINE_INVALID")
                val amount = QianjiPageSupport.toCents(match.groupValues[2])
                    ?: return rejected(pageType, "AMOUNT_MISSING_OR_INVALID")
                val discount = match.groupValues.getOrNull(3)
                    ?.takeIf(String::isNotBlank)
                    ?.let(QianjiPageSupport::toCents)
                return accepted(
                    pageType = pageType,
                    amount = amount,
                    merchant = valueAfter(nodes, MERCHANT_KEYS) ?: "京东",
                    paymentMethod = match.groupValues[1],
                    observedAt = observedAt,
                    transactionAt = timestamp(nodes, listOf("支付时间", "下单时间"), observedAt),
                    transactionType = "EXPENSE",
                    note = "京东购物",
                    orderId = orderId(nodes),
                    discount = discount,
                )
            }
            "MeiTuanOrderDetail" -> return expense(
                nodes, pageType, observedAt,
                amountKeys = listOf("实付", "实付款", "订单实付"),
                merchantKeys = MEITUAN_MERCHANT_KEYS,
                paymentKeys = listOf("支付方式"),
                timeKeys = listOf("下单时间", "订单时间"),
                noteKeys = listOf("已消费", "已使用"),
                fallbackMerchant = "美团",
                defaultNote = "美团",
                orderId = orderId(nodes),
            )
            "MeiTuanVoucherDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("实付"),
                    merchantKeys = MEITUAN_MERCHANT_KEYS + "券名称",
                    paymentKeys = listOf("支付方式"),
                    timeKeys = listOf("使用时间", "下单时间"),
                    noteKeys = listOf("已使用", "立即用券 到店取"),
                    fallbackMerchant = "美团",
                )
            }
            "MeiTuanVoucherSuccessDetail" -> return expense(
                nodes, pageType, observedAt,
                amountKeys = listOf("实付款金额", "实付金额"),
                merchantKeys = MEITUAN_MERCHANT_KEYS,
                paymentKeys = listOf("支付方式"),
                timeKeys = listOf("消费时间", "订单时间"),
                noteKeys = listOf("备注"),
                fallbackMerchant = "美团",
                defaultNote = "美团",
                discountKeys = listOf("买单共省"),
                orderId = orderId(nodes),
            )
            "MeiTuanGrouponDetail" -> return expense(
                nodes, pageType, observedAt,
                amountKeys = listOf("实付"),
                merchantKeys = MEITUAN_MERCHANT_KEYS + listOf("团购名称", "项目名称"),
                paymentKeys = listOf("支付方式"),
                timeKeys = listOf("使用时间", "订单时间"),
                noteKeys = listOf("已使用", "团购详情"),
                fallbackMerchant = "美团",
                defaultNote = "美团",
                orderId = orderId(nodes),
            )
            "MeiTuanMovieDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("实付金额", "实付"),
                    merchantKeys = MEITUAN_MERCHANT_KEYS + listOf("影院名称", "影院"),
                    paymentKeys = listOf("支付方式"),
                    timeKeys = listOf("订单时间", "放映时间"),
                    noteKeys = listOf("放映结束", "开场"),
                fallbackMerchant = "美团电影",
                defaultNote = "美团",
                    orderId = orderId(nodes),
                )
            }
            "MeiTuanDeliveryDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("实付款", "实付", "合计"),
                    merchantKeys = MEITUAN_MERCHANT_KEYS + listOf("收货店铺", "商家"),
                    paymentKeys = listOf("支付方式"),
                    timeKeys = listOf("下单时间", "订单时间"),
                    noteKeys = listOf("商品费用", "配送服务"),
                fallbackMerchant = "美团外卖",
                defaultNote = "美团外卖",
                    discountKeys = listOf("已优惠"),
                    orderId = orderId(nodes),
                )
            }
            "MeiTuanBikeOrderDetail" -> return expense(
                nodes, pageType, observedAt,
                amountKeys = listOf("已支付"),
                merchantKeys = listOf("商户名称", "商户", "服务商"),
                paymentKeys = listOf("支付方式"),
                timeKeys = listOf("骑行时间", "订单时间"),
                noteKeys = listOf("骑行"),
                fallbackMerchant = "美团单车",
                orderId = orderId(nodes),
                transactionAtOverride = QianjiPageSupport.labels(nodes)
                    .firstOrNull(bikeDateTimePattern::matches)
                    ?.let(QianjiPageSupport::timestampFromText),
                noteOverride = QianjiPageSupport.labels(nodes)
                    .firstOrNull(bikeDurationPattern::matches),
            )
            "MeiTuanChargeOrderDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("订单金额"),
                    merchantKeys = listOf("商户名称", "商户"),
                    paymentKeys = listOf("支付方式"),
                    timeKeys = listOf("订单时间", "使用时间"),
                    noteKeys = listOf("使用时长"),
                fallbackMerchant = "美团充电宝",
                defaultNote = "美团充电宝",
                    orderId = orderId(nodes),
                )
            }
            "MeiTuanPaySuccess" -> return expense(
                nodes, pageType, observedAt,
                amountKeys = listOf("支付成功"),
                merchantKeys = MEITUAN_MERCHANT_KEYS,
                paymentKeys = listOf("支付方式"),
                timeKeys = listOf("支付时间", "下单时间"),
                noteKeys = listOf("备注"),
                fallbackMerchant = "美团",
                defaultNote = "美团",
            )
            "MeiTuanWalletBillDetail" -> {
                return expense(
                    nodes, pageType, observedAt,
                    amountKeys = listOf("支付成功", "先用后付自动扣款成功", "极速支付成功"),
                    merchantKeys = MEITUAN_MERCHANT_KEYS,
                    paymentKeys = listOf("支付方式"),
                    timeKeys = listOf("下单时间"),
                    noteKeys = listOf("账单详情", "全部账单"),
                fallbackMerchant = "美团",
                defaultNote = "美团",
                )
            }
            else -> return QianjiPageParseResult.NoMatch
        }
    }

    private fun expense(
        nodes: List<ScreenNode>,
        pageType: String,
        observedAt: Long,
        amountKeys: List<String>,
        merchantKeys: List<String>,
        paymentKeys: List<String> = emptyList(),
        timeKeys: List<String> = emptyList(),
        noteKeys: List<String> = emptyList(),
        fallbackMerchant: String? = null,
        transactionType: String = "EXPENSE",
        discountKeys: List<String> = emptyList(),
        orderId: String? = orderId(nodes),
        defaultNote: String? = null,
        transactionAtOverride: Long? = null,
        noteOverride: String? = null,
    ): QianjiPageParseResult {
        val amount = amount(nodes, amountKeys)
            ?: visibleAmount(nodes)
            ?: return rejected(pageType, "AMOUNT_MISSING_OR_AMBIGUOUS")
        val merchant = valueAfter(nodes, merchantKeys)
            ?: fallbackMerchant
            ?: return rejected(pageType, "COUNTERPARTY_MISSING")
        return accepted(
            pageType = pageType,
            amount = amount,
            merchant = merchant,
            paymentMethod = valueAfter(nodes, paymentKeys) ?: "UNKNOWN",
            observedAt = observedAt,
            transactionAt = transactionAtOverride ?: timestamp(nodes, timeKeys, observedAt),
            transactionType = transactionType,
            note = listOfNotNull(
                statusHint(nodes),
                noteOverride ?: valueAfter(nodes, noteKeys) ?: defaultNote,
            ).distinct().joinToString("；").ifBlank { null },
            orderId = orderId,
            discount = amount(nodes, discountKeys),
        )
    }

    private fun transfer(
        nodes: List<ScreenNode>,
        pageType: String,
        observedAt: Long,
        amountKeys: List<String>,
        timeKeys: List<String>,
        explicitPartyKeys: List<String>,
        accountKeys: List<String>,
        paymentKeys: List<String> = emptyList(),
        noteKeys: List<String> = emptyList(),
        fallbackParty: String? = null,
    ): QianjiPageParseResult {
        val amount = amount(nodes, amountKeys)
            ?: visibleAmount(nodes)
            ?: return rejected(pageType, "AMOUNT_MISSING_OR_AMBIGUOUS")
        val text = QianjiPageSupport.labels(nodes).joinToString(" ")
        val party = valueAfter(nodes, explicitPartyKeys)
            ?: transferRecipientRegex.find(text)?.groupValues?.getOrNull(1)?.trim()
            ?: fallbackParty
            ?: return rejected(pageType, "TRANSFER_RECIPIENT_MISSING")
        val accountHint = valueAfter(nodes, accountKeys)
        return accepted(
            pageType = pageType,
            amount = amount,
            merchant = party,
            paymentMethod = valueAfter(nodes, paymentKeys) ?: "UNKNOWN",
            observedAt = observedAt,
            transactionAt = timestamp(nodes, timeKeys, observedAt),
            transactionType = "TRANSFER",
            note = valueAfter(nodes, noteKeys) ?: statusHint(nodes),
            orderId = orderId(nodes),
            targetAccountHint = accountHint,
            targetIdentifierSuffix = accountHint?.let(::lastFourDigits),
        )
    }

    private fun accepted(
        pageType: String,
        amount: Long,
        merchant: String,
        paymentMethod: String,
        observedAt: Long,
        transactionAt: Long,
        transactionType: String,
        note: String? = null,
        orderId: String? = null,
        discount: Long? = null,
        targetAccountHint: String? = null,
        targetIdentifierSuffix: String? = null,
    ): QianjiPageParseResult {
        val original = discount?.let { runCatching { Math.addExact(amount, it) }.getOrNull() }
        val candidate = QianjiPageSupport.candidate(
            sourceApp = sourceAppFor(pageType),
            pageType = pageType,
            amountInCents = amount,
            merchant = merchant,
            paymentMethod = paymentMethod,
            observedAt = observedAt,
            transactionAt = transactionAt,
            transactionType = transactionType,
            note = note,
            orderId = orderId,
            originalAmountInCents = original,
            discountAmountInCents = discount,
            targetIdentifierSuffix = targetIdentifierSuffix,
            targetAccountHint = targetAccountHint,
        ) ?: return rejected(pageType, "CANDIDATE_FIELDS_INVALID")
        return QianjiPageParseResult(pageType = pageType, candidate = candidate)
    }

    private fun amount(nodes: List<ScreenNode>, keys: List<String>): Long? {
        for (key in keys) {
            QianjiPageSupport.uniqueMoneyAfter(nodes, setOf(key))?.let { return it }
        }
        return null
    }

    private fun visibleAmount(nodes: List<ScreenNode>): Long? {
        val values = nodes.asSequence()
            .map(ScreenNode::label)
            .filter { label ->
                label.contains('¥') || label.contains('￥') ||
                    label.endsWith("元") || label.startsWith("已支付") ||
                    label.startsWith("支出") || label.startsWith("收入")
            }
            .flatMap { QianjiPageSupport.moneyValues(it).asSequence() }
            .toSet()
        return values.singleOrNull()
    }

    private fun statusHint(nodes: List<ScreenNode>): String? =
        QianjiPageSupport.labels(nodes).firstOrNull { label ->
            listOf("已退款", "部分退款", "待到店使用", "等待收货", "等待处理", "预计送达", "放映结束")
                .any(label::contains)
        }?.let { "钱迹状态：$it" }

    private fun valueAfter(nodes: List<ScreenNode>, keys: List<String>): String? {
        for (key in keys) {
            QianjiPageSupport.firstValueAfter(nodes, setOf(key))
                ?.let(::cleanValue)
                ?.takeIf(String::isNotBlank)
                ?.let { return it }
        }
        return null
    }

    private fun timestamp(nodes: List<ScreenNode>, keys: List<String>, observedAt: Long): Long =
        QianjiPageSupport.timestampFromText(valueAfter(nodes, keys)) ?: observedAt

    private fun orderId(nodes: List<ScreenNode>): String? =
        valueAfter(nodes, ORDER_ID_KEYS)
            ?.takeIf { it.length in 6..64 && !it.any(Char::isWhitespace) }

    private fun cleanValue(value: String): String = value
        .trim()
        .trimStart('：', ':', '￥', '¥', ' ')
        .trim()
        .takeIf { candidate ->
            candidate.isNotBlank() &&
                !amountOnlyPattern.matches(candidate) &&
                QianjiPageSupport.timestampFromText(candidate) == null &&
                !candidate.matches(Regex("(?:支付成功|交易成功|已退款|部分退款|订单已完成|已使用|待到店使用)"))
        }
        .orEmpty()

    private fun lastFourDigits(value: String): String? =
        Regex("(?:尾号|后四位)?\\D*(\\d{4})$").find(value)?.groupValues?.get(1)

    private fun hasAll(nodes: List<ScreenNode>, vararg labels: String): Boolean =
        QianjiPageSupport.hasAll(nodes, *labels)

    private fun hasAny(nodes: List<ScreenNode>, vararg labels: String): Boolean =
        QianjiPageSupport.hasAny(nodes, *labels)

    private fun hasAmountToken(nodes: List<ScreenNode>): Boolean =
        nodes.any { amountTokenPattern.matches(it.label.trim()) }

    private fun hasViewLabel(nodes: List<ScreenNode>, label: String, classFragment: String): Boolean =
        nodes.any { it.label.contains(label) && it.className.contains(classFragment, ignoreCase = true) }

    private fun hasWebViewLabel(nodes: List<ScreenNode>, label: String): Boolean =
        hasViewLabel(nodes, label, "WebView")

    private fun hasTextViewLabel(nodes: List<ScreenNode>, label: String): Boolean =
        nodes.any { it.label == label && it.className.contains("TextView", ignoreCase = true) }

    private fun hasRegex(nodes: List<ScreenNode>, regex: Regex): Boolean =
        nodes.any { regex.matches(it.label.trim()) }

    private fun hasTextSequence(nodes: List<ScreenNode>, sequence: String): Boolean =
        QianjiPageSupport.labels(nodes).joinToString("").contains(sequence)

    private fun sourceAppFor(pageType: String): String = when {
        pageType.startsWith("Unionpay") -> "UNIONPAY"
        pageType.startsWith("JingDong") -> "JD"
        else -> "MEITUAN"
    }

    private fun rejected(pageType: String, reason: String) =
        QianjiPageParseResult.rejected(pageType, reason)

    private val recognizers: List<Pair<String, (List<ScreenNode>) -> Boolean>> = listOf(
        "UnionpayBillDetail" to { nodes ->
            (hasAny(nodes, "账单详情") || hasAny(nodes, "云闪付交易详情")) &&
                hasViewLabel(nodes, "客服按钮", "ViewGroup") &&
                hasAll(nodes, "当前状态", "交易成功", "付款方式", "订单金额", "订单时间") &&
                hasAmountToken(nodes)
        },
        "UnionpayPaySuccess" to { nodes ->
            hasAll(nodes, "支付成功", "付款方式", "完成") && hasAmountToken(nodes)
        },
        "UnionpayTransferSuccess" to { nodes ->
            hasAll(nodes, "转账成功", "转账详情", "继续转账", "完成") && hasAmountToken(nodes)
        },
        "UnionpayTransferDetail" to { nodes ->
            (hasAny(nodes, "账单详情") || hasAny(nodes, "云闪付交易详情")) &&
                hasViewLabel(nodes, "客服按钮", "ViewGroup") &&
                hasAll(nodes, "当前状态", "交易成功", "转账金额", "付款方式", "订单时间") &&
                hasAny(nodes, "转账到", "收款方式") && hasAmountToken(nodes)
        },
        "UnionpayMessageOrderDetail" to { nodes ->
            (hasAny(nodes, "交易详情") || hasAny(nodes, "银联交易详情")) &&
                hasAll(nodes, "卡号", "交易时间", "交易类别", "分类") && hasAmountToken(nodes)
        },
        "JingDongWalletBillDetail" to { nodes ->
            hasWebViewLabel(nodes, "账单详情") &&
                hasAny(nodes, "支付方式", "付款方式") &&
                hasAll(nodes, "创建时间", "总订单编号") &&
                (hasAny(nodes, "交易成功") || nodes.any { it.label.startsWith("已退款(￥") }) &&
                nodes.any { jdOrderCountPattern.matches(it.label.trim()) } && hasAmountToken(nodes)
        },
        "JingDongWalletBillDetailV2" to { nodes ->
            hasWebViewLabel(nodes, "账单详情") &&
                nodes.any { it.label.startsWith("支付方式") || it.label.startsWith("支付立减") } &&
                hasAll(nodes, "创建时间", "总订单编号") &&
                (hasAny(nodes, "交易成功") || hasAny(nodes, "已退款(￥"))
        },
        "JingDongAihuishouOrderDetail" to { nodes ->
            hasWebViewLabel(nodes, "订单详情") &&
                hasAll(nodes, "回收成功啦", "合计收款", "订单编号", "收款方式") && hasAmountToken(nodes)
        },
        "JingDongOrderDetail" to { nodes ->
            hasAny(nodes, "正在出库", "商品出库", "完成", "订单状态 完成", "付款成功", "等待收货") &&
                nodes.any { it.label.startsWith("数量 ×") } &&
                hasAll(nodes, "实付款", "合计", "订单编号", "复制") &&
                hasAny(nodes, "支付时间", "下单时间") && hasAmountToken(nodes)
        },
        "JingDongOrderWeb" to { nodes ->
            hasWebViewLabel(nodes, "订单详情") && hasAny(nodes, "已完成", "等待处理") &&
                hasAll(nodes, "订单编号：", "下单时间：", "支付时间：", "商品总额", "实付款：") &&
                hasAmountToken(nodes)
        },
        "JingDongPaySuccess" to { nodes ->
            hasTextViewLabel(nodes, "支付成功") &&
                nodes.any { it.className.contains("TextView", ignoreCase = true) && jdPayPattern.matches(it.label) }
        },
        "MeiTuanOrderDetail" to { nodes ->
            hasAll(nodes, "已消费", "实付", "订单信息", "订单编号：", "下单时间：") && hasAmountToken(nodes)
        },
        "MeiTuanVoucherDetail" to { nodes ->
            hasAny(nodes, "已使用", "待到店使用") &&
                hasAll(nodes, "实付", "使用须知", "有效日期", "使用时间") && hasAmountToken(nodes)
        },
        "MeiTuanVoucherSuccessDetail" to { nodes ->
            hasAny(nodes, "买单成功！") &&
                hasTextSequence(nodes, "实付款金额：") &&
                hasTextSequence(nodes, "订单编号：") && hasAny(nodes, "复制") &&
                hasTextSequence(nodes, "消费时间：") && hasAmountToken(nodes)
        },
        "MeiTuanGrouponDetail" to { nodes ->
            hasAll(nodes, "已使用", "实付", "团购详情", "使用须知", "有效日期", "使用时间", "订单信息") &&
                hasAmountToken(nodes)
        },
        "MeiTuanMovieDetail" to { nodes ->
            (hasAny(nodes, "放映结束") || hasRegex(nodes, movieOpeningPattern)) &&
                hasAny(nodes, "展开取票码", "取电影票") &&
                hasAll(nodes, "订单详情", "实付金额：", "订单号码：", "订单时间：") &&
                hasAmountToken(nodes)
        },
        "MeiTuanDeliveryDetail" to { nodes ->
            hasAny(nodes, "订单已完成") &&
                (hasRegex(nodes, earlyDeliveryPattern) || hasAny(nodes, "预计送达")) &&
                hasAll(nodes, "合计", "实付款", "￥") && hasAmountToken(nodes)
        },
        "MeiTuanBikeOrderDetail" to { nodes ->
            hasRegex(nodes, bikePaidPattern) && hasAll(nodes, "费用申诉", "车辆报修") &&
                hasRegex(nodes, bikeDateTimePattern) && hasRegex(nodes, bikeDurationPattern)
        },
        "MeiTuanChargeOrderDetail" to { nodes ->
            hasAll(nodes, "订单完成", "充电宝已归还，感谢使用", "使用时长", "订单金额", "元", "再次租借") &&
                hasAmountToken(nodes)
        },
        "MeiTuanPaySuccess" to { nodes ->
            hasWebViewLabel(nodes, "支付成功") && hasRegex(nodes, meituanPayPattern)
        },
        "MeiTuanWalletBillDetail" to { nodes ->
            (hasAny(nodes, "账单详情") || hasWebViewLabel(nodes, "账单详情")) &&
                (hasAny(nodes, "支付成功", "先用后付自动扣款成功", "极速支付成功") ||
                    nodes.any { refundAmountPattern.matches(it.label.trim()) }) &&
                hasAll(nodes, "支付方式", "下单时间") && hasAmountToken(nodes)
        },
    )

    private val MERCHANT_KEYS = listOf("商户名称", "商户名", "商户", "商家名称", "店铺名称", "店铺", "收款方")
    private val JD_MERCHANT_KEYS = MERCHANT_KEYS + listOf("商品名称", "商品标题", "经营者")
    private val MEITUAN_MERCHANT_KEYS = MERCHANT_KEYS + listOf("商家名称", "影院名称", "商品名称")
    private val TRANSFER_PARTY_KEYS = listOf("收款方", "收款人", "转账对象", "转账给")
    private val ORDER_ID_KEYS = listOf("订单编号", "订单号码", "订单号", "总订单编号")

    private val amountOnlyPattern = Regex("^(?:[¥￥])?\\d+(?:,\\d{3})*(?:\\.\\d{1,2})?(?:元)?$")
    private val amountTokenPattern = Regex(
        "^(?:已支付|支出|收入)?\\s*(?:(?:[-+][¥￥]|[¥￥][-+]|[-+]|[¥￥])\\s*)?(?:\\d{1,3}(?:,\\d{3}){0,2}|\\d{1,9})(?:\\.\\d{1,2})?(?:元)?$",
    )
    private val jdOrderCountPattern = Regex("共\\d+笔订单")
    private val jdPayPattern = Regex(
        "^(?!微信支付)(.+?)¥\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?)(?:.*?共优惠¥\\s*([0-9][0-9,]*(?:\\.[0-9]{1,2})?))?.*$",
    )
    private val movieOpeningPattern = Regex(".*\\d{2}:\\d{2}开场.*")
    private val earlyDeliveryPattern = Regex(".*已提前\\d+分钟送达.*")
    private val deliveredPattern = Regex(".*(?:已提前\\d+分钟送达|已送达).*")
    private val bikePaidPattern = Regex("已支付\\d+(?:\\.\\d{1,2})?元")
    private val bikeDateTimePattern = Regex("\\d{4}-\\d{2}-\\d{2} \\d{2}:\\d{2}:\\d{2}")
    private val bikeDurationPattern = Regex("骑行\\d+分\\d+秒")
    private val meituanPayPattern = Regex("支付成功 ¥\\d+(?:\\.\\d{1,2})?")
    private val refundAmountPattern = Regex("已退款\\d+(?:\\.\\d{1,2})?元")
    private val transferRecipientRegex = Regex("(?:转账：?转给|转账给|转给)\\s*([^，,￥¥\\s]+)")
}
