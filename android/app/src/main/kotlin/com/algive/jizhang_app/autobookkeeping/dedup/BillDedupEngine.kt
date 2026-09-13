package com.algive.jizhang_app.autobookkeeping.dedup

import com.algive.jizhang_app.autobookkeeping.model.PaymentCandidate
import java.security.MessageDigest
import kotlin.math.abs

enum class DedupResult { NOT_DUPLICATE, POSSIBLE_DUPLICATE, DUPLICATE }
object BillFingerprint {
    fun of(c: PaymentCandidate): String = hash("${identity(c)}|${c.timestamp / 60000}")
    fun identity(c: PaymentCandidate): String = listOf(c.sourceApp, c.amountInCents, c.merchantNormalized, c.paymentMethod, c.transactionType).joinToString("|")
    fun hash(value: String): String = MessageDigest.getInstance("SHA-256").digest(value.toByteArray()).joinToString("") { "%02x".format(it) }
}
class BillDedupEngine {
    private val recent = ArrayDeque<PaymentCandidate>()
    fun check(candidate: PaymentCandidate, samePage: Boolean = false): DedupResult {
        recent.removeAll { abs(candidate.timestamp - it.timestamp) > 300000 }
        val exact = recent.any { BillFingerprint.identity(it) == BillFingerprint.identity(candidate) }
        if (samePage && exact) return DedupResult.DUPLICATE
        if (recent.any { it.amountInCents == candidate.amountInCents && it.merchantNormalized == candidate.merchantNormalized }) return DedupResult.POSSIBLE_DUPLICATE
        return DedupResult.NOT_DUPLICATE
    }
    fun remember(candidate: PaymentCandidate) { recent.addLast(candidate); while (recent.size > 100) recent.removeFirst() }
}
