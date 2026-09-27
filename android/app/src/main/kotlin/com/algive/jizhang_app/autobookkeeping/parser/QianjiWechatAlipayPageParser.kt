package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode

private data class OrderedQianjiPageRule(
    val pageType: String,
    val matches: (List<ScreenNode>) -> Boolean,
    val parse: (List<ScreenNode>, Long) -> QianjiPageParseResult,
)

private fun orderedPageResult(
    nodes: List<ScreenNode>,
    observedAt: Long,
    rules: List<OrderedQianjiPageRule>,
): QianjiPageParseResult {
    val matched = rules.firstOrNull { it.matches(nodes) } ?: return QianjiPageParseResult.NoMatch
    return matched.parse(nodes, observedAt)
}

internal class QianjiWechatPageParser : QianjiAppPageParser {
    override val packageName: String = "com.tencent.mm"

    override fun acceptsActivity(activityClassName: String?): Boolean =
        activityClassName != "com.tencent.mm.ui.LauncherUI"

    private val rules = listOf(
        OrderedQianjiPageRule(
            "WechatPersonalRedPacketSend",
            ::matchesWechatPersonalRedPacketSend,
            ::parseWechatPersonalRedPacketSend,
        ),
        OrderedQianjiPageRule(
            "WechatGroupRedPacketDetail",
            ::matchesWechatGroupRedPacketDetail,
            ::parseWechatGroupRedPacketDetail,
        ),
        OrderedQianjiPageRule(
            "WechatPersonalRedPacketReceive",
            ::matchesWechatPersonalRedPacketReceive,
            ::parseWechatPersonalRedPacketReceive,
        ),
        OrderedQianjiPageRule(
            "WechatPersonalRedPacketReceive2",
            ::matchesWechatPersonalRedPacketReceive2,
            ::parseWechatPersonalRedPacketReceive2,
        ),
        OrderedQianjiPageRule(
            "WeChatTransferDetail",
            ::matchesWechatTransferDetail,
            ::parseWechatTransferDetail,
        ),
        OrderedQianjiPageRule(
            "WeChatTransferInDetail",
            ::matchesWechatTransferInDetail,
            ::parseWechatTransferInDetail,
        ),
        OrderedQianjiPageRule(
            "WeChatBillDetail",
            ::matchesWechatBillDetail,
            ::parseWechatBillDetail,
        ),
        OrderedQianjiPageRule(
            "WeChatTransferDetailWaiting",
            ::matchesWechatTransferDetailWaiting,
            ::parseWechatTransferDetailWaiting,
        ),
        OrderedQianjiPageRule(
            "WechatWithdrawSuccess",
            ::matchesWechatWithdrawSuccess,
            ::parseWechatWithdrawSuccess,
        ),
        OrderedQianjiPageRule(
            "WechatWithdrawDetail",
            ::matchesWechatWithdrawDetail,
            ::parseWechatWithdrawDetail,
        ),
        OrderedQianjiPageRule(
            "WechatChargeDetail",
            ::matchesWechatChargeDetail,
            ::parseWechatChargeDetail,
        ),
        OrderedQianjiPageRule(
            "WechatPayPassword",
            ::matchesWechatPayPassword,
            { _, _ -> reject("WechatPayPassword", "NO_REGISTERED_PAGE_PARSER") },
        ),
        OrderedQianjiPageRule(
            "WeChatPaySuccess",
            ::matchesWechatPaySuccess,
            ::parseWechatPaySuccess,
        ),
    )

    override val registeredPageTypes: List<String> = rules
        .map(OrderedQianjiPageRule::pageType)
        .filterNot { it == "WechatPayPassword" }

    override fun parse(nodes: List<ScreenNode>, observedAt: Long): QianjiPageParseResult =
        orderedPageResult(nodes, observedAt, rules)
}

internal class QianjiAlipayPageParser : QianjiAppPageParser {
    override val packageName: String = "com.eg.android.AlipayGphone"

    private val rules = listOf(
        OrderedQianjiPageRule("AlipayBillDetail", ::matchesAlipayBillDetail, ::parseAlipayBillDetail),
        OrderedQianjiPageRule("AlipayPaySuccess", ::matchesAlipayPaySuccess, ::parseAlipayPaySuccess),
        OrderedQianjiPageRule("AlipayTransfer", ::matchesAlipayTransfer, ::parseAlipayTransfer),
        OrderedQianjiPageRule("AlipayTransferOut", ::matchesAlipayTransferOut, ::parseAlipayTransferOut),
        OrderedQianjiPageRule("AlipayTransferIn", ::matchesAlipayTransferIn, ::parseAlipayTransferIn),
        OrderedQianjiPageRule("AlipayCharge", ::matchesAlipayCharge, ::parseAlipayCharge),
        OrderedQianjiPageRule("AlipayChargeDetail", ::matchesAlipayChargeDetail, ::parseAlipayChargeDetail),
        OrderedQianjiPageRule("AlipayWithdraw", ::matchesAlipayWithdraw, ::parseAlipayWithdraw),
        OrderedQianjiPageRule("AlipayWithdrawDetail", ::matchesAlipayWithdrawDetail, ::parseAlipayWithdrawDetail),
        OrderedQianjiPageRule("AlipaySendRedPacket", ::matchesAlipaySendRedPacket, ::parseAlipaySendRedPacket),
        OrderedQianjiPageRule(
            "AlipayQRCodeReceiveDetail",
            ::matchesAlipayQrReceiveDetail,
            ::parseAlipayQrReceiveDetail,
        ),
        OrderedQianjiPageRule(
            "AlipayYuLiBaoIncomeDetail",
            ::matchesAlipayYuLiBaoIncomeDetail,
            ::parseAlipayYuLiBaoIncomeDetail,
        ),
        OrderedQianjiPageRule(
            "AlipayYuLiBaoTransferOutSuccess",
            ::matchesAlipayYuLiBaoTransferOutSuccess,
            ::parseAlipayYuLiBaoTransferOutSuccess,
        ),
        OrderedQianjiPageRule(
            "AlipayYuLiBaoTransferOutDetail",
            ::matchesAlipayYuLiBaoTransferOutDetail,
            ::parseAlipayYuLiBaoTransferOutDetail,
        ),
        OrderedQianjiPageRule(
            "AlipayYuLiBaoTransferInDetail",
            ::matchesAlipayYuLiBaoTransferInDetail,
            ::parseAlipayYuLiBaoTransferInDetail,
        ),
        OrderedQianjiPageRule(
            "AlipayYuLiBaoTransferInSuccess",
            ::matchesAlipayYuLiBaoTransferInSuccess,
            ::parseAlipayYuLiBaoTransferInSuccess,
        ),
    )

