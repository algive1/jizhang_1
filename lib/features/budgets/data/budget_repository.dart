import 'dart:math' as math;

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_provider.dart';
import '../../books/data/book_repository.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/safe_to_spend_service.dart';
import '../../goals/data/goal_repository.dart';
import '../../../core/models/goal.dart';

abstract interface class BudgetRepository {
  Stream<List<Budget>> watchMonth(String monthKey);
  Future<List<Budget>> getMonth(String monthKey);
  Future<void> setBudget({
    required String monthKey,
    required double amount,
    String? categoryId,
  });
  Future<void> removeBudget(String id);
  BudgetOverview calculateOverview({
    required List<Budget> budgets,
    required List<TransactionRecord> transactions,
    required List<Category> categories,
    required DateTime now,
    double goalReservation = 0,
  });
}

class DriftBudgetRepository implements BudgetRepository {
  DriftBudgetRepository(
    this._database,
    this._safeToSpend, {
    this.bookId = 'book-personal',
  });

  final String bookId;

  final AppDatabase _database;
  final SafeToSpendService _safeToSpend;

  @override
  Stream<List<Budget>> watchMonth(String monthKey) {
    return _database.budgetDao
        .watchMonth(monthKey, bookId: bookId)
        .map((rows) => rows.map(_fromEntity).toList(growable: false));
  }

  @override
  Future<List<Budget>> getMonth(String monthKey) async {
    final rows = await _database.budgetDao.getMonth(monthKey, bookId: bookId);
    return rows.map(_fromEntity).toList(growable: false);
  }

  @override
  Future<void> setBudget({
    required String monthKey,
    required double amount,
    String? categoryId,
  }) async {
    if (!amount.isFinite || amount <= 0) {
      throw ArgumentError.value(amount, 'amount', 'must be > 0');
    }
    if (categoryId != null) {
      final category = await _database.categoryDao.findById(categoryId);
      if (category == null || category.bookId != bookId)
        throw ArgumentError('分类不属于当前账本');
    }
    final existing = (await _database.budgetDao.getMonth(
      monthKey,
      bookId: bookId,
    )).where((item) => item.categoryId == categoryId).firstOrNull;
    final now = DateTime.now();
    await _database.budgetDao.upsert(
      BudgetEntriesCompanion(
        id: Value(
          existing?.id ?? 'budget-$bookId-$monthKey-${categoryId ?? 'total'}',
        ),
        bookId: Value(bookId),
        monthKey: Value(monthKey),
        categoryId: Value(categoryId),
        amountInCents: Value((amount * 100).round()),
        createdAt: Value(existing?.createdAt ?? now),
        updatedAt: Value(now),
      ),
    );
  }

  @override
  Future<void> removeBudget(String id) async {
    final row =
        await (_database.select(_database.budgetEntries)
              ..where((r) => r.id.equals(id) & r.bookId.equals(bookId)))
            .getSingleOrNull();
    if (row == null) throw StateError('预算不属于当前账本');
    await _database.budgetDao.deleteById(id);
  }

  @override
  BudgetOverview calculateOverview({
    required List<Budget> budgets,
    required List<TransactionRecord> transactions,
    required List<Category> categories,
    required DateTime now,
    double goalReservation = 0,
  }) {
    final monthTransactions = transactions.where(
      (item) =>
          item.isExpense &&
          item.currency.toUpperCase() == 'CNY' &&
          !item.occurredAt.isAfter(now) &&
          item.deletedAt == null &&
          item.occurredAt.year == now.year &&
          item.occurredAt.month == now.month,
    );
    final totalUsed =
        monthTransactions.fold<int>(
          0,
          (total, item) => total + (item.netExpenseAmount * 100).round(),
        ) /
        100;
    final totalBudget = budgets
        .where((item) => item.categoryId == null)
        .firstOrNull;
    final total = totalBudget == null
        ? null
        : _progress(totalBudget, totalUsed, now, null, goalReservation);
    final categoryMap = {
      for (final category in categories) category.id: category,
    };
    final categoryProgress = budgets
        .where((item) => item.categoryId != null)
        .map((budget) {
          final used = monthTransactions
              .where(
                (item) =>
                    _belongsToCategory(item, budget.categoryId!, categoryMap),
              )
              .fold<double>(0, (sum, item) => sum + item.netExpenseAmount);
          return _progress(budget, used, now, categoryMap[budget.categoryId]);
        })
        .toList(growable: false);
    return BudgetOverview(total: total, categories: categoryProgress);
  }

  bool _belongsToCategory(
    TransactionRecord transaction,
    String budgetCategoryId,
    Map<String, Category> categories,
  ) {
    final storedIds = {transaction.categoryId, transaction.subcategoryId}
      ..remove(null);
    if (storedIds.contains(budgetCategoryId)) return true;
    return storedIds.any((id) => categories[id]?.parentId == budgetCategoryId);
  }

  BudgetProgress _progress(
    Budget budget,
    double used,
    DateTime now,
    Category? category, [
    double goalReservation = 0,
  ]) {
    final remaining =
        ((budget.amount * 100).round() -
            (used * 100).round() -
            (goalReservation * 100).round()) /
        100;
    final percentage = budget.amount == 0
        ? 0.0
        : (used + goalReservation) / budget.amount;
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = math.max(1, lastDay - now.day + 1);
    final status = percentage > 1
        ? BudgetAlertStatus.exceeded
        : percentage >= .8
        ? BudgetAlertStatus.nearLimit
        : BudgetAlertStatus.normal;
    return BudgetProgress(
      budget: budget,
      goalReservation: goalReservation,
      category: category,
      used: used,
      remaining: remaining,
      percentage: percentage,
      remainingDays: remainingDays,
      dailyAvailable: _safeToSpend.calculate(
        budgetAmount: budget.amount,
        spentAmount: used,
        goalReservation: goalReservation,
        now: now,
      ),
      status: status,
    );
  }

  Budget _fromEntity(BudgetEntity row) {
    return Budget(
      id: row.id,
      bookId: row.bookId,
      monthKey: row.monthKey,
      categoryId: row.categoryId,
      amount: row.amountInCents / 100,
      createdAt: row.createdAt,
      updatedAt: row.updatedAt,
    );
  }
}

String budgetMonthKey(DateTime date) =>
    '${date.year}-${date.month.toString().padLeft(2, '0')}';

final safeToSpendServiceProvider = Provider<SafeToSpendService>(
  (ref) => const SafeToSpendService(),
);

final budgetRepositoryProvider = Provider<BudgetRepository>((ref) {
  return DriftBudgetRepository(
    ref.watch(databaseProvider),
    ref.watch(safeToSpendServiceProvider),
    bookId: ref.watch(activeBookIdProvider),
  );
});

final currentMonthBudgetsProvider = StreamProvider<List<Budget>>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref
      .watch(budgetRepositoryProvider)
      .watchMonth(budgetMonthKey(DateTime.now()));
});

final budgetOverviewProvider = Provider<BudgetOverview>((ref) {
  final budgets = ref.watch(currentMonthBudgetsProvider).value ?? const [];
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final categories = ref.watch(allCategoriesProvider).value ?? const [];
  return ref
      .watch(budgetRepositoryProvider)
      .calculateOverview(
        budgets: budgets,
        transactions: transactions,
        categories: categories,
        now: DateTime.now(),
        goalReservation:
            (ref.watch(goalsProvider).value ?? const <Goal>[])
                .where((goal) => goal.status == GoalStatus.active)
                .fold<int>(
                  0,
                  (total, goal) =>
                      total + (goal.monthlyReservation * 100).round(),
                ) /
            100,
      );
});
