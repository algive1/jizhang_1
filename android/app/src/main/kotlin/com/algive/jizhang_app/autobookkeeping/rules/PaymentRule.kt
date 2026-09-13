package com.algive.jizhang_app.autobookkeeping.rules

/** Local, versioned rules. No remote execution and no page upload. */
data class PaymentRule(
    val app: String = "com.tencent.mm",
    val scene: String = "WECHAT_PAYMENT_SUCCESS",
    val version: Int = 1,
    val keywords: Set<String> = setOf("支付成功", "付款成功", "已支付", "支付完成"),
    val amountPatterns: List<Regex> = listOf(Regex("[¥￥]\\s*([0-9]+(?:\\.[0-9]{1,2})?)(?![0-9.])"), Regex("(?<![0-9.])([0-9]+(?:\\.[0-9]{1,2})?)\\s*元")),
    val merchantPatterns: Set<String> = setOf("收款方", "商户", "商户名称", "收款商户", "收款单位"),
    val amountLabels: Set<String> = setOf("实付", "实付金额", "付款金额", "支付金额", "实际支付"),
    val excludedKeywords: Set<String> = setOf("优惠", "余额", "订单", "时间", "积分", "原价", "商品金额", "合计", "立减", "红包"),
    val methodLabels: Set<String> = setOf("支付方式", "付款方式"),
)