    override val registeredPageTypes: List<String> = rules.map(OrderedQianjiPageRule::pageType)

    override fun parse(nodes: List<ScreenNode>, observedAt: Long): QianjiPageParseResult =
        orderedPageResult(nodes, observedAt, rules)
}

private val supportedTextClasses = setOf(
    "android.widget.TextView",
    "android.widget.ImageView",
    "android.widget.Image",
    "android.widget.Button",
    "android.view.View",
    "com.lynx.tasm.behavior.ui.text.FlattenUIText",
)

private val commonAmountPattern = Regex(
    "^(?:已支付|支出|收入)?\\s*(?:[-+][¥￥]|[¥￥][-+]|[-+]|[¥￥])?" +
        "(?:\\d{1,3}(?:,\\d{3}){0,2}|\\d{1,9})(?:\\.\\d{1,2})?(?:元)?$",
)
private val commonDatePattern = Regex(
    "^\\d{4}[-./年]\\d{1,2}[-./月]\\d{1,2}(?:日)?(?:\\s*\\d{2}:\\d{2}(?::\\d{2})?)?$",
)
private val refundLabelPattern = Regex("已退款\\s*[（(]\\s*[¥￥]\\s*\\d+(?:\\.\\d+)?\\s*[）)]")
private val wechatGroupClaimPattern =
    Regex("^已?领取(\\d+)/(\\d+)个(，共(\\d+\\.\\d{2})/(\\d+\\.\\d{2})元)?$")
private val wechatGroupGrabbedPattern = Regex("^.*\\d+.*被抢光$")
private val wechatPersonalReceiveAmountPattern = Regex("^(?:[¥￥]\\s*)?(\\d+\\.\\d{2})(?:元)?$")
private val alipayTransferInSuccessAmountPattern =
    Regex("^转入成功\\s*[¥￥]?\\s*([\\d,]+(?:\\.\\d{1,2})?)")
private val redPacketSenderPattern = Regex("^(.+?)的红包$")
private val alipayRedPacketAmountPattern =
    Regex("已领取(\\d+)/(\\d+)个，共(\\d+\\.\\d{2})/(\\d+\\.\\d{2})元")

private fun visibleLabels(nodes: List<ScreenNode>): List<String> =
    nodes.filter(::isTextNode).map(ScreenNode::label).filter(String::isNotBlank)

private fun isTextNode(node: ScreenNode): Boolean =
    node.className.isBlank() || node.className in supportedTextClasses

private fun hasExact(nodes: List<ScreenNode>, vararg values: String): Boolean =
    values.all { expected -> nodes.any { isTextNode(it) && it.label == expected } }

private fun hasAnyExact(nodes: List<ScreenNode>, values: Set<String>): Boolean =
    nodes.any { isTextNode(it) && it.label in values }

private fun hasContains(nodes: List<ScreenNode>, vararg values: String): Boolean =
    nodes.any { node -> isTextNode(node) && values.any(node.label::contains) }

private fun hasStartsWith(nodes: List<ScreenNode>, vararg values: String): Boolean =
    values.all { expected -> nodes.any { isTextNode(it) && it.label.startsWith(expected) } }

private fun hasEndsWith(nodes: List<ScreenNode>, suffix: String): Boolean =
    nodes.any { isTextNode(it) && it.label.endsWith(suffix) }

private fun hasRegex(nodes: List<ScreenNode>, regex: Regex): Boolean =
    nodes.any { isTextNode(it) && regex.matches(it.label) }

private fun hasRegexContaining(nodes: List<ScreenNode>, regex: Regex): Boolean =
    nodes.any { isTextNode(it) && regex.containsMatchIn(it.label) }

private fun hasClassLabel(
    nodes: List<ScreenNode>,
    className: String,
    label: String,
): Boolean = nodes.any { it.className == className && it.label == label }

private fun hasViewId(nodes: List<ScreenNode>, idSuffix: String, className: String? = null): Boolean =
    nodes.any {
        it.viewId.endsWith(idSuffix) && (className == null || it.className == className)
    }

private fun hasCommonAmount(nodes: List<ScreenNode>): Boolean =
    hasRegex(nodes, commonAmountPattern)

private fun hasDateOrTime(nodes: List<ScreenNode>, vararg labels: String): Boolean =
    hasAnyExact(nodes, labels.toSet()) || hasRegex(nodes, commonDatePattern)

private fun matchesWechatPersonalRedPacketSend(nodes: List<ScreenNode>): Boolean =
    hasEndsWith(nodes, "的红包") &&
        (
            hasRegexContaining(nodes, Regex("红包金额\\d+\\.\\d{2}元，等待对方领取")) ||
                hasRegex(nodes, Regex("^\\d+个红包共[0-9]+(?:\\.[0-9]{2})元$"))
            )

private fun matchesWechatGroupRedPacketDetail(nodes: List<ScreenNode>): Boolean =
    hasEndsWith(nodes, "的红包") &&
        hasExact(nodes, "元") &&
        (
            nodes.any { node ->
                isTextNode(node) &&
                    (wechatGroupClaimPattern.matches(node.label) ||
                        wechatGroupGrabbedPattern.matches(node.label))
            }
            ) &&
        hasClassLabel(nodes, "android.widget.ImageView", "返回") &&
        hasClassLabel(nodes, "android.widget.ImageView", "更多")

private fun matchesWechatPersonalRedPacketReceive(nodes: List<ScreenNode>): Boolean =
    hasEndsWith(nodes, "的红包") &&
        nodes.any { isTextNode(it) && Regex("^\\d+\\.\\d{2}$").matches(it.label) } &&
        nodes.any { isTextNode(it) && Regex("^(\\d+\\.\\d{2})元$").matches(it.label) }

