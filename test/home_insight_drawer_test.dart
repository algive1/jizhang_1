import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/home/presentation/home_insight_drawer.dart';
import 'package:jizhang_app/features/insights/domain/insight_models.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

void main() {
  testWidgets(
    'home insight drawer rechecks cooldown when the top candidate changes',
    (tester) async {
      final day = DateTime(2026, 9, 20);
      final settings = _MemorySettings({
        'home.insight.lastShown.book-personal.first': day.toIso8601String(),
      });

      Widget app(FinancialInsightItem insight) => ProviderScope(
        overrides: [
          appSettingsRepositoryProvider.overrideWithValue(settings),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: HomeInsightDrawer(
              bookId: 'book-personal',
              day: day,
              insight: insight,
              available: true,
              cooldownDays: 7,
              onTap: () {},
            ),
          ),
        ),
      );

      await tester.pumpWidget(app(_insight('first', '第一条')));
      await tester.pumpAndSettle();
      expect(find.text('第一条').hitTestable(), findsNothing);

      await tester.pumpWidget(app(_insight('second', '第二条')));
      await tester.pumpAndSettle();

      expect(find.text('第二条').hitTestable(), findsOneWidget);
      expect(
        settings.values['home.insight.lastShown.book-personal.second'],
        day.toIso8601String(),
      );
    },
  );
}

FinancialInsightItem _insight(String id, String title) => FinancialInsightItem(
  id: id,
  kind: FinancialInsightKind.discovery,
  priority: InsightPriority.attention,
  title: title,
  summary: '摘要',
  analysis: '分析',
  meaning: '含义',
  response: InsightResponse.notice,
  score: 80,
  confidence: const InsightConfidence(
    data: 1,
    completeness: 1,
    classification: 1,
    baseline: 1,
  ),
  generatedAt: DateTime(2026, 9, 20),
);

class _MemorySettings implements AppSettingsRepository {
  _MemorySettings(this.values);

  final Map<String, String> values;

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}
