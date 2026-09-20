import '../../../core/models/analysis.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/utils/transaction_semantic_text.dart';
import '../../intelligence/domain/financial_truth_service.dart';

class TransactionFeatureService {
  const TransactionFeatureService();

  TimeSegment segmentFor(DateTime value) => switch (value.hour) {
    < 5 => TimeSegment.earlyMorning,
    < 8 => TimeSegment.dawn,
    < 11 => TimeSegment.morning,
    < 14 => TimeSegment.noon,
    < 17 => TimeSegment.afternoon,
    < 22 => TimeSegment.evening,
    _ => TimeSegment.lateNight,
  };

  bool isWeekend(DateTime value) =>
      value.weekday == DateTime.saturday || value.weekday == DateTime.sunday;

  TransactionBehaviorType behaviorFor(
    TransactionRecord transaction, {
    required bool distributionOutlier,
  }) {
    if (transaction.type == TransactionType.assetPurchase) {
      return TransactionBehaviorType.assetPurchase;
    }
    if (transaction.isRecurring) return TransactionBehaviorType.recurring;
    if (transaction.isLargeTransaction || distributionOutlier) {
      return TransactionBehaviorType.largeOneTime;
    }
    if (transaction.isOneTime) return TransactionBehaviorType.oneTime;
    return TransactionBehaviorType.regular;
  }
}

class LargeTransactionDetector {
  const LargeTransactionDetector({this.fixedThreshold = 3000});

  final double fixedThreshold;

  double distributionThreshold(Iterable<TransactionRecord> transactions) {
    final amounts =
        transactions
            .where(
              (item) => item.isConsumptionExpense,
            )
            .map((item) => item.personalExpenseAmount)
            .where((amount) => amount > 0)
            .toList()
          ..sort();
    if (amounts.length < 5) return fixedThreshold;
    final middle = amounts.length ~/ 2;
    final median = amounts.length.isOdd
        ? amounts[middle]
        : (amounts[middle - 1] + amounts[middle]) / 2;
    return (median * 5).clamp(500, fixedThreshold).toDouble();
  }

  bool isLarge(
    TransactionRecord item,
    Iterable<TransactionRecord> history, {
    double? threshold,
  }) {
    if (item.type == TransactionType.assetPurchase || item.isLargeTransaction) {
      return true;
    }
    return item.personalExpenseAmount >= fixedThreshold ||
        item.personalExpenseAmount >=
            (threshold ?? distributionThreshold(history));
  }
}

class StatisticalAnalysisService {
  const StatisticalAnalysisService({
    this.features = const TransactionFeatureService(),
    this.largeDetector = const LargeTransactionDetector(),
    this.truth = const FinancialTruthService(),
  });

  final TransactionFeatureService features;
  final LargeTransactionDetector largeDetector;
  final FinancialTruthService truth;

