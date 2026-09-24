import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/investments/data/investment_repository.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';
import 'package:jizhang_app/features/home/presentation/home_asset_card.dart';

void main() {
  late ProviderContainer container;

  Future<void> pumpApp(WidgetTester tester) async {
    final database = createMemoryDatabase();
    await DatabaseSeeder(database).seedIfNeeded();
    addTearDown(database.close);
    container = ProviderContainer(
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
    await tester.pumpAndSettle();
    return;
  }

  Future<void> openInvestments(WidgetTester tester) async {
    container.read(appRouterProvider).go('/profile/investments');
    await tester.pumpAndSettle();
  }

  Future<void> addHolding(
    WidgetTester tester, {
    required InvestmentAssetType type,
    required String symbol,
    required String name,
    required double price,
    required double quantity,
  }) async {
    await container
        .read(investmentRepositoryProvider)
        .addHolding(
          AddInvestmentRequest(
            type: type,
            symbol: symbol,
            name: name,
            price: price,
            quantity: quantity,
            transactionDate: DateTime(2026, 9, 1),
          ),
        );
  }

  testWidgets('homepage asset card and trend use opted-in investment values', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);

    final repository = container.read(investmentRepositoryProvider);
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: 'CLOSED-HOME-TEST',
        name: '未计入首页仓位',
        price: 10,
        currentPrice: 10,
        quantity: 10,
        transactionDate: DateTime.now(),
        priceSource: PriceSource.manual,
      ),
    );
    await repository.addHolding(
      AddInvestmentRequest(
        type: InvestmentAssetType.stock,
        symbol: 'OPEN-HOME-TEST',
        name: '计入首页仓位',
        price: 10,
        currentPrice: 10,
        quantity: 3,
        transactionDate: DateTime.now(),
        priceSource: PriceSource.manual,
        includeInHomeNetAssets: true,
      ),
    );
    container.invalidate(investmentPortfolioProvider);
    await tester.pumpAndSettle();

    final portfolio = await repository.getPortfolio();
    expect(portfolio.positions, hasLength(2));
    expect(portfolio.investmentValue, closeTo(130, 1e-9));

    final card = tester.widget<HomeAssetCard>(find.byType(HomeAssetCard));
    expect(card.investmentByCurrency, {'CNY': 30});

    final semantics = tester.ensureSemantics();
    final trend = tester.getSemantics(
      find.byKey(const ValueKey('home-trend-chart')),
    );
    expect(trend.value, contains('总资产 30.00 CNY'));
    semantics.dispose();
    await tester.pump(const Duration(milliseconds: 700));
  });

  testWidgets('the asset overview replaces 分类统计 with 投资管理', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);

    container.read(appRouterProvider).go('/profile/assets');
    await tester.pumpAndSettle();

    expect(find.text('投资管理'), findsOneWidget);
    expect(find.text('股票·基金·债券'), findsOneWidget);
    // The replaced entry must not survive anywhere on the page.
    expect(find.text('分类统计'), findsNothing);
  });

  testWidgets('tapping 投资管理 opens the overview with all five tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);

    container.read(appRouterProvider).go('/profile/assets');
    await tester.pumpAndSettle();
    await tester.tap(find.text('投资管理'));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('investment-tab-overview')), findsOneWidget);
    for (final type in InvestmentAssetType.values) {
      expect(
        find.byKey(ValueKey('investment-tab-${type.name}')),
        findsOneWidget,
      );
    }
    // The page must be able to get back to the asset overview.
    expect(find.byKey(const ValueKey('investment-back')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('investment-back')));
    await tester.pumpAndSettle();
    expect(find.text('资产总览'), findsOneWidget);
  });

  testWidgets('an empty portfolio shows one friendly invitation, not zeros', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await openInvestments(tester);

    expect(find.text('还没有投资资产'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('investment-empty-add')),
      findsOneWidget,
    );
    // No misleading ¥0.00 summary card.
    expect(find.text('投资资产'), findsNothing);
  });

  testWidgets('switching to a class tab shows its own empty state', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await openInvestments(tester);

    for (final type in InvestmentAssetType.values) {
      await tester.tap(
        find.byKey(ValueKey('investment-tab-${type.name}')),
      );
      await tester.pumpAndSettle();
      expect(find.text(type.emptyLabel), findsOneWidget);
    }
  });

  testWidgets('the overview shows totals, four classes and a trend', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await addHolding(
      tester,
      type: InvestmentAssetType.stock,
      symbol: '600519',
      name: '贵州茅台',
      price: 100,
      quantity: 100,
    );
    await addHolding(
      tester,
      type: InvestmentAssetType.fund,
      symbol: '510300',
      name: '沪深300ETF',
      price: 3.5,
      quantity: 1000,
    );
    await openInvestments(tester);
    await tester.pumpAndSettle();

    expect(find.text('投资资产'), findsOneWidget);
    expect(find.text('今日涨跌'), findsOneWidget);
    expect(find.text('累计收益'), findsOneWidget);
    expect(find.text('投资分类'), findsOneWidget);
    expect(find.text('投资资产趋势'), findsOneWidget);
    for (final type in InvestmentAssetType.values) {
      expect(
        find.byKey(ValueKey('investment-category-${type.name}')),
        findsOneWidget,
      );
    }
    expect(find.text('贵州茅台'), findsOneWidget);
    expect(find.text('沪深300ETF'), findsOneWidget);
  });

  testWidgets('the amount mask reuses the existing privacy dots', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await addHolding(
      tester,
      type: InvestmentAssetType.stock,
      symbol: '600519',
      name: '贵州茅台',
      price: 100,
      quantity: 100,
    );
    await openInvestments(tester);
    await tester.pumpAndSettle();

    expect(find.text('••••'), findsNothing);
    await tester.tap(find.byKey(const ValueKey('investment-amount-toggle')));
    await tester.pumpAndSettle();
    // The same mask widget the asset page uses, so the hidden amount never
    // scales the dots with the headline font size.
    expect(find.text('••••'), findsWidgets);
  });

  testWidgets('a class tab lists its holdings and opens the detail page', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await addHolding(
      tester,
      type: InvestmentAssetType.bond,
      symbol: '230023',
      name: '23附息国债10',
      price: 100,
      quantity: 100,
    );
    await openInvestments(tester);
    await tester.tap(
      find.byKey(const ValueKey('investment-tab-bond')),
    );
    await tester.pumpAndSettle();

    expect(find.text('债券总资产'), findsOneWidget);
    expect(find.text('持仓列表'), findsOneWidget);
    expect(find.text('23附息国债10'), findsOneWidget);
    expect(find.text('230023'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('investment-category-add-bond')),
      findsOneWidget,
    );

    final holdings = await container
        .read(investmentRepositoryProvider)
        .getHoldings(InvestmentAssetType.bond);
    await tester.tap(
      find.byKey(ValueKey('investment-holding-${holdings.single.id}')),
    );
    await tester.pumpAndSettle();
    expect(find.text('持仓数据'), findsOneWidget);
    expect(find.text('平均成本'), findsOneWidget);
    expect(find.text('交易记录'), findsOneWidget);
    // The opening buy is always present.
    expect(find.text('买入'), findsWidgets);
  });

  testWidgets('the add page offers search and manual modes', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await openInvestments(tester);

    await tester.tap(find.byKey(const ValueKey('investment-add-action')));
    await tester.pumpAndSettle();
    // The type picker asks which class first.
    expect(find.text('选择投资类型'), findsOneWidget);
    await tester.tap(
      find.byKey(const ValueKey('investment-type-pick-stock')),
    );
    await tester.pumpAndSettle();

    expect(find.text('添加投资'), findsOneWidget);
    expect(
      find.byKey(const ValueKey('investment-add-mode-search')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('investment-add-mode-manual')),
      findsOneWidget,
    );
    expect(
      find.byKey(const ValueKey('investment-search-field')),
      findsOneWidget,
    );

    await tester.enterText(
      find.byKey(const ValueKey('investment-search-field')),
      '600519',
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 500));
    expect(
      find.byKey(const ValueKey('investment-search-result-600519')),
      findsOneWidget,
    );

    // Selecting a hit reveals the purchase form.
    await tester.tap(
      find.byKey(const ValueKey('investment-search-result-600519')),
    );
    await tester.pumpAndSettle();
    expect(
      find.byKey(const ValueKey('investment-form-quantity')),
      findsOneWidget,
    );
    expect(find.byKey(const ValueKey('investment-form-submit')), findsOneWidget);
  });

  testWidgets('manual add writes a holding with a manual price source', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await openInvestments(tester);

    await tester.tap(find.byKey(const ValueKey('investment-empty-add')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('investment-type-pick-crypto')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('investment-add-mode-manual')),
    );
    await tester.pumpAndSettle();

    final inclusionSwitch = find.byKey(
      const ValueKey('investment-include-in-home-net-assets'),
    );
    expect(inclusionSwitch, findsOneWidget);
    expect(tester.widget<SwitchListTile>(inclusionSwitch).value, isFalse);
    await tester.tap(
      find.byKey(const ValueKey('investment-home-assets-tip')),
    );
    await tester.pumpAndSettle();
    expect(
      find.text('关闭后，投资类金额仅在投资管理页面展示，不计入首页展示的账目净资产。'),
      findsOneWidget,
    );
    await tester.tap(find.text('知道了'));
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const ValueKey('investment-form-name')),
      '我的币',
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-form-symbol')),
      'MYCOIN',
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-form-price')),
      '10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-form-quantity')),
      '100',
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-form-valuation')),
      '12',
    );
    await tester.tap(find.byKey(const ValueKey('investment-form-submit')));
    await tester.pumpAndSettle();

    final holdings = await container
        .read(investmentRepositoryProvider)
        .getHoldings(InvestmentAssetType.crypto);
    expect(holdings.length, 1);
    expect(holdings.single.asset.priceSource.name, 'manual');
    expect(holdings.single.asset.manualPrice, closeTo(12, 1e-9));
    expect(holdings.single.quantity, closeTo(100, 1e-9));
    expect(holdings.single.includeInHomeNetAssets, isFalse);

    // And it renders on the crypto tab.
    await tester.tap(find.byKey(const ValueKey('investment-tab-crypto')));
    await tester.pumpAndSettle();
    expect(find.text('我的币'), findsOneWidget);
  });

  testWidgets('manual add persists opt-in to homepage net assets', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await openInvestments(tester);
    await tester.tap(find.byKey(const ValueKey('investment-empty-add')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('investment-type-pick-crypto')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('investment-add-mode-manual')),
    );
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('investment-include-in-home-net-assets')),
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-form-name')),
      '计入首页的币',
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-form-symbol')),
      'INCLUDED',
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-form-price')),
      '10',
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-form-quantity')),
      '2',
    );
    await tester.tap(find.byKey(const ValueKey('investment-form-submit')));
    await tester.pumpAndSettle();

    final holdings = await container
        .read(investmentRepositoryProvider)
        .getHoldings(InvestmentAssetType.crypto);
    expect(holdings.single.includeInHomeNetAssets, isTrue);
  });

  testWidgets('invalid input is rejected in the form', (tester) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await openInvestments(tester);
    await tester.tap(find.byKey(const ValueKey('investment-empty-add')));
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('investment-type-pick-stock')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('investment-add-mode-manual')),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('investment-form-submit')));
    await tester.pumpAndSettle();
    expect(find.text('请输入投资名称'), findsOneWidget);
    expect(find.text('请输入投资代码'), findsOneWidget);
    expect(find.text('请输入有效价格'), findsOneWidget);
    expect(find.text('请输入有效数量'), findsOneWidget);
  });

  testWidgets('交易记录 records a sell and keeps the position correct', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await addHolding(
      tester,
      type: InvestmentAssetType.stock,
      symbol: '600519',
      name: '贵州茅台',
      price: 100,
      quantity: 100,
    );
    await openInvestments(tester);
    await tester.tap(find.byKey(const ValueKey('investment-tab-stock')));
    await tester.pumpAndSettle();

    final holdings = await container
        .read(investmentRepositoryProvider)
        .getHoldings(InvestmentAssetType.stock);
    final holdingId = holdings.single.id;
    container
        .read(appRouterProvider)
        .go('/profile/investments/holdings/detail/$holdingId');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('investment-detail-add-transaction')),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('记录交易'), findsOneWidget);
    // All four MVP transaction types are offered.
    for (final type in InvestmentTransactionType.values) {
      expect(
        find.byKey(ValueKey('investment-tx-type-${type.name}')),
        findsOneWidget,
      );
    }

    await tester.tap(
      find.byKey(const ValueKey('investment-tx-type-sell')),
    );
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byKey(const ValueKey('investment-tx-quantity')),
      '40',
    );
    await tester.enterText(
      find.byKey(const ValueKey('investment-tx-price')),
      '120',
    );
    await tester.tap(find.byKey(const ValueKey('investment-tx-submit')));
    await tester.pumpAndSettle();

    final updated = await container
        .read(investmentRepositoryProvider)
        .getHolding(holdingId);
    expect(updated!.quantity, closeTo(60, 1e-9));
    expect(updated.averageCost, closeTo(100, 1e-9));

    final records = await container
        .read(investmentRepositoryProvider)
        .getTransactions(holdingId);
    expect(records.length, 2);
    expect(records.first.type, InvestmentTransactionType.sell);
    expect(find.text('卖出'), findsWidgets);
  });

  testWidgets('交易记录 records a dividend without moving the position', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(420.5, 935));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await pumpApp(tester);
    await addHolding(
      tester,
      type: InvestmentAssetType.bond,
      symbol: '230023',
      name: '23附息国债10',
      price: 100,
      quantity: 100,
    );
    await openInvestments(tester);
    final holdings = await container
        .read(investmentRepositoryProvider)
        .getHoldings(InvestmentAssetType.bond);
    final holdingId = holdings.single.id;
    container
        .read(appRouterProvider)
        .go('/profile/investments/holdings/detail/$holdingId');
    await tester.pumpAndSettle();

    await tester.tap(
      find.byKey(const ValueKey('investment-detail-add-transaction')),
    );
    await tester.pumpAndSettle();
    await tester.tap(
      find.byKey(const ValueKey('investment-tx-type-dividend')),
    );
    await tester.pumpAndSettle();
    // A cash distribution asks for an amount, not quantity × price.
    expect(find.byKey(const ValueKey('investment-tx-amount')), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('investment-tx-amount')),
      '120',
    );
    await tester.tap(find.byKey(const ValueKey('investment-tx-submit')));
    await tester.pumpAndSettle();

    final updated = await container
        .read(investmentRepositoryProvider)
        .getHolding(holdingId);
    expect(updated!.quantity, closeTo(100, 1e-9));
    final records = await container
        .read(investmentRepositoryProvider)
        .getTransactions(holdingId);
    expect(records.first.type, InvestmentTransactionType.dividend);
    expect(records.first.amount, closeTo(120, 1e-9));
    expect(find.text('分红'), findsWidgets);
  });
}
