import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/accounts/presentation/asset_dashboard_charts.dart';

void main() {
  testWidgets('asset cards open detail bottom sheets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [databaseProvider.overrideWithValue(database)],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    router.go('/profile/assets');
    await tester.pumpAndSettle();
    expect(find.text('全部账本'), findsNothing);

    final trendScroll = find.descendant(
      of: find.byType(AssetTrend),
      matching: find.byType(SingleChildScrollView),
    );
    expect(trendScroll, findsOneWidget);
    final trendController = tester
        .widget<SingleChildScrollView>(trendScroll)
        .controller;
    expect(trendController, isNotNull);
    expect(trendController!.position.maxScrollExtent, greaterThan(0));
    final latestOffset = trendController.offset;
    await tester.drag(trendScroll, const Offset(80, 0));
    await tester.pumpAndSettle();
    expect(trendController.offset, lessThan(latestOffset));

    await tester.tap(find.byKey(const ValueKey('home-asset-card')));
    await tester.pumpAndSettle();
    expect(find.text('资产详情'), findsOneWidget);
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    final distribution = find.text('资产分布').first;
    await tester.ensureVisible(distribution);
    await tester.tap(distribution);
    await tester.pumpAndSettle();
    expect(find.text('资产分布详情'), findsWidgets);
    expect(
      find.byKey(const ValueKey('asset-distribution-analysis')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('asset-sheet-frame'))).height,
      lessThan(935 * .54),
    );
    await tester.tap(find.byTooltip('关闭'));
    await tester.pumpAndSettle();

    // Period controls keep their own action and must not open the parent sheet.
    await tester.tap(find.text('近7天').first);
    await tester.pumpAndSettle();
    expect(find.text('资产变化详情'), findsNothing);

    final trend = find.text('资产变化').first;
    await tester.ensureVisible(trend);
    await tester.tap(trend);
    await tester.pumpAndSettle();
    expect(find.text('资产变化详情'), findsWidgets);
    expect(find.byKey(const ValueKey('asset-trend-analysis')), findsOneWidget);
    final sheet = find.byKey(const ValueKey('asset-sheet-frame'));
    final sheetSevenDays = find.descendant(
      of: sheet,
      matching: find.text('近7天'),
    );
    expect(sheetSevenDays, findsOneWidget);
    await tester.tap(sheetSevenDays);
    await tester.pumpAndSettle();
    expect(find.textContaining('统计区间：近7天'), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-trend-analysis')), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
