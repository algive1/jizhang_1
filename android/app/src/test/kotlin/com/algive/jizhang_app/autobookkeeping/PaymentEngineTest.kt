package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.parser.WeChatPaymentParser
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
    @Test fun normalization() { assertEquals("麦当劳", parse("支付成功", "商户", "McDonald's 成都", "￥38.50")?.merchantNormalized) }
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
