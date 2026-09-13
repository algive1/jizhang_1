import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/features/home/presentation/home_cards.dart';
import 'package:jizhang_app/features/home/presentation/home_asset_card.dart';

void main() {
  testWidgets('shows separated asset totals and opens the asset overview', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: HomeAssetCard(
              accounts: [
                _account('银行卡', 1500),
                _account('信用卡', -300, type: AccountType.creditCard),
                _account('美元账户', 50, currency: 'USD'),
              ],
              amountHidden: false,
              onTap: () => taps++,
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('home-asset-card')), findsOneWidget);
    expect(find.text('账面净资产'), findsOneWidget);
    expect(find.text('¥1,200.00'), findsOneWidget);
    expect(find.text('¥1,500.00'), findsOneWidget);
    expect(find.text('¥300.00'), findsOneWidget);
    expect(find.text('另有 1 种币种 · 分开统计'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('home-asset-card')));
    expect(taps, 1);
    expect(tester.takeException(), isNull);
  });

  testWidgets('hides every asset amount without changing the card structure', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: HomeAssetCard(
            accounts: [_account('现金', 1234.56)],
            amountHidden: true,
            onTap: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('••••'), findsNWidgets(3));
    expect(find.textContaining('1,234.56'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('uses explicit empty, loading and error states', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(
            children: [
              HomeAssetCard(
                accounts: const [],
                amountHidden: false,
                onTap: () {},
              ),
              const HomeAssetCard.loading(),
              HomeAssetCard.error(onRetry: () {}),
            ],
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('还没有资产数据'), findsOneWidget);
    expect(find.text('正在读取资产'), findsOneWidget);
    expect(find.text('资产暂时无法读取'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('homepage privacy state also masks the asset summary', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    var hidden = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    HomeSpendingGoalCard(
                      snapshot: DashboardSnapshot(
                        safeToSpend: 800,
                        forecastBalance: 1000,
                        hasBudget: true,
                        month: DateTime(2026, 9),
                        income: 1000,
                        expense: 200,
                        budgetAmount: 1000,
                        availableAmount: 800,
                        remainingDays: 20,
                        goalReservation: 0,
                      ),
                      onBudget: () {},
                      onGoal: () {},
                      onCalculation: () {},
                      amountHidden: hidden,
                      onAmountHiddenChanged: (value) => setState(() {
                        hidden = value;
                      }),
                    ),
                    const SizedBox(height: 12),
                    HomeAssetCard(
                      accounts: [
                        _account('银行卡', 2100),
                        _account('信用卡', -300, type: AccountType.creditCard),
                      ],
                      amountHidden: hidden,
                      onTap: () {},
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('¥800'), findsOneWidget);
    expect(find.text('¥1,800.00'), findsOneWidget);
    final spendingCard = tester.getRect(
      find.byKey(const ValueKey('home-spending-card')),
    );
    final assetCard = tester.getRect(
      find.byKey(const ValueKey('home-asset-card')),
    );
    await tester.tap(find.byKey(const ValueKey('home-hide-amount')));
    await tester.pump();

    expect(find.text('¥800'), findsNothing);
    expect(find.text('¥1,800.00'), findsNothing);
    expect(find.text('••••'), findsNWidgets(4));
    expect(
      tester.getRect(find.byKey(const ValueKey('home-spending-card'))),
      spendingCard,
    );
    expect(
      tester.getRect(find.byKey(const ValueKey('home-asset-card'))),
      assetCard,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('asset scene grows naturally at 320dp with large text', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: const TextScaler.linear(1.6)),
          child: child!,
        ),
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: HomeAssetCard(
              accounts: [
                _account('长期储蓄账户', 123456789.12),
                _account('信用卡', -9876543.21, type: AccountType.creditCard),
              ],
              amountHidden: false,
              onTap: () {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(
      tester.getSize(find.byKey(const ValueKey('home-asset-card'))).height,
      greaterThan(165),
    );
  });
}

Account _account(
  String name,
  double balance, {
  AccountType type = AccountType.debitCard,
  String currency = 'CNY',
}) => Account(
  id: name,
  name: name,
  type: type,
  balance: balance,
  currency: currency,
  icon: 'wallet',
  color: 0xff73963b,
  sortOrder: 0,
  isArchived: false,
  createdAt: DateTime(2026),
  updatedAt: DateTime(2026),
);
