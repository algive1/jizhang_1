package com.algive.jizhang_app.autobookkeeping

import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.parser.WeChatPaymentParser
import com.algive.jizhang_app.autobookkeeping.parser.PaymentAppParser
import com.algive.jizhang_app.autobookkeeping.parser.PaymentNotificationCandidateParser
import com.algive.jizhang_app.autobookkeeping.detector.PaymentSceneDetector
import com.algive.jizhang_app.autobookkeeping.dedup.*
import com.algive.jizhang_app.autobookkeeping.repository.AutoBookkeepingPendingStore
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry
import com.algive.jizhang_app.autobookkeeping.rules.PaymentParserKind
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
    @Test fun builtInRuleRegistryCoversEverySupportedPackage() {
        val registry = AutoBookkeepingRuleRegistry.builtIn()
        assertEquals(
            setOf(
                "com.tencent.mm",
                "com.eg.android.AlipayGphone",
                "com.unionpay",
                "com.sankuai.meituan",
                "com.sankuai.meituan.takeout",
                "com.jingdong.app.mall",
                "com.xunmeng.pinduoduo",
                "com.ss.android.ugc.aweme",
                "com.ss.android.ugc.aweme.mobile",
            ),
            registry.supportedPackages,
        )
        assertEquals(
            setOf(
                "WalletPayUI",
                "WalletOrderInfo",
                "WalletOfflineCoinPurseUI",
                "WalletOrderInfoNewUI",
                "UIPageFragmentActivity",
            ),
            registry.ruleForKind(PaymentParserKind.WECHAT)?.activityHints,
        )
    }

    @Test fun registryKeepsSourceAndScenePerPaymentApp() {
        val expected = mapOf(
            "com.eg.android.AlipayGphone" to
                ("ALIPAY" to "ALIPAY_PAYMENT_SUCCESS"),
            "com.unionpay" to
                ("UNIONPAY" to "UNIONPAY_PAYMENT_SUCCESS"),
            "com.jingdong.app.mall" to
                ("JD" to "JD_PAYMENT_SUCCESS"),
            "com.xunmeng.pinduoduo" to
                ("PINDUODUO" to "PINDUODUO_PAYMENT_SUCCESS"),
            "com.ss.android.ugc.aweme" to
                ("DOUYIN" to "DOUYIN_PAYMENT_SUCCESS"),
        )
        val detector = PaymentSceneDetector(AutoBookkeepingRuleRegistry.builtIn())
        expected.forEach { (packageName, sourceAndScene) ->
            val candidate = detector.detect(
                packageName,
                nodes(
                    "支付成功",
                    "商户",
                    "测试商户",
                    "实付金额",
                    "18.80元",
                ),
                100000,
            )
            assertEquals(packageName, sourceAndScene.first, candidate?.sourceApp)
            assertEquals(
                packageName,
                sourceAndScene.second,
                candidate?.scene?.scene,
            )
        }
    }

    @Test fun supportedAppsUseConservativeGenericParser() {
        val candidate = PaymentSceneDetector().detect(
            "com.sankuai.meituan",
            nodes("支付成功", "商户", "美团外卖", "实付金额", "36.00元"),
            100000,
        )
        assertEquals(3600L, candidate?.amountInCents)
        assertEquals("MEITUAN", candidate?.sourceApp)
    }
    @Test fun meituanDedicatedParserAcceptsOrderPaidLayout() {
        val candidate = PaymentSceneDetector().detect(
            "com.sankuai.meituan",
            nodes("订单已支付", "店铺名称", "测试餐厅", "订单实付", "36.00"),
            100000,
        )
        assertEquals(3600L, candidate?.amountInCents)
        assertEquals("MEITUAN", candidate?.sourceApp)
        assertEquals("测试餐厅", candidate?.merchantRaw)
    }

    @Test fun meituanDedicatedParserRejectsPendingPayment() {
        assertNull(
            PaymentSceneDetector().detect(
                "com.sankuai.meituan",
                nodes("待支付", "店铺名称", "测试餐厅", "订单实付", "36.00"),
                100000,
            ),
        )
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
    @Test fun nativeNotificationParserAcceptsCompletedMeituanPayment() {
        val candidate = PaymentNotificationCandidateParser().parse(
            "com.sankuai.meituan",
            "美团",
            "支付成功，原价 ￥40.00，优惠券 ￥4.00，实付金额 ￥36.00，商户：测试餐厅",
            100000,
        )
        assertEquals(3600L, candidate?.amountInCents)
        assertEquals("测试餐厅", candidate?.merchantRaw)
        assertEquals("MEITUAN", candidate?.sourceApp)
        assertEquals("PAYMENT_NOTIFICATION", candidate?.scene?.scene)
    }

    @Test fun nativeNotificationParserKeepsEnrichedFields() {
        val candidate = PaymentNotificationCandidateParser().parse(
            "com.eg.android.AlipayGphone",
            "支付宝",
            "支付成功，原价 ￥40.00，优惠券 ￥4.00，实付金额 ￥36.00，商户：测试餐厅，订单号：ORDER_123456，尾号 3316，备注：晚餐",
            100000,
        )
        assertEquals(3600L, candidate?.amountInCents)
        assertEquals(4000L, candidate?.originalAmountInCents)
        assertEquals(400L, candidate?.discountAmountInCents)
        assertEquals("ORDER_123456", candidate?.orderId)
        assertEquals("3316", candidate?.identifierSuffix)
        assertEquals("晚餐", candidate?.note)
    }

    @Test fun nativeNotificationParserDoesNotTreatPaymentOrderIdAsAmount() {
        val candidate = PaymentNotificationCandidateParser().parse(
            "com.eg.android.AlipayGphone",
            "支付宝",
            "支付成功 ￥28.50，商户：瑞幸咖啡，支付单号：PAY202609200001",
            100000,
        )
        assertEquals(2850L, candidate?.amountInCents)
        assertEquals("PAY202609200001", candidate?.orderId)
    }

    @Test fun nativeNotificationParserClassifiesIncomeAndRefund() {
        val parser = PaymentNotificationCandidateParser()
        val income = parser.parse(
            "com.tencent.mm",
            "微信支付",
            "收款到账 ￥88.00，来自张三",
            100000,
        )
        assertEquals("INCOME", income?.transactionType)
        assertEquals("张三", income?.merchantRaw)
        assertEquals("PAYMENT_NOTIFICATION_INCOME", income?.scene?.scene)

        val refund = parser.parse(
            "com.eg.android.AlipayGphone",
            "支付宝",
            "退款成功 ￥28.50，退款方：测试餐厅",
            100000,
        )
        assertEquals("REFUND", refund?.transactionType)
        assertEquals(2850L, refund?.amountInCents)
        assertEquals("测试餐厅", refund?.merchantRaw)
        assertEquals("PAYMENT_NOTIFICATION_REFUND", refund?.scene?.scene)
    }

    @Test fun nativeNotificationParserRejectsWechatChatIncomeAndRefundQuotes() {
        val parser = PaymentNotificationCandidateParser()
        assertNull(
            parser.parse(
                "com.tencent.mm",
                "小王",
                "收款成功 ￥88.00，来自张三",
                100000,
            ),
        )
        assertNull(
            parser.parse(
                "com.tencent.mm",
                "小王",
                "退款成功 ￥28.50，退款方：测试餐厅",
                100000,
            ),
        )
    }

    @Test fun nativeNotificationParserRejectsPendingAndWechatChat() {
        val parser = PaymentNotificationCandidateParser()
        assertNull(
            parser.parse(
                "com.sankuai.meituan",
                "美团",
                "订单待支付 ￥36.00，请尽快支付",
                100000,
            ),
        )
        assertNull(
            parser.parse(
                "com.tencent.mm",
                "小王",
                "我刚支付成功 ￥20.00，商户：便利店",
                100000,
            ),
        )
        assertNotNull(
            parser.parse(
                "com.tencent.mm",
                "微信支付",
                "支付成功 ￥20.00，商户：便利店",
                100000,
            ),
        )
    }

    @Test fun pageParserExtractsOrderDiscountNoteAndSuffix() {
        val candidate = PaymentAppParser().parse(
            "com.eg.android.AlipayGphone",
            nodes(
                "支付成功",
                "商户",
                "测试餐厅",
                "原价",
                "￥40.00",
                "优惠",
                "￥4.00",
                "实付金额",
                "￥36.00",
                "订单号",
                "ORDER_123456",
                "支付方式",
                "招商银行储蓄卡 尾号3316",
                "备注",
                "晚餐",
            ),
            100000,
        )
        assertEquals(3600L, candidate?.amountInCents)
        assertEquals(4000L, candidate?.originalAmountInCents)
        assertEquals(400L, candidate?.discountAmountInCents)
        assertEquals("ORDER_123456", candidate?.orderId)
        assertEquals("3316", candidate?.identifierSuffix)
        assertEquals("晚餐", candidate?.note)
    }

    @Test fun accessibilityParserDetectsRefundAndIncomePages() {
        val refund = PaymentSceneDetector().detect(
            "com.eg.android.AlipayGphone",
            nodes(
                "退款成功",
                "退款方",
                "测试餐厅",
                "退款金额",
                "28.50",
                "订单号",
                "ORDER_REFUND_123",
            ),
            100000,
        )
        assertEquals("REFUND", refund?.transactionType)
        assertEquals(2850L, refund?.amountInCents)
        assertEquals("测试餐厅", refund?.merchantRaw)
        assertEquals("ORDER_REFUND_123", refund?.orderId)

        val income = PaymentSceneDetector().detect(
            "com.tencent.mm",
            nodes(
                "收款到账",
                "来自张三",
                "￥88.00",
            ),
            100000,
        )
        assertEquals("INCOME", income?.transactionType)
        assertEquals(8800L, income?.amountInCents)
        assertEquals("张三", income?.merchantRaw)
    }

    @Test fun accessibilityParserDetectsOutgoingTransferWithoutCallingItInternal() {
        val candidate = PaymentSceneDetector().detect(
            "com.tencent.mm",
            nodes(
                "转账成功",
                "收款人",
                "张三",
                "转账金额",
                "66.00",
                "转出方式",
                "微信支付",
                "转入账户",
                "招商银行储蓄卡 尾号7777",
            ),
            100000,
        )
        assertEquals("TRANSFER", candidate?.transactionType)
        assertEquals("WECHAT_TRANSFER_SUCCESS", candidate?.scene?.scene)
        assertEquals(6600L, candidate?.amountInCents)
        assertEquals("张三", candidate?.merchantRaw)
        assertEquals("7777", candidate?.targetIdentifierSuffix)
        assertEquals("招商银行储蓄卡 尾号7777", candidate?.targetAccountHint)
    }

    @Test fun wechatConfirmationLayoutIsTypedAsTransferBySceneDetector() {
        val candidate = PaymentSceneDetector().detect(
            "com.tencent.mm",
            nodes(
                "支付成功",
                "待陆勤老师-专注职工社保确认收款",
                "￥1.00",
            ),
            100000,
        )
        assertEquals("TRANSFER", candidate?.transactionType)
        assertEquals(100L, candidate?.amountInCents)
        assertEquals("陆勤老师-专注职工社保", candidate?.merchantRaw)
    }

    @Test fun nativeNotificationParserDetectsCompletedTransferAndTargetSuffix() {
        val candidate = PaymentNotificationCandidateParser().parse(
            "com.tencent.mm",
            "微信支付",
            "转账成功 ￥66.00，收款人：张三，转入账户：招商银行储蓄卡 尾号7777，转出方式：微信支付",
            100000,
        )
        assertEquals("TRANSFER", candidate?.transactionType)
        assertEquals("PAYMENT_NOTIFICATION_TRANSFER", candidate?.scene?.scene)
        assertEquals(6600L, candidate?.amountInCents)
        assertEquals("张三", candidate?.merchantRaw)
        assertEquals("7777", candidate?.targetIdentifierSuffix)
    }

    @Test fun accessibilityTypedParserRejectsMissingCounterparty() {
        val result = PaymentSceneDetector().inspect(
            "com.eg.android.AlipayGphone",
            nodes("退款成功", "退款金额", "28.50"),
            100000,
        )
        assertNull(result.candidate)
        assertEquals("NO_COUNTERPARTY", result.rejectionReason)
    }

    @Test fun genericParserRejectsAmbiguousExplicitAmounts() {
        assertNull(PaymentAppParser().parse("com.eg.android.AlipayGphone", nodes("支付成功", "商户", "商店", "支付金额", "12", "支付金额", "18"), 100000))
    }
    @Test fun pendingStoreKeepsTransferTargetFields() {
        val candidate = AutoBookkeepingPendingStore.candidateFromMap(
            mapOf(
                "amountInCents" to 50000L,
                "merchant" to "张三",
                "paymentMethod" to "支付宝余额",
                "timestamp" to 100000L,
                "sourceApp" to "ALIPAY",
                "scene" to "PAYMENT_NOTIFICATION_TRANSFER",
                "transactionType" to "TRANSFER",
                "targetIdentifierSuffix" to "1234",
                "targetAccountHint" to "招商银行储蓄卡 尾号1234",
            ),
        )
        assertNotNull(candidate)
        assertEquals("TRANSFER", candidate?.transactionType)
        assertEquals("1234", candidate?.targetIdentifierSuffix)
        assertEquals(
            "招商银行储蓄卡 尾号1234",
            candidate?.targetAccountHint,
        )
    }

    @Test fun pendingStoreAcceptsAllNotificationSourceApps() {
        val sources = listOf("WECHAT", "ALIPAY", "UNIONPAY", "MEITUAN", "JD", "PINDUODUO", "DOUYIN")
        sources.forEach { source ->
            val candidate = AutoBookkeepingPendingStore.candidateFromMap(
                mapOf(
                    "amountInCents" to 1880L,
                    "merchant" to "测试商户",
                    "paymentMethod" to "测试支付",
                    "timestamp" to 100000L,
                    "sourceApp" to source,
                    "scene" to "PAYMENT_NOTIFICATION",
                    "transactionType" to "REFUND",
                    "orderId" to "ORDER_123456",
                    "note" to "测试备注",
                    "originalAmountInCents" to 2000L,
                    "discountAmountInCents" to 120L,
                    "identifierSuffix" to "3316",
                ),
            )
            assertNotNull(source, candidate)
            assertEquals(source, candidate?.sourceApp)
            assertEquals("REFUND", candidate?.transactionType)
            assertEquals("ORDER_123456", candidate?.orderId)
            assertEquals("3316", candidate?.identifierSuffix)
        }
    }

    @Test fun pendingStoreCarriesTransferTargetHints() {
        val candidate = AutoBookkeepingPendingStore.candidateFromMap(
            mapOf(
                "amountInCents" to 6600L,
                "merchant" to "张三",
                "paymentMethod" to "微信支付",
                "timestamp" to 100000L,
                "sourceApp" to "WECHAT",
                "scene" to "WECHAT_TRANSFER_SUCCESS",
                "transactionType" to "TRANSFER",
                "targetIdentifierSuffix" to "7777",
                "targetAccountHint" to "招商银行储蓄卡 尾号7777",
            ),
        )
        assertEquals("TRANSFER", candidate?.transactionType)
        assertEquals("7777", candidate?.targetIdentifierSuffix)
        assertEquals("招商银行储蓄卡 尾号7777", candidate?.targetAccountHint)
    }

    @Test fun normalization() { assertEquals("麦当劳", parse("支付成功", "商户", "McDonald's 成都", "￥38.50")?.merchantNormalized) }
    @Test fun transferSuccessUsesRecipientAsCounterparty() {
        val candidate = PaymentSceneDetector().detect(
            "com.tencent.mm",
            nodes(
                "支付成功",
                "待陆勤老师-专注职工社保确认收款",
                "￥1.00",
            ),
            100000,
        )
        assertEquals(100L, candidate?.amountInCents)
        assertEquals("TRANSFER", candidate?.transactionType)
        assertEquals("WECHAT_TRANSFER_SUCCESS", candidate?.scene?.scene)
        assertEquals("待陆勤老师-专注职工社保", candidate?.merchantRaw)
    }

    @Test fun explicitTransferPageExtractsOwnAccountTargetHint() {
        val candidate = PaymentSceneDetector().detect(
            "com.eg.android.AlipayGphone",
            nodes(
                "转账成功",
                "收款人",
                "张三",
                "转账金额",
                "500.00",
                "转出方式",
                "支付宝余额",
                "转入账户",
                "招商银行储蓄卡 尾号1234",
            ),
            100000,
        )
        assertEquals("TRANSFER", candidate?.transactionType)
        assertEquals(50000L, candidate?.amountInCents)
        assertEquals("张三", candidate?.merchantRaw)
        assertEquals("招商银行储蓄卡 尾号1234", candidate?.targetAccountHint)
        assertEquals("1234", candidate?.targetIdentifierSuffix)
    }

    @Test fun nativeTransferNotificationKeepsTargetHintAndType() {
        val candidate = PaymentNotificationCandidateParser().parse(
            "com.eg.android.AlipayGphone",
            "支付宝",
            "转账成功 ￥500.00，收款人：张三，转入账户：招商银行储蓄卡 尾号1234",
            100000,
        )
        assertEquals("TRANSFER", candidate?.transactionType)
        assertEquals("PAYMENT_NOTIFICATION_TRANSFER", candidate?.scene?.scene)
        assertEquals(50000L, candidate?.amountInCents)
        assertEquals("张三", candidate?.merchantRaw)
        assertEquals("1234", candidate?.targetIdentifierSuffix)
    }

    @Test fun transferReminderAndWechatChatAreRejected() {
        assertNull(
            PaymentSceneDetector().detect(
                "com.eg.android.AlipayGphone",
                nodes("转账提醒", "收款人", "张三", "￥500.00"),
                100000,
            ),
        )
        assertNull(
            PaymentNotificationCandidateParser().parse(
                "com.tencent.mm",
                "小王",
                "我刚转账成功 ￥500.00，收款人：张三",
                100000,
            ),
        )
    }
    @Test fun pendingMatcherAllowsExpenseTransferMismatchOnlyAcrossCaptureSources() {
        assertTrue(
            AutoBookkeepingPendingStore.transactionTypesCompatible(
                "EXPENSE",
                "TRANSFER",
                true,
            ),
        )
        assertFalse(
            AutoBookkeepingPendingStore.transactionTypesCompatible(
                "EXPENSE",
                "TRANSFER",
                false,
            ),
        )
        assertFalse(
            AutoBookkeepingPendingStore.transactionTypesCompatible(
                "TRANSFER",
                "INCOME",
                true,
            ),
        )
        assertTrue(
            AutoBookkeepingPendingStore.transactionTypesCompatible(
                "REFUND",
                "REFUND",
                false,
            ),
        )
    }

    @Test fun repeatedPageVersusNewPayment() {
        val c = parse("支付成功", "收款方", "商店", "￥20")!!
        val engine = BillDedupEngine()
        assertEquals(DedupResult.NOT_DUPLICATE, engine.check(c))
        engine.remember(c)
        assertEquals(DedupResult.DUPLICATE, engine.check(c.copy(timestamp = 100100), samePage = true))
        assertEquals(DedupResult.POSSIBLE_DUPLICATE, engine.check(c.copy(timestamp = 160000)))
        assertEquals(DedupResult.NOT_DUPLICATE, engine.check(c.copy(timestamp = 500001)))
        assertEquals(
            DedupResult.NOT_DUPLICATE,
            engine.check(c.copy(timestamp = 160000, transactionType = "REFUND")),
        )
        assertNotEquals(BillFingerprint.of(c), BillFingerprint.of(c.copy(paymentMethod = "银行卡")))
        val ordered = c.copy(orderId = "ORDER_123456")
        assertEquals(
            BillFingerprint.of(ordered),
            BillFingerprint.of(ordered.copy(timestamp = 900000)),
        )
    }
}
