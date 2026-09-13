import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/installment_plan.dart';
import '../../../core/models/transaction_record.dart';
import '../../books/data/book_repository.dart';
import '../../transactions/data/transactions_repository.dart';

abstract interface class InstallmentPlanRepository {
  Stream<List<InstallmentPlan>> watchActive();
  Future<List<InstallmentPlan>> getActive();
  Future<InstallmentPlan?> getById(String id);
  Future<InstallmentPlan> create(InstallmentPlan plan);
  Future<InstallmentPlan> update(InstallmentPlan plan);
  Future<TransactionRecord> recordRepayment(
    String planId, {
    DateTime? occurredAt,
  });
  Future<int> processDueRepayments({DateTime? now});
}

class DriftInstallmentPlanRepository implements InstallmentPlanRepository {
  DriftInstallmentPlanRepository(this._database, {required this.bookId});

  final AppDatabase _database;
  final String bookId;

  @override
  Stream<List<InstallmentPlan>> watchActive() =>
      _database.installmentPlanDao.watchActive(bookId: bookId).map(_map);

  @override
  Future<List<InstallmentPlan>> getActive() async =>
      _map(await _database.installmentPlanDao.getActive(bookId: bookId));

  @override
  Future<InstallmentPlan?> getById(String id) async {
    final row = await _database.installmentPlanDao.findById(id);
    if (row == null || row.bookId != bookId) return null;
    return _map([row]).single;
  }

  @override
  Future<InstallmentPlan> create(InstallmentPlan plan) async {
    _validate(plan);
    if (plan.bookId != bookId) throw ArgumentError('分期计划必须属于当前账本');
    final originalCurrency = await _ensureOriginal(plan);
    await _ensureAccounts(plan, transactionCurrency: originalCurrency);
    if (await _database.installmentPlanDao.findById(plan.id) != null) {
      throw StateError('分期计划已存在');
    }
    await _database.installmentPlanDao.insertOne(_toCompanion(plan));
    return plan;
  }

  @override
  Future<InstallmentPlan> update(InstallmentPlan plan) async {
    _validate(plan);
    if (plan.bookId != bookId) throw ArgumentError('分期计划必须属于当前账本');
    final existing = await _database.installmentPlanDao.findById(plan.id);
    if (existing == null || existing.bookId != bookId) {
      throw StateError('分期计划不存在');
    }
    final originalCurrency = await _ensureOriginal(plan);
    await _ensureAccounts(plan, transactionCurrency: originalCurrency);
    await _database.installmentPlanDao.replaceOne(_toCompanion(plan));
    return plan;
  }

  @override
  Future<TransactionRecord> recordRepayment(
    String planId, {
    DateTime? occurredAt,
  }) async {
    final row = await _database.installmentPlanDao.findById(planId);
    if (row == null || row.bookId != bookId) {
      throw StateError('分期计划不存在');
    }
    final plan = _map([row]).single;
    if (plan.status != InstallmentPlanStatus.active ||
        plan.currentPeriod >= plan.totalPeriods) {
      throw StateError('该分期计划已完成或已取消');
    }
    final originalCurrency = await _ensureOriginal(plan);
    await _ensureAccounts(plan, transactionCurrency: originalCurrency);
    final repaymentAccount = await _database.accountDao.findById(
      plan.repaymentAccountId,
    );
    final creditAccount = await _database.accountDao.findById(
      plan.creditAccountId,
    );
    if (repaymentAccount == null || creditAccount == null) {
      throw StateError('分期账户不存在');
    }
    if (repaymentAccount.currency.toUpperCase() !=
        creditAccount.currency.toUpperCase()) {
      throw ArgumentError('还款账户与信用卡账户币种必须一致');
    }
    final nextPeriod = plan.currentPeriod + 1;
    final principalPaid = nextPeriod == plan.totalPeriods
        ? plan.remainingPrincipal
        : plan.principalPerPeriod.clamp(0, plan.remainingPrincipal).toDouble();
    final amount = principalPaid + plan.feePerPeriod;
    if (amount <= 0) throw StateError('本期还款金额无效');
    final now = occurredAt ?? DateTime.now();
    final transaction = TransactionRecord(
      id: 'installment-repayment-${plan.id}-$nextPeriod',
      bookId: bookId,
      userId: _database.currentActor,
      type: TransactionType.repayment,
      amount: amount,
      currency: repaymentAccount.currency,
      accountId: plan.repaymentAccountId,
      destinationAccountId: plan.creditAccountId,
      relatedTransactionId: plan.originalTransactionId,
      merchant: plan.name,
      note: '第 $nextPeriod/${plan.totalPeriods} 期',
      occurredAt: now,
      createdAt: now,
      updatedAt: now,
      source: TransactionSource.auto,
      isOneTime: true,
      isRecurring: false,
      metadataJson:
          '{"installment_plan_id":"${plan.id}","installment_period":$nextPeriod}',
      createdBy: _database.currentActor,
      updatedBy: _database.currentActor,
    );
    final transactionRepository = DriftTransactionRepository(
      _database,
      bookId: bookId,
      accountBookId: repaymentAccount.bookId,
    );
    final remaining = (plan.remainingPrincipal - principalPaid)
        .clamp(0, plan.remainingPrincipal)
        .toDouble();
    final updatedPlan = _copyWith(
      plan,
      currentPeriod: nextPeriod,
      remainingPrincipal: remaining,
      status: nextPeriod >= plan.totalPeriods || remaining <= 0
          ? InstallmentPlanStatus.completed
          : InstallmentPlanStatus.active,
      updatedAt: now,
    );
    final existingTransaction = await transactionRepository.getById(
      transaction.id,
    );
    if (existingTransaction != null) {
      if (plan.currentPeriod < nextPeriod) {
        await _database.installmentPlanDao.replaceOne(
          _toCompanion(updatedPlan),
        );
      }
      return existingTransaction;
    }
    await _database.transaction(() async {
      await transactionRepository.create(transaction);
      await _database.installmentPlanDao.replaceOne(_toCompanion(updatedPlan));
    });
    return transaction;
  }

