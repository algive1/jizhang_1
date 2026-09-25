import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/models/analysis.dart';
import 'package:jizhang_app/features/analysis/data/analysis_repository.dart';
import 'package:jizhang_app/features/analysis/domain/statistical_analysis_service.dart';

void main() {
  test('analysis snapshot family caches each period until source data changes', () {
    final repository = _CountingAnalysisRepository();
    final container = ProviderContainer(
      overrides: [
        analysisRepositoryProvider.overrideWithValue(repository),
      ],
    );
    addTearDown(container.dispose);

    const monthKey = (
      period: AnalysisPeriod.currentMonth,
      currency: 'CNY',
    );
    const yearKey = (
      period: AnalysisPeriod.currentYear,
      currency: 'CNY',
    );

    container.read(analysisSnapshotForPeriodProvider(monthKey));
    container.read(analysisSnapshotForPeriodProvider(monthKey));
    expect(repository.calls, 1);

    container.read(analysisSnapshotForPeriodProvider(yearKey));
    container.read(analysisSnapshotForPeriodProvider(yearKey));
    expect(repository.calls, 2);

    container.invalidate(analysisSnapshotForPeriodProvider(monthKey));
    container.read(analysisSnapshotForPeriodProvider(monthKey));
    expect(repository.calls, 3);
  });
}

class _CountingAnalysisRepository implements AnalysisRepository {
  int calls = 0;

  @override
  AnalysisSnapshot analyze({
    required AnalysisPeriod period,
    DateTime? now,
    DateTime? month,
    String currency = 'CNY',
  }) {
    calls++;
    return const StatisticalAnalysisService().analyze(
      const [],
      period: period,
      now: DateTime(2026, 9, 25, 12),
      month: month,
      currency: currency,
    );
  }
}
