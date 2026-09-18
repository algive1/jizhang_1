enum RecurringBillType {
  membership,
  mortgage,
  rent,
  carLoan,
  insurance,
  subscription,
  mobilePlan,
  income,
  other,
}

enum RecurringBillCycle {
  daily,
  weekly,
  monthly,
  quarterly,
  halfYear,
  yearly,
  custom,
}

enum RecurringBillStatus { active, paused, ended }

class RecurringBill {
  const RecurringBill({
    required this.id,
    required this.bookId,
    required this.name,
    required this.type,
    required this.amount,
    required this.cycle,
    required this.startDate,
    this.endDate,
    this.interval = 1,
    this.weekday,
    this.dayOfMonth,
    this.month,
    this.repeatCount,
    this.completedCount = 0,
    this.reminderDays = 1,
    this.subcategoryId,
    required this.nextDate,
    this.accountId,
    this.categoryId,
    this.customIntervalDays,
    this.autoRecord = false,
    this.reminder = true,
    this.status = RecurringBillStatus.active,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String bookId;
  final String name;
  final RecurringBillType type;
  final double amount;
  final RecurringBillCycle cycle;
  final DateTime startDate;
  final DateTime? endDate;
  final int interval;
  final int? weekday;

  /// -1 means the last day of the month.
  final int? dayOfMonth;
  final int? month;
  final int? repeatCount;
  final int completedCount;
  final int reminderDays;
  final String? subcategoryId;
  final DateTime nextDate;
  final String? accountId;
  final String? categoryId;
  final int? customIntervalDays;
  final bool autoRecord;
  final bool reminder;
  final RecurringBillStatus status;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isIncome => type == RecurringBillType.income;

  String get endType => repeatCount != null
      ? 'count'
      : endDate != null
      ? 'date'
      : 'never';

  String get scheduleLabel {
    final unit = switch (cycle) {
      RecurringBillCycle.daily => '天',
      RecurringBillCycle.weekly => '周',
      RecurringBillCycle.monthly => '月',
      RecurringBillCycle.yearly => '年',
      RecurringBillCycle.quarterly => '季度',
      RecurringBillCycle.halfYear => '半年',
      RecurringBillCycle.custom => '$customIntervalDays 天',
    };
    final prefix = interval == 1 ? '每$unit' : '每 $interval $unit';
    return switch (cycle) {
      RecurringBillCycle.weekly =>
        '$prefix · 周${'一二三四五六日'[(weekday ?? startDate.weekday) - 1]}',
      RecurringBillCycle.daily || RecurringBillCycle.custom => prefix,
      _ =>
        '$prefix · ${cycle == RecurringBillCycle.yearly ? '${month ?? startDate.month}月' : ''}${dayOfMonth == -1 ? '最后一天' : '${dayOfMonth ?? startDate.day}日'}',
    };
  }

  /// First scheduled calendar date on/after effectiveness, preserving its anchor.
  DateTime firstOccurrence() {
    final start = DateTime(startDate.year, startDate.month, startDate.day);
    if (cycle == RecurringBillCycle.weekly) {
      return DateTime(
        start.year,
        start.month,
        start.day + ((weekday ?? start.weekday) - start.weekday + 7) % 7,
      );
    }
    if (cycle == RecurringBillCycle.daily || cycle == RecurringBillCycle.custom)
      return start;
    final targetMonth = cycle == RecurringBillCycle.yearly
        ? month ?? start.month
        : start.month;
    final last = DateTime(start.year, targetMonth + 1, 0).day;
    final candidate = DateTime(
      start.year,
      targetMonth,
      dayOfMonth == -1 ? last : (dayOfMonth ?? start.day).clamp(1, last),
    );
    return candidate.isBefore(start) ? nextOccurrence(candidate) : candidate;
  }

  RecurringBill copyWith({
    String? id,
    String? name,
    double? amount,
    DateTime? nextDate,
    RecurringBillStatus? status,
    DateTime? updatedAt,
    int? completedCount,
  }) => RecurringBill(
    id: id ?? this.id,
    bookId: bookId,
    name: name ?? this.name,
    type: type,
    amount: amount ?? this.amount,
    cycle: cycle,
    startDate: startDate,
    endDate: endDate,
    nextDate: nextDate ?? this.nextDate,
    accountId: accountId,
    categoryId: categoryId,
    subcategoryId: subcategoryId,
    customIntervalDays: customIntervalDays,
    interval: interval,
    weekday: weekday,
    dayOfMonth: dayOfMonth,
    month: month,
    repeatCount: repeatCount,
    completedCount: completedCount ?? this.completedCount,
    reminderDays: reminderDays,
    autoRecord: autoRecord,
    reminder: reminder,
    status: status ?? this.status,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  DateTime nextOccurrence(DateTime from) {
    final base = DateTime(from.year, from.month, from.day);
    return switch (cycle) {
      RecurringBillCycle.daily => DateTime(
        base.year,
        base.month,
        base.day + interval,
      ),
      RecurringBillCycle.weekly => DateTime(
        base.year,
        base.month,
        base.day + 7 * interval,
      ),
      RecurringBillCycle.monthly => _addMonths(base, 1 * interval),
      RecurringBillCycle.quarterly => _addMonths(base, 3 * interval),
      RecurringBillCycle.halfYear => _addMonths(base, 6 * interval),
      RecurringBillCycle.yearly => _addMonths(base, 12 * interval),
      RecurringBillCycle.custom => base.add(
        Duration(days: customIntervalDays ?? 30),
      ),
    };
  }

  DateTime _addMonths(DateTime base, int months) {
    final target = DateTime(base.year, base.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(
      target.year,
      target.month,
      (dayOfMonth == -1
          ? lastDay
          : (dayOfMonth ?? startDate.day).clamp(1, lastDay)),
    );
  }
}
