package com.algive.jizhang_app.autobookkeeping.parser

import com.algive.jizhang_app.autobookkeeping.merchant.MerchantNormalizer
import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import com.algive.jizhang_app.autobookkeeping.model.PaymentScene
import com.algive.jizhang_app.autobookkeeping.model.ScreenNode
import com.algive.jizhang_app.autobookkeeping.rules.AppPaymentRule
import com.algive.jizhang_app.autobookkeeping.rules.AutoBookkeepingRuleRegistry
import com.algive.jizhang_app.autobookkeeping.rules.PaymentParserKind
import com.algive.jizhang_app.autobookkeeping.rules.PaymentRule
import java.math.BigDecimal

/** Conservative parser for payment apps whose accessibility layouts vary. */
class PaymentAppParser(
    private val registry: AutoBookkeepingRuleRegistry =
        AutoBookkeepingRuleRegistry.builtIn(),
) {
    private val amountPatterns = PaymentRule.DEFAULT_AMOUNT_PATTERNS

    fun parse(
        packageName: String,
        nodes: List<ScreenNode>,
        timestamp: Long,
    ): PaymentCandidate? {
        val rule = registry.ruleFor(packageName)
            ?.takeIf { it.parserKind == PaymentParserKind.GENERIC }
            ?: return null
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        if (labels.none(rule::isSuccessLabel)) return null
        if (rule.hasRejectedStatus(labels)) return null

        val merchant =
            (CandidateFieldExtractor.field(labels, rule.merchantKeys)
                ?: fallbackMerchant(labels, rule))
                ?.takeIf { value ->
                    value.isNotBlank() &&
                        value !in rule.successMarkers &&
                        rule.amountKeys.none { value.contains(it) }
                }
                ?: return null
        val method = CandidateFieldExtractor
            .field(labels, rule.methodKeys)
            ?.takeIf { it.isNotBlank() }
            ?: "UNKNOWN"
        val amounts = mutableListOf<Pair<Long, Int>>()
        labels.forEachIndexed { index, label ->
            if (rule.excludedAmountLabels.any { label.contains(it) }) {
                return@forEachIndexed
            }
            val previous = labels.getOrNull(index - 1).orEmpty()
            val explicit = rule.amountKeys.any {
                label.startsWith(it) || previous == it
            }
            if (
                !explicit &&
                rule.excludedAmountLabels.any { previous.contains(it) }
            ) {
                return@forEachIndexed
            }
            val matches = amountPatterns.flatMap { pattern ->
                pattern.findAll(label).map { it.groupValues[1] }.toList()
            }.distinct()
            val raw =
                if (
                    matches.isEmpty() &&
                    explicit &&
                    label.matches(Regex("[0-9]+(?:\\.[0-9]{1,2})?"))
                ) {
                    listOf(label)
                } else {
                    matches
                }
            raw.forEach { value ->
                val cents = value.toBigDecimalOrNull()
                    ?.multiply(BigDecimal(100))
                    ?.let { runCatching { it.longValueExact() }.getOrNull() }
                if (cents != null && cents in 1..99_999_999_999L) {
                    amounts += cents to if (explicit) 3 else 1
                }
            }
        }
        val best = amounts.maxOfOrNull { it.second } ?: return null
        val winners = amounts
            .filter { it.second == best }
            .map { it.first }
            .distinct()
        if (winners.size != 1) return null

        val paidAmount = winners.single()
        val (originalAmount, discountAmount) =
            CandidateFieldExtractor.amountBreakdown(labels, paidAmount)
        return PaymentCandidate(
            amountInCents = paidAmount,
            merchantRaw = merchant.take(80),
            merchantNormalized = MerchantNormalizer.normalize(merchant),
            paymentMethod = method.take(80),
            timestamp = timestamp,
            scene = PaymentScene(
                sourceApp = rule.sourceApp,
                scene = rule.scene,
                confidence = if (method != "UNKNOWN") .95 else .88,
            ),
            amountConfidence = if (best == 3) 1.0 else .9,
            merchantConfidence = .9,
            sourceApp = rule.sourceApp,
            orderId = CandidateFieldExtractor.orderId(labels),
            note = CandidateFieldExtractor.note(labels),
            originalAmountInCents = originalAmount,
            discountAmountInCents = discountAmount,
            identifierSuffix =
                CandidateFieldExtractor.identifierSuffix(method, labels),
        )
    }

    private fun fallbackMerchant(
        labels: List<String>,
        rule: AppPaymentRule,
    ): String? = labels.firstOrNull { label ->
        label.length in 2..80 &&
            label !in rule.successMarkers &&
            label !in rule.amountKeys &&
            label !in rule.excludedAmountLabels &&
            label !in rule.fallbackMerchantBlockedLabels &&
            rule.fallbackMerchantBlockedFragments.none { label.contains(it) } &&
            amountPatterns.none { it.containsMatchIn(label) } &&
            rule.methodKeys.none { key ->
                label == key || label.contains(key)
            }
    }
}
