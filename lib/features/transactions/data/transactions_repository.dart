import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/family.dart';
import '../../../core/models/book.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/models/account_balance_effect.dart';
import '../../books/data/book_repository.dart';

abstract interface class TransactionRepository {
  Stream<List<TransactionRecord>> watchAll();
  Stream<List<TransactionRecord>> watchRecent({int limit = 10});
  Future<List<TransactionRecord>> getAll();
  Future<List<TransactionRecord>> getRecent({int limit = 10});
  Future<TransactionRecord?> getById(String id);
  Future<TransactionRecord> create(TransactionRecord transaction);
  Future<List<TransactionRecord>> createAll(
    List<TransactionRecord> transactions,
  );
  Future<TransactionRecord> update(TransactionRecord transaction);
  Future<void> softDelete(String id);
}

class DriftTransactionRepository implements TransactionRepository {
  DriftTransactionRepository(
    this._database, {
    this.bookId,
    this.accountBookId,
    this.accountBookIdForBook,
  });
  final String? bookId;
  final String? accountBookId;
  final String? Function(String bookId)? accountBookIdForBook;

  final AppDatabase _database;

  @override
  Stream<List<TransactionRecord>> watchAll() {
    return _database.transactionDao
        .watchActive(bookId: bookId)
        .asyncMap(_mapEntities);
  }

  @override
  Stream<List<TransactionRecord>> watchRecent({int limit = 10}) {
    _validateRecentLimit(limit);
    return _database.transactionDao
        .watchActive(bookId: bookId, limit: limit, onlyOccurred: true)
        .asyncMap(_mapEntities);
  }

  @override
  Future<List<TransactionRecord>> getAll() async {
    return _mapEntities(
      await _database.transactionDao.getActive(bookId: bookId),
    );
  }

  @override
  Future<List<TransactionRecord>> getRecent({int limit = 10}) async {
    _validateRecentLimit(limit);
    // The home page is a history view: scheduled/future transactions must
    // not consume its recent-items limit.
    return _mapEntities(
      await _database.transactionDao.getActive(
        bookId: bookId,
        limit: limit,
        onlyOccurred: true,
      ),
    );
  }

  @override
  Future<TransactionRecord?> getById(String id) async {
    final entity = await _database.transactionDao.findActiveById(
      id,
      bookId: bookId,
    );
    return entity == null ? null : _mapEntity(entity);
  }

  @override
  Future<TransactionRecord> create(TransactionRecord transaction) async {
    return (await createAll([transaction])).single;
  }

  @override
  Future<List<TransactionRecord>> createAll(
    List<TransactionRecord> transactions,
  ) async {
    if (transactions.isEmpty) return const [];
    for (final transaction in transactions) {
      _validate(transaction);
      _ensureBookForWrite(transaction.bookId);
    }
    final ids = transactions.map((item) => item.id).toSet();
    if (ids.length != transactions.length) {
      throw ArgumentError('Transaction IDs must be unique within a batch');
    }
    return _database.transaction(() async {
      for (final transaction in transactions) {
        if (await _database.transactionDao.findById(transaction.id) != null) {
          throw StateError('Transaction ${transaction.id} already exists');
        }
        await _ensureAccountsExist(transaction);
      }
      for (final transaction in transactions) {
        await _database.transactionDao.insertOne(_toCompanion(transaction));
        await _applyBalanceEffect(transaction, 1);
      }
      return List<TransactionRecord>.unmodifiable(transactions);
    });
  }

  @override
  Future<TransactionRecord> update(TransactionRecord transaction) async {
    _validate(transaction);
    _ensureBookForWrite(transaction.bookId);
    return _database.transaction(() async {
      final oldEntity = await _database.transactionDao.findById(transaction.id);
      if (oldEntity == null || oldEntity.deletedAt != null) {
        throw StateError('Transaction ${transaction.id} does not exist');
      }
      final old = await _mapEntity(oldEntity);
      if (old.bookId != transaction.bookId)
        throw ArgumentError('不能通过编辑移动流水到其他账本');
      await _ensureAccountsExist(transaction);
      await _applyBalanceEffect(old, -1);
      await _database.transactionDao.replaceOne(_toCompanion(transaction));
      await _applyBalanceEffect(transaction, 1);
      return transaction;
    });
  }

