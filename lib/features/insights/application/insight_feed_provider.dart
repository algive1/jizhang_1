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
  final analysis = ref
      .watch(analysisRepositoryProvider)
      .analyze(
        period: AnalysisPeriod.currentMonth,
        currency: 'CNY',
      );
  final budgets = ref.watch(budgetOverviewProvider);
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  final goals = ref.watch(goalsProvider).value ?? const [];
  final preferences =
      ref.watch(insightPreferencesProvider).value ??
      const InsightPreferences();
  return ref
      .watch(financialInsightEngineProvider)
      .build(
        transactions: transactions,
        analysis: analysis,
        budgets: budgets,
        accounts: accounts,
        goals: goals,
        preferences: preferences,
      );
});


final confirmedInsightFeedProvider = FutureProvider<InsightFeed?>((ref) async {
  final transactions =
      ref.watch(transactionsProvider).value ?? const <TransactionRecord>[];
  final accounts = ref.watch(allAccountsProvider).value ?? const [];
  final budgets = ref.watch(currentMonthBudgetsProvider).value ?? const [];
  final goals = ref.watch(goalsProvider).value ?? const [];
  final recurringBills =
      ref.watch(recurringBillsProvider).value ?? const [];
  final preferences =
      ref.watch(insightPreferencesProvider).value ??
      const InsightPreferences();
  final bookId = ref.watch(activeBookIdProvider);
  // Debounce bursts from automatic/import bookkeeping. Riverpod discards stale
  // results when dependencies change while this request is waiting.
  await Future<void>.delayed(const Duration(milliseconds: 650));
  return ref.read(remoteInsightRepositoryProvider).analyze(
        bookId: bookId,
        transactions: transactions,
        accounts: accounts,
        budgets: budgets,
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
