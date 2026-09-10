import 'dart:math' as math;

class GoalMilestoneService {
  const GoalMilestoneService();

  List<double> suggest(double targetAmount) {
    if (!targetAmount.isFinite || targetAmount <= 0) {
      throw ArgumentError.value(targetAmount, 'targetAmount', 'must be > 0');
    }
    const ratios = [.125, .25, .375, .625];
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

  double _roundToFriendly(double amount) {
    if (amount < 10) return (amount * 100).round() / 100;
    final magnitude = math.pow(
      10,
      math.max(0, (math.log(amount) / math.ln10).floor() - 1),
    );
    return (amount / magnitude).round() * magnitude.toDouble();
  }
}
