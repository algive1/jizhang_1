import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:drift/drift.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/budget.dart';
import '../../../core/models/transaction_record.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../domain/budget_period.dart';
import 'budget_repository.dart';

final budgetPeriodBudgetsProvider = StreamProvider.autoDispose
    .family<List<Budget>, BudgetPeriod>((ref, period) async* {
      final bookId = ref.watch(activeBookIdProvider);
      final db = ref.watch(databaseProvider);
      await ref.watch(databaseBootstrapProvider.future);
      yield* (db.select(db.budgetEntries)..where(
            (row) =>
                row.bookId.equals(bookId) &
                row.monthKey.isBetweenValues(
                  budgetMonthKey(period.start),
                  budgetMonthKey(period.lastDay),
                ),
          ))
          .watch()
          .map(
            (rows) => rows
                .map(
                  (row) => Budget(
                    id: row.id,
                    bookId: row.bookId,
                    monthKey: row.monthKey,
                    categoryId: row.categoryId,
                    amount: row.amountInCents / 100,
                    createdAt: row.createdAt,
                    updatedAt: row.updatedAt,
                  ),
                )
                .toList(),
          );
    });

final budgetPeriodTransactionsProvider = StreamProvider.autoDispose
    .family<List<TransactionRecord>, BudgetPeriod>((ref, period) async* {
      await ref.watch(databaseBootstrapProvider.future);
      yield* ref
          .watch(transactionRepositoryProvider)
          .watchRanges(
            ranges: [
              (start: period.start, endExclusive: period.end),
              (start: period.previous.start, endExclusive: period.previous.end),
            ],
          );
    });

final budgetPeriodOverviewProvider = Provider.autoDispose
    .family<AsyncValue<BudgetPeriodOverview>, BudgetPeriod>((ref, period) {
      final bookId = ref.watch(activeBookIdProvider);
      final budgets = ref.watch(budgetPeriodBudgetsProvider(period));
      final transactions = ref.watch(budgetPeriodTransactionsProvider(period));
      final categories = ref.watch(allCategoriesProvider);
      final goals = ref.watch(goalsProvider);
      final sources = <AsyncValue<Object>>[
        budgets,
        transactions,
        categories,
        goals,
      ];
      for (final source in sources) {
        if (source.hasError)
          return AsyncError(source.error!, source.stackTrace!);
      }
      if (sources.any((source) => source.isLoading || !source.hasValue))
        return const AsyncLoading();
      return AsyncData(
        const BudgetPeriodService().calculate(
          period: period,
          bookId: bookId,
          now: DateTime.now(),
          budgets: budgets.value!,
          transactions: transactions.value!,
          categories: categories.value!,
          goals: goals.value!,
        ),
      );
    });
