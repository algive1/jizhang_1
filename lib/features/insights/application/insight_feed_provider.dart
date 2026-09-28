import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/transaction_record.dart';
import '../../goals/data/goal_repository.dart';
import '../../books/data/book_repository.dart';
import '../../recurring/data/recurring_bill_repository.dart';
import '../data/remote_insight_repository.dart';
import '../../accounts/data/account_repository.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../budgets/data/budget_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/insight_preferences_repository.dart';
import '../domain/financial_insight_engine.dart';
import '../domain/insight_models.dart';

final financialInsightEngineProvider = Provider<FinancialInsightEngine>(
  (ref) => const FinancialInsightEngine(),
);

List<TransactionRecord> _mergeInsightTransactions(
  Iterable<TransactionRecord> recent,
  Iterable<TransactionRecord> pending,
) {
  final byId = <String, TransactionRecord>{
    for (final item in recent) item.id: item,
  };
  for (final item in pending) {
    byId[item.id] = item;
  }
  return byId.values.toList(growable: false);
}

final insightRecentTransactionsProvider =
    StreamProvider<List<TransactionRecord>>((ref) async* {
      await ref.watch(databaseBootstrapProvider.future);
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      yield* ref.watch(transactionRepositoryProvider).watchRange(
        start: today.subtract(const Duration(days: 180)),
        endExclusive: today.add(const Duration(days: 1)),
      );
    });

final insightPendingReimbursementsProvider =
    StreamProvider<List<TransactionRecord>>((ref) async* {
      await ref.watch(databaseBootstrapProvider.future);
      yield* ref
          .watch(transactionRepositoryProvider)
          .watchPendingReimbursements();
    });

final insightLargeExpenseThresholdProvider = StreamProvider<double>((ref) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref
      .watch(databaseProvider)
      .transactionDao
      .watchLargeExpenseThresholdInCents(
        bookId: ref.watch(activeBookIdProvider),
      )
      .map((cents) => cents / 100);
});

final localInsightFeedProvider = Provider<InsightFeed>((ref) {
  final transactions = _mergeInsightTransactions(
    ref.watch(insightRecentTransactionsProvider).value ??
        const <TransactionRecord>[],
    ref.watch(insightPendingReimbursementsProvider).value ??
        const <TransactionRecord>[],
  );
  final engine = ref.watch(financialInsightEngineProvider);
  final analysis = ref.watch(statisticalAnalysisServiceProvider).analyze(
        engine.normalizeAnalysisTransactions(transactions),
        period: AnalysisPeriod.currentMonth,
        currency: 'CNY',
        largeExpenseThreshold:
            ref.watch(insightLargeExpenseThresholdProvider).value,
      );
  final budgets = ref.watch(budgetOverviewProvider);
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  final categories = ref.watch(allCategoriesProvider).value ?? const [];
  final goals = ref.watch(goalsProvider).value ?? const [];
  final recurringBills =
      ref.watch(recurringBillsProvider).value ?? const [];
  final preferences =
      ref.watch(insightPreferencesProvider).value ??
      const InsightPreferences();
  return engine.build(
    transactions: transactions,
    analysis: analysis,
    budgets: budgets,
    accounts: accounts,
    categories: categories,
    goals: goals,
    recurringBills: recurringBills,
    preferences: preferences,
  );
});


final confirmedInsightFeedProvider = FutureProvider<InsightFeed?>((ref) async {
  // Keep remote analysis reactive to transaction changes without subscribing
  // to the entire ledger. The bounded stream reruns on transaction-table
  // updates, while the actual query below follows the server's history policy.
  ref.watch(insightRecentTransactionsProvider);
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  final budgets = ref.watch(currentMonthBudgetsProvider).value ?? const [];
  final categories = ref.watch(allCategoriesProvider).value ?? const [];
  final goals = ref.watch(goalsProvider).value ?? const [];
  final recurringBills =
      ref.watch(recurringBillsProvider).value ?? const [];
  final preferences =
      ref.watch(insightPreferencesProvider).value ??
      const InsightPreferences();
  final bookId = ref.watch(activeBookIdProvider);
  final remoteRepository = ref.read(remoteInsightRepositoryProvider);
  final remotePolicy = await remoteRepository.policy();
  final historyDays = (remotePolicy?.historyDays ?? 90).clamp(1, 3650);
  final now = DateTime.now();
  final transactions = await ref.read(transactionRepositoryProvider).getRange(
        start: now.subtract(Duration(days: historyDays)),
        endExclusive: DateTime(now.year, now.month, now.day + 1),
      );
  // Debounce bursts from automatic/import bookkeeping. Keep the delay
  // cancellable so disposing the provider never leaves a timer alive in tests
  // or after navigating away from Home.
  var disposed = false;
  final delay = Completer<void>();
  final timer = Timer(const Duration(milliseconds: 650), delay.complete);
  ref.onDispose(() {
    disposed = true;
    timer.cancel();
    if (!delay.isCompleted) delay.complete();
  });
  await delay.future;
  if (disposed) return null;
  return remoteRepository.analyze(
        bookId: bookId,
        transactions: transactions,
        accounts: accounts,
        budgets: budgets,
        categories: categories,
        goals: goals,
        recurringBills: recurringBills,
        preferences: preferences,
      );
});

final insightFeedProvider = Provider<InsightFeed>((ref) {
  final local = ref.watch(localInsightFeedProvider);
  final remote = ref.watch(confirmedInsightFeedProvider).value;
  final preferences =
      ref.watch(insightPreferencesProvider).value ??
      const InsightPreferences();
  final selected = remote ?? local;
  if (preferences.dismissedIds.isEmpty) return selected;
  return selected.copyWith(
    items: selected.items
        .where((item) => !preferences.dismissedIds.contains(item.id))
        .toList(growable: false),
  );
});