  /// Executes all repayment periods whose due date has passed. The caller
  /// decides when to run this (for example from the installment page), while
  /// each repayment remains idempotent by plan and period.
  @override
  Future<int> processDueRepayments({DateTime? now}) async {
    final cutoff = now ?? DateTime.now();
    var processed = 0;
    for (var plan in await getActive()) {
      var guard = 0;
      while (plan.status == InstallmentPlanStatus.active &&
          plan.currentPeriod < plan.totalPeriods &&
          !dueDateFor(plan, plan.currentPeriod + 1).isAfter(cutoff) &&
          guard < 366) {
        final due = dueDateFor(plan, plan.currentPeriod + 1);
        await recordRepayment(plan.id, occurredAt: due);
        processed++;
        final updated = await getById(plan.id);
        if (updated == null) break;
        plan = updated;
        guard++;
      }
    }
    return processed;
  }

  DateTime dueDateFor(InstallmentPlan plan, int period) {
    if (period < 1 || period > plan.totalPeriods) {
      throw ArgumentError('分期期数超出范围');
    }
    final firstMonthOffset = plan.dueDay <= plan.startDate.day ? 1 : 0;
    final month = DateTime(
      plan.startDate.year,
      plan.startDate.month + firstMonthOffset + period - 1,
      1,
    );
    final lastDay = DateTime(month.year, month.month + 1, 0).day;
    return DateTime(month.year, month.month, plan.dueDay.clamp(1, lastDay));
  }

  void _validate(InstallmentPlan plan) {
    if (plan.name.trim().isEmpty) throw ArgumentError('分期计划名称不能为空');
    if (!plan.totalAmount.isFinite || plan.totalAmount <= 0) {
      throw ArgumentError('分期总金额必须大于 0');
    }
    if (plan.totalPeriods < 1 ||
        plan.currentPeriod < 0 ||
        plan.currentPeriod > plan.totalPeriods) {
      throw ArgumentError('分期期数无效');
    }
    if (plan.dueDay < 1 || plan.dueDay > 31) {
      throw ArgumentError('还款日必须在 1 到 31 之间');
    }
    for (final value in [
      plan.principalPerPeriod,
      plan.feePerPeriod,
      plan.remainingPrincipal,
    ]) {
      if (!value.isFinite || value < 0) throw ArgumentError('分期金额无效');
    }
  }

  Future<String> _ensureOriginal(InstallmentPlan plan) async {
    final original = await _database.transactionDao.findById(
      plan.originalTransactionId,
    );
    if (original == null ||
        original.bookId != bookId ||
        original.deletedAt != null ||
        !{'expense', 'lend', 'assetPurchase'}.contains(original.type) ||
        original.amountInCents != (plan.totalAmount * 100).round()) {
      throw ArgumentError('分期计划必须关联当前账本的原始消费');
    }
    return original.currency;
  }