  AnalysisSnapshot analyze(
    List<TransactionRecord> allTransactions, {
    AnalysisPeriod period = AnalysisPeriod.currentMonth,
    String currency = 'CNY',
    DateTime? now,
    DateTime? month,
  }) {
    final clock = now ?? DateTime.now();
    allTransactions = truth.normalizeForAnalysis(
      allTransactions,
      currency: currency,
      now: clock,
    );
    final selectedCurrent =
        month != null && month.year == clock.year && month.month == clock.month;
    final range = month == null
        ? rangeFor(period, clock)
        : selectedCurrent
        ? rangeFor(AnalysisPeriod.currentMonth, clock)
        : AnalysisDateRange(
            start: DateTime(month.year, month.month),
            endExclusive: DateTime(month.year, month.month + 1),
          );
    final previousRange = month != null
        ? (selectedCurrent
              ? _previousComparableMonthRange(clock)
              : AnalysisDateRange(
                  start: DateTime(month.year, month.month - 1),
                  endExclusive: DateTime(month.year, month.month),
                ))
        : switch (period) {
            AnalysisPeriod.currentMonth => _previousComparableMonthRange(clock),
            AnalysisPeriod.currentYear => AnalysisDateRange(
              start: DateTime(clock.year - 1),
              endExclusive: DateTime(
                clock.year - 1,
                clock.month,
                clock.day.clamp(
                      1,
                      DateTime(clock.year - 1, clock.month + 1, 0).day,
                    ) +
                    1,
              ),
            ),
            AnalysisPeriod.previousMonth => AnalysisDateRange(
              start: DateTime(clock.year, clock.month - 2),
              endExclusive: DateTime(clock.year, clock.month - 1),
            ),
            _ => AnalysisDateRange(
              start: range.start.subtract(Duration(days: range.dayCount)),
              endExclusive: range.start,
            ),
          };
    final expenses = allTransactions
        .where(truth.isPersonalConsumption)
        .toList(growable: false);
    final current = expenses
        .where(
          (item) =>
              range.contains(item.occurredAt) &&
              !item.occurredAt.isAfter(clock),
        )
        .toList();
    final previous = expenses
        .where((item) => previousRange.contains(item.occurredAt))
        .toList();
    final currentRegular = _regularTransactions(current, expenses);
    final previousRegular = _regularTransactions(previous, expenses);
    final total = _sum(current);
    final regular = _sum(currentRegular);
    final previousRegularAmount = _sum(previousRegular);
    final incomes = allTransactions
        .where(
          (item) =>
              truth.isEarnedIncome(item) && range.contains(item.occurredAt),
        )
        .toList();

    return AnalysisSnapshot(
      period: period,
      range: range,
      previousRange: previousRange,
      totalIncome: _sum(incomes),
      netCashflow: _sum(incomes) - total,
      currency: currency,
      incomeCount: incomes.length,
      expenseCount: current.length,
      cashflowTrend: _cashflowTrend(range, incomes, current),
      incomeCategories: _cashflowCategories(incomes),
      expenseCategories: _cashflowCategories(current),
      totalExpense: total,
      regularExpense: regular,
      excludedLargeExpense: total - regular,
      previousRegularExpense: previousRegularAmount,
      transactionCount: currentRegular.length,
      heatmap: _heatmap(currentRegular),
      segmentAmounts: _segmentAmounts(currentRegular),
      categoryTrends: _categoryTrends(currentRegular, previousRegular),
      insights: _insights(
        currentRegular,
        previousRegular,
        period: period,
        generatedAt: clock,
        currency: currency,
      ),
      baselines: [
        for (final days in const [7, 30, 90, 180])
          _baseline(expenses, clock, days),
      ],
    );
  }

  AnalysisDateRange rangeFor(AnalysisPeriod period, DateTime now) {
    final today = DateTime(now.year, now.month, now.day);
    return switch (period) {
      AnalysisPeriod.currentYear => AnalysisDateRange(
        start: DateTime(now.year),
        endExclusive: today.add(const Duration(days: 1)),
      ),
      AnalysisPeriod.last7Days => AnalysisDateRange(
        start: today.subtract(const Duration(days: 6)),
        endExclusive: today.add(const Duration(days: 1)),
      ),
      AnalysisPeriod.last30Days => AnalysisDateRange(
        start: today.subtract(const Duration(days: 29)),
        endExclusive: today.add(const Duration(days: 1)),
      ),
      AnalysisPeriod.last90Days => AnalysisDateRange(
        start: today.subtract(const Duration(days: 89)),
        endExclusive: today.add(const Duration(days: 1)),
      ),
      AnalysisPeriod.currentMonth => AnalysisDateRange(
        start: DateTime(now.year, now.month),
        endExclusive: today.add(const Duration(days: 1)),
      ),
      AnalysisPeriod.previousMonth => AnalysisDateRange(
        start: DateTime(now.year, now.month - 1),
        endExclusive: DateTime(now.year, now.month),
      ),
    };
  }

