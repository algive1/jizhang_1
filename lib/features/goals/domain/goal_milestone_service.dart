import 'dart:math' as math;

import '../../../core/models/goal.dart';

class GoalMilestoneService {
  const GoalMilestoneService();

  List<double> suggest(double targetAmount) {
    if (!targetAmount.isFinite || targetAmount <= 0) {
      throw ArgumentError.value(targetAmount, 'targetAmount', 'must be > 0');
    }
    const ratios = [.1, .2, .3, .4, .5, .6, .75, .9];
    final suggestions =
        ratios
            .map((ratio) => _roundToFriendly(targetAmount * ratio))
            .where((amount) => amount > 0 && amount < targetAmount)
            .toSet()
            .toList()
          ..sort();
    suggestions.add(targetAmount);
    return suggestions;
  }

  /// Returns a readable, bounded set of milestones for a compact timeline.
  ///
  /// Persisted milestones are never changed here. The method only chooses
  /// which existing values to show, always keeping the current amount and the
  /// final target visible. When there are many values, it favors the latest
  /// completed milestones and the nearest pending milestones, then fills any
  /// remaining slots by distance from the current amount.
  List<double> visibleAmounts(Goal goal, {int maxNodes = 7}) {
    if (maxNodes < 2) {
      throw ArgumentError.value(maxNodes, 'maxNodes', 'must be at least 2');
    }
    final target = goal.targetAmount;
    if (!target.isFinite || target <= 0) {
      return [goal.currentAmount];
    }
    final current = goal.currentAmount.clamp(0, target).toDouble();
    final milestoneAmounts = <double>{
      for (final milestone in goal.milestones)
        if (milestone.amount.isFinite &&
            milestone.amount >= 0 &&
            milestone.amount <= target)
          milestone.amount,
    };
    final completed =
        milestoneAmounts.where((amount) => amount < current).toList()..sort();
    final pending =
        milestoneAmounts
            .where((amount) => amount > current && amount < target)
            .toList()
          ..sort();
    final all = <double>{...milestoneAmounts, current, target}.toList()..sort();
    if (all.length <= maxNodes) return all;

    final selected = <double>{current, target};
    var remaining = maxNodes - selected.length;
    final completedCount = math.min(3, math.min(completed.length, remaining));
    selected.addAll(
      completed.skip(completed.length - completedCount).take(completedCount),
    );
    remaining = maxNodes - selected.length;
    final pendingCount = math.min(2, math.min(pending.length, remaining));
    selected.addAll(pending.take(pendingCount));
    remaining = maxNodes - selected.length;

    if (remaining > 0) {
      final candidates =
          <double>{
            ...completed,
            ...pending,
          }.where((amount) => !selected.contains(amount)).toList()..sort((
            a,
            b,
          ) {
            final distance = (a - current).abs().compareTo((b - current).abs());
            return distance == 0 ? a.compareTo(b) : distance;
          });
      selected.addAll(candidates.take(remaining));
    }
    return selected.toList()..sort();
  }

  double _roundToFriendly(double amount) {
    if (amount < 10) return (amount * 100).round() / 100;
    final magnitude = math.pow(
      10,
      math.max(0, (math.log(amount) / math.ln10).floor() - 1),
    );
    return (amount / magnitude).round() * magnitude.toDouble();
  }
}
