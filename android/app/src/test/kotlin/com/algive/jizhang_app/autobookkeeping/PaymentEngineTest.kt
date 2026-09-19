package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.parser.WeChatPaymentParser
import com.algive.jizhang_app.autobookkeeping.parser.PaymentAppParser
import com.algive.jizhang_app.autobookkeeping.detector.PaymentSceneDetector
import com.algive.jizhang_app.autobookkeeping.dedup.*
import org.junit.Assert.*
import org.junit.Test

class PaymentEngineTest {
    private fun nodes(vararg text: String) = text.map { ScreenNode(text = it) }
    private fun parse(vararg text: String) = WeChatPaymentParser().parse(nodes(*text), 100000)
    @Test fun fixtures() {
        val fixtures = javaClass.getResourceAsStream("/wechat/payments.txt")!!.bufferedReader().readText().trim().split("\n\n")
        fixtures.forEach { fixture ->
            val lines = fixture.lines()
            val expected = lines.first().toLong()
            assertEquals(fixture, expected, WeChatPaymentParser().parse(nodes(*lines.drop(1).toTypedArray()))?.amountInCents)
        }
    }
    @Test fun ambiguousAmountRejected() { assertNull(parse("支付成功", "收款方", "商店", "￥20", "￥30")) }
    @Test fun noMerchantRejected() { assertNull(parse("支付成功", "￥20")) }
    @Test fun chatQuoteRejected() { assertNull(parse("他说支付成功", "收款方", "商店", "￥20")) }
    @Test fun wrongAppRejected() { assertNull(PaymentSceneDetector().detect("other", nodes("支付成功", "收款方", "商店", "￥20"))) }
    @Test fun failureRejected() { assertNull(parse("支付失败", "收款方", "商店", "￥20")) }
    @Test fun supportedAppsUseConservativeGenericParser() {
        val candidate = PaymentSceneDetector().detect(
            "com.sankuai.meituan",
            nodes("支付成功", "商户", "美团外卖", "实付金额", "36.00元"),
            100000,
        )
        assertEquals(3600L, candidate?.amountInCents)
        assertEquals("MEITUAN", candidate?.sourceApp)
    }
    @Test fun jdPinduoduoAndDouyinUseGenericParser() {
        val expected = mapOf(
            "com.jingdong.app.mall" to "JD",
            "com.xunmeng.pinduoduo" to "PINDUODUO",
            "com.ss.android.ugc.aweme" to "DOUYIN",
            "com.ss.android.ugc.aweme.mobile" to "DOUYIN",
        )
        expected.forEach { (packageName, sourceApp) ->
            val candidate = PaymentSceneDetector().detect(
                packageName,
                nodes("订单支付成功", "商户", "测试商户", "实付金额", "18.80元"),
                100000,
            )
            assertEquals(packageName, 1880L, candidate?.amountInCents)
            assertEquals(packageName, sourceApp, candidate?.sourceApp)
        }
    }
    @Test fun genericParserRejectsAmbiguousExplicitAmounts() {
        assertNull(PaymentAppParser().parse("com.eg.android.AlipayGphone", nodes("支付成功", "商户", "商店", "支付金额", "12", "支付金额", "18"), 100000))
    }
    @Test fun normalization() { assertEquals("麦当劳", parse("支付成功", "商户", "McDonald's 成都", "￥38.50")?.merchantNormalized) }
    @Test fun transferSuccessUsesRecipientAsMerchant() {
        val candidate = parse("支付成功", "待陆勤老师-专注职工社保确认收款", "￥1.00")
        assertEquals(100L, candidate?.amountInCents)
        assertEquals("待陆勤老师-专注职工社保确认收款", candidate?.merchantRaw)
    }
    @Test fun repeatedPageVersusNewPayment() {
        val c = parse("支付成功", "收款方", "商店", "￥20")!!
        val engine = BillDedupEngine()
        assertEquals(DedupResult.NOT_DUPLICATE, engine.check(c))
        engine.remember(c)
        assertEquals(DedupResult.DUPLICATE, engine.check(c.copy(timestamp = 100100), samePage = true))
        assertEquals(DedupResult.POSSIBLE_DUPLICATE, engine.check(c.copy(timestamp = 160000)))
        assertEquals(DedupResult.NOT_DUPLICATE, engine.check(c.copy(timestamp = 500001)))
        assertNotEquals(BillFingerprint.of(c), BillFingerprint.of(c.copy(paymentMethod = "银行卡")))
    }
}