private fun matchesWechatPersonalRedPacketReceive2(nodes: List<ScreenNode>): Boolean =
    hasEndsWith(nodes, "的红包") &&
        nodes.any { isTextNode(it) && Regex("^\\d+\\.\\d{2}$").matches(it.label) } &&
        hasExact(nodes, "元") &&
        hasClassLabel(nodes, "android.widget.ImageView", "返回") &&
        hasClassLabel(nodes, "android.widget.ImageView", "更多")

private fun matchesWechatTransferDetail(nodes: List<ScreenNode>): Boolean =
    hasStartsWith(nodes, "转账-转给") &&
        hasExact(nodes, "当前状态", "转账时间", "支付方式")

private fun matchesWechatTransferInDetail(nodes: List<ScreenNode>): Boolean =
    hasStartsWith(nodes, "商家转账-来自") &&
        hasExact(nodes, "付款商家", "收款方式", "转账时间")

private val wechatBillStatuses = setOf("支付成功", "收款成功", "已收钱")
private val wechatBillStatusStarts = setOf("已存入")

private fun matchesWechatBillDetail(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "当前状态") &&
        hasDateOrTime(nodes, "支付时间", "转账时间", "收款时间", "到账时间", "时间") &&
        (
            hasAnyExact(nodes, wechatBillStatuses) ||
                hasContains(nodes, "交易成功") ||
                nodes.any { node -> isTextNode(node) && wechatBillStatusStarts.any(node.label::startsWith) } ||
                nodes.any { node -> isTextNode(node) && refundLabelPattern.matches(node.label) }
            )

private fun matchesWechatTransferDetailWaiting(nodes: List<ScreenNode>): Boolean {
    val tabTexts = listOf("微信", "通讯录", "发现", "我")
    val mainTabPage = tabTexts.all { text -> hasExact(nodes, text) }
    val transferTitle = nodes.any { node ->
        isTextNode(node) &&
            (
                Regex("^待(.+)收款$").matches(node.label) ||
                    Regex("^(.+)已收款$").matches(node.label) ||
                    node.label.startsWith("你已收款，")
                )
    }
    return !mainTabPage &&
        transferTitle &&
        hasCommonAmount(nodes) &&
        hasDateOrTime(nodes, "转账时间", "收款时间", "时间")
}

private fun matchesWechatWithdrawSuccess(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "零钱提现", "发起提现申请", "提现金额", "到账银行卡")

private fun matchesWechatWithdrawDetail(nodes: List<ScreenNode>): Boolean =
    hasStartsWith(nodes, "零钱提现-") &&
        hasExact(nodes, "当前状态", "发起提现", "提现金额", "申请时间", "到账时间")

private fun matchesWechatChargeDetail(nodes: List<ScreenNode>): Boolean =
    hasStartsWith(nodes, "零钱充值-") &&
        hasExact(nodes, "当前状态", "充值完成", "充值时间", "支付方式")

private fun matchesWechatPayPassword(nodes: List<ScreenNode>): Boolean =
    hasViewId(nodes, "tenpay_keyboard_1", "android.widget.TextView") &&
        hasViewId(nodes, "tenpay_keyboard_2", "android.widget.TextView") &&
        hasViewId(nodes, "tenpay_keyboard_3", "android.widget.TextView") &&
        hasViewId(nodes, "tenpay_keyboard_d", "android.widget.Button") &&
        hasExact(nodes, "完成", "付款方式") &&
        hasStartsWith(nodes, "密码框,共六位数字") &&
        hasCommonAmount(nodes)

private fun matchesWechatPaySuccess(nodes: List<ScreenNode>): Boolean =
    hasAnyExact(nodes, setOf("支付成功", "充值成功")) &&
        hasCommonAmount(nodes) &&
        !(hasClassLabel(nodes, "android.widget.TextView", "首页") &&
            hasClassLabel(nodes, "android.widget.TextView", "点单")) &&
        !(hasClassLabel(nodes, "android.widget.TextView", "支付成功") &&
            hasClassLabel(nodes, "android.widget.TextView", "去下单"))

private val alipayBillStatuses = setOf(
    "交易成功",
    "支付成功",
    "充值成功",
    "代付成功",
    "免密支付成功",
    "自动扣款成功",
    "等待确认收货",
    "等待发货",
    "等待对方确认收货",
    "还款成功",
    "收款成功",
    "已全额退款",
    "领取中",
)
private val alipayBillTimeLabels = setOf("支付时间", "创建时间", "收款时间", "到账时间", "时间")

private fun matchesAlipayBillDetail(nodes: List<ScreenNode>): Boolean =
    (
        hasAnyExact(nodes, alipayBillStatuses) ||
            nodes.any { node -> isTextNode(node) && refundLabelPattern.matches(node.label) }
        ) &&
        hasAnyExact(nodes, alipayBillTimeLabels) &&
        hasCommonAmount(nodes)

private fun matchesAlipayPaySuccess(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "支付成功") &&
        hasCommonAmount(nodes) &&
        (
            nodes.any { node -> isTextNode(node) && Regex("^支付成功￥\\d+\\.\\d+$").matches(node.label) } ||
                hasClassLabel(nodes, "android.widget.TextView", "完成")
            )

private fun matchesAlipayTransfer(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "转账成功") &&
        hasAnyExact(nodes, setOf("交易方式", "付款方式")) &&
        hasExact(nodes, "收款方") &&
        hasCommonAmount(nodes)

private fun matchesAlipayTransferOut(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "转出成功", "¥", "到账账户", "完成") && hasCommonAmount(nodes)

private fun matchesAlipayTransferIn(nodes: List<ScreenNode>): Boolean =
    nodes.any { it.className == "android.webkit.WebView" } &&
        hasExact(nodes, "转入成功") &&
        hasCommonAmount(nodes) &&
        hasClassLabel(nodes, "android.widget.Button", "完成") &&
        hasClassLabel(nodes, "android.widget.FrameLayout", "返回")

private fun matchesAlipayCharge(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "充值成功", "付款方式") && hasCommonAmount(nodes)

private fun matchesAlipayChargeDetail(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "余额明细详情", "对方账户") &&
        hasStartsWith(nodes, "余额充值", "支付时间") &&
        hasCommonAmount(nodes)

