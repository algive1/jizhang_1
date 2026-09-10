enum AnalysisPeriod {
  last7Days,
  last30Days,
  last90Days,
  currentMonth,
  previousMonth,
  currentYear,
}

extension AnalysisPeriodLabel on AnalysisPeriod {
  String get label => switch (this) {
    AnalysisPeriod.last7Days => '近7天',
    AnalysisPeriod.last30Days => '近30天',
    AnalysisPeriod.last90Days => '近90天',
    AnalysisPeriod.currentMonth => '本月',
    AnalysisPeriod.previousMonth => '上月',
    AnalysisPeriod.currentYear => '本年',
  };
}

enum TimeSegment {
  earlyMorning,
  dawn,
  morning,
  noon,
  afternoon,
  evening,
  lateNight,
}

extension TimeSegmentLabel on TimeSegment {
  String get label => switch (this) {
    TimeSegment.earlyMorning => '凌晨',
    TimeSegment.dawn => '清晨',
    TimeSegment.morning => '上午',
    TimeSegment.noon => '中午',
    TimeSegment.afternoon => '下午',
    TimeSegment.evening => '晚间',
    TimeSegment.lateNight => '深夜',
  };
}

enum TransactionBehaviorType {
  regular,
  recurring,
  oneTime,
  largeOneTime,
  assetPurchase,
}

enum SpendingAttributionType { frequency, averageTicket, mixed }

extension SpendingAttributionTypeLabel on SpendingAttributionType {
  String get label => switch (this) {
    SpendingAttributionType.frequency => '消费次数',
    SpendingAttributionType.averageTicket => '单次金额',
    SpendingAttributionType.mixed => '次数和单价共同',
  };
}

enum AnalysisInsightType {
  categoryIncrease,
  lateNightIncrease,
  weekendIncrease,
  deliveryIncrease,
}

enum AnalysisInsightSeverity { info, attention, important }

class AnalysisDateRange {
  const AnalysisDateRange({required this.start, required this.endExclusive});

  final DateTime start;
  final DateTime endExclusive;

  int get dayCount => endExclusive.difference(start).inDays;

  bool contains(DateTime value) =>
      !value.isBefore(start) && value.isBefore(endExclusive);
}

class CategoryTrend {
  const CategoryTrend({
    required this.categoryId,
    required this.name,
    required this.currentAmount,
    required this.previousAmount,
    required this.currentCount,
    required this.previousCount,
    required this.attribution,
  });

  final String categoryId;
  final String name;
  final double currentAmount;
  final double previousAmount;
  final int currentCount;
  final int previousCount;
  final SpendingAttributionType attribution;

  double get amountDelta => currentAmount - previousAmount;
  double get changePercent => previousAmount == 0
      ? (currentAmount == 0 ? 0 : 100)
      : amountDelta / previousAmount * 100;
  double get currentAverage =>
      currentCount == 0 ? 0 : currentAmount / currentCount;
  double get previousAverage =>
      previousCount == 0 ? 0 : previousAmount / previousCount;
}

class BehaviorBaseline {
  const BehaviorBaseline({
    required this.windowDays,
    required this.dailyRegularSpending,
    required this.lateNightDailyAmount,
    required this.lateNightDailyCount,
    required this.weekendDailySpending,
  });

  final int windowDays;
  final double dailyRegularSpending;
  final double lateNightDailyAmount;
  final double lateNightDailyCount;
  final double weekendDailySpending;
}

class AnalysisInsight {
  const AnalysisInsight({
    required this.id,
    required this.type,
    required this.title,
    required this.description,
    required this.metricName,
    required this.period,
    required this.amount,
    required this.baselineAmount,
    required this.deltaAmount,
    required this.deltaPercent,
    required this.severity,
    required this.reasonCode,
    this.categoryId,
    this.timeSegment,
    this.metadata = const {},
    required this.generatedAt,
  });

  final String id;
  final AnalysisInsightType type;
  final String title;
  final String description;
  final String metricName;
  final AnalysisPeriod period;
  final double amount;
  final double baselineAmount;
  final double deltaAmount;
  final double deltaPercent;
  final AnalysisInsightSeverity severity;
  final String reasonCode;
  final String? categoryId;
  final TimeSegment? timeSegment;
  final Map<String, Object?> metadata;
  final DateTime generatedAt;

  // Compatibility aliases for callers that still use the original names.
  double get currentValue => amount;
  double get baselineValue => baselineAmount;
  double get changePercent => deltaPercent;
}

class CashflowPoint {
  const CashflowPoint(this.date, this.income, this.expense);
  final DateTime date;
  final double income;
  final double expense;
}

class CashflowCategory {
  const CashflowCategory(
    this.id,
    this.name,
    this.amount,
    this.count, {
    this.icon,
  });
  final String id;
  final String name;
  final double amount;
  final int count;
  final String? icon;
}

class AnalysisSnapshot {
  const AnalysisSnapshot({
    required this.period,
    required this.range,
    required this.previousRange,
    required this.totalIncome,
    required this.netCashflow,
    required this.totalExpense,
    required this.regularExpense,
    required this.excludedLargeExpense,
    required this.previousRegularExpense,
    required this.transactionCount,
    required this.heatmap,
    required this.segmentAmounts,
    required this.categoryTrends,
    required this.insights,
    required this.baselines,
    this.currency = 'CNY',
    this.cashflowTrend = const [],
    this.incomeCategories = const [],
    this.expenseCategories = const [],
    this.incomeCount = 0,
    this.expenseCount = 0,
  });

  final AnalysisPeriod period;
  final AnalysisDateRange range;
  final AnalysisDateRange previousRange;
  final double totalIncome;
  final double netCashflow;
  final double totalExpense;
  final double regularExpense;
  final double excludedLargeExpense;
  final double previousRegularExpense;
  final int transactionCount;
  final List<List<double>> heatmap;
  final Map<TimeSegment, double> segmentAmounts;
  final List<CategoryTrend> categoryTrends;
  final List<AnalysisInsight> insights;
  final List<BehaviorBaseline> baselines;
  final String currency;
  final List<CashflowPoint> cashflowTrend;
  final List<CashflowCategory> incomeCategories;
  final List<CashflowCategory> expenseCategories;
  final int incomeCount;
  final int expenseCount;

  double get regularChangePercent => previousRegularExpense == 0
      ? 0
      : (regularExpense - previousRegularExpense) /
            previousRegularExpense *
            100;

  bool get hasComparableBaseline => previousRegularExpense > 0;
}
