import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/insights/domain/budget_recommendation_service.dart';
import 'package:jizhang_app/features/insights/domain/insight_models.dart';

void main() {
  test('three stable dining months create goal-aware budget bands', () {
    final now = DateTime(2026, 9, 20);
    final records = <TransactionRecord>[];
    for (final entry in [
      (DateTime(2026, 6, 10), 390.0),
      (DateTime(2026, 7, 10), 455.0),
      (DateTime(2026, 8, 10), 455.0),
    ]) {
      for (var i = 0; i < 6; i++) {
        final amount = entry.$2 / 6;
        records.add(
          TransactionRecord(
            id: '${entry.$1.month}-$i',
            bookId: 'book-personal',
            type: TransactionType.expense,
            amount: amount,
            categoryId: 'food',
            categoryName: '餐饮',
            accountId: 'cash',
            occurredAt: entry.$1.add(Duration(days: i)),
            createdAt: entry.$1,
            updatedAt: entry.$1,
          ),
        );
      }
    }

    final recommendation = const BudgetRecommendationService().recommendTotal(
      transactions: records,
      preferences: const InsightPreferences(
        intents: {BookkeepingIntent.controlSpending},
        configured: true,
      ),
      now: now,
    );

    expect(recommendation, isNotNull);
    expect(recommendation!.historicalMedian, closeTo(455, 1));
    expect(recommendation.recommended, recommendation.moderateControl);
    expect(recommendation.moderateControl, lessThan(recommendation.maintain));
    expect(recommendation.rangeMin, lessThan(recommendation.rangeMax));
  });
}