private fun matchesAlipayWithdraw(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "提现成功", "到账银行卡", "完成") &&
        hasStartsWith(nodes, "提现金额") &&
        hasCommonAmount(nodes)

private fun matchesAlipayWithdrawDetail(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "余额明细详情", "付款方式", "对方账户") &&
        hasStartsWith(nodes, "余额提现", "支付时间") &&
        hasCommonAmount(nodes)

private fun matchesAlipaySendRedPacket(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "发的红包", "24小时内未领取，红包金额将被退回", "查看红包记录") &&
        nodes.any { node -> isTextNode(node) && alipayRedPacketAmountPattern.containsMatchIn(node.label) }

private fun matchesAlipayQrReceiveDetail(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "账单详情", "当前状态", "已收款", "收款时间")

private fun matchesAlipayYuLiBaoIncomeDetail(nodes: List<ScreenNode>): Boolean =
    hasExact(nodes, "收益", "收益到账") &&
        hasStartsWith(nodes, "收益发放：", "余额") &&
        hasCommonAmount(nodes)

private fun matchesAlipayYuLiBaoTransferOutSuccess(nodes: List<ScreenNode>): Boolean =
    hasClassLabel(nodes, "android.widget.Image", "快赎结果页状态") &&
        hasExact(nodes, "转出成功", "收款账号") &&
        hasCommonAmount(nodes)

private fun matchesAlipayYuLiBaoTransferOutDetail(nodes: List<ScreenNode>): Boolean =
    hasClassLabel(nodes, "android.webkit.WebView", "转出详情") &&
        hasStartsWith(nodes, "转出到", "从哪转出：", "收款账号：") &&
        hasExact(nodes, "成功转出") &&
        hasCommonAmount(nodes)

private fun matchesAlipayYuLiBaoTransferInDetail(nodes: List<ScreenNode>): Boolean =
    hasClassLabel(nodes, "android.webkit.WebView", "转入详情") &&
        hasExact(nodes, "转入") &&
        hasContains(nodes, "成功转入") &&
        hasStartsWith(nodes, "转入到：", "付款账号：", "余额") &&
        hasCommonAmount(nodes)

private fun matchesAlipayYuLiBaoTransferInSuccess(nodes: List<ScreenNode>): Boolean =
    hasStartsWith(nodes, "转入成功") &&
        hasExact(nodes, "付款方式", "开始计算收益", "收益到账")

private fun reject(pageType: String, reason: String): QianjiPageParseResult =
    QianjiPageParseResult.rejected(pageType, reason)

private fun parseWechatPersonalRedPacketSend(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WechatPersonalRedPacketSend"
    val amount = amountAfter(nodes, "红包金额")
        ?: captureAmount(nodes, Regex("红包金额(\\d+\\.\\d{2})元，等待对方领取"))
        ?: captureAmount(nodes, Regex("^\\d+个红包共([0-9]+(?:\\.[0-9]{2})?)元$"))
    val sender = redPacketSender(nodes)
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (sender.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = sender,
        transactionType = "EXPENSE", // Qianji leaves raw billType unset, which maps to 0.
    )
}

private fun parseWechatGroupRedPacketDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WechatGroupRedPacketDetail"
    val amount = amountBeforeExact(nodes, "元")
    val sender = redPacketSender(nodes)
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (sender.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    val claimedOut = nodes.any { isTextNode(it) && wechatGroupGrabbedPattern.matches(it.label) }
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = sender,
        transactionType = if (claimedOut) "INCOME" else "EXPENSE",
        note = visibleLabels(nodes).firstOrNull { it.endsWith("的红包") },
        timeLabels = arrayOf("收款时间", "到账时间", "时间"),
    )
}

private fun parseWechatPersonalRedPacketReceive(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult =
    parseWechatPersonalRedPacketReceived(nodes, observedAt, "WechatPersonalRedPacketReceive")

private fun parseWechatPersonalRedPacketReceive2(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult =
    parseWechatPersonalRedPacketReceived(nodes, observedAt, "WechatPersonalRedPacketReceive2")

private fun parseWechatPersonalRedPacketReceived(
    nodes: List<ScreenNode>,
    observedAt: Long,
    pageType: String,
): QianjiPageParseResult {
    val amount = strictTwoDecimalAmount(nodes)
    val sender = redPacketSender(nodes)
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (sender.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = sender,
        transactionType = "INCOME",
        note = "微信红包",
        timeLabels = arrayOf("收款时间", "到账时间", "时间"),
    )
}

private fun parseWechatTransferDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WeChatTransferDetail"
    val amount = amountAfter(nodes, "转账金额", "支付金额", "金额")
    val recipient = valueAfter(nodes, "收款方", "收款人")
        ?: suffixAfter(nodes, "转账-转给")
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (recipient.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = recipient,
        transactionType = "EXPENSE", // No raw billType assignment; Qianji defaults to 0.
        note = noteValue(nodes),
        timeLabels = arrayOf("转账时间", "支付时间", "时间"),
        account = valueAfter(nodes, "支付方式"),
    )
}

private fun parseWechatTransferInDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WeChatTransferInDetail"
    val amount = amountAfter(nodes, "转账金额", "收款金额", "金额")
    val payer = valueAfter(nodes, "付款商家", "付款方")
        ?: suffixAfter(nodes, "商家转账-来自")
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (payer.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = payer,
        transactionType = "INCOME",
        note = noteValue(nodes),
        timeLabels = arrayOf("转账时间", "收款时间", "时间"),
        account = valueAfter(nodes, "收款方式"),
    )
}

private fun parseWechatBillDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WeChatBillDetail"
    val transactionType = when {
        nodes.any { node ->
            isTextNode(node) && listOf(
                "转账-来自", "经营收款-来自", "微信红包-来自", "二维码收款-",
            ).any(node.label::startsWith)
        } ||
            nodes.any { node ->
                isTextNode(node) && commonAmountPattern.matches(node.label) &&
                    (node.label.startsWith("收入") || node.label.startsWith("+") ||
                        node.label.startsWith("¥+") || node.label.startsWith("￥+"))
            } -> "INCOME"
        hasStartsWith(nodes, "提现金额") -> "TRANSFER"
        else -> "EXPENSE" // Qianji's shared mapper defaults unset raw billType to 0.
    }
    val amount = amountAfter(
        nodes,
        "支付金额",
        "支出金额",
        "收入金额",
        "收款金额",
        "转账金额",
        "提现金额",
        "充值金额",
        "金额",
    )
    val merchant = merchantValue(nodes) ?: suffixAfter(nodes, "转账-转给")
        ?: suffixAfter(nodes, "转账-来自")
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (merchant.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = merchant,
        transactionType = transactionType,
        note = noteValue(nodes),
        timeLabels = arrayOf("支付时间", "转账时间", "收款时间", "到账时间", "时间"),
        account = valueAfter(nodes, "支付方式", "收款方式"),
    )
}