  AnalysisDateRange _previousComparableMonthRange(DateTime now) {
    final start = DateTime(now.year, now.month - 1);
    final lastDay = DateTime(now.year, now.month, 0).day;
    final comparableDay = now.day.clamp(1, lastDay);
    return AnalysisDateRange(
      start: start,
      endExclusive: DateTime(start.year, start.month, comparableDay + 1),
    );
  }

  List<CashflowPoint> _cashflowTrend(
    AnalysisDateRange range,
    List<TransactionRecord> incomes,
    List<TransactionRecord> expenses,
  ) {
    final values = <DateTime, List<int>>{};
    for (var kind = 0; kind < 2; kind++) {
      for (final item in kind == 0 ? incomes : expenses) {
        final date = DateTime(
          item.occurredAt.year,
          item.occurredAt.month,
          item.occurredAt.day,
        );
        values.putIfAbsent(date, () => [0, 0])[kind] +=
            ((kind == 1 ? item.personalExpenseAmount : item.amount) * 100)
                .round();
      }
    }
    return [
      for (var i = 0; i < range.dayCount; i++)
        CashflowPoint(
          range.start.add(Duration(days: i)),
          (values[range.start.add(Duration(days: i))]?[0] ?? 0) / 100,
          (values[range.start.add(Duration(days: i))]?[1] ?? 0) / 100,
        ),
    ];
  }

  List<CashflowCategory> _cashflowCategories(List<TransactionRecord> records) {
    final groups = <String, List<TransactionRecord>>{};
    for (final record in records) {
      groups.putIfAbsent(_categoryKey(record), () => []).add(record);
    }
    return groups.entries
        .map(
          (entry) => CashflowCategory(
            entry.key,
            entry.value.first.categoryName ?? '未分类',
            _sum(entry.value),
            entry.value.length,
            icon: entry.value.first.categoryIcon,
          ),
        )
        .toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
  }

  List<TransactionRecord> _regularTransactions(
    List<TransactionRecord> candidates,
    List<TransactionRecord> history,
  ) {
    final threshold = largeDetector.distributionThreshold(history);
    return candidates
        .where((item) {
          final behavior = features.behaviorFor(
            item,
            distributionOutlier: largeDetector.isLarge(
              item,
              history,
              threshold: threshold,
            ),
          );
          return behavior != TransactionBehaviorType.largeOneTime &&
              behavior != TransactionBehaviorType.assetPurchase;
        })
        .toList(growable: false);
  }

  List<List<double>> _heatmap(List<TransactionRecord> items) {
    final values = List.generate(7, (_) => List<double>.filled(24, 0));
    for (final item in items) {
      values[item.occurredAt.weekday - 1][item.occurredAt.hour] +=
          item.netExpenseAmount;
    }
    return values;
  }

  Map<TimeSegment, double> _segmentAmounts(List<TransactionRecord> items) {
    final result = {for (final segment in TimeSegment.values) segment: 0.0};
    for (final item in items) {
      final segment = features.segmentFor(item.occurredAt);
      result[segment] = result[segment]! + item.netExpenseAmount;
    }
    return result;
  }

  List<CategoryTrend> _categoryTrends(
    List<TransactionRecord> current,
    List<TransactionRecord> previous,
  ) {
    final keys = <String>{
      ...current.map(_categoryKey),
      ...previous.map(_categoryKey),
    };
    final trends = keys.map((key) {
      final currentItems = current
          .where((item) => _categoryKey(item) == key)
          .toList();
      final previousItems = previous
          .where((item) => _categoryKey(item) == key)
          .toList();
      final currentAmount = _sum(currentItems);
      final previousAmount = _sum(previousItems);
      return CategoryTrend(
        categoryId: key,
        name:
            currentItems.firstOrNull?.categoryName ??
            previousItems.firstOrNull?.categoryName ??
            '未分类',
        currentAmount: currentAmount,
        previousAmount: previousAmount,
        currentCount: currentItems.length,
        previousCount: previousItems.length,
        attribution: _attribution(
          currentAmount,
          previousAmount,
          currentItems.length,
          previousItems.length,
        ),
      );
    }).toList()..sort((a, b) => b.currentAmount.compareTo(a.currentAmount));
    return trends;
  }

