import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/analysis.dart';
import 'package:jizhang_app/core/models/budget.dart';
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/core/models/recurring_bill.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';
import 'package:jizhang_app/features/insights/domain/financial_insight_engine.dart';
import 'package:jizhang_app/features/insights/domain/insight_models.dart';

void main() {
  final now = DateTime(2026, 9, 10, 12);

  test('local trend analysis removes expected reimbursements', () {
    final raw = <TransactionRecord>[
      for (var index = 0; index < 4; index++)
        _tx(
          'previous-$index',
          DateTime(2026, 8, 3 + index),
          50,
        ),
      for (var index = 0; index < 4; index++)
        _tx(
          'current-$index',
          DateTime(2026, 9, 3 + index),
          200,
        ).copyWith(
          reimbursementStatus: ReimbursementStatus.pending,
          reimbursementAmount: 200,
        ),
    ];
    const engine = FinancialInsightEngine();
    final analysis = const StatisticalAnalysisService().analyze(
      engine.normalizeAnalysisTransactions(raw),
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final feed = engine.build(
      transactions: raw,
      analysis: analysis,
      budgets: const BudgetOverview(categories: []),
      accounts: const [],
      preferences: const InsightPreferences(configured: true),
      now: now,
    );

    expect(
      engine.normalizeAnalysisTransactions(raw).length,
      4,
      reason: 'Fully expected reimbursed rows should not affect trend counts.',
    );
    expect(
      feed.items.any((item) => item.id == 'analysis:category:food'),
      isFalse,
    );
  });

  test('one-time local category spike is not labeled as a persistent habit', () {
    final transactions = <TransactionRecord>[
      for (var index = 0; index < 8; index++)
        _tx(
          'previous-$index',
          DateTime(2026, 8, 2 + index),
          30,
          categoryId: 'shopping',
          categoryName: '购物',
        ).copyWith(isOneTime: false),
      for (var index = 0; index < 5; index++)
        _tx(
          'current-$index',
          DateTime(2026, 9, 2 + index),
          30,
          categoryId: 'shopping',
          categoryName: '购物',
        ).copyWith(isOneTime: false),
      _tx(
        'special',
        DateTime(2026, 9, 9),
        900,
        categoryId: 'shopping',
        categoryName: '购物',
      ).copyWith(isOneTime: true, isLargeTransaction: true),
    ];
    final normalized =
        const FinancialInsightEngine().normalizeAnalysisTransactions(
      transactions,
    );
    final analysis = const StatisticalAnalysisService().analyze(
      normalized,
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final feed = const FinancialInsightEngine().build(
      transactions: transactions,
      analysis: analysis,
      budgets: const BudgetOverview(categories: []),
      accounts: const [],
      preferences: const InsightPreferences(configured: true),
      now: now,
    );

    expect(
      feed.items.any((item) => item.id == 'category:shopping:one-time'),
      isTrue,
    );
    expect(
      feed.items.any((item) => item.id == 'analysis:category:shopping'),
      isFalse,
    );
  });

  test('three-month dining history can proactively recommend a category budget', () {
    final transactions = <TransactionRecord>[];
    final monthlyTotals = [420.0, 440.0, 440.0];
    for (var monthIndex = 0; monthIndex < monthlyTotals.length; monthIndex++) {
      final month = 8 - monthIndex;
      for (var index = 0; index < 8; index++) {
        transactions.add(
          _tx(
            'dining-$month-$index',
            DateTime(2026, month, 3 + index),
            monthlyTotals[monthIndex] / 8,
            categoryId: 'food',
            categoryName: '餐饮',
          ).copyWith(isOneTime: false),
        );
      }
    }
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
      categories: const [
        Category(
          id: 'food',
          name: '餐饮',
          icon: 'food',
          type: CategoryType.expense,
          sortOrder: 0,
          isDefault: true,
          isArchived: false,
        ),
      ],
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.controlSpending},
        focus: {InsightFocus.dining},
        configured: true,
      ),
      now: now,
    );

    final insight = feed.items.firstWhere(
      (item) => item.id == 'budget:recommendation:category:food',
    );
    expect(insight.title, contains('餐饮'));
    expect(insight.amount, inInclusiveRange(350, 420));
    expect(insight.summary, contains('中位数'));
    expect(insight.actionRoute, '/profile/budgets?recommend=1&categoryId=food');
  });

  test('category budget pace warns before month-end overspend', () {
    final transactions = _history(now);
    final analysis = const StatisticalAnalysisService().analyze(
      transactions,
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final category = Category(
      id: 'food',
      name: '餐饮',
      icon: 'food',
      type: CategoryType.expense,
      sortOrder: 0,
      isDefault: true,
      isArchived: false,
    );
    final budget = Budget(
      id: 'food-budget',
      monthKey: '2026-09',
      categoryId: 'food',
      amount: 400,
      createdAt: now,
      updatedAt: now,
    );
    final feed = const FinancialInsightEngine().build(
      transactions: transactions,
      analysis: analysis,
      budgets: BudgetOverview(
        categories: [
          BudgetProgress(
            budget: budget,
            category: category,
            used: 220,
            remaining: 180,
            percentage: .55,
            remainingDays: 21,
            dailyAvailable: 8.57,
            status: BudgetAlertStatus.normal,
          ),
        ],
      ),
      accounts: const [],
      categories: [category],
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.controlSpending},
        focus: {InsightFocus.dining},
        configured: true,
      ),
      now: now,
    );

    final insight = feed.items.firstWhere(
      (item) => item.id == 'budget:2026-09:category:food',
    );
    expect(insight.kind, FinancialInsightKind.risk);
    expect(insight.analysis, contains('月底预计'));
    expect(insight.title, contains('餐饮'));
  });

  test('control-spending intent ranks category budget risk above lifestyle discovery', () {
    final transactions = <TransactionRecord>[
      ..._history(now),
      for (var index = 0; index < 6; index++)
        _tx(
          'beauty-$index',
          now.subtract(Duration(days: 2 + index)),
          80,
          categoryId: 'beauty',
          categoryName: '美妆护理',
        ).copyWith(merchant: '护肤'),
    ];
    final analysis = const StatisticalAnalysisService().analyze(
      transactions,
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final dining = Category(
      id: 'food',
      name: '餐饮',
      icon: 'food',
      type: CategoryType.expense,
      sortOrder: 0,
      isDefault: true,
      isArchived: false,
    );
    final feed = const FinancialInsightEngine().build(
      transactions: transactions,
      analysis: analysis,
      budgets: BudgetOverview(
        categories: [
          BudgetProgress(
            budget: Budget(
              id: 'food-budget',
              monthKey: '2026-09',
              categoryId: 'food',
              amount: 400,
              createdAt: now,
              updatedAt: now,
            ),
            category: dining,
            used: 260,
            remaining: 140,
            percentage: .65,
            remainingDays: 21,
            dailyAvailable: 6.67,
            status: BudgetAlertStatus.normal,
          ),
        ],
      ),
      accounts: const [],
      categories: [dining],
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.controlSpending},
        focus: {InsightFocus.dining, InsightFocus.healthHabits},
        configured: true,
      ),
      now: now,
    );

    expect(feed.homeCandidate, isNotNull);
    expect(feed.homeCandidate!.id, 'budget:2026-09:category:food');
    expect(
      feed.items.any((item) => item.id == 'life:beauty-care'),
      isTrue,
    );
  });

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

  test('ambiguous family transfers do not become family-support insights', () {
    final transactions = [
      ..._history(now),
      TransactionRecord(
        id: 'transfer-family-1',
        bookId: 'book-personal',
        type: TransactionType.transfer,
        amount: 800,
        accountId: 'cash',
        note: '给妈妈',
        occurredAt: now.subtract(const Duration(days: 5)),
        createdAt: now,
        updatedAt: now,
      ),
      TransactionRecord(
        id: 'transfer-family-2',
        bookId: 'book-personal',
        type: TransactionType.transfer,
        amount: 600,
        accountId: 'cash',
        note: '给爸爸',
        occurredAt: now.subtract(const Duration(days: 9)),
        createdAt: now,
        updatedAt: now,
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

    expect(
      feed.items.any((item) => item.id == 'life:family-support'),
      isFalse,
    );
  });

  test('specific suspicious-record insight suppresses generic classification noise', () {
    final transactions = [
      for (var index = 0; index < 14; index++)
        TransactionRecord(
          id: 'import-$index',
          bookId: 'book-personal',
          type: TransactionType.expense,
          amount: 20,
          accountId: 'cash',
          occurredAt: now.subtract(Duration(days: index)),
          createdAt: now,
          updatedAt: now,
          source: TransactionSource.import,
          aiConfidence: .3,
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
      preferences: const InsightPreferences(configured: true),
      now: now,
    );

    expect(
      feed.items.any((item) => item.id == 'data:review-needed'),
      isTrue,
    );
    expect(
      feed.items.any((item) => item.id == 'data:classification'),
      isFalse,
    );
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

  test('offline engine notices concentrated recurring cashflow', () {
    final transactions = _history(now);
    final analysis = const StatisticalAnalysisService().analyze(
      transactions,
      period: AnalysisPeriod.currentMonth,
      now: now,
    );
    final recurring = [
      RecurringBill(
        id: 'rent',
        bookId: 'book-personal',
        name: '房租',
        type: RecurringBillType.rent,
        amount: 420,
        cycle: RecurringBillCycle.monthly,
        startDate: DateTime(2026, 1, 1),
        nextDate: now.add(const Duration(days: 3)),
        accountId: 'cash',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: now,
      ),
      RecurringBill(
        id: 'subscription',
        bookId: 'book-personal',
        name: '订阅',
        type: RecurringBillType.subscription,
        amount: 120,
        cycle: RecurringBillCycle.monthly,
        startDate: DateTime(2026, 1, 1),
        nextDate: now.add(const Duration(days: 5)),
        accountId: 'cash',
        createdAt: DateTime(2026, 1, 1),
        updatedAt: now,
      ),
    ];
    final feed = const FinancialInsightEngine().build(
      transactions: transactions,
      analysis: analysis,
      budgets: const BudgetOverview(categories: []),
      accounts: [
        Account(
          id: 'cash',
          name: '现金',
          type: AccountType.cash,
          balance: 600,
          currency: 'CNY',
          icon: 'wallet',
          color: 0,
          sortOrder: 0,
          isArchived: false,
          assetForm: AssetForm.cash,
          createdAt: DateTime(2026, 1, 1),
          updatedAt: now,
        ),
      ],
      recurringBills: recurring,
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.optimizeFinances},
        configured: true,
      ),
      now: now,
    );

    expect(
      feed.items.any((item) => item.id == 'cashflow:upcoming-recurring'),
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
  String categoryId = 'food',
  String categoryName = '餐饮',
}) {
  return TransactionRecord(
    id: id,
    bookId: 'book-personal',
    type: TransactionType.expense,
    amount: amount,
    categoryId: categoryId,
    categoryName: categoryName,
    accountId: 'cash',
    note: note,
    occurredAt: date,
    createdAt: date,
    updatedAt: date,
  );
}
