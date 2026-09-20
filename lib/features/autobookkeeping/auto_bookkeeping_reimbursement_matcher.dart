import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/database_provider.dart';
import '../../core/models/transaction_record.dart';
import '../books/data/book_repository.dart';
import '../transactions/data/transactions_repository.dart';
import 'auto_bookkeeping_pending.dart';

class AutoBookkeepingReimbursementMatcher {
  AutoBookkeepingReimbursementMatcher(this._transactions);

  final TransactionRepository _transactions;

  Future<TransactionRecord?> findOriginal({
    required PendingAutoBookkeepingCandidate candidate,
  }) async {
    if (candidate.transactionType != 'REIMBURSEMENT') return null;
    final receivedCents = candidate.amountInCents;
    final receivedAt = candidate.timestamp;

    final exact = (await _transactions.getAll())
        .where((item) => _eligible(item, receivedAt))
        .where((item) => _expectedRemainingCents(item) == receivedCents)
        .toList(growable: false);

    return exact.length == 1 ? exact.single : null;
  }

  bool _eligible(TransactionRecord item, DateTime receivedAt) {
    if (!item.isExpense) return false;
    if (item.reimbursementStatus != ReimbursementStatus.pending &&
        item.reimbursementStatus != ReimbursementStatus.partial) {
      return false;
    }
    if (item.occurredAt.isAfter(receivedAt)) return false;
    return receivedAt.difference(item.occurredAt) <= const Duration(days: 180);
  }

  int _expectedRemainingCents(TransactionRecord item) {
    final total = (item.amount * 100).round();
    return switch (item.reimbursementStatus) {
      ReimbursementStatus.partial =>
        (total - ((item.reimbursementAmount ?? 0) * 100).round())
            .clamp(0, total),
      ReimbursementStatus.pending =>
        ((item.reimbursementAmount ?? item.amount) * 100).round()
            .clamp(0, total),
      _ => 0,
    };
  }
}

final autoBookkeepingReimbursementMatcherProvider = Provider.family<
  AutoBookkeepingReimbursementMatcher,
  String
>((ref, bookId) {
  final book = (ref.watch(booksProvider).value ?? const [])
      .where((item) => item.id == bookId)
      .firstOrNull;
  return AutoBookkeepingReimbursementMatcher(
    DriftTransactionRepository(
      ref.watch(databaseProvider),
      bookId: bookId,
      accountBookId: book?.assetBookId,
    ),
  );
});