private fun parseWechatTransferDetailWaiting(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WeChatTransferDetailWaiting"
    val title = visibleLabels(nodes).firstOrNull {
        it.startsWith("待") && it.endsWith("收款") ||
            it.endsWith("已收款") ||
            it.startsWith("你已收款，")
    }
    if (title.isNullOrBlank()) return reject(pageType, "TRANSFER_STATUS_UNCONFIRMED")
    val type = if (title.startsWith("你已收款，") || title.startsWith("待你收款")) "INCOME" else "EXPENSE"
    val counterparty = when {
        title.startsWith("你已收款，") -> title.removePrefix("你已收款，").trim()
        title.endsWith("已收款") -> title.removeSuffix("已收款").trim()
        title.startsWith("待你收款") -> merchantValue(nodes)
        title.startsWith("待") && title.endsWith("收款") -> title.removePrefix("待").removeSuffix("收款").trim()
        else -> merchantValue(nodes)
    }
    val amount = amountAfter(nodes, "转账金额", "支付金额", "收款金额", "金额")
        ?: uniqueVisiblePageAmount(nodes, exclude = setOf("时间", "付款方式", "支付方式"))
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (counterparty.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = counterparty,
        transactionType = type,
        note = noteValue(nodes),
        timeLabels = arrayOf("转账时间", "收款时间", "时间"),
        account = valueAfter(nodes, "支付方式"),
    )
}

private fun parseWechatWithdrawSuccess(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WechatWithdrawSuccess"
    val amount = amountAfter(nodes, "提现金额")
    val bank = valueAfter(nodes, "到账银行卡")
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (bank.isNullOrBlank()) return reject(pageType, "NO_TARGET_ACCOUNT")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = bank,
        transactionType = "TRANSFER",
        note = "微信提现",
        timeLabels = arrayOf("到账时间", "申请时间"),
        account = valueAfter(nodes, "支付方式", "提现账户"),
        targetAccount = bank,
    )
}

private fun parseWechatWithdrawDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WechatWithdrawDetail"
    val amount = amountAfter(nodes, "提现金额")
    val bank = valueAfter(nodes, "提现银行", "到账银行卡")
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (bank.isNullOrBlank()) return reject(pageType, "NO_TARGET_ACCOUNT")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = bank,
        transactionType = "TRANSFER",
        note = "微信提现",
        timeLabels = arrayOf("到账时间", "申请时间"),
        account = valueAfter(nodes, "支付方式", "提现账户"),
        targetAccount = bank,
    )
}

private fun parseWechatChargeDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WechatChargeDetail"
    val amount = amountAfter(nodes, "零钱充值-来自", "充值金额", "金额")
    val account = valueAfter(nodes, "零钱充值-来自", "支付方式")
        ?: suffixAfter(nodes, "零钱充值-来自")
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (account.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = account,
        transactionType = "TRANSFER",
        note = "微信零钱充值",
        timeLabels = arrayOf("充值时间"),
        account = account,
    )
}

private fun parseWechatPaySuccess(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "WeChatPaySuccess"
    val amount = amountAfter(nodes, "实付金额", "实际支付", "支付金额", "支出金额", "金额")
        ?: uniqueVisiblePageAmount(nodes, exclude = setOf("时间", "优惠", "服务费"))
    val merchant = merchantValue(nodes) ?: wechatSuccessPageRecipient(nodes)
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (merchant.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "WECHAT",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = merchant,
        transactionType = "EXPENSE", // Qianji leaves raw billType unset, including recharge pages.
        note = noteValue(nodes),
        timeLabels = arrayOf("支付时间", "交易时间", "时间"),
        account = valueAfter(nodes, "支付方式", "付款方式"),
        orderId = orderId(nodes),
    )
}

private fun parseAlipayBillDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "AlipayBillDetail"
    val amountSource = visibleLabels(nodes).firstOrNull { commonAmountPattern.matches(it) }.orEmpty()
    val transactionType = when {
        amountSource.contains("收入") || amountSource.startsWith("+") ||
            amountSource.startsWith("+¥") || amountSource.startsWith("+￥") -> "INCOME"
        hasExact(nodes, "收款成功") || hasExact(nodes, "已存入") || hasExact(nodes, "已收钱") -> "INCOME"
        hasExact(nodes, "充值成功") || hasStartsWith(nodes, "余额充值") ||
            hasStartsWith(nodes, "提现到") || hasStartsWith(nodes, "还款到") -> "TRANSFER"
        hasAnyExact(nodes, setOf("支付成功", "代付成功", "免密支付成功", "自动扣款成功", "还款成功")) ||
            amountSource.contains("支出") || amountSource.contains("已支付") ||
            amountSource.startsWith("-") -> "EXPENSE"
        else -> "EXPENSE" // Qianji's shared mapper defaults unset raw billType to 0.
    }
    val amount = amountAfter(
        nodes,
        "实付金额",
        "实际支付",
        "支付金额",
        "收入金额",
        "支出金额",
        "收款金额",
        "转账金额",
        "提现金额",
        "订单金额",
        "金额",
    ) ?: uniqueVisiblePageAmount(nodes, exclude = setOf("时间", "优惠", "服务费"))
    val merchant = merchantValue(nodes)
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (merchant.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = merchant,
        transactionType = transactionType,
        note = noteValue(nodes),
        timeLabels = arrayOf("支付时间", "创建时间", "收款时间", "到账时间", "时间"),
        account = valueAfter(nodes, "付款方式", "收款方式"),
        targetAccount = valueAfter(nodes, "提现到", "还款到"),
        orderId = orderId(nodes),
        originalAmount = amountAfter(nodes, "原价", "订单金额"),
        discountAmount = amountAfter(nodes, "优惠金额", "优惠券"),
    )
}

