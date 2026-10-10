import '../../../core/models/transaction_record.dart';

/// Calendar-aligned month-to-date comparison, based only on observed CNY
/// consumption. Missing comparison samples are unknown, never a 0% change.
class InsightMonthSummary {
  const InsightMonthSummary({
    required this.spent,
    required this.previousSpent,
    required this.count,
    required this.previousCount,
  });
  final double spent;
  final double previousSpent;
  final int count;
  final int previousCount;
  double? get changePercent => previousCount > 0 && previousSpent > 0
      ? (spent - previousSpent) / previousSpent * 100
      : null;

  factory InsightMonthSummary.from(
    Iterable<TransactionRecord> rows,
    DateTime now,
  ) {
    final start = DateTime(now.year, now.month);
    final previous = DateTime(now.year, now.month - 1);
    final previousDays = DateTime(now.year, now.month, 0).day;
    final previousEnd = now.day > previousDays
        ? start
        : DateTime(
            previous.year,
            previous.month,
            now.day,
            now.hour,
            now.minute,
            now.second,
            now.millisecond,
            now.microsecond,
          );
    var spentCents = 0, previousCents = 0, count = 0, previousCount = 0;
    for (final row in rows) {
      if (row.deletedAt != null ||
          row.currency.toUpperCase() != 'CNY' ||
          !row.isConsumptionExpense ||
          row.occurredAt.isAfter(now))
        continue;
      final cents = (row.personalExpenseAmount * 100).round();
      if (cents <= 0) continue;
      if (!row.occurredAt.isBefore(start)) {
        spentCents += cents;
        count++;
      } else if (!row.occurredAt.isBefore(previous) &&
          row.occurredAt.isBefore(start) &&
          !row.occurredAt.isAfter(previousEnd)) {
        previousCents += cents;
        previousCount++;
      }
    }
    return InsightMonthSummary(
      spent: spentCents / 100,
      previousSpent: previousCents / 100,
      count: count,
      previousCount: previousCount,
    );
  }
}
