import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';

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

    final distributionCard = find.byKey(
      const ValueKey('asset-distribution-card'),
    );
    final distributionHeight = tester.getSize(distributionCard).height;
    await tester.tap(find.byKey(const ValueKey('home-assets-hide-amount')));
    await tester.pumpAndSettle();
    expect(find.text('资产分布'), findsOneWidget);
    expect(find.text('资产变化'), findsOneWidget);
    expect(find.text('负债管理'), findsOneWidget);
    expect(find.text('近期资产变动'), findsOneWidget);
    expect(
      tester.getSize(distributionCard).height,
      closeTo(distributionHeight, 0.1),
    );

    await tester.tap(find.byKey(const ValueKey('home-asset-card')));
    await tester.pumpAndSettle();
    expect(find.text('资产详情'), findsOneWidget);
    expect(find.byTooltip('关闭'), findsNothing);
    Navigator.of(tester.element(find.text('资产详情'))).pop();
    await tester.pumpAndSettle();

    final distribution = find.text('资产分布').first;
    await tester.ensureVisible(distribution);
    await tester.tap(distribution);
    await tester.pumpAndSettle();
    expect(find.text('资产分布详情'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('asset-distribution-analysis')),
      findsOneWidget,
    );
    expect(
      tester.getSize(find.byKey(const ValueKey('asset-sheet-frame'))).height,
      lessThan(935 * .54),
    );
    expect(find.byTooltip('关闭'), findsNothing);
    Navigator.of(tester.element(find.text('资产分布详情'))).pop();
    await tester.pumpAndSettle();

    // Period controls keep their own action and must not open the parent sheet.
    await tester.tap(find.text('近7天').first);
    await tester.pumpAndSettle();
    expect(find.text('资产变化详情'), findsNothing);

    final trend = find.text('资产变化').first;
    await tester.ensureVisible(trend);
    await tester.tap(trend);
    await tester.pumpAndSettle();
    expect(find.text('资产变化详情'), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-trend-analysis')), findsOneWidget);
    final sheet = find.byKey(const ValueKey('asset-sheet-frame'));
    final sheetTitle = tester.getRect(find.text('资产变化详情'));
    final sheetRect = tester.getRect(sheet);
    expect(sheetTitle.center.dx, closeTo(sheetRect.center.dx, 1));
    final detailAmount = tester.getRect(
      find.byKey(const ValueKey('asset-trend-detail-amount')),
    );
    final detailPeriods = tester.getRect(
      find.byKey(const ValueKey('asset-trend-detail-periods')),
    );
    expect(detailPeriods.left, greaterThan(detailAmount.right));
    expect(detailPeriods.center.dy, closeTo(detailAmount.center.dy, 8));
    for (final label in const ['近7天', '近30天', '近1年']) {
      expect(
        find.descendant(of: sheet, matching: find.text(label)),
        findsOneWidget,
      );
    }
    final sheetSevenDays = find.descendant(
      of: sheet,
      matching: find.text('近7天'),
    );
    expect(sheetSevenDays, findsOneWidget);
    await tester.tap(find.descendant(of: sheet, matching: find.text('近30天')));
    await tester.pumpAndSettle();
    expect(find.textContaining('统计区间：近30天'), findsOneWidget);
    await tester.tap(find.descendant(of: sheet, matching: find.text('近1年')));
    await tester.pumpAndSettle();
    expect(find.textContaining('统计区间：近1年'), findsOneWidget);
    await tester.tap(sheetSevenDays);
    await tester.pumpAndSettle();
    expect(find.textContaining('统计区间：近7天'), findsOneWidget);
    expect(find.byKey(const ValueKey('asset-trend-analysis')), findsOneWidget);

    final selected = find.byKey(const ValueKey('asset-trend-selected'));
    final before = tester.widget<Text>(selected).data;
    final detailPlot = find.byKey(const ValueKey('asset-trend-detail-plot'));
    final plotRect = tester.getRect(detailPlot);
    await tester.dragFrom(
      Offset(plotRect.left + plotRect.width * .8, plotRect.center.dy),
      Offset(-plotRect.width * .55, 0),
    );
    await tester.pumpAndSettle();
    expect(tester.widget<Text>(selected).data, isNot(before));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'asset trend detail keeps the amount and period buttons aligned on narrow screens',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
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
      final trend = find.text('资产变化').first;
      await tester.ensureVisible(trend);
      await tester.tap(trend);
      await tester.pumpAndSettle();

      expect(find.text('资产变化详情'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('asset-trend-detail-periods')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('asset-trend-detail-amount')),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );
}
