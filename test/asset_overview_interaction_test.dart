import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/features/accounts/domain/asset_overview.dart';
import 'package:jizhang_app/features/accounts/presentation/asset_dashboard_charts.dart';
import 'package:jizhang_app/features/investments/data/investment_repository.dart';

void main() {
  testWidgets('distribution compact and detail rows share filtered data', (
    tester,
  ) async {
    final overview = AssetOverview(
      'CNY',
      [_account('included', 300), _account('excluded', 900)],
      investmentValue: 700,
      excludedAccountIds: const {'excluded'},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              AssetDistribution(overview: overview),
              AssetDistributionDetail(overview: overview),
            ],
          ),
        ),
      ),
    );

    expect(find.text('投资管理'), findsNWidgets(2));
    expect(find.text('¥700.00'), findsNWidgets(2));
    expect(find.text('¥300.00'), findsNWidgets(2));
    expect(find.text('70.0%'), findsNWidgets(2));
    expect(find.text('30.0%'), findsNWidgets(2));
    expect(find.text('excluded'), findsNothing);
    final compact = find.byKey(const ValueKey('asset-distribution-card'));
    final compactInvestment = tester.getTopLeft(
      find.descendant(of: compact, matching: find.text('投资管理')),
    );
    final compactAccount = tester.getTopLeft(
      find.descendant(of: compact, matching: find.text('included')),
    );
    expect(compactInvestment.dy, lessThan(compactAccount.dy));
    final detail = find.byType(AssetDistributionDetail);
    expect(
      tester
          .getRect(find.descendant(of: detail, matching: find.text('¥700.00')))
          .right,
      closeTo(
        tester
            .getRect(find.descendant(of: detail, matching: find.text('70.0%')))
            .right,
        1,
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('zero total distribution renders without a percentage error', (
    tester,
  ) async {
    final overview = AssetOverview(
      'CNY',
      [_account('zero', 0), _account('excluded', 100)],
      excludedAccountIds: const {'excluded'},
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(
            children: [
              AssetDistribution(overview: overview),
              AssetDistributionDetail(overview: overview),
            ],
          ),
        ),
      ),
    );

    expect(find.text('暂无正余额资产'), findsNWidgets(2));
    expect(find.textContaining('NaN'), findsNothing);
    expect(find.textContaining('Infinity'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('compact distribution legend is a fixed scrolling viewport', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final overview = AssetOverview(
      'CNY',
      List.generate(8, (index) => _account('账户${index + 1}', 800 - index * 100)),
      investmentValue: 10,
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: ListView(children: [AssetDistribution(overview: overview)]),
        ),
      ),
    );

    final card = find.byKey(const ValueKey('asset-distribution-card'));
    final viewport = find.descendant(
      of: card,
      matching: find.byKey(
        const ValueKey('asset-distribution-legend-scroll'),
      ),
    );
    expect(tester.getSize(viewport).height, closeTo(95, 0.1));
    expect(tester.getSize(card).height, lessThan(200));
    final lastAccount = find.descendant(of: card, matching: find.text('账户8'));
    final lastAccountTop = tester.getTopLeft(lastAccount).dy;
    await tester.drag(viewport, const Offset(0, -120));
    await tester.pumpAndSettle();
    expect(tester.getTopLeft(lastAccount).dy, lessThan(lastAccountTop));
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset cards open detail bottom sheets', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final systemInset = 24 * tester.view.devicePixelRatio;
    tester.view.viewPadding = FakeViewPadding(
      top: systemInset,
      bottom: systemInset,
    );
    tester.view.padding = FakeViewPadding(
      top: systemInset,
      bottom: systemInset,
    );
    addTearDown(tester.view.resetViewPadding);
    addTearDown(tester.view.resetPadding);
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
    addTearDown(database.close);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(database),
        includedInvestmentValueByCurrencyProvider.overrideWithValue(const {
          'CNY': 700,
        }),
      ],
    );
    addTearDown(container.dispose);
    final router = container.read(appRouterProvider);

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
          builder: (context, child) => RepaintBoundary(
            key: const ValueKey('asset-route-pixels'),
            child: child!,
          ),
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
    final overviewSheet = find.byKey(const ValueKey('asset-sheet-frame'));
    final overviewPlot = find.byKey(const ValueKey('asset-trend-detail-plot'));
    final plotBeforeScroll = tester.getRect(overviewPlot);
    await tester.drag(
      find.descendant(of: overviewSheet, matching: find.byType(ListView)),
      const Offset(0, -180),
    );
    await tester.pumpAndSettle();
    expect(tester.getRect(overviewPlot).top, lessThan(plotBeforeScroll.top));
    Navigator.of(tester.element(find.text('资产详情'))).pop();
    await tester.pumpAndSettle();

    final distribution = find.text('资产分布').first;
    await tester.ensureVisible(distribution);
    await tester.tap(distribution);
    await tester.pumpAndSettle();
    expect(find.text('资产分布详情'), findsOneWidget);
    final detailContext = tester.element(find.text('资产分布详情'));
    expect(MediaQuery.paddingOf(detailContext).bottom, closeTo(24, 0.1));
    expect(MediaQuery.viewPaddingOf(detailContext).bottom, closeTo(24, 0.1));
    final darkFooterRows = await _readDarkFooterRows(tester);
    expect(darkFooterRows, isEmpty);
    expect(find.text('投资管理'), findsWidgets);
    final distributionSheet = find.byKey(const ValueKey('asset-sheet-frame'));
    expect(
      find.descendant(of: distributionSheet, matching: find.text('¥700.00')),
      findsOneWidget,
    );
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
    expect(
      find.byKey(const ValueKey('asset-trend-detail-current-investment')),
      findsOneWidget,
    );
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

Future<List<int>> _readDarkFooterRows(WidgetTester tester) async {
  final sheetRect = tester.getRect(
    find.byKey(const ValueKey('asset-sheet-frame')),
  );
  final routeBoundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(const ValueKey('asset-route-pixels')),
  );
  return (await tester.runAsync(() async {
    final image = await routeBoundary.toImage(pixelRatio: 1);
    try {
      final pixels = (await image.toByteData(
        format: ui.ImageByteFormat.rawRgba,
      ))!;
      final footerRows = <int>[];
      for (var y = sheetRect.top.ceil(); y < image.height; y++) {
        var dark = 0;
        var samples = 0;
        for (var x = 4; x < image.width - 4; x += 2) {
          final offset = (y * image.width + x) * 4;
          if (pixels.getUint8(offset) < 128 &&
              pixels.getUint8(offset + 1) < 128 &&
              pixels.getUint8(offset + 2) < 128) {
            dark++;
          }
          samples++;
        }
        if (samples > 0 && dark / samples > .8 && y >= image.height - 80) {
          footerRows.add(y);
        }
      }
      return footerRows;
    } finally {
      image.dispose();
    }
  }))!;
}

Account _account(String id, double balance) => Account(
  id: id,
  name: id,
  type: AccountType.debitCard,
  balance: balance,
  currency: 'CNY',
  icon: 'wallet',
  color: 0xff73963b,
  sortOrder: 0,
  isArchived: false,
  assetForm: AssetForm.demandDeposit,
  identifierSuffix: null,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