  @override
  Future<void> softDelete(String id) async {
    await _database.transaction(() async {
      final entity = await _database.transactionDao.findActiveById(
        id,
        bookId: bookId,
      );
      if (entity == null || entity.deletedAt != null) return;
      final existing = await _mapEntity(entity);
      final linkedTransactions =
          await (_database.select(_database.transactionEntries)..where(
                (row) =>
                    row.deletedAt.isNull() &
                    row.bookId.equals(existing.bookId) &
                    (row.relatedTransactionId.equals(id) |
                        row.originalTransactionId.equals(id)),
              ))
              .get();
      if (linkedTransactions.isNotEmpty) {
        throw StateError('该流水存在关联流水，请先撤销或处理关联退款、报销或还款');
      }
      final linkedInstallmentPlans =
          await (_database.select(_database.installmentPlanEntries)..where(
                (row) =>
                    row.bookId.equals(existing.bookId) &
                    row.originalTransactionId.equals(id),
              ))
              .get();
      if (linkedInstallmentPlans.isNotEmpty) {
        throw StateError('该流水存在分期计划，请先取消分期计划后再删除');
      }
      if (existing.type == TransactionType.repayment &&
          existing.relatedTransactionId != null) {
        final repaymentPlans =
            await (_database.select(_database.installmentPlanEntries)..where(
                  (row) =>
                      row.bookId.equals(existing.bookId) &
                      row.originalTransactionId.equals(
                        existing.relatedTransactionId!,
                      ),
                ))
                .get();
        if (repaymentPlans.isNotEmpty) {
          throw StateError('分期还款不能直接删除，请在分期计划中处理');
        }
      }
      await _applyBalanceEffect(existing, -1);
      final now = DateTime.now();
      await _database.transactionDao.replaceOne(
        _toCompanion(existing.copyWith(deletedAt: now, updatedAt: now)),
      );
    });
  }

  void _validate(TransactionRecord transaction) {
    if (!transaction.amount.isFinite ||
        (transaction.type == TransactionType.adjustment
            ? _toCents(transaction.amount) == 0
            : _toCents(transaction.amount) <= 0)) {
      throw ArgumentError.value(transaction.amount, 'amount', 'must be > 0');
    }
    if (transaction.type == TransactionType.transfer) {
      final destination = transaction.destinationAccountId;
      if (destination == null || destination == transaction.accountId) {
        throw ArgumentError(
          'A transfer requires two different source/destination accounts',
        );
      }
    }
    for (final value in [
      transaction.reimbursementAmount,
      transaction.refundAmount,
    ].whereType<double>()) {
      if (!value.isFinite || value <= 0 || value > transaction.amount) {
        throw ArgumentError('关联金额必须大于 0 且不超过原流水金额');
      }
    }
  }

  Future<void> _ensureAccountsExist(TransactionRecord transaction) async {
    for (final categoryId in [
      transaction.categoryId,
      transaction.subcategoryId,
    ].whereType<String>()) {
      final category = await _database.categoryDao.findById(categoryId);
      if (category == null || category.bookId != transaction.bookId)
        throw ArgumentError('分类与流水必须属于同一账本');
    }
    for (final relationId in [
      transaction.originalTransactionId,
      transaction.relatedTransactionId,
    ].whereType<String>()) {
      final related = await _database.transactionDao.findById(relationId);
      if (related == null ||
          related.bookId != transaction.bookId ||
          related.deletedAt != null) {
        throw ArgumentError('关联流水必须属于同一账本');
      }
    }
    final resolvedAccountBookId = accountBookIdForBook?.call(
      transaction.bookId,
    );
    final allowedAccountBooks = <String>{
      transaction.bookId,
      ?accountBookId,
      ?resolvedAccountBookId,
    };
    for (final id in [
      transaction.accountId,
      transaction.destinationAccountId,
    ].whereType<String>()) {
      final account = await _database.accountDao.findById(id);
      if (account == null) throw StateError('账户不存在');
      if (!allowedAccountBooks.contains(account.bookId))
        throw ArgumentError('账户与流水必须属于同一账本');
      if (account.currency.toUpperCase() !=
          transaction.currency.toUpperCase()) {
        throw ArgumentError('账户与流水币种必须一致；暂不支持跨币种转账');
      }
    }
  }

