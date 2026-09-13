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

enum RecurringBillCycle { weekly, monthly, quarterly, halfYear, yearly, custom }

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

  DateTime nextOccurrence(DateTime from) {
    final base = DateTime(from.year, from.month, from.day);
    return switch (cycle) {
      RecurringBillCycle.weekly => base.add(const Duration(days: 7)),
      RecurringBillCycle.monthly => _addMonths(base, 1),
      RecurringBillCycle.quarterly => _addMonths(base, 3),
      RecurringBillCycle.halfYear => _addMonths(base, 6),
      RecurringBillCycle.yearly => _addMonths(base, 12),
      RecurringBillCycle.custom => base.add(
        Duration(days: customIntervalDays ?? 30),
      ),
    };
  }

  DateTime _addMonths(DateTime base, int months) {
    final target = DateTime(base.year, base.month + months, 1);
    final lastDay = DateTime(target.year, target.month + 1, 0).day;
    return DateTime(target.year, target.month, base.day.clamp(1, lastDay));
  }
}
