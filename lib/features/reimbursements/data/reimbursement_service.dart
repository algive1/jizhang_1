import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/utils/entity_id.dart';
import '../../books/data/book_repository.dart';
import '../../transactions/data/transactions_repository.dart';

/// Commits a reimbursement payment and the source status in one database
/// transaction. The payment remains a canonical transaction row linked to the
/// source through [TransactionRecord.relatedTransactionId].
class ReimbursementService {
  ReimbursementService(this._database, {required this.bookId});

  final AppDatabase _database;
  final String bookId;

  Future<TransactionRecord> markReimbursed({
    required TransactionRecord original,
    required Account account,
    required Category category,
    DateTime? occurredAt,
  }) async {
    if (original.bookId != bookId) throw ArgumentError('流水不属于当前账本');
    if (!original.isExpense) throw ArgumentError('只有消费流水可以登记报销');
    if (original.reimbursementStatus == ReimbursementStatus.reimbursed) {
      throw StateError('该流水已经完成报销');
    }
    if (category.type != CategoryType.income) {
      throw ArgumentError('报销回款必须使用收入分类');
    }
    if (account.isArchived ||
        account.currency.toUpperCase() != original.currency.toUpperCase()) {
      throw ArgumentError('报销到账账户不可用或币种不一致');
    }
    final previousPaid =
        original.reimbursementStatus == ReimbursementStatus.partial
        ? original.reimbursementAmount ?? 0
        : 0;
    final requested = original.reimbursementAmount ?? original.amount;
    final paid = original.reimbursementStatus == ReimbursementStatus.partial
        ? (original.amount - previousPaid).clamp(0, original.amount).toDouble()
        : requested;
    if (paid <= 0) throw StateError('没有可报销的剩余金额');
    final now = occurredAt ?? DateTime.now();
    final cumulative = previousPaid + paid;
    final transaction = TransactionRecord(
      id: 'reimbursement-${original.id}-${newEntityId()}',
      bookId: bookId,
      userId: _database.currentActor,
      type: TransactionType.reimbursement,
      amount: paid,
      currency: account.currency,
      accountId: account.id,
      categoryId: category.id,
      categoryName: category.name,
      merchant: original.merchant,
      note: '报销：${original.displayTitle}',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      relatedTransactionId: original.id,
      source: TransactionSource.manual,
      createdBy: _database.currentActor,
      updatedBy: _database.currentActor,
    );
    final updatedOriginal = original.copyWith(
      reimbursementStatus: ReimbursementStatus.reimbursed,
      reimbursementAmount: cumulative,
      reimbursementDate: now,
      updatedAt: now,
    );
    await _database.transaction(() async {
      final repository = DriftTransactionRepository(
        _database,
        bookId: bookId,
        accountBookId: account.bookId,
      );
      await repository.create(transaction);
      await repository.update(updatedOriginal);
    });
    return transaction;
  }

  Future<TransactionRecord> registerDetectedPayment({
    required TransactionRecord original,
    required Account account,
    required Category category,
    required double amount,
    DateTime? occurredAt,
    String? transactionId,
    String? note,
    String? metadataJson,
    TransactionSource source = TransactionSource.auto,
  }) async {
    if (original.bookId != bookId) throw ArgumentError('流水不属于当前账本');
    if (!original.isExpense) throw ArgumentError('只有消费流水可以登记报销');
    if (original.reimbursementStatus == ReimbursementStatus.reimbursed) {
      throw StateError('该流水已经完成报销');
    }
    if (category.type != CategoryType.income) {
      throw ArgumentError('报销回款必须使用收入分类');
    }
    if (account.isArchived ||
        account.currency.toUpperCase() != original.currency.toUpperCase()) {
      throw ArgumentError('报销到账账户不可用或币种不一致');
    }
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError('报销到账金额必须大于 0');
    }

    final repository = await _repository(bookId);
    final linkedPaidCents = (await repository.getAll())
        .where(
          (item) =>
              item.type == TransactionType.reimbursement &&
              item.relatedTransactionId == original.id,
        )
        .fold<int>(0, (sum, item) => sum + _toCents(item.amount));
    final originalCents = _toCents(original.amount);
    final incomingCents = _toCents(amount);
    if (linkedPaidCents + incomingCents > originalCents) {
      throw ArgumentError('报销到账金额不能超过原消费剩余可报金额');
    }