  Future<void> _applyBalanceEffect(
    TransactionRecord transaction,
    int direction,
  ) async {
    for (final entry in accountBalanceEffect(transaction).entries) {
      await _database.accountDao.adjustBalance(
        entry.key,
        entry.value * direction,
        transaction.updatedAt,
      );
    }
  }

  Future<List<TransactionRecord>> _mapEntities(
    List<TransactionEntity> entities,
  ) async {
    final categories = await _database.categoryDao.getAll();
    final categoriesByBookAndId = {
      for (final category in categories)
        '${category.bookId}\u0000${category.id}': category,
    };
    return entities
        .map(
          (entity) => _fromEntity(
            entity,
            entity.categoryId == null
                ? null
                : categoriesByBookAndId['${entity.bookId}\u0000${entity.categoryId}'],
          ),
        )
        .toList(growable: false);
  }

  Future<TransactionRecord> _mapEntity(TransactionEntity entity) async {
    final categories = await _database.categoryDao.getAll();
    CategoryEntity? category;
    for (final item in categories) {
      if (item.id == entity.categoryId && item.bookId == entity.bookId) {
        category = item;
        break;
      }
    }
    return _fromEntity(entity, category);
  }

  TransactionRecord _fromEntity(
    TransactionEntity entity,
    CategoryEntity? category,
  ) {
    return TransactionRecord(
      id: entity.id,
      bookId: entity.bookId,
      userId: entity.userId,
      type: TransactionType.values.byName(entity.type),
      amount: entity.amountInCents / 100,
      currency: entity.currency,
      categoryId: entity.categoryId,
      categoryName: category?.name,
      categoryIcon: category?.icon,
      subcategoryId: entity.subcategoryId,
      accountId: entity.accountId,
      destinationAccountId: entity.destinationAccountId,
      merchant: entity.merchant,
      note: entity.note,
      occurredAt: entity.occurredAt,
      createdAt: entity.createdAt,
      updatedAt: entity.updatedAt,
      deletedAt: entity.deletedAt,
      isRecurring: entity.isRecurring,
      isOneTime: entity.isOneTime,
      isLargeTransaction: entity.isLargeTransaction,
      isPlanned: entity.isPlanned,
      source: TransactionSource.values.byName(entity.source),
      aiConfidence: entity.aiConfidence,
      userCorrected: entity.userCorrected,
      syncStatus: SyncStatus.values.byName(entity.syncStatus),
      deviceId: entity.deviceId,
      originalTransactionId: entity.originalTransactionId,
      relatedTransactionId: entity.relatedTransactionId,
      reimbursementStatus: ReimbursementStatus.values.byName(
        entity.reimbursementStatus,
      ),
      reimbursementAmount: entity.reimbursementAmountInCents == null
          ? null
          : entity.reimbursementAmountInCents! / 100,
      reimbursementDate: entity.reimbursementDate,
      reimbursementNote: entity.reimbursementNote,
      refundStatus: RefundStatus.values.byName(entity.refundStatus),
      refundAmount: entity.refundAmountInCents == null
          ? null
          : entity.refundAmountInCents! / 100,
      metadataJson: entity.metadataJson,
      duplicateConfidence: entity.duplicateConfidence,
      visibility: TransactionVisibility.values.byName(entity.visibility),
      createdBy: entity.createdBy,
      updatedBy: entity.updatedBy,
      version: entity.version,
    );
  }