  Future<void> _ensureAccounts(
    InstallmentPlan plan, {
    String? transactionCurrency,
  }) async {
    if (plan.creditAccountId == plan.repaymentAccountId) {
      throw ArgumentError('信用卡账户与还款账户必须是两个不同账户');
    }
    final accounts = [
      await _database.accountDao.findById(plan.creditAccountId),
      await _database.accountDao.findById(plan.repaymentAccountId),
    ];
    if (accounts.any((account) => account == null)) {
      throw StateError('分期账户不存在');
    }
    final creditAccount = accounts[0]!;
    final repaymentAccount = accounts[1]!;
    final book = await _database.familyDao.findBook(bookId);
    final allowedAccountBooks = <String>{
      bookId,
      if (book?.assetSourceBookId != null) book!.assetSourceBookId!,
    };
    if (!allowedAccountBooks.contains(creditAccount.bookId) ||
        !allowedAccountBooks.contains(repaymentAccount.bookId)) {
      throw ArgumentError('分期账户必须属于当前账本的资产范围');
    }
    if (creditAccount.isArchived || repaymentAccount.isArchived) {
      throw StateError('分期账户已归档');
    }
    if (creditAccount.bookId != repaymentAccount.bookId) {
      throw ArgumentError('信用卡账户与还款账户必须属于同一资产账本');
    }
    if (creditAccount.currency.toUpperCase() !=
        repaymentAccount.currency.toUpperCase()) {
      throw ArgumentError('信用卡账户与还款账户币种必须一致');
    }
    if (transactionCurrency != null &&
        creditAccount.currency.toUpperCase() !=
            transactionCurrency.toUpperCase()) {
      throw ArgumentError('分期账户与原流水币种必须一致');
    }
  }

  List<InstallmentPlan> _map(List<InstallmentPlanEntity> rows) => [
    for (final row in rows)
      InstallmentPlan(
        id: row.id,
        bookId: row.bookId,
        name: row.name,
        originalTransactionId: row.originalTransactionId,
        totalAmount: row.totalAmountInCents / 100,
        totalPeriods: row.totalPeriods,
        currentPeriod: row.currentPeriod,
        principalPerPeriod: row.principalPerPeriodInCents / 100,
        feePerPeriod: row.feePerPeriodInCents / 100,
        startDate: row.startDate,
        dueDay: row.dueDay,
        creditAccountId: row.creditAccountId,
        repaymentAccountId: row.repaymentAccountId,
        remainingPrincipal: row.remainingPrincipalInCents / 100,
        status: InstallmentPlanStatus.values.byName(row.status),
        createdAt: row.createdAt,
        updatedAt: row.updatedAt,
      ),
  ];

  InstallmentPlanEntriesCompanion _toCompanion(
    InstallmentPlan plan,
  ) => InstallmentPlanEntriesCompanion(
    id: Value(plan.id),
    bookId: Value(plan.bookId),
    name: Value(plan.name.trim()),
    originalTransactionId: Value(plan.originalTransactionId),
    totalAmountInCents: Value((plan.totalAmount * 100).round()),
    totalPeriods: Value(plan.totalPeriods),
    currentPeriod: Value(plan.currentPeriod),
    principalPerPeriodInCents: Value((plan.principalPerPeriod * 100).round()),
    feePerPeriodInCents: Value((plan.feePerPeriod * 100).round()),
    startDate: Value(plan.startDate),
    dueDay: Value(plan.dueDay),
    creditAccountId: Value(plan.creditAccountId),
    repaymentAccountId: Value(plan.repaymentAccountId),
    remainingPrincipalInCents: Value((plan.remainingPrincipal * 100).round()),
    status: Value(plan.status.name),
    createdAt: Value(plan.createdAt),
    updatedAt: Value(plan.updatedAt),
  );

  InstallmentPlan _copyWith(
    InstallmentPlan plan, {
    int? currentPeriod,
    double? remainingPrincipal,
    InstallmentPlanStatus? status,
    DateTime? updatedAt,
  }) => InstallmentPlan(
    id: plan.id,
    bookId: plan.bookId,
    name: plan.name,
    originalTransactionId: plan.originalTransactionId,
    totalAmount: plan.totalAmount,
    totalPeriods: plan.totalPeriods,
    currentPeriod: currentPeriod ?? plan.currentPeriod,
    principalPerPeriod: plan.principalPerPeriod,
    feePerPeriod: plan.feePerPeriod,
    startDate: plan.startDate,
    dueDay: plan.dueDay,
    creditAccountId: plan.creditAccountId,
    repaymentAccountId: plan.repaymentAccountId,
    remainingPrincipal: remainingPrincipal ?? plan.remainingPrincipal,
    status: status ?? plan.status,
    createdAt: plan.createdAt,
    updatedAt: updatedAt ?? plan.updatedAt,
  );
}

final installmentPlanRepositoryProvider = Provider<InstallmentPlanRepository>((
  ref,
) {
  return DriftInstallmentPlanRepository(
    ref.watch(databaseProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

final installmentPlansProvider = StreamProvider<List<InstallmentPlan>>((
  ref,
) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref.watch(installmentPlanRepositoryProvider).watchActive();
});

final installmentPlanProvider = FutureProvider.family<InstallmentPlan?, String>(
  (ref, id) async {
    await ref.watch(databaseBootstrapProvider.future);
    return ref.watch(installmentPlanRepositoryProvider).getById(id);
  },
);