  SpendingAttributionType _attribution(
    double currentAmount,
    double previousAmount,
    int currentCount,
    int previousCount,
  ) {
    if (currentCount == 0 || previousCount == 0) {
      return currentCount > previousCount
          ? SpendingAttributionType.frequency
          : SpendingAttributionType.averageTicket;
    }
    final previousAverage = previousAmount / previousCount;
    final currentAverage = currentAmount / currentCount;
    final frequencyImpact = (currentCount - previousCount) * previousAverage;
    final ticketImpact = (currentAverage - previousAverage) * currentCount;
    if (frequencyImpact.abs() > ticketImpact.abs() * 1.25) {
      return SpendingAttributionType.frequency;
    }
    if (ticketImpact.abs() > frequencyImpact.abs() * 1.25) {
      return SpendingAttributionType.averageTicket;
    }
    return SpendingAttributionType.mixed;
  }

  List<AnalysisInsight> _insights(
    List<TransactionRecord> current,
    List<TransactionRecord> previous, {
    required AnalysisPeriod period,
    required DateTime generatedAt,
    required String currency,
  }) {
    final insights = <AnalysisInsight>[];
    final trends = _categoryTrends(current, previous);
    for (final trend in trends) {
      if (trend.amountDelta < 100 ||
          trend.previousAmount == 0 ||
          trend.changePercent < 30) {
        continue;
      }
      var reasonCode = switch (trend.attribution) {
        SpendingAttributionType.frequency => 'frequency_increase',
        SpendingAttributionType.averageTicket => 'average_ticket_increase',
        SpendingAttributionType.mixed => 'frequency_and_ticket_increase',
      };
      var reasonText = '${trend.attribution.label}增加';
      final categoryCurrent = current.where(
        (item) => _categoryKey(item) == trend.categoryId,
      );
      final categoryPrevious = previous.where(
        (item) => _categoryKey(item) == trend.categoryId,
      );
      final deliveryCount = categoryCurrent.where(_isDelivery).length;
      final previousDeliveryCount = categoryPrevious.where(_isDelivery).length;
      if (deliveryCount >= 2 &&
          deliveryCount > previousDeliveryCount &&
          deliveryCount * 2 >= trend.currentCount) {
        reasonCode = 'delivery_frequency_increase';
        reasonText = '外卖次数增加';
      } else {
        final lateCount = categoryCurrent.where(_isLateNight).length;
        final previousLateCount = categoryPrevious.where(_isLateNight).length;
        if (lateCount >= 2 &&
            lateCount > previousLateCount &&
            lateCount * 2 >= trend.currentCount) {
          reasonCode = 'late_night_frequency_increase';
          reasonText = '深夜消费次数增加';
        }
      }
      insights.add(
        AnalysisInsight(
          id: 'category:${trend.categoryId}',
          type: reasonCode.startsWith('delivery')
              ? AnalysisInsightType.deliveryIncrease
              : AnalysisInsightType.categoryIncrease,
          title: '${trend.name}支出增加',
          description:
              '较上一同期增加 $currency ${trend.amountDelta.toStringAsFixed(2)}，主要来自$reasonText。',
          metricName: '分类消费金额',
          period: period,
          amount: trend.currentAmount,
          baselineAmount: trend.previousAmount,
          deltaAmount: trend.amountDelta,
          deltaPercent: trend.changePercent,
          severity: trend.changePercent >= 80
              ? AnalysisInsightSeverity.important
              : AnalysisInsightSeverity.attention,
          reasonCode: reasonCode,
          categoryId: trend.categoryId,
          metadata: {
            'currentCount': trend.currentCount,
            'previousCount': trend.previousCount,
            'attribution': trend.attribution.name,
          },
          generatedAt: generatedAt,
        ),
      );
    }

    final currentLate = current.where(_isLateNight).toList();
    final previousLate = previous.where(_isLateNight).toList();
    final lateDelta = _sum(currentLate) - _sum(previousLate);
    final latePercent = _percentChange(_sum(currentLate), _sum(previousLate));
    if (lateDelta >= 100 &&
        _sum(previousLate) > 0 &&
        latePercent >= 30 &&
        currentLate.length >= 2 &&
        currentLate.length > previousLate.length) {
      insights.add(
        AnalysisInsight(
          id: 'time:late-night',
          type: AnalysisInsightType.lateNightIncrease,
          title: '深夜消费上升',
          description:
              '22:00 后消费 ${currentLate.length} 次，比上一同期多 ${currentLate.length - previousLate.length} 次。',
          metricName: '深夜消费金额',
          period: period,
          amount: _sum(currentLate),
          baselineAmount: _sum(previousLate),
          deltaAmount: lateDelta,
          deltaPercent: latePercent,
          severity: AnalysisInsightSeverity.attention,
          reasonCode: 'late_night_amount_and_count_increase',
          timeSegment: TimeSegment.lateNight,
          metadata: {
            'currentCount': currentLate.length,
            'previousCount': previousLate.length,
          },
          generatedAt: generatedAt,
        ),
      );
    }
    return insights..sort((a, b) => b.changePercent.compareTo(a.changePercent));
  }