    final now = occurredAt ?? DateTime.now();
    final cumulativeCents = linkedPaidCents + incomingCents;
    final transaction = TransactionRecord(
      id:
          transactionId ??
          'reimbursement-${original.id}-${newEntityId()}',
      bookId: bookId,
      userId: _database.currentActor,
      type: TransactionType.reimbursement,
      amount: incomingCents / 100,
      currency: account.currency,
      accountId: account.id,
      categoryId: category.id,
      categoryName: category.name,
      merchant: original.merchant,
      note: note ?? '报销：${original.displayTitle}',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      relatedTransactionId: original.id,
      source: source,
      metadataJson: metadataJson,
      createdBy: _database.currentActor,
      updatedBy: _database.currentActor,
    );
    final updatedOriginal = _withReimbursementState(
      original,
      cumulativeCents: cumulativeCents,
      updatedAt: now,
    );
    await _database.transaction(() async {
      final writeRepository = DriftTransactionRepository(
        _database,
        bookId: bookId,
        accountBookId: account.bookId,
      );
      await writeRepository.create(transaction);
      await writeRepository.update(updatedOriginal);
    });
    return transaction;
  }

  /// Edits a reimbursement receipt and recalculates the source status in the
  /// same transaction. The source expense remains the canonical record.
  Future<TransactionRecord> updatePayment({
    required TransactionRecord payment,
    required double amount,
    DateTime? occurredAt,
  }) async {
    final originalId = payment.relatedTransactionId;
    if (payment.bookId != bookId ||
        payment.type != TransactionType.reimbursement ||
        originalId == null) {
      throw ArgumentError('只能编辑已关联原消费的报销回款');
    }
    final readRepository = await _repository(bookId);
    final original = await readRepository.getById(originalId);
    final current = await readRepository.getById(payment.id);
    if (original == null ||
        current == null ||
        current.type != TransactionType.reimbursement ||
        current.relatedTransactionId != original.id) {
      throw StateError('报销回款或原消费不存在');
    }
    final all = await readRepository.getAll();
    final otherPaidCents = all
        .where(
          (item) =>
              item.type == TransactionType.reimbursement &&
              item.relatedTransactionId == original.id &&
              item.id != payment.id,
        )
        .fold<int>(0, (sum, item) => sum + _toCents(item.amount));
    if (!amount.isFinite) throw ArgumentError('报销金额无效');
    final amountCents = _toCents(amount);
    final originalCents = _toCents(original.amount);
    if (amountCents <= 0 || otherPaidCents + amountCents > originalCents) {
      throw ArgumentError('报销金额不能超过原消费剩余可报金额');
    }
    final account = await _database.accountDao.findById(payment.accountId);
    if (account == null || account.isArchived) {
      throw StateError('报销到账账户不存在或已归档');
    }
    final repository = await _repository(bookId);
    final now = occurredAt ?? DateTime.now();
    final updatedPayment = current.copyWith(
      amount: amountCents / 100,
      occurredAt: now,
      updatedAt: now,
    );
    final updatedOriginal = _withReimbursementState(
      original,
      cumulativeCents: otherPaidCents + amountCents,
      updatedAt: now,
    );
    await _database.transaction(() async {
      await repository.update(updatedPayment);
      await repository.update(updatedOriginal);
    });
    return updatedPayment;
  }

  /// Voids a reimbursement receipt while restoring the source lifecycle and
  /// reversing the receipt account balance through the normal repository.
  Future<void> voidPayment(TransactionRecord payment) async {
    final originalId = payment.relatedTransactionId;
    if (payment.bookId != bookId ||
        payment.type != TransactionType.reimbursement ||
        originalId == null) {
      throw ArgumentError('只能撤销已关联原消费的报销回款');
    }
    final readRepository = await _repository(bookId);
    final original = await readRepository.getById(originalId);
    final current = await readRepository.getById(payment.id);
    if (original == null ||
        current == null ||
        current.type != TransactionType.reimbursement ||
        current.relatedTransactionId != original.id) {
      throw StateError('报销回款或原消费不存在');
    }
    final all = await readRepository.getAll();
    final account = await _database.accountDao.findById(payment.accountId);
    if (account == null || account.isArchived) {
      throw StateError('报销到账账户不存在或已归档');
    }
    final remainingCents = all
        .where(
          (item) =>
              item.type == TransactionType.reimbursement &&
              item.relatedTransactionId == original.id &&
              item.id != payment.id,
        )
        .fold<int>(0, (sum, item) => sum + _toCents(item.amount));
    final now = DateTime.now();
    final repository = await _repository(bookId);
    await _database.transaction(() async {
      await repository.softDelete(current.id);
      await repository.update(
        _withReimbursementState(
          original,
          cumulativeCents: remainingCents,
          updatedAt: now,
        ),
      );
    });
  }

  TransactionRecord _withReimbursementState(
    TransactionRecord original, {
    required int cumulativeCents,
    required DateTime updatedAt,
  }) {
    if (cumulativeCents <= 0) {
      return original.copyWith(
        reimbursementStatus: ReimbursementStatus.none,
        reimbursementAmount: null,
        reimbursementDate: null,
        reimbursementNote: null,
        updatedAt: updatedAt,
      );
    }
    return original.copyWith(
      reimbursementStatus: cumulativeCents >= _toCents(original.amount)
          ? ReimbursementStatus.reimbursed
          : ReimbursementStatus.partial,
      reimbursementAmount: cumulativeCents / 100,
      reimbursementDate: updatedAt,
      updatedAt: updatedAt,
    );
  }

  int _toCents(double amount) => (amount * 100).round();

  Future<DriftTransactionRepository> _repository(String targetBookId) async {
    final book = await _database.familyDao.findBook(targetBookId);
    return DriftTransactionRepository(
      _database,
      bookId: targetBookId,
      accountBookId: book?.assetSourceBookId,
    );
  }
}

final reimbursementServiceProvider = Provider<ReimbursementService>((ref) {
  return ReimbursementService(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});
