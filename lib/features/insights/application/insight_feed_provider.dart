import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

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

final localInsightFeedProvider = Provider<InsightFeed>((ref) {
  final transactions =
      ref.watch(transactionsProvider).value ?? const <TransactionRecord>[];
  final engine = ref.watch(financialInsightEngineProvider);
  final analysis = ref.watch(statisticalAnalysisServiceProvider).analyze(
        engine.normalizeAnalysisTransactions(transactions),
        period: AnalysisPeriod.currentMonth,
        currency: 'CNY',
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
  final transactions =
      ref.watch(transactionsProvider).value ?? const <TransactionRecord>[];
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
  return ref.read(remoteInsightRepositoryProvider).analyze(
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
