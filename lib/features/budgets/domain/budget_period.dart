import '../../../core/models/budget.dart';
import '../../../core/models/category.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/transaction_record.dart';

enum BudgetPeriodKind { month, year, custom }

/// Calendar dates; the end is exclusive, including across DST boundaries.
class BudgetPeriod {
  BudgetPeriod(DateTime start, DateTime end, this.kind)
    : start = DateTime(start.year, start.month, start.day),
      end = DateTime(end.year, end.month, end.day) {
    if (!this.start.isBefore(this.end)) throw ArgumentError('日期范围无效');
  }
  factory BudgetPeriod.month(DateTime date) => BudgetPeriod(
    DateTime(date.year, date.month),
    DateTime(date.year, date.month + 1),
    BudgetPeriodKind.month,
  );
  factory BudgetPeriod.year(DateTime date) => BudgetPeriod(
    DateTime(date.year),
    DateTime(date.year + 1),
    BudgetPeriodKind.year,
  );
  final DateTime start;
  final DateTime end;
  final BudgetPeriodKind kind;
  static int daysBetween(DateTime a, DateTime b) => DateTime.utc(
    b.year,
    b.month,
    b.day,
  ).difference(DateTime.utc(a.year, a.month, a.day)).inDays;
  int get days => daysBetween(start, end);
  Iterable<DateTime> get months sync* {
    for (
      var date = DateTime(start.year, start.month);
      date.isBefore(end);
      date = DateTime(date.year, date.month + 1)
    ) {
      yield date;
    }
  }

  double monthWeight(DateTime month) {
    final next = DateTime(month.year, month.month + 1);
    final first = start.isAfter(month) ? start : month;
    final last = end.isBefore(next) ? end : next;
    return first.isBefore(last)
        ? daysBetween(first, last) / daysBetween(month, next)
        : 0;
  }

  BudgetPeriod get previous => switch (kind) {
    BudgetPeriodKind.month => BudgetPeriod.month(
      DateTime(start.year, start.month - 1),
    ),
    BudgetPeriodKind.year => BudgetPeriod.year(DateTime(start.year - 1)),
    BudgetPeriodKind.custom => BudgetPeriod(
      DateTime(start.year, start.month, start.day - days),
      start,
      kind,
    ),
  };
  bool contains(DateTime date) => !date.isBefore(start) && date.isBefore(end);
  DateTime get lastDay => DateTime(end.year, end.month, end.day - 1);
  String get label => switch (kind) {
    BudgetPeriodKind.month => '${start.year}年${start.month}月',
    BudgetPeriodKind.year => '${start.year}年',
    BudgetPeriodKind.custom =>
      '${start.month}/${start.day}–${lastDay.month}/${lastDay.day}',
  };
  String get description =>
      '${start.year}/${start.month}/${start.day} — '
      '${DateTime(end.year, end.month, end.day - 1).year}/'
      '${DateTime(end.year, end.month, end.day - 1).month}/'
      '${DateTime(end.year, end.month, end.day - 1).day}';
  String get noun => switch (kind) {
    BudgetPeriodKind.month => '本月',
    BudgetPeriodKind.year => '本年',
    BudgetPeriodKind.custom => '此期间',
  };
  @override
  bool operator ==(Object other) =>
      other is BudgetPeriod &&
      start == other.start &&
      end == other.end &&
      kind == other.kind;
  @override
  int get hashCode => Object.hash(start, end, kind);
}

class BudgetPeriodOverview {
  const BudgetPeriodOverview({
    required this.period,
    required this.overview,
    required this.spent,
    required this.previousSpent,
    required this.previousCategorySpending,
  });
  final BudgetPeriod period;
  final BudgetOverview overview;
  final double spent;
  final double previousSpent;
  final Map<String, double> previousCategorySpending;
  double? get changePercent =>
      previousSpent > 0 ? (spent - previousSpent) / previousSpent * 100 : null;
  double get dailyBudget => (overview.total?.budget.amount ?? 0) / period.days;
  BudgetProgress? get leadingCategory {
    final rows = [...overview.categories]
      ..sort((a, b) => b.used.compareTo(a.used));
    return rows.where((row) => row.used > 0).firstOrNull;
  }
}

