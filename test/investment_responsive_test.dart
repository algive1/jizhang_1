import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/investments/data/investment_repository.dart';
import 'package:jizhang_app/features/investments/domain/investment_asset.dart';

/// The investment module must hold up on the smallest supported width and at
/// the largest text scale the app supports, exactly like the existing pages.
void main() {
  /// A deliberately large position: the amounts must never break the card.
  const hugeQuantity = 987654.32;
  const hugePrice = 1234.56;

  for (final size in [const Size(320, 700), const Size(393, 844)]) {
    for (final scale in [1.0, 1.6]) {
      testWidgets(
        '投资管理 renders without overflow at $size and scale $scale',
        (tester) async {
          await tester.binding.setSurfaceSize(size);
          addTearDown(() => tester.binding.setSurfaceSize(null));
          final database = createMemoryDatabase();
          await DatabaseSeeder(database).seedIfNeeded();
          addTearDown(database.close);
          final container = ProviderContainer(
            overrides: [databaseProvider.overrideWithValue(database)],
          );
          addTearDown(container.dispose);

          // One holding in every class, plus a manual asset.
          final repository = container.read(investmentRepositoryProvider);
          for (final type in InvestmentAssetType.values) {
            await repository.addHolding(
              AddInvestmentRequest(
                type: type,
                symbol: type == InvestmentAssetType.crypto
                    ? 'BTC'
                    : type == InvestmentAssetType.fund
                    ? '510300'
                    : type == InvestmentAssetType.bond
                    ? '230023'
                    : '600519',
                name: type == InvestmentAssetType.stock
                    ? '贵州茅台超长名称用于验证省略号'
                    : '${type.label}测试标的',
                price: hugePrice,
                quantity: hugeQuantity,
                transactionDate: DateTime(2026, 9, 1),
              ),
            );
          }
          await repository.addHolding(
            AddInvestmentRequest(
              type: InvestmentAssetType.crypto,
              symbol: 'MYCOIN',
              name: '手动估值资产',
              price: 10,
              quantity: 100,
              transactionDate: DateTime(2026, 9, 1),
              priceSource: PriceSource.manual,
              currentPrice: 12,
            ),
          );

          final router = container.read(appRouterProvider);
          await tester.pumpWidget(
            MediaQuery(
              data: MediaQueryData(
                size: size,
                textScaler: TextScaler.linear(scale),
              ),
              child: UncontrolledProviderScope(
                container: container,
                child: MaterialApp.router(
                  theme: AppTheme.light(),
                  routerConfig: router,
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();

          // Overview tab.
          router.go('/profile/investments');
          await tester.pumpAndSettle();
          expect(find.text('投资资产'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Masked amounts must not overflow either.
          await tester.tap(find.byKey(const ValueKey('investment-amount-toggle')));
          await tester.pumpAndSettle();
          expect(tester.takeException(), isNull);

          // Each class tab.
          for (final type in InvestmentAssetType.values) {
            await tester.tap(
              find.byKey(ValueKey('investment-tab-${type.name}')),
            );
            await tester.pumpAndSettle();
            expect(find.text('${type.label}总资产'), findsOneWidget);
            expect(tester.takeException(), isNull);
          }

          // Detail page.
          final holdings = await repository.getHoldings(
            InvestmentAssetType.stock,
          );
          router.go(
            '/profile/investments/holdings/detail/${holdings.single.id}',
          );
          await tester.pumpAndSettle();
          expect(find.text('持仓数据'), findsOneWidget);
          expect(tester.takeException(), isNull);

          // Add page in both modes.
          router.go('/profile/investments/add?type=stock');
          await tester.pumpAndSettle();
          expect(find.text('添加投资'), findsOneWidget);
          expect(tester.takeException(), isNull);

          await tester.tap(
            find.byKey(const ValueKey('investment-add-mode-manual')),
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('investment-form-name')),
            findsOneWidget,
          );
          // The form is a scrollable list; the submit button legitimately sits
          // below the fold on a 320dp/1.6 screen and must be reachable.
          final formScrollable = find
              .descendant(
                of: find.byKey(const ValueKey('investment-form-scroll')),
                matching: find.byType(Scrollable),
              )
              .first;
          await tester.scrollUntilVisible(
            find.byKey(const ValueKey('investment-form-submit')),
            260,
            scrollable: formScrollable,
          );
          await tester.pumpAndSettle();
          expect(
            find.byKey(const ValueKey('investment-form-submit')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
  }
}