  BehaviorBaseline _baseline(
    List<TransactionRecord> expenses,
    DateTime now,
    int days,
  ) {
    // A baseline describes prior behavior. Exclude today's partial data so a
    // spike on the current day cannot raise its own comparison bar.
    final end = DateTime(now.year, now.month, now.day);
    final start = end.subtract(Duration(days: days));
    final values = expenses
        .where(
          (item) =>
              !item.occurredAt.isBefore(start) && item.occurredAt.isBefore(end),
        )
        .toList();
    final regular = _regularTransactions(values, expenses);
    final weekendDays = List.generate(
      days,
      (index) => start.add(Duration(days: index)),
    ).where(features.isWeekend).length;
    return BehaviorBaseline(
      windowDays: days,
      dailyRegularSpending: _sum(regular) / days,
      lateNightDailyAmount: _sum(regular.where(_isLateNight)) / days,
      lateNightDailyCount: regular.where(_isLateNight).length / days,
      weekendDailySpending: weekendDays == 0
          ? 0
          : _sum(regular.where((item) => features.isWeekend(item.occurredAt))) /
                weekendDays,
    );
  }

  String _categoryKey(TransactionRecord item) {
    final name = item.categoryName?.trim();
    if (name != null && name.isNotEmpty) return 'name:$name';
    final id = item.categoryId?.trim();
    if (id != null && id.isNotEmpty) return 'id:${item.bookId}:$id';
    return 'uncategorized';
  }

  bool _isLateNight(TransactionRecord item) => item.occurredAt.hour >= 22;

  bool _isDelivery(TransactionRecord item) {
    final source = transactionSemanticText(item).toLowerCase();
    return const ['外卖', '美团', '饿了么', 'eleme', 'delivery'].any(source.contains);
  }

  double _sum(Iterable<TransactionRecord> items) =>
      items.fold<int>(
        0,
        (total, item) =>
            total +
            ((item.isConsumptionExpense
                        ? item.personalExpenseAmount
                        : item.amount) *
                    100)
                .round(),
      ) /
      100;

  double _percentChange(double current, double previous) => previous == 0
      ? (current == 0 ? 0 : 100)
      : (current - previous) / previous * 100;
}