/// Same expense and reservation semantics as monthly budgeting. A period
/// aggregates only stored budgets; partial months are prorated by calendar day.
class BudgetPeriodService {
  const BudgetPeriodService();
  BudgetPeriodOverview calculate({
    required BudgetPeriod period,
    required String bookId,
    required List<Budget> budgets,
    required List<TransactionRecord> transactions,
    required List<Category> categories,
    required List<Goal> goals,
    required DateTime now,
  }) {
    final categoryMap = {
      for (final c in categories.where((c) => c.bookId == bookId)) c.id: c,
    };
    final expenses = transactions
        .where(
          (t) =>
              t.bookId == bookId &&
              t.isConsumptionExpense &&
              t.currency.toUpperCase() == 'CNY' &&
              t.deletedAt == null &&
              !t.occurredAt.isAfter(now),
        )
        .toList();
    bool matches(TransactionRecord t, String id) =>
        t.categoryId == id ||
        t.subcategoryId == id ||
        categoryMap[t.categoryId]?.parentId == id ||
        categoryMap[t.subcategoryId]?.parentId == id;
    double spent(BudgetPeriod range, [String? id]) =>
        expenses
            .where(
              (t) =>
                  range.contains(t.occurredAt) &&
                  (id == null || matches(t, id)),
            )
            .fold<int>(
              0,
              (sum, t) => sum + (t.personalExpenseAmount * 100).round(),
            ) /
        100;
    final amounts = <String?, int>{};
    for (final budget in budgets.where((b) => b.bookId == bookId)) {
      final month = DateTime.tryParse('${budget.monthKey}-01');
      if (month == null) continue;
      final weight = period.monthWeight(month);
      if (weight <= 0) continue;
      amounts.update(
        budget.categoryId,
        (value) => value + (budget.amount * 100 * weight).round(),
        ifAbsent: () => (budget.amount * 100 * weight).round(),
      );
    }
    final monthlyReservation = goals
        .where((g) => g.bookId == bookId && g.status == GoalStatus.active)
        .fold<int>(0, (sum, g) => sum + (g.monthlyReservation * 100).round());
    final reservation =
        (monthlyReservation *
                period.months.fold<double>(
                  0,
                  (sum, month) => sum + period.monthWeight(month),
                ))
            .round() /
        100;
    final remainingStart = now.isAfter(period.start)
        ? DateTime(now.year, now.month, now.day)
        : period.start;
    final remainingDays = BudgetPeriod.daysBetween(
      remainingStart,
      period.end,
    ).clamp(0, period.days);
    BudgetProgress progress(String? id, int cents) {
      final amount = cents / 100;
      final used = spent(period, id);
      final reserved = id == null ? reservation : 0.0;
      final remaining =
          (cents - (used * 100).round() - (reserved * 100).round()) / 100;
      final ratio = amount > 0 ? (used + reserved) / amount : 0.0;
      return BudgetProgress(
        budget: Budget(
          id: 'period-${period.start.toIso8601String()}-${id ?? 'total'}',
          bookId: bookId,
          monthKey:
              '${period.start.year}-${period.start.month.toString().padLeft(2, '0')}',
          amount: amount,
          categoryId: id,
          createdAt: now,
          updatedAt: now,
        ),
        category: categoryMap[id],
        used: used,
        remaining: remaining,
        percentage: ratio,
        remainingDays: remainingDays,
        goalReservation: reserved,
        dailyAvailable: remainingDays == 0
            ? 0
            : remaining.clamp(0, double.infinity) / remainingDays,
        status: ratio > 1
            ? BudgetAlertStatus.exceeded
            : ratio >= .8
            ? BudgetAlertStatus.nearLimit
            : BudgetAlertStatus.normal,
      );
    }

    return BudgetPeriodOverview(
      period: period,
      spent: spent(period),
      previousSpent: spent(period.previous),
      previousCategorySpending: {
        for (final id in amounts.keys.whereType<String>())
          id: spent(period.previous, id),
      },
      overview: BudgetOverview(
        total: amounts.containsKey(null)
            ? progress(null, amounts[null]!)
            : null,
        categories: [
          for (final entry in amounts.entries)
            if (entry.key != null) progress(entry.key, entry.value),
        ],
      ),
    );
  }
}