  TransactionEntriesCompanion _toCompanion(TransactionRecord transaction) {
    return TransactionEntriesCompanion(
      id: Value(transaction.id),
      bookId: Value(transaction.bookId),
      userId: Value(
        transaction.userId == null || transaction.userId == 'user-local'
            ? _database.currentActor
            : transaction.userId,
      ),
      type: Value(transaction.type.name),
      amountInCents: Value(_toCents(transaction.amount)),
      currency: Value(transaction.currency),
      categoryId: Value(transaction.categoryId),
      subcategoryId: Value(transaction.subcategoryId),
      accountId: Value(transaction.accountId),
      destinationAccountId: Value(transaction.destinationAccountId),
      merchant: Value(transaction.merchant),
      note: Value(transaction.note),
      occurredAt: Value(transaction.occurredAt),
      createdAt: Value(transaction.createdAt),
      updatedAt: Value(transaction.updatedAt),
      deletedAt: Value(transaction.deletedAt),
      isRecurring: Value(transaction.isRecurring),
      isOneTime: Value(transaction.isOneTime),
      isLargeTransaction: Value(transaction.isLargeTransaction),
      isPlanned: Value(transaction.isPlanned),
      source: Value(transaction.source.name),
      aiConfidence: Value(transaction.aiConfidence),
      userCorrected: Value(transaction.userCorrected),
      syncStatus: Value(transaction.syncStatus.name),
      deviceId: Value(transaction.deviceId),
      originalTransactionId: Value(transaction.originalTransactionId),
      relatedTransactionId: Value(transaction.relatedTransactionId),
      reimbursementStatus: Value(transaction.reimbursementStatus.name),
      reimbursementAmountInCents: Value(
        transaction.reimbursementAmount == null
            ? null
            : _toCents(transaction.reimbursementAmount!),
      ),
      reimbursementDate: Value(transaction.reimbursementDate),
      reimbursementNote: Value(transaction.reimbursementNote),
      refundStatus: Value(transaction.refundStatus.name),
      refundAmountInCents: Value(
        transaction.refundAmount == null
            ? null
            : _toCents(transaction.refundAmount!),
      ),
      metadataJson: Value(transaction.metadataJson),
      duplicateConfidence: Value(transaction.duplicateConfidence),
      visibility: Value(transaction.visibility.name),
      createdBy: Value(
        transaction.createdBy == null || transaction.createdBy == 'user-local'
            ? _database.currentActor
            : transaction.createdBy,
      ),
      updatedBy: Value(_database.currentActor),
      version: Value(transaction.version),
    );
  }

  int _toCents(double amount) => (amount * 100).round();

  void _validateRecentLimit(int limit) {
    if (limit < 1) throw ArgumentError.value(limit, 'limit', 'must be > 0');
  }

  void _ensureBookForWrite(String transactionBookId) {
    if (bookId != null && transactionBookId != bookId) {
      throw ArgumentError('流水必须属于当前账本');
    }
  }
}

final transactionRepositoryProvider = Provider<TransactionRepository>((ref) {
  return DriftTransactionRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
    accountBookId: ref.watch(activeBookProvider)?.assetBookId,
  );
});

final transactionsByBookProvider =
    StreamProvider.family<List<TransactionRecord>, String>((
      ref,
      bookId,
    ) async* {
      await ref.watch(databaseBootstrapProvider.future);
      yield* DriftTransactionRepository(
        ref.watch(databaseProvider),
        bookId: bookId,
        accountBookId: (ref.watch(booksProvider).value ?? const <LedgerBook>[])
            .where((book) => book.id == bookId)
            .firstOrNull
            ?.assetBookId,
      ).watchAll();
    });

final transactionsProvider = StreamProvider<List<TransactionRecord>>((
  ref,
) async* {
  await ref.watch(databaseBootstrapProvider.future);
  final bookId = ref.watch(activeBookIdProvider);
  yield* DriftTransactionRepository(
    ref.watch(databaseProvider),
    bookId: bookId,
    accountBookId: ref.watch(activeBookProvider)?.assetBookId,
  ).watchAll();
});

/// All active transactions visible to the current user, across every ledger.
///
/// Most pages intentionally scope their data to [activeBookIdProvider]. The
/// consumption calendar is a cross-ledger view, so it uses this provider
/// instead of changing the global active ledger.
final allTransactionsProvider = StreamProvider<List<TransactionRecord>>((
  ref,
) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* DriftTransactionRepository(ref.watch(databaseProvider)).watchAll();
});

final transactionControllerProvider = Provider<TransactionController>((ref) {
  return TransactionController(ref.watch(transactionRepositoryProvider));
});

class TransactionController {
  TransactionController(this._repository);

  final TransactionRepository _repository;

  Future<TransactionRecord> add(TransactionRecord transaction) {
    return _repository.create(transaction);
  }

  Future<TransactionRecord> update(TransactionRecord transaction) {
    return _repository.update(transaction);
  }

  Future<void> delete(String id) => _repository.softDelete(id);
}
