import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/utils/entity_id.dart';
import '../../books/data/book_repository.dart';
import '../data/transactions_repository.dart';

/// Atomically writes a refund receipt and updates the original expense.
class RefundService {
  RefundService(this._database, {required this.bookId});

  final AppDatabase _database;
  final String bookId;

  DriftTransactionRepository _repository(String accountBookId) =>
      DriftTransactionRepository(
        _database,
        bookId: bookId,
        accountBookId: accountBookId,
      );

  Future<TransactionRecord> register({
    required TransactionRecord original,
    required double amount,
    required Category category,
    DateTime? occurredAt,
  }) async {
    if (original.bookId != bookId) throw ArgumentError('流水不属于当前账本');
    if (!original.isExpense) throw ArgumentError('只有消费流水可以登记退款');
    final previous = original.refundAmount ?? 0;
    final remaining = original.amount - previous;
    if (!amount.isFinite || amount <= 0 || amount > remaining) {
      throw ArgumentError('退款金额不能超过剩余可退金额');
    }
    if (category.type != CategoryType.income) {
      throw ArgumentError('退款必须使用收入分类');
    }
    final account = await _database.accountDao.findById(original.accountId);
    if (account == null || account.isArchived) {
      throw StateError('退款账户不存在或已归档');
    }
    if (account.currency.toUpperCase() != original.currency.toUpperCase()) {
      throw ArgumentError('退款账户与原消费币种必须一致');
    }
    final now = occurredAt ?? DateTime.now();
    final cumulative = previous + amount;
    final refund = TransactionRecord(
      id: 'refund-${original.id}-${newEntityId()}',
      bookId: bookId,
      userId: _database.currentActor,
      type: TransactionType.refund,
      amount: amount,
      currency: account.currency,
      accountId: account.id,
      categoryId: category.id,
      categoryName: category.name,
      merchant: original.merchant,
      note: '退款：${original.displayTitle}',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      relatedTransactionId: original.id,
      source: TransactionSource.manual,
      createdBy: _database.currentActor,
      updatedBy: _database.currentActor,
    );
    final updatedOriginal = original.copyWith(
      refundStatus: cumulative >= original.amount
          ? RefundStatus.refunded
          : RefundStatus.partial,
      refundAmount: cumulative,
      updatedAt: now,
    );
    await _database.transaction(() async {
      final repository = _repository(account.bookId);
      await repository.create(refund);
      await repository.update(updatedOriginal);
    });
    return refund;
  }

  /// Edits a refund receipt and recalculates the original expense's
  /// cumulative refund state in the same transaction.
  Future<TransactionRecord> updateRefund({
    required TransactionRecord refund,
    required double amount,
    DateTime? occurredAt,
  }) async {
    final originalId = refund.relatedTransactionId;
    if (refund.bookId != bookId ||
        refund.type != TransactionType.refund ||
        originalId == null) {
      throw ArgumentError('只能编辑已关联原消费的退款流水');
    }
    final readRepository = await _readRepository();
    final original = await readRepository.getById(originalId);
    final current = await readRepository.getById(refund.id);
    if (original == null ||
        current == null ||
        current.type != refund.type ||
        current.relatedTransactionId != original.id) {
      throw StateError('退款或原消费不存在');
    }
    final all = await readRepository.getAll();
    final otherRefundCents = all
        .where(
          (item) =>
              item.type == TransactionType.refund &&
              item.relatedTransactionId == original.id &&
              item.id != refund.id,
        )
        .fold<int>(0, (sum, item) => sum + _toCents(item.amount));
    if (!amount.isFinite) throw ArgumentError('退款金额无效');
    final amountCents = _toCents(amount);
    final originalCents = _toCents(original.amount);
    if (amountCents <= 0 || otherRefundCents + amountCents > originalCents) {
      throw ArgumentError('退款金额不能超过原消费剩余可退金额');
    }
    final account = await _database.accountDao.findById(refund.accountId);
    if (account == null || account.isArchived) {
      throw StateError('退款账户不存在或已归档');
    }
    final repository = _repository(account.bookId);
    final now = occurredAt ?? DateTime.now();
    final updatedRefund = current.copyWith(
      amount: amountCents / 100,
      occurredAt: now,
      updatedAt: now,
    );
    final updatedOriginal = _withRefundState(
      original,
      cumulativeCents: otherRefundCents + amountCents,
      updatedAt: now,
    );
    await _database.transaction(() async {
      await repository.update(updatedRefund);
      await repository.update(updatedOriginal);
    });
    return updatedRefund;
  }

  /// Voids a refund receipt while restoring the original refund status and
  /// reversing the receipt account balance through the normal repository.
  Future<void> voidRefund(TransactionRecord refund) async {
    final originalId = refund.relatedTransactionId;
    if (refund.bookId != bookId ||
        refund.type != TransactionType.refund ||
        originalId == null) {
      throw ArgumentError('只能撤销已关联原消费的退款流水');
    }
    final readRepository = await _readRepository();
    final original = await readRepository.getById(originalId);
    final current = await readRepository.getById(refund.id);
    if (original == null ||
        current == null ||
        current.type != TransactionType.refund ||
        current.relatedTransactionId != original.id) {
      throw StateError('退款或原消费不存在');
    }
    final all = await readRepository.getAll();
    final account = await _database.accountDao.findById(refund.accountId);
    if (account == null || account.isArchived) {
      throw StateError('退款账户不存在或已归档');
    }
    final repository = _repository(account.bookId);
    final remainingCents = all
        .where(
          (item) =>
              item.type == TransactionType.refund &&
              item.relatedTransactionId == original.id &&
              item.id != refund.id,
        )
        .fold<int>(0, (sum, item) => sum + _toCents(item.amount));
    final now = DateTime.now();
    await _database.transaction(() async {
      await repository.softDelete(current.id);
      await repository.update(
        _withRefundState(
          original,
          cumulativeCents: remainingCents,
          updatedAt: now,
        ),
      );
    });
  }

  TransactionRecord _withRefundState(
    TransactionRecord original, {
    required int cumulativeCents,
    required DateTime updatedAt,
  }) {
    if (cumulativeCents <= 0) {
      return original.copyWith(
        refundStatus: RefundStatus.none,
        clearRefundAmount: true,
        updatedAt: updatedAt,
      );
    }
    return original.copyWith(
      refundStatus: cumulativeCents >= _toCents(original.amount)
          ? RefundStatus.refunded
          : RefundStatus.partial,
      refundAmount: cumulativeCents / 100,
      updatedAt: updatedAt,
    );
  }

  int _toCents(double amount) => (amount * 100).round();

  Future<DriftTransactionRepository> _readRepository() async {
    final book = await _database.familyDao.findBook(bookId);
    return _repository(book?.assetSourceBookId ?? bookId);
  }
}

final refundServiceProvider = Provider<RefundService>((ref) {
  return RefundService(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});
