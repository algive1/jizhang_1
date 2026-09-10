import 'dart:math' as math;

import '../../../core/models/goal.dart';

class GoalForecastService {
  const GoalForecastService();

  GoalForecast forecast(Goal goal, {required int windowDays, DateTime? now}) {
    if (![30, 60, 90].contains(windowDays)) {
      throw ArgumentError.value(
        windowDays,
        'windowDays',
        'must be 30, 60 or 90',
      );
    }
    final calculationTime = now ?? DateTime.now();
    final start = calculationTime.subtract(Duration(days: windowDays));
    final netDeposits = goal.contributions
        .where(
          (item) =>
              !item.createdAt.isBefore(start) &&
              !item.createdAt.isAfter(calculationTime) &&
              item.type != GoalContributionType.adjustment,
        )
        .fold<double>(0, (total, contribution) {
          return switch (contribution.type) {
            GoalContributionType.deposit => total + contribution.amount,
            GoalContributionType.withdraw => total - contribution.amount,
            GoalContributionType.adjustment => total,
          };
        });
    final dailyAverage = math.max(0, netDeposits / windowDays).toDouble();
    final remaining = math
        .max(0, goal.targetAmount - goal.currentAmount)
        .toDouble();
    final daysNeeded = dailyAverage <= 0
        ? null
        : (remaining / dailyAverage).ceil();
    return GoalForecast(
      windowDays: windowDays,
      averageDailyDeposit: dailyAverage,
      estimatedCompletionDate: daysNeeded == null
          ? null
          : calculationTime.add(Duration(days: daysNeeded)),
    );
  }

  List<GoalForecast> allWindows(Goal goal, {DateTime? now}) {
    return [
      for (final days in [30, 60, 90])
        forecast(goal, windowDays: days, now: now),
    ];
  }
}
