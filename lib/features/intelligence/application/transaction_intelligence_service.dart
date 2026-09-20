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
    final result = await _classifyRecord(await _find(transactionId));
    return result.$2;
  }

  Future<DuplicateDecision> inspectExisting(String transactionId) async {
    final transaction = await _find(transactionId);
    final bucket = _duplicateBucket(transaction);
    final existing = (await transactions.getAll())
        .where(
          (item) =>
              item.id != transactionId &&
              _duplicateBucket(item) == bucket,
        )
        .toList(growable: false);
    final result = await _inspectAgainst(transaction, existing);
    return result.$2;
  }

  Future<void> processSavedBatch(List<TransactionRecord> saved) async {
    if (saved.isEmpty) return;
    final savedIds = saved.map((item) => item.id).toSet();
    final buckets = <String, List<TransactionRecord>>{};
    for (final item in await transactions.getAll()) {
      if (savedIds.contains(item.id)) continue;
      buckets.putIfAbsent(_duplicateBucket(item), () => []).add(item);
    }

    for (final raw in saved) {
      final classified = await _classifyRecord(raw);
      final transaction = classified.$1;
      final bucket = _duplicateBucket(transaction);
      final inspected = await _inspectAgainst(
        transaction,
        buckets[bucket] ?? const [],
      );
      buckets.putIfAbsent(bucket, () => []).add(inspected.$1);
    }
  }

  Future<(TransactionRecord, ClassificationResult)> _classifyRecord(
    TransactionRecord transaction,
  ) async {
    if (transaction.type == TransactionType.transfer ||
        transaction.type == TransactionType.repayment ||
        transaction.type == TransactionType.adjustment ||
        transaction.type == TransactionType.assetSale) {
      // These are movement/settlement rows rather than category-driven
      // consumption or earned income. Do not create "uncertain category"
      // inbox noise for records that are valid without a category.
      return (
        transaction,
        const ClassificationResult(
          source: ClassificationSource.defaultCategory,
          confidence: 1,
        ),
      );
    }
    if (transaction.categoryId != null) {
      return (
        transaction,
        ClassificationResult(
          categoryId: transaction.categoryId,
          subcategoryId: transaction.subcategoryId,
          source: ClassificationSource.defaultCategory,
          confidence: 1,
        ),
      );
    }
    final classification = await merchantRules.classify(
      merchant: transaction.merchant,
      userId: transaction.userId,
      transactionType: transaction.type,
      bookId: transaction.bookId,
    );
    if (classification.categoryId != null) {
      final updated = await transactions.update(
        transaction.copyWith(
          categoryId: classification.categoryId,
          subcategoryId: classification.subcategoryId,
          updatedAt: DateTime.now(),
        ),
      );
      return (updated, classification);
    }
    await inbox.add(
      reason: InboxReason.uncertainCategory,
      transactionId: transaction.id,
    );
    return (transaction, classification);
  }

  Future<(TransactionRecord, DuplicateDecision)> _inspectAgainst(
    TransactionRecord transaction,
    Iterable<TransactionRecord> existing,
  ) async {
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
    if (!best.needsReview || matched == null) return (transaction, best);

    final updated = await transactions.update(
      transaction.copyWith(
        duplicateConfidence: best.confidence,
        updatedAt: DateTime.now(),
      ),
    );
    if (best.type == DuplicateDecisionType.sameEconomicEvent) {
      if (await economicEvents.areLinked(updated.id, matched.id)) {
        return (updated, best);
      }
      await economicEvents.createCandidate(updated, matched);
    }
    await inbox.add(
      reason: InboxReason.suspectedDuplicate,
      transactionId: updated.id,
      candidateTransactionId: matched.id,
      duplicateConfidence: best.confidence,
      payloadJson: jsonEncode({'reasonCode': best.reasonCode}),
    );
    return (updated, best);
  }

  String _duplicateBucket(TransactionRecord item) => [
    item.bookId,
    item.type.name,
    item.currency.toUpperCase(),
    (item.amount * 100).round(),
  ].join('|');

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
    final item = await transactions.getById(id);
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
