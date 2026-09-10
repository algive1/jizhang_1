import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../books/data/book_repository.dart';
import '../../../core/models/transaction_intelligence.dart';

abstract interface class BillInboxRepository {
  Stream<List<BillInboxItem>> watchPending();
  Future<List<BillInboxItem>> getPending();
  Future<BillInboxItem> add({
    required InboxReason reason,
    String? transactionId,
    String? candidateTransactionId,
    double? duplicateConfidence,
    String? payloadJson,
  });
  Future<void> resolve(String id, InboxStatus status);
}

class DriftBillInboxRepository implements BillInboxRepository {
  const DriftBillInboxRepository(
    this._database, {
    this.bookId = 'book-personal',
  });
  final String bookId;

  final AppDatabase _database;

  @override
  Stream<List<BillInboxItem>> watchPending() {
    return (_database.select(_database.inboxItemEntries)
          ..where((r) => r.bookId.equals(bookId) & r.status.equals('pending'))
          ..orderBy([(r) => OrderingTerm.desc(r.createdAt)]))
        .watch()
        .map((rows) => rows.map(_fromEntity).toList(growable: false));
  }

  @override
  Future<List<BillInboxItem>> getPending() async {
    return (await (_database.select(_database.inboxItemEntries)..where(
              (r) => r.bookId.equals(bookId) & r.status.equals('pending'),
            ))
            .get())
        .map(_fromEntity)
        .toList(growable: false);
  }

  @override
  Future<BillInboxItem> add({
    required InboxReason reason,
    String? transactionId,
    String? candidateTransactionId,
    double? duplicateConfidence,
    String? payloadJson,
  }) async {
    final now = DateTime.now();
    final referencedTransaction = transactionId == null
        ? null
        : await _database.transactionDao.findById(transactionId);
    if (transactionId != null &&
        (referencedTransaction == null ||
            referencedTransaction.bookId != bookId)) {
      throw StateError('收件箱流水必须属于当前账本');
    }
    final item = BillInboxItem(
      id: 'inbox-${now.microsecondsSinceEpoch}',
      transactionId: transactionId,
      candidateTransactionId: candidateTransactionId,
      reason: reason,
      status: InboxStatus.pending,
      duplicateConfidence: duplicateConfidence,
      payloadJson: payloadJson,
      createdAt: now,
    );
    await _database.intelligenceDao.upsertInboxItem(
      InboxItemEntriesCompanion.insert(
        id: item.id,
        bookId: Value(referencedTransaction?.bookId ?? bookId),
        transactionId: Value(transactionId),
        candidateTransactionId: Value(candidateTransactionId),
        reason: reason.name,
        duplicateConfidence: Value(duplicateConfidence),
        payloadJson: Value(payloadJson),
        createdAt: now,
      ),
    );
    return item;
  }

  @override
  Future<void> resolve(String id, InboxStatus status) async {
    if (status == InboxStatus.pending) {
      throw ArgumentError('Resolving requires accepted or dismissed status');
    }
    final existing = await _database.intelligenceDao.findInboxItem(id);
    if (existing == null || existing.bookId != bookId)
      throw StateError('Inbox item $id does not exist');
    await _database.intelligenceDao.upsertInboxItem(
      InboxItemEntriesCompanion(
        id: Value(existing.id),
        bookId: Value(existing.bookId),
        transactionId: Value(existing.transactionId),
        candidateTransactionId: Value(existing.candidateTransactionId),
        reason: Value(existing.reason),
        status: Value(status.name),
        duplicateConfidence: Value(existing.duplicateConfidence),
        payloadJson: Value(existing.payloadJson),
        createdAt: Value(existing.createdAt),
        resolvedAt: Value(DateTime.now()),
      ),
    );
  }

  BillInboxItem _fromEntity(InboxItemEntity entity) {
    return BillInboxItem(
      id: entity.id,
      transactionId: entity.transactionId,
      candidateTransactionId: entity.candidateTransactionId,
      reason: InboxReason.values.byName(entity.reason),
      status: InboxStatus.values.byName(entity.status),
      duplicateConfidence: entity.duplicateConfidence,
      payloadJson: entity.payloadJson,
      createdAt: entity.createdAt,
      resolvedAt: entity.resolvedAt,
    );
  }
}

final billInboxRepositoryProvider = Provider<BillInboxRepository>((ref) {
  return DriftBillInboxRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

final pendingInboxProvider = StreamProvider<List<BillInboxItem>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref.watch(billInboxRepositoryProvider).watchPending();
});
