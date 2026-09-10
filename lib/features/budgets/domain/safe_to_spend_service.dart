import 'dart:math' as math;

class SafeToSpendService {
  const SafeToSpendService();

  double calculate({
    required double budgetAmount,
    required double spentAmount,
    required DateTime now,
    double goalReservation = 0,
  }) {
    final lastDay = DateTime(now.year, now.month + 1, 0).day;
    final remainingDays = math.max(1, lastDay - now.day + 1);
    return math.max(0, budgetAmount - spentAmount - goalReservation) /
        remainingDays;
  }
}