private fun parseAlipayPaySuccess(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "支付成功", "实付金额", "实际支付", "支付金额")
        ?: uniqueVisiblePageAmount(nodes, exclude = setOf("优惠", "服务费"))
    // Some Alipay success layouts omit a labelled counterparty. The page gate
    // still requires the success title, amount and completion control, so keep
    // the candidate reviewable with the platform name instead of dropping it.
    val merchant = merchantValue(nodes) ?: "支付宝"
    if (amount == null) return reject("AlipayPaySuccess", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (merchant.isNullOrBlank()) return reject("AlipayPaySuccess", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayPaySuccess",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = merchant,
        transactionType = "EXPENSE",
        note = noteValue(nodes),
        timeLabels = arrayOf("支付时间", "时间"),
        account = valueAfter(nodes, "交易方式", "付款方式"),
        orderId = orderId(nodes),
        originalAmount = amountAfter(nodes, "原价", "订单金额"),
        discountAmount = amountAfter(nodes, "优惠金额", "优惠券"),
    )
}

private fun parseAlipayTransfer(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "转账金额", "金额", "转账成功")
    val recipient = valueAfter(nodes, "收款方", "收款人")
    if (amount == null) return reject("AlipayTransfer", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (recipient.isNullOrBlank()) return reject("AlipayTransfer", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayTransfer",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = recipient,
        transactionType = "EXPENSE", // Parser does not set raw billType; Qianji defaults to 0.
        note = noteValue(nodes) ?: "转账给" + recipient,
        timeLabels = arrayOf("转账时间", "支付时间", "时间"),
        account = valueAfter(nodes, "付款方式", "交易方式"),
        targetAccount = valueAfter(nodes, "到账账户", "转入账户"),
        orderId = orderId(nodes),
    )
}

private fun parseAlipayTransferOut(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "转出成功", "转账金额")
    val target = valueAfter(nodes, "到账账户")
    if (amount == null) return reject("AlipayTransferOut", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (target.isNullOrBlank()) return reject("AlipayTransferOut", "NO_TARGET_ACCOUNT")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayTransferOut",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = target,
        transactionType = "TRANSFER",
        note = "支付宝转出",
        timeLabels = arrayOf("转出时间", "到账时间", "时间"),
        account = valueAfter(nodes, "转出方式", "付款方式"),
        targetAccount = target,
    )
}

private fun parseAlipayTransferIn(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "转入成功", "转账金额")
    val source = valueAfter(nodes, "付款方式", "转出账户")
    if (amount == null) return reject("AlipayTransferIn", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (source.isNullOrBlank()) return reject("AlipayTransferIn", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayTransferIn",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = source,
        transactionType = "TRANSFER",
        note = "支付宝转入",
        timeLabels = arrayOf("转入时间", "到账时间", "时间"),
        account = source,
        targetAccount = valueAfter(nodes, "到账账户", "转入账户"),
    )
}

private fun parseAlipayCharge(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val orderAmount = amountAfter(nodes, "订单金额", "充值成功")
    val paidAmount = amountAfter(nodes, "提交成功", "实付金额", "实际支付")
    val amount = orderAmount ?: paidAmount
    val paymentMethod = valueAfter(nodes, "付款方式", "交易方式")
    if (amount == null) return reject("AlipayCharge", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (paymentMethod.isNullOrBlank()) return reject("AlipayCharge", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayCharge",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = paymentMethod,
        transactionType = "EXPENSE", // Qianji's charge parser leaves raw billType unset.
        note = noteValue(nodes) ?: "支付宝余额充值",
        timeLabels = arrayOf("支付时间", "到账时间", "时间"),
        account = paymentMethod,
        targetAccount = valueAfter(nodes, "余额"),
        orderId = orderId(nodes),
        originalAmount = orderAmount,
        discountAmount = amountAfter(nodes, "优惠金额", "优惠券"),
    )
}

private fun parseAlipayChargeDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "余额充值", "充值金额")
    val source = valueAfter(nodes, "对方账户")
    if (amount == null) return reject("AlipayChargeDetail", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (source.isNullOrBlank()) return reject("AlipayChargeDetail", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayChargeDetail",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = source,
        transactionType = "TRANSFER",
        note = noteValue(nodes),
        timeLabels = arrayOf("支付时间"),
        account = source,
        targetAccount = valueAfter(nodes, "余额"),
        orderId = orderId(nodes),
    )
}

private fun parseAlipayWithdraw(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "提现成功", "提现金额")
    val bank = valueAfter(nodes, "到账银行卡")
    if (amount == null) return reject("AlipayWithdraw", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (bank.isNullOrBlank()) return reject("AlipayWithdraw", "NO_TARGET_ACCOUNT")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayWithdraw",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = bank,
        transactionType = "TRANSFER",
        note = "支付宝提现",
        timeLabels = arrayOf("支付时间", "到账时间", "时间"),
        account = valueAfter(nodes, "付款方式", "提现账户"),
        targetAccount = bank,
    )
}

private fun parseAlipayWithdrawDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "余额提现", "提现金额")
    val bank = valueAfter(nodes, "对方账户", "到账银行卡")
    if (amount == null) return reject("AlipayWithdrawDetail", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (bank.isNullOrBlank()) return reject("AlipayWithdrawDetail", "NO_TARGET_ACCOUNT")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayWithdrawDetail",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = bank,
        transactionType = "TRANSFER",
        note = noteValue(nodes) ?: "支付宝提现",
        timeLabels = arrayOf("支付时间", "到账时间", "时间"),
        account = valueAfter(nodes, "付款方式"),
        targetAccount = bank,
    )
}

private fun parseAlipaySendRedPacket(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val pageType = "AlipaySendRedPacket"
    val rawIndex = nodes.indexOfFirst { isTextNode(it) && alipayRedPacketAmountPattern.containsMatchIn(it.label) }
    val raw = nodes.getOrNull(rawIndex)?.label
    val amount = raw?.let { text ->
        alipayRedPacketAmountPattern.find(text)?.groups?.get(4)?.value?.let(QianjiPageSupport::toCents)
    }
    val sender = adjacentVisibleLabel(nodes, rawIndex, -1)
    val note = adjacentVisibleLabel(nodes, rawIndex, 1)
    if (amount == null) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (sender.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = pageType,
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = sender,
        transactionType = "EXPENSE", // No raw billType assignment; Qianji defaults to 0.
        note = note,
    )
}

private fun parseAlipayQrReceiveDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "订单金额")
    val payer = valueAfter(nodes, "付款方备注", "交易说明", "付款方", "收款方")
    if (amount == null) return reject("AlipayQRCodeReceiveDetail", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (payer.isNullOrBlank()) return reject("AlipayQRCodeReceiveDetail", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayQRCodeReceiveDetail",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = payer,
        transactionType = "INCOME",
        note = noteValue(nodes),
        timeLabels = arrayOf("收款时间"),
        account = valueAfter(nodes, "收款方式"),
        orderId = orderId(nodes),
    )
}

private fun parseAlipayYuLiBaoIncomeDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "收益到账", "收益金额", "金额")
    val source = valueAfter(nodes, "收益发放：", "收益发放")
    if (amount == null) return reject("AlipayYuLiBaoIncomeDetail", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (source.isNullOrBlank()) return reject("AlipayYuLiBaoIncomeDetail", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayYuLiBaoIncomeDetail",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = source,
        transactionType = "INCOME",
        note = "余利宝收益",
        timeLabels = arrayOf("收益时间", "到账时间", "时间"),
        account = valueAfter(nodes, "余额"),
    )
}

private fun parseAlipayYuLiBaoTransferOutSuccess(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "转出成功")
    val target = valueAfter(nodes, "收款账号")
    if (amount == null) return reject("AlipayYuLiBaoTransferOutSuccess", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (target.isNullOrBlank()) return reject("AlipayYuLiBaoTransferOutSuccess", "NO_TARGET_ACCOUNT")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayYuLiBaoTransferOutSuccess",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = target,
        transactionType = "TRANSFER",
        note = "余利宝转出",
        timeLabels = arrayOf("到账时间", "转出时间", "时间"),
        account = "余利宝",
        targetAccount = target,
    )
}

private fun parseAlipayYuLiBaoTransferOutDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "成功转出", "转出金额")
    val source = valueAfter(nodes, "从哪转出：")
    val target = valueAfter(nodes, "收款账号：")
    if (amount == null) return reject("AlipayYuLiBaoTransferOutDetail", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (target.isNullOrBlank()) return reject("AlipayYuLiBaoTransferOutDetail", "NO_TARGET_ACCOUNT")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayYuLiBaoTransferOutDetail",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = target,
        transactionType = "TRANSFER",
        note = "余利宝转出",
        timeLabels = arrayOf("转出时间", "支付时间", "时间"),
        account = source ?: "余利宝",
        targetAccount = target,
        orderId = orderId(nodes),
    )
}

