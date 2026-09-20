import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/analysis.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';

void main() {
  const service = StatisticalAnalysisService();
  final now = DateTime(2026, 8, 31, 12);

  test('time segments use the product boundary definitions', () {
    final featureService = service.features;
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 4, 59)),
      TimeSegment.earlyMorning,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 5)),
      TimeSegment.dawn,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 7, 59)),
      TimeSegment.dawn,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 8)),
      TimeSegment.morning,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 10, 59)),
      TimeSegment.morning,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 11)),
      TimeSegment.noon,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 13, 59)),
      TimeSegment.noon,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 14)),
      TimeSegment.afternoon,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 16, 59)),
      TimeSegment.afternoon,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 17)),
      TimeSegment.evening,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 21, 59)),
      TimeSegment.evening,
    );
    expect(
      featureService.segmentFor(DateTime(2026, 8, 1, 22)),
      TimeSegment.lateNight,
    );
  });

  test('normal spending is compared with the same length prior period', () {
    final snapshot = service.analyze([
      _expense('current', 100, DateTime(2026, 8, 10, 12)),
      _expense('previous', 90, DateTime(2026, 7, 10, 12)),
    ], now: now);

    expect(snapshot.regularExpense, 100);
    expect(snapshot.previousRegularExpense, 90);
    expect(snapshot.transactionCount, 1);
    expect(snapshot.insights, isEmpty);
    expect(snapshot.heatmap[DateTime(2026, 8, 10).weekday - 1][12], 100);
  });

  test(
    'late night amount and frequency anomaly creates structured insight',
    () {
      final snapshot = service.analyze([
        _expense('night-1', 150, DateTime(2026, 8, 20, 23)),
        _expense('night-2', 150, DateTime(2026, 8, 21, 22)),
        _expense('old-night', 50, DateTime(2026, 7, 20, 23)),
      ], now: now);

      final insight = snapshot.insights.firstWhere(
        (item) => item.type == AnalysisInsightType.lateNightIncrease,
      );
      expect(insight.reasonCode, 'late_night_amount_and_count_increase');
      expect(insight.currentValue, 300);
      expect(insight.baselineValue, 50);
      expect(insight.period, AnalysisPeriod.currentMonth);
      expect(insight.deltaAmount, 250);
      expect(insight.deltaPercent, 500);
      expect(insight.timeSegment, TimeSegment.lateNight);
      expect(insight.metadata['currentCount'], 2);
      expect(insight.metadata['previousCount'], 1);
      expect(insight.generatedAt, now);
    },
  );

  test('car asset purchase is excluded from daily trend and heatmap', () {
    final snapshot = service.analyze([
      _expense(
        'car',
        160000,
        DateTime(2026, 8, 8, 15),
        type: TransactionType.assetPurchase,
        categoryName: '购车',
      ),
      _expense('lunch', 35, DateTime(2026, 8, 8, 12)),
    ], now: now);

    expect(snapshot.totalExpense, 160035);
    expect(snapshot.regularExpense, 35);
    expect(snapshot.excludedLargeExpense, 160000);
    expect(snapshot.categoryTrends.single.name, '餐饮');
    expect(snapshot.heatmap.expand((row) => row).reduce((a, b) => a + b), 35);
  });

  test('food increase is attributed to frequency instead of ticket size', () {
    final snapshot = service.analyze([
      for (var index = 0; index < 4; index++)
        _expense(
          'delivery-$index',
          50,
          DateTime(2026, 8, 10 + index, 19),
          merchant: '美团外卖',
        ),
      _expense('old-food', 60, DateTime(2026, 7, 12, 19)),
    ], now: now);

    final trend = snapshot.categoryTrends.single;
    expect(trend.attribution, SpendingAttributionType.frequency);
    expect(trend.currentCount, 4);
    expect(trend.previousCount, 1);
    expect(snapshot.insights.first.reasonCode, 'delivery_frequency_increase');
  });

  test('MuMu import metadata can identify delivery frequency growth', () {
    final current = [
      for (var index = 0; index < 4; index++)
        _expense(
          'mumu-delivery-$index',
          50,
          DateTime(2026, 8, 10 + index, 19),
        ).copyWith(
          metadataJson: jsonEncode({
            'importProvider': 'mumu',
            'sourceCategory': '餐饮',
            'sourceSubcategory': '外卖',
          }),
        ),
    ];
    final previous = _expense(
      'mumu-old-food',
      60,
      DateTime(2026, 7, 12, 19),
    ).copyWith(
      metadataJson: jsonEncode({
        'importProvider': 'mumu',
        'sourceCategory': '餐饮',
        'sourceSubcategory': '三餐',
      }),
    );

    final snapshot = service.analyze([...current, previous], now: now);

    expect(snapshot.insights.first.reasonCode, 'delivery_frequency_increase');
  });

  test('personal distribution detects an outlier below fixed threshold', () {
    final history = [
      for (var index = 0; index < 6; index++)
        _expense('regular-$index', 100, DateTime(2026, 8, 1 + index, 10)),
      _expense('outlier', 800, DateTime(2026, 8, 20, 10)),
    ];

    final snapshot = service.analyze(history, now: now);
    expect(snapshot.regularExpense, 600);
    expect(snapshot.excludedLargeExpense, 800);
  });

  test(
    'refunds reduce consumption and repayments stay out of consumption totals',
    () {
      final refunded = _expense(
        'refunded',
        500,
        DateTime(2026, 8, 12, 12),
      ).copyWith(refundStatus: RefundStatus.partial, refundAmount: 200);
      final repayment = _expense(
        'repayment',
        1000,
        DateTime(2026, 8, 13, 12),
        type: TransactionType.repayment,
      );
      final snapshot = service.analyze([refunded, repayment], now: now);
      expect(snapshot.totalExpense, 300);
      expect(snapshot.expenseCount, 1);
    },
  );
}

TransactionRecord _expense(
  String id,
  double amount,
  DateTime occurredAt, {
  TransactionType type = TransactionType.expense,
  String categoryName = '餐饮',
  String? merchant,
}) {
  return TransactionRecord(
    id: id,
    bookId: 'book',
    type: type,
    amount: amount,
    categoryId: categoryName,
    categoryName: categoryName,
    accountId: 'cash',
    merchant: merchant,
    occurredAt: occurredAt,
    createdAt: occurredAt,
    updatedAt: occurredAt,
  );
}
