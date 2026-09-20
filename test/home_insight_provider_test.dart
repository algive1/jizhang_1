import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';
import 'package:jizhang_app/features/home/data/home_data.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';

void main() {
  test(
    'home insight uses whole-day category changes and includes an action',
    () async {
      final now = DateTime.now();
      final currentDay = now.subtract(const Duration(minutes: 5));
      final previousDay = DateTime(
        now.year,
        now.month - 1,
        now.day.clamp(1, 28),
        12,
      );
      final records = [
        _expense('current-1', 120, currentDay, category: 'food'),
        _expense(
          'current-2',
          120,
          currentDay.subtract(const Duration(hours: 1)),
          category: 'food',
        ),
        _expense('previous-1', 60, previousDay, category: 'food'),
        _expense(
          'previous-2',
          60,
          previousDay.subtract(const Duration(hours: 1)),
          category: 'food',
        ),
      ];
      final container = ProviderContainer(
        overrides: [transactionsProvider.overrideWithValue(AsyncData(records))],
      );
      addTearDown(container.dispose);

      final snapshot = const StatisticalAnalysisService().analyze(
        records,
        now: now,
      );
      expect(snapshot.insights, isNotEmpty);
      final insight = container.read(homeInsightProvider);

      expect(insight, isNotNull);
      expect(insight!.amount, 240);
      expect(insight.title, '餐饮支出增加');
      expect(insight.changePercent, 100);
      expect(insight.suggestion, isNotEmpty);
      expect(insight.actionLabel, isNotEmpty);
    },
  );

  test('home insight stays empty when no rule reaches its threshold', () async {
    final now = DateTime.now();
    final records = [
      _expense(
        'current',
        100,
        now.subtract(const Duration(minutes: 5)),
        category: 'food',
      ),
      _expense(
        'previous',
        90,
        DateTime(now.year, now.month - 1, now.day.clamp(1, 28), 12),
        category: 'food',
      ),
    ];
    final container = ProviderContainer(
      overrides: [transactionsProvider.overrideWithValue(AsyncData(records))],
    );
    addTearDown(container.dispose);

    final insight = container.read(homeInsightProvider);

    expect(insight, isNull);
  });
}

TransactionRecord _expense(
  String id,
  double amount,
  DateTime occurredAt, {
  required String category,
}) {
  return TransactionRecord(
    id: id,
    bookId: 'book',
    type: TransactionType.expense,
    amount: amount,
    accountId: 'cash',
    categoryId: category,
    categoryName: '餐饮',
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}
