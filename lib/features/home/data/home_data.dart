import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/analysis.dart';
import '../../../core/models/dashboard_snapshot.dart';
import '../../../core/models/transaction_record.dart';
import '../../budgets/data/budget_repository.dart';
import '../../analysis/domain/statistical_analysis_service.dart';
import '../../transactions/data/transactions_repository.dart';

final dashboardSnapshotProvider = Provider<DashboardSnapshot>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final now = DateTime.now();
  final monthTransactions = transactions.where(
    (item) =>
        item.currency.toUpperCase() == 'CNY' &&
        item.deletedAt == null &&
        !item.occurredAt.isAfter(now) &&
        item.occurredAt.year == now.year &&
        item.occurredAt.month == now.month,
  );
  final income =
      monthTransactions
          .where((item) => item.isIncome)
          .fold<int>(0, (total, item) => total + (item.amount * 100).round()) /
      100;
  final spending =
      monthTransactions
          .where((item) => item.isExpense)
          .fold<int>(0, (total, item) => total + (item.amount * 100).round()) /
      100;
  final forecastBalance = income - spending;
  final budgetOverview = ref.watch(budgetOverviewProvider);
  return DashboardSnapshot(
    safeToSpend: budgetOverview.total?.dailyAvailable ?? 0,
    forecastBalance: forecastBalance,
    hasBudget: budgetOverview.total != null,
    month: DateTime(now.year, now.month),
    income: income,
    expense: spending,
    budgetAmount: budgetOverview.total?.budget.amount ?? 0,
    availableAmount: budgetOverview.total?.remaining ?? 0,
    remainingDays: DateTime(now.year, now.month + 1, 0).day - now.day + 1,
    goalReservation: budgetOverview.total?.goalReservation ?? 0,
  );
});

final homeInsightProvider = Provider<FinancialInsight>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final now = DateTime.now();
  const analysisService = StatisticalAnalysisService();
  final analysis = analysisService.analyze(
    transactions,
    period: AnalysisPeriod.currentMonth,
    now: now,
  );
  final lateNightAmount = analysis.segmentAmounts[TimeSegment.lateNight] ?? 0;
  final previous = analysisService.analyze(
    transactions,
    now: analysis.previousRange.endExclusive.subtract(
      const Duration(microseconds: 1),
    ),
  );
  final previousAmount = previous.segmentAmounts[TimeSegment.lateNight] ?? 0;
  final increasePercent = previousAmount <= 0 || previous.transactionCount < 3
      ? null
      : ((lateNightAmount - previousAmount) / previousAmount * 100).round();
  return FinancialInsight(
    timeLabel: '22:00后消费',
    amount: lateNightAmount,
    increasePercent: increasePercent,
    description: increasePercent == null
        ? (lateNightAmount == 0
              ? '本月暂时没有深夜消费记录，保持从容的节奏。'
              : '上月同期样本不足，暂不显示消费增幅。')
        : '对比上月相同日期，点击查看消费时间分布。',
  );
});

final homeRecentTransactionsProvider = Provider<List<TransactionRecord>>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  return transactions.take(6).toList(growable: false);
});

class HomeMonthController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void select(DateTime month) {
    final now = DateTime.now();
    final normalized = DateTime(month.year, month.month);
    if (normalized.isAfter(DateTime(now.year, now.month))) return;
    state = normalized == DateTime(now.year, now.month) ? null : normalized;
  }
}

final selectedHomeMonthProvider =
    NotifierProvider<HomeMonthController, DateTime?>(HomeMonthController.new);

MonthlyLedgerSummary monthlySummary(
  Iterable<TransactionRecord> records,
  DateTime month,
  DateTime now,
) {
  var income = 0;
  var expense = 0;
  for (final item in records) {
    if (item.deletedAt != null ||
        item.currency.toUpperCase() != 'CNY' ||
        item.occurredAt.isAfter(now) ||
        item.occurredAt.year != month.year ||
        item.occurredAt.month != month.month)
      continue;
    if (item.isIncome) income += (item.amount * 100).round();
    if (item.isExpense) expense += (item.amount * 100).round();
  }
  return MonthlyLedgerSummary(
    month: DateTime(month.year, month.month),
    income: income / 100,
    expense: expense / 100,
  );
}

final homeMonthlySummaryProvider = Provider<MonthlyLedgerSummary>((ref) {
  final now = DateTime.now();
  return monthlySummary(
    ref.watch(transactionsProvider).value ?? [],
    ref.watch(selectedHomeMonthProvider) ?? now,
    now,
  );
});
