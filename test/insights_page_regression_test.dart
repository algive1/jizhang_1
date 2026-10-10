import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/insights/application/insight_feed_provider.dart';
import 'package:jizhang_app/features/insights/data/insight_preferences_repository.dart';
import 'package:jizhang_app/features/insights/domain/insight_models.dart';
import 'package:jizhang_app/features/insights/domain/insight_month_summary.dart';
import 'package:jizhang_app/features/insights/presentation/insights_page.dart';

const empty = InsightFeed(
  items: [],
  dataConfidence: 0,
  completeness: 0,
  classificationConfidence: 0,
  baselineConfidence: 0,
);
void main() {
  for (final dark in [false, true]) {
    testWidgets(
      'insights support narrow screens and large text (${dark ? 'dark' : 'light'})',
      (tester) async {
        tester.view.physicalSize = const Size(320, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              activeBookProvider.overrideWithValue(null),
              insightDataStateProvider.overrideWithValue(const AsyncData(null)),
              insightFeedProvider.overrideWithValue(empty),
              insightPreferencesProvider.overrideWith(
                (ref) async => const InsightPreferences(),
              ),
              insightMonthSummaryProvider.overrideWithValue(
                const InsightMonthSummary(
                  spent: 123456789,
                  previousSpent: 0,
                  count: 3,
                  previousCount: 0,
                ),
              ),
            ],
            child: MaterialApp(
              theme: dark ? AppTheme.dark() : AppTheme.light(),
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context)
                    .copyWith(textScaler: const TextScaler.linear(2)),
                child: child!,
              ),
              home: const Scaffold(body: InsightsPage()),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('本月个人消费'), findsOneWidget);
        expect(find.text('上月同期记录不足，暂不比较'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.drag(find.byType(ListView).first, const Offset(0, -550));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      },
    );
  }
}
