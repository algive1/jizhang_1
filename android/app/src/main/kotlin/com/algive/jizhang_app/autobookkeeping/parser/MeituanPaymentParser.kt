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

/**
 * Dedicated Meituan parser.
 *
 * Meituan mixes native, WebView and dynamically rendered order pages. The
 * parser therefore does not depend on a specific Activity name or view id, but
 * it still requires an explicit completed-payment status plus one unambiguous
 * paid amount before producing a candidate.
 */
class MeituanPaymentParser(
    private val rule: AppPaymentRule =
        AutoBookkeepingRuleRegistry.builtIn()
            .ruleForKind(PaymentParserKind.MEITUAN)
            ?: error("Missing built-in Meituan payment rule"),
) {
    private val amountPatterns = PaymentRule.DEFAULT_AMOUNT_PATTERNS

    fun parse(
        packageName: String,
        nodes: List<ScreenNode>,
        timestamp: Long,
    ): PaymentCandidate? {
        if (packageName !in rule.packageNames) return null
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        if (labels.isEmpty()) return null
        if (rule.hasRejectedStatus(labels)) return null
        if (labels.none(rule::isSuccessLabel)) return null

        val merchant = CandidateFieldExtractor.field(labels, rule.merchantKeys)
            ?: fallbackMerchant(labels)
            ?: return null
        val method = CandidateFieldExtractor
            .field(labels, rule.methodKeys)
            ?.takeIf { it.isNotBlank() }
            ?: "UNKNOWN"
        val amount = findPaidAmount(labels) ?: return null
        val (originalAmount, discountAmount) =
            CandidateFieldExtractor.amountBreakdown(labels, amount)

        return PaymentCandidate(
            amountInCents = amount,
            merchantRaw = merchant.take(80),
            merchantNormalized = MerchantNormalizer.normalize(merchant).take(80),
            paymentMethod = method.take(80),
            timestamp = timestamp,
            scene = PaymentScene(
                sourceApp = rule.sourceApp,
                scene = rule.scene,
                confidence = if (method == "UNKNOWN") .93 else .97,
            ),
            amountConfidence = 1.0,
            merchantConfidence = .92,
            sourceApp = rule.sourceApp,
            orderId = CandidateFieldExtractor.orderId(labels),
            note = CandidateFieldExtractor.note(labels),
            originalAmountInCents = originalAmount,
            discountAmountInCents = discountAmount,
            identifierSuffix =
                CandidateFieldExtractor.identifierSuffix(method, labels),
        )
    }

    fun rejectionReason(
        packageName: String,
        nodes: List<ScreenNode>,
    ): String {
        if (packageName !in rule.packageNames) return "UNSUPPORTED_PACKAGE"
        val labels = nodes.map { it.label.trim() }.filter { it.isNotBlank() }
        if (labels.isEmpty()) return "NO_VISIBLE_LABELS"
        if (rule.hasRejectedStatus(labels)) return "REJECTED_STATUS"
        if (labels.none(rule::isSuccessLabel)) return "NO_SUCCESS_MARKER"
        if (findPaidAmount(labels) == null) return "NO_UNIQUE_PAID_AMOUNT"
        if (
            CandidateFieldExtractor.field(labels, rule.merchantKeys) == null &&
            fallbackMerchant(labels) == null
        ) {
            return "NO_MERCHANT"
        }
        return "UNSUPPORTED_LAYOUT"
    }

    private fun findPaidAmount(labels: List<String>): Long? {
        val candidates = mutableListOf<Pair<Long, Int>>()
        labels.forEachIndexed { index, label ->
            val previous = labels.getOrNull(index - 1).orEmpty()
            if (rule.excludedAmountLabels.any { label.contains(it) }) {
                return@forEachIndexed
            }
            val explicit = rule.amountKeys.any { key ->
                label == key ||
                    label.startsWith("$key：") ||
                    label.startsWith("$key:") ||
                    previous == key
            }
            if (
                !explicit &&
                rule.excludedAmountLabels.any { previous.contains(it) }
            ) {
                return@forEachIndexed
            }

            val matched = amountPatterns
                .flatMap { pattern ->
                    pattern.findAll(label).map { it.groupValues[1] }.toList()
                }
                .distinct()
            val raw =
                if (
                    matched.isEmpty() &&
                    explicit &&
                    label.matches(Regex("[0-9]+(?:\\.[0-9]{1,2})?"))
                ) {
                    listOf(label)
                } else {
                    matched
                }

            raw.forEach { value ->
                val cents = value.toBigDecimalOrNull()
                    ?.multiply(BigDecimal(100))
                    ?.let { runCatching { it.longValueExact() }.getOrNull() }
                if (cents != null && cents in 1..99_999_999_999L) {
                    candidates += cents to if (explicit) 3 else 1
                }
            }
        }

        val bestScore = candidates.maxOfOrNull { it.second } ?: return null
        val winners = candidates
            .filter { it.second == bestScore }
            .map { it.first }
            .distinct()
        return winners.singleOrNull()
    }

    private fun fallbackMerchant(labels: List<String>): String? {
        val generic =
            rule.successMarkers +
                rule.rejectMarkers +
                rule.amountKeys +
                rule.fallbackMerchantBlockedLabels
        return labels.firstOrNull { label ->
            label.length in 2..80 &&
                label !in generic &&
                rule.fallbackMerchantBlockedFragments.none {
                    label.contains(it)
                } &&
                amountPatterns.none { it.containsMatchIn(label) } &&
                rule.excludedAmountLabels.none { label.contains(it) } &&
                rule.merchantKeys.none { label == it } &&
                !label.matches(Regex("[A-Za-z0-9_-]{6,}"))
        }
    }
}
