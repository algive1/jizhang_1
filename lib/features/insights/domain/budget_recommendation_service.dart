import 'dart:math' as math;

import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import 'insight_models.dart';

class BudgetRecommendationService {
  const BudgetRecommendationService();

  BudgetRecommendation? recommendTotal({
    required List<TransactionRecord> transactions,
    required InsightPreferences preferences,
    DateTime? now,
  }) {
    return _recommend(
      transactions: transactions,
      preferences: preferences,
      now: now ?? DateTime.now(),
      matches: (_) => true,
    );
  }

  BudgetRecommendation? recommendCategory({
    required List<TransactionRecord> transactions,
    required List<Category> categories,
    required String categoryId,
    required InsightPreferences preferences,
    DateTime? now,
  }) {
    final categoryMap = {for (final item in categories) item.id: item};
    return _recommend(
      transactions: transactions,
      preferences: preferences,
      now: now ?? DateTime.now(),
      matches: (item) {
        if (item.categoryId == categoryId || item.subcategoryId == categoryId) {
          return true;
        }
        final category =
            item.categoryId == null ? null : categoryMap[item.categoryId!];
        final subcategory = item.subcategoryId == null
            ? null
            : categoryMap[item.subcategoryId!];
        return category?.parentId == categoryId ||
            subcategory?.parentId == categoryId;
      },
    );
  }

  BudgetRecommendation? _recommend({
    required List<TransactionRecord> transactions,
    required InsightPreferences preferences,
    required DateTime now,
    required bool Function(TransactionRecord) matches,
  }) {
    final monthly = <double>[];
    var coveredTransactions = 0;
    for (var offset = 1; offset <= 3; offset++) {
      final month = DateTime(now.year, now.month - offset);
      var cents = 0;
      var count = 0;
      for (final item in transactions) {
        if (!_eligible(item, now) ||
            item.occurredAt.year != month.year ||
            item.occurredAt.month != month.month ||
            !matches(item)) {
          continue;
        }
        final personal = _personalExpense(item);
        if (personal <= .005) continue;
        cents += (personal * 100).round();
        count++;
      }
      if (count >= 2 && cents > 0) {
        monthly.add(cents / 100);
        coveredTransactions += count;
      }
    }
    if (monthly.length < 2 || coveredTransactions < 6) return null;

    final sorted = [...monthly]..sort();
    final median = sorted.length.isOdd
        ? sorted[sorted.length ~/ 2]
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;
    final p75 = sorted[((sorted.length - 1) * .75).round()];
    final maintain = _friendly(math.max(median, p75));
    final moderate = _friendly(median * .90);
    final active = _friendly(median * .80);
    final recommended =
        preferences.intents.contains(BookkeepingIntent.saveForGoal)
        ? active
        : preferences.intents.contains(BookkeepingIntent.controlSpending)
        ? moderate
        : maintain;
    final spread = sorted.last - sorted.first;
    final stability = median <= 0
        ? 0.0
        : (1 - (spread / median).clamp(0, 1)).toDouble();
    final confidence =
        (.55 + .15 * (monthly.length / 3) + .30 * stability).clamp(0, 1);

    return BudgetRecommendation(
      recommended: recommended,
      rangeMin: active,
      rangeMax: maintain,
      maintain: maintain,
      moderateControl: moderate,
      activeSaving: active,
      historicalMedian: median,
      confidence: confidence.toDouble(),
      reason:
          '根据最近 ${monthly.length} 个完整月份的真实支出，中位数约 ¥${median.toStringAsFixed(0)}。'
          '推荐值会结合你的记账目的，而不是直接照搬历史平均。',
    );
  }

  bool _eligible(TransactionRecord item, DateTime now) =>
      item.deletedAt == null &&
      !item.occurredAt.isAfter(now) &&
      item.currency.toUpperCase() == 'CNY' &&
      item.isConsumptionExpense;

  double _personalExpense(TransactionRecord item) {
    final afterRefund = item.netExpenseAmount;
    final reimbursable = switch (item.reimbursementStatus) {
      ReimbursementStatus.none => 0.0,
      ReimbursementStatus.pending || ReimbursementStatus.reimbursed =>
        item.reimbursementAmount ?? afterRefund,
      ReimbursementStatus.partial => item.reimbursementAmount ?? 0.0,
    };
    return (afterRefund - reimbursable).clamp(0, afterRefund).toDouble();
  }

  double _friendly(double value) {
    if (value <= 0) return 0;
    final step = value >= 1000 ? 50.0 : 10.0;
    return (value / step).round() * step;
  }
}
