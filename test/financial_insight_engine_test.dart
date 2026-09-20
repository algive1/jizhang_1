import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/analysis.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';
import 'package:jizhang_app/features/insights/domain/financial_insight_engine.dart';
import 'package:jizhang_app/features/insights/domain/insight_models.dart';

void main() {
  final now = DateTime(2026, 9, 10, 12);

  test('budget velocity becomes a high-value risk insight', () {
    final transactions = _history(now);
    final analysis = const StatisticalAnalysisService().analyze(
      transactions,
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final budget = Budget(
      id: 'budget',
      monthKey: '2026-09',
      amount: 400,
      createdAt: now,
      updatedAt: now,
    );
    final feed = const FinancialInsightEngine().build(
      transactions: transactions,
      analysis: analysis,
      budgets: BudgetOverview(
        total: BudgetProgress(
          budget: budget,
          used: 300,
          remaining: 100,
          percentage: .75,
          remainingDays: 21,
          dailyAvailable: 4.76,
          status: BudgetAlertStatus.normal,
        ),
        categories: const [],
      ),
      accounts: const [],
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.controlSpending},
        configured: true,
      ),
      now: now,
    );

    final insight = feed.items.firstWhere(
      (item) => item.id == 'budget:2026-09:total',
    );
    expect(insight.kind, FinancialInsightKind.risk);
    expect(insight.analysis, contains('月底预计'));
    expect(insight.actionRoute, '/profile/budgets');
  });

  test('multiple credit accounts become a financial insight', () {
    final transactions = _history(now);
    final analysis = const StatisticalAnalysisService().analyze(
      transactions,
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final feed = const FinancialInsightEngine().build(
      transactions: transactions,
      analysis: analysis,
      budgets: const BudgetOverview(categories: []),
      accounts: [
        Account(
          id: 'card',
          name: '招商信用卡',
          type: AccountType.creditCard,
          balance: 0,
          currency: 'CNY',
          icon: 'card',
          color: 0,
          sortOrder: 0,
          isArchived: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
        Account(
          id: 'huabei',
          name: '花呗',
          type: AccountType.liability,
          balance: 0,
          currency: 'CNY',
          icon: 'wallet',
          color: 0,
          sortOrder: 1,
          isArchived: false,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      ],
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.optimizeFinances},
        focus: {InsightFocus.credit},
        configured: true,
      ),
      now: now,
    );

    final insight = feed.items.firstWhere(
      (item) => item.id == 'accounts:multiple-credit',
    );
    expect(insight.summary, contains('2 个'));
    expect(insight.meaning, contains('待还金额'));
  });

  test('family support is treated as life context rather than overspending', () {
    final transactions = [
      ..._history(now),
      _tx(
        'family-1',
        now.subtract(const Duration(days: 12)),
        600,
        note: '给妈妈',
      ),
      _tx(
        'family-2',
        now.subtract(const Duration(days: 45)),
        888,
        note: '给爸爸',
      ),
    ];
    final analysis = const StatisticalAnalysisService().analyze(
      transactions,
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final feed = const FinancialInsightEngine().build(
      transactions: transactions,
      analysis: analysis,
      budgets: const BudgetOverview(categories: []),
      accounts: const [],
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.recordLife},
        focus: {InsightFocus.family},
        configured: true,
      ),
      now: now,
    );

    final insight = feed.items.firstWhere(
      (item) => item.id == 'life:family-support',
    );
    expect(insight.kind, FinancialInsightKind.life);
    expect(insight.analysis, contains('家庭支持'));
    expect(insight.summary, isNot(contains('超支')));
  });

  test('goal context can produce progress insight', () {
    final transactions = _history(now);
    final analysis = const StatisticalAnalysisService().analyze(
      transactions,
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final goal = Goal(
      id: 'travel',
      name: '旅行基金',
      icon: 'travel',
      targetAmount: 10000,
      currentAmount: 1500,
      createdAt: DateTime(2026, 1, 1),
      targetDate: DateTime(2026, 12, 31),
      status: GoalStatus.active,
      milestones: const [],
    );
    final feed = const FinancialInsightEngine().build(
      transactions: transactions,
      analysis: analysis,
      budgets: const BudgetOverview(categories: []),
      accounts: const [],
      goals: [goal],
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.saveForGoal},
        configured: true,
      ),
      now: now,
    );

    expect(
      feed.items.any((item) => item.id == 'goal:travel:progress'),
      isTrue,
    );
  });
}

List<TransactionRecord> _history(DateTime now) {
  final records = <TransactionRecord>[];
  for (var monthOffset = 0; monthOffset < 4; monthOffset++) {
    final month = DateTime(now.year, now.month - monthOffset, 12);
    for (var index = 0; index < 14; index++) {
      records.add(
        _tx(
          'tx-$monthOffset-$index',
          month.subtract(Duration(days: index % 10)),
          25 + (index % 3) * 4,
        ),
      );
    }
  }
  return records;
}

TransactionRecord _tx(
  String id,
  DateTime date,
  double amount, {
  String? note,
}) {
  return TransactionRecord(
    id: id,
    bookId: 'book-personal',
    type: TransactionType.expense,
    amount: amount,
    categoryId: 'food',
    categoryName: '餐饮',
    accountId: 'cash',
    note: note,
    occurredAt: date,
    createdAt: date,
    updatedAt: date,
  );
}