private fun parseAlipayYuLiBaoTransferInDetail(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = amountAfter(nodes, "成功转入", "转入金额")
    val source = valueAfter(nodes, "付款账号：")
    val target = valueAfter(nodes, "转入到：")
    if (amount == null) return reject("AlipayYuLiBaoTransferInDetail", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (source.isNullOrBlank()) return reject("AlipayYuLiBaoTransferInDetail", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayYuLiBaoTransferInDetail",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = source,
        transactionType = "TRANSFER",
        note = "余利宝转入",
        timeLabels = arrayOf("转入时间", "支付时间", "时间"),
        account = source,
        targetAccount = target ?: "余利宝",
        orderId = orderId(nodes),
    )
}

private fun parseAlipayYuLiBaoTransferInSuccess(
    nodes: List<ScreenNode>,
    observedAt: Long,
): QianjiPageParseResult {
    val amount = captureAmount(nodes, alipayTransferInSuccessAmountPattern)
        ?: amountAfter(nodes, "转入成功")
    val source = valueAfter(nodes, "付款方式")
    if (amount == null) return reject("AlipayYuLiBaoTransferInSuccess", "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (source.isNullOrBlank()) return reject("AlipayYuLiBaoTransferInSuccess", "NO_COUNTERPARTY")
    return emitCandidate(
        sourceApp = "ALIPAY",
        pageType = "AlipayYuLiBaoTransferInSuccess",
        nodes = nodes,
        observedAt = observedAt,
        amount = amount,
        merchant = source,
        transactionType = "TRANSFER",
        note = "余利宝转入",
        timeLabels = arrayOf("转入时间", "到账时间", "时间"),
        account = source,
        targetAccount = "余利宝",
    )
}

private fun amountAfter(nodes: List<ScreenNode>, vararg labels: String): Long? =
    QianjiPageSupport.uniqueMoneyAfter(nodes, labels.toSet())

private fun uniqueVisiblePageAmount(
    nodes: List<ScreenNode>,
    exclude: Set<String> = emptySet(),
): Long? = QianjiPageSupport.uniqueVisibleMoney(nodes, exclude)

private fun strictTwoDecimalAmount(nodes: List<ScreenNode>): Long? {
    val amounts = nodes.asSequence()
        .filter(::isTextNode)
        .map(ScreenNode::label)
        .mapNotNull { label ->
            wechatPersonalReceiveAmountPattern.matchEntire(label)
                ?.groupValues
                ?.getOrNull(1)
                ?.let(QianjiPageSupport::toCents)
        }
        .toSet()
    return amounts.singleOrNull()
}

private fun amountBeforeExact(nodes: List<ScreenNode>, exactLabel: String): Long? {
    val amounts = linkedSetOf<Long>()
    nodes.indices.filter { index -> isTextNode(nodes[index]) && nodes[index].label == exactLabel }
        .forEach { index ->
            for (previous in (index - 1).downTo((index - 2).coerceAtLeast(0))) {
                val label = nodes[previous].label.trim()
                val match = wechatPersonalReceiveAmountPattern.matchEntire(label) ?: continue
                QianjiPageSupport.toCents(match.groupValues[1])?.let(amounts::add)
                break
            }
        }
    return amounts.singleOrNull()
}

private fun captureAmount(nodes: List<ScreenNode>, regex: Regex): Long? {
    val values = nodes.asSequence()
        .filter(::isTextNode)
        .mapNotNull { node -> regex.find(node.label)?.groups?.get(1)?.value }
        .mapNotNull(QianjiPageSupport::toCents)
        .toSet()
    return values.singleOrNull()
}

private fun adjacentVisibleLabel(nodes: List<ScreenNode>, index: Int, direction: Int): String? {
    if (index !in nodes.indices) return null
    var cursor = index + direction
    while (cursor in nodes.indices) {
        if (isTextNode(nodes[cursor]) && nodes[cursor].label.isNotBlank()) return nodes[cursor].label
        cursor += direction
    }
    return null
}

private fun valueAfter(nodes: List<ScreenNode>, vararg labels: String): String? =
    QianjiPageSupport.firstValueAfter(nodes, labels.toSet())

private fun suffixAfter(nodes: List<ScreenNode>, vararg prefixes: String): String? {
    for (prefix in prefixes.sortedByDescending(String::length)) {
        val value = visibleLabels(nodes).firstOrNull { label ->
            label.startsWith(prefix) && label.length > prefix.length
        }?.removePrefix(prefix)?.trimStart(' ', '：', ':', '-', '－')
        if (!value.isNullOrBlank()) return value
    }
    return null
}

private fun redPacketSender(nodes: List<ScreenNode>): String? =
    visibleLabels(nodes).firstNotNullOfOrNull { label ->
        redPacketSenderPattern.matchEntire(label)?.groups?.get(1)?.value?.trim()
    }

private fun merchantValue(nodes: List<ScreenNode>): String? =
    valueAfter(
        nodes,
        "商户全称",
        "商户名称",
        "商家名称",
        "交易对方",
        "收款方全称",
        "收款方",
        "收款人",
        "付款商家",
        "付款方",
        "对方账户",
        "到账银行卡",
        "收款账号",
        "付款方备注",
        "交易说明",
    ) ?: suffixAfter(nodes, "转账-转给", "转账-来自", "商家转账-来自")

/**
 * WeChat's payment success screen can expose the recipient without a field label.
 * Keep this fallback tied to its observed accessibility layout so generic page
 * copy, action labels, or neighboring unrelated text cannot become a merchant.
 */
private fun wechatSuccessPageRecipient(nodes: List<ScreenNode>): String? {
    val hasSuccessRoot = nodes.any {
        it.className == "android.view.ViewGroup" && it.contentDescription.trim() == "支付成功"
    }
    val hasCompletionButton = nodes.any {
        it.className == "android.widget.Button" && it.contentDescription.trim() == "完成"
    }
    if (!hasSuccessRoot || !hasCompletionButton) return null
    if (!hasClassLabel(nodes, "android.widget.TextView", "完成")) return null

    val successIndex = nodes.indexOfFirst {
        it.className == "android.widget.TextView" && it.text.trim() == "支付成功"
    }
    if (successIndex < 0) return null

    val amountIndices = nodes.indices.filter { index ->
        val node = nodes[index]
        node.className == "android.widget.TextView" &&
            wechatPersonalReceiveAmountPattern.matches(node.text.trim())
    }
    val amountIndex = amountIndices.singleOrNull()?.takeIf { it > successIndex } ?: return null
    val between = (successIndex + 1 until amountIndex).mapNotNull { index ->
        nodes[index].takeIf { it.className == "android.widget.TextView" && it.text.isNotBlank() }
    }
    val recipient = between.singleOrNull()?.text?.trim() ?: return null
    if (recipient in wechatSuccessPageNonRecipientLabels ||
        recipient.contains("提示") || recipient.contains("支付成功") ||
        wechatPersonalReceiveAmountPattern.matches(recipient)
    ) return null
    return recipient
}

private val wechatSuccessPageNonRecipientLabels = setOf(
    "完成",
    "返回",
    "支付详情",
    "查看账单",
    "订单详情",
    "交易成功",
    "收款成功",
    "充值成功",
    "付款成功",
)

private fun noteValue(nodes: List<ScreenNode>): String? =
    valueAfter(
        nodes,
        "商品说明",
        "商品",
        "备注",
        "转账说明",
        "转账备注",
        "付款备注",
        "付款方留言",
        "交易说明",
        "红包说明",
        "收款方备注",
        "付款方备注",
    )

private fun orderId(nodes: List<ScreenNode>): String? =
    QianjiPageSupport.firstRegexValue(
        nodes,
        Regex("(?:订单号|交易号)\\s*[：:]?\\s*([A-Za-z0-9_-]{6,})"),
    )

private fun emitCandidate(
    sourceApp: String,
    pageType: String,
    nodes: List<ScreenNode>,
    observedAt: Long,
    amount: Long?,
    merchant: String?,
    transactionType: String,
    note: String? = null,
    timeLabels: Array<String> = emptyArray(),
    account: String? = null,
    targetAccount: String? = null,
    orderId: String? = null,
    originalAmount: Long? = null,
    discountAmount: Long? = null,
): QianjiPageParseResult {
    if (amount == null || amount <= 0L) return reject(pageType, "MISSING_OR_AMBIGUOUS_AMOUNT")
    if (merchant.isNullOrBlank()) return reject(pageType, "NO_COUNTERPARTY")
    val transactionAt = if (timeLabels.isNotEmpty()) {
        QianjiPageSupport.timestampFromText(valueAfter(nodes, *timeLabels))
    } else {
        null
    }
    val candidate = QianjiPageSupport.candidate(
        sourceApp = sourceApp,
        pageType = pageType,
        amountInCents = amount,
        merchant = merchant,
        paymentMethod = account ?: "UNKNOWN",
        observedAt = observedAt,
        transactionAt = transactionAt,
        transactionType = transactionType,
        note = note,
        orderId = orderId,
        originalAmountInCents = originalAmount,
        discountAmountInCents = discountAmount,
        targetIdentifierSuffix = targetAccount?.let {
            Regex("尾号\\s*(\\d{4})").find(it)?.groups?.get(1)?.value
        },
        targetAccountHint = targetAccount,
    )
    return candidate?.let { QianjiPageParseResult(pageType = pageType, candidate = it) }
        ?: reject(pageType, "INVALID_CANDIDATE_FIELDS")
}
