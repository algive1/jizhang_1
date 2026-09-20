import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/analysis.dart';
import '../../../core/models/transaction_record.dart';
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

final insightFeedProvider = Provider<InsightFeed>((ref) {
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
        preferences: preferences,
      );
});
