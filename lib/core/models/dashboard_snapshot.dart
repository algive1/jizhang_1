abstract interface class MonthlyTotals {
  DateTime get month;
  double get income;
  double get expense;
  double get forecastBalance;
}

class MonthlyLedgerSummary implements MonthlyTotals {
  const MonthlyLedgerSummary({
    required this.month,
    required this.income,
    required this.expense,
  });
  @override
  final DateTime month;
  @override
  final double income;
  @override
  final double expense;
  @override
  double get forecastBalance => income - expense;
}

class DashboardSnapshot implements MonthlyTotals {
  const DashboardSnapshot({
    required this.safeToSpend,
    required this.forecastBalance,
    required this.hasBudget,
    required this.month,
    required this.income,
    required this.expense,
    required this.budgetAmount,
    required this.availableAmount,
    required this.remainingDays,
    required this.goalReservation,
  });

  final double safeToSpend;
  @override
  final double forecastBalance;
  final bool hasBudget;
  @override
  final DateTime month;
  @override
  final double income;
  @override
  final double expense;
  final double budgetAmount;
  final double availableAmount;
  final int remainingDays;
  final double goalReservation;
}

class FinancialInsight {
  const FinancialInsight({
    required this.timeLabel,
    required this.amount,
    required this.increasePercent,
    required this.description,
  });

  final String timeLabel;
  final double amount;
  final int? increasePercent;
  final String description;
}
