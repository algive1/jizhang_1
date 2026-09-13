import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/transaction_intelligence.dart';
import '../../../core/models/transaction_record.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/bill_inbox_repository.dart';
import '../data/economic_event_repository.dart';
import '../data/merchant_rule_repository.dart';
import '../domain/transaction_fingerprint_service.dart';

class TransactionIntelligenceService {
  const TransactionIntelligenceService({
    required this.transactions,
    required this.merchantRules,
    required this.inbox,
    required this.economicEvents,
    required this.fingerprints,
  });

  final TransactionRepository transactions;
  final MerchantRuleRepository merchantRules;
  final BillInboxRepository inbox;
  final EconomicEventRepository economicEvents;
  final TransactionFingerprintService fingerprints;

  Future<ClassificationResult> classifyAndApply(String transactionId) async {
    final transaction = await _find(transactionId);
    if (transaction.type == TransactionType.transfer ||
        transaction.type == TransactionType.adjustment) {
      // Account movements/corrections do not need a spending category or an
      // uncertain-category inbox item.
      return const ClassificationResult(
        source: ClassificationSource.defaultCategory,
        confidence: 1,
      );
    }
    if (transaction.categoryId != null) {
      return ClassificationResult(
        categoryId: transaction.categoryId,
        subcategoryId: transaction.subcategoryId,
        source: ClassificationSource.defaultCategory,
        confidence: 1,
      );
    }
    final classification = await merchantRules.classify(
      merchant: transaction.merchant,
      userId: transaction.userId,
      transactionType: transaction.type,
      bookId: transaction.bookId,
    );
    if (classification.categoryId != null) {
      await transactions.update(
        transaction.copyWith(
          categoryId: classification.categoryId,
          subcategoryId: classification.subcategoryId,
          updatedAt: DateTime.now(),
        ),
      );
    } else {
      await inbox.add(
        reason: InboxReason.uncertainCategory,
        transactionId: transaction.id,
      );
    }
    return classification;
  }

  Future<DuplicateDecision> inspectExisting(String transactionId) async {
    var transaction = await _find(transactionId);
    final existing = (await transactions.getAll())
        .where(
          (item) =>
              item.id != transactionId && item.bookId == transaction.bookId,
        )
        .toList(growable: false);
    var best = const DuplicateDecision(
      type: DuplicateDecisionType.unrelated,
      confidence: 0,
      reasonCode: 'no_candidate',
    );
    TransactionRecord? matched;
    for (final other in existing) {
      final decision = fingerprints.compare(transaction, other);
      if (decision.confidence > best.confidence) {
        best = decision;
        matched = other;
      }
    }
    if (!best.needsReview || matched == null) return best;

    transaction = transaction.copyWith(
      duplicateConfidence: best.confidence,
      updatedAt: DateTime.now(),
    );
    await transactions.update(transaction);
    if (best.type == DuplicateDecisionType.sameEconomicEvent) {
      await economicEvents.createCandidate(transaction, matched);
    }
    await inbox.add(
      reason: InboxReason.suspectedDuplicate,
      transactionId: transaction.id,
      candidateTransactionId: matched.id,
      duplicateConfidence: best.confidence,
      payloadJson: jsonEncode({'reasonCode': best.reasonCode}),
    );
    return best;
  }

  Future<void> queueMissingAccount({required String sourcePayloadJson}) {
    return inbox.add(
      reason: InboxReason.missingAccount,
      payloadJson: sourcePayloadJson,
    );
  }

  Future<void> confirmEconomicEvent(String transactionId) {
    return economicEvents.resolveCandidateForTransaction(
      transactionId,
      status: EconomicEventStatus.confirmed,
    );
  }

  Future<TransactionRecord> _find(String id) async {
    final item = (await transactions.getAll())
        .where((transaction) => transaction.id == id)
        .firstOrNull;
    if (item == null) throw StateError('Transaction $id does not exist');
    return item;
  }
}

final transactionFingerprintServiceProvider = Provider(
  (ref) => const TransactionFingerprintService(),
);

final economicEventRepositoryProvider = Provider((ref) {
  return EconomicEventRepository(
    ref.watch(databaseProvider),
    ref.watch(transactionFingerprintServiceProvider),
  );
});

final transactionIntelligenceServiceProvider = Provider((ref) {
  return TransactionIntelligenceService(
    transactions: DriftTransactionRepository(ref.watch(databaseProvider)),
    merchantRules: ref.watch(merchantRuleRepositoryProvider),
    inbox: ref.watch(allBookBillInboxRepositoryProvider),
    economicEvents: ref.watch(economicEventRepositoryProvider),
    fingerprints: ref.watch(transactionFingerprintServiceProvider),
  );
});
