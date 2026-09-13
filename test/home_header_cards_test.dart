import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/dashboard_snapshot.dart';
import 'package:jizhang_app/features/home/data/home_data.dart';
import 'package:jizhang_app/features/home/presentation/home_promotional_cards.dart';

import 'support/reference_capture.dart';

void main() {
  for (final width in [393.0, 320.0]) {
    testWidgets('header cards interaction and layout at $width', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(Size(width, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await loadReferenceFonts(tester);
      final db = createMemoryDatabase();
      addTearDown(db.close);
      await DatabaseSeeder(db).seedIfNeeded();
      var amount = 120.0;
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          homeInsightProvider.overrideWith(
            (ref) => FinancialInsight(
              timeLabel: '22:00后消费',
              amount: amount,
              increasePercent: null,
              description: '上月同期样本不足，暂不显示消费增幅。',
            ),
          ),
        ],
      );
      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
      });
      final router = container.read(appRouterProvider);
      const boundary = ValueKey('header-cards-capture');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: RepaintBoundary(
            key: boundary,
            child: MaterialApp.router(
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light().copyWith(
                textTheme: AppTheme.light().textTheme.apply(
                  fontFamily: 'Reference Latin',
                  fontFamilyFallback: const ['PingFang SC'],
                ),
              ),
              routerConfig: router,
              builder: (context, child) => MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  textScaler: TextScaler.linear(width == 320 ? 1.6 : 1),
                ),
                child: child!,
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeProCard), findsNothing);
      expect(find.byType(HomeInsightCard).hitTestable(), findsOneWidget);
      await captureReference(
        tester,
        find.byKey(boundary),
        'header-expanded-$width',
      );

      await tester.tap(find.byType(HomeInsightCard));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/analysis');
      router.pop();
      await tester.pumpAndSettle();

      await tester.drag(find.byType(HomeInsightCard), const Offset(0, -90));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeInsightCard).hitTestable(), findsNothing);
      container.invalidate(homeInsightProvider);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeInsightCard).hitTestable(), findsNothing);
      await captureReference(
        tester,
        find.byKey(boundary),
        'header-collapsed-$width',
      );

      amount = 240;
      container.invalidate(homeInsightProvider);
      await tester.pumpAndSettle();
      expect(find.byType(HomeInsightCard).hitTestable(), findsNothing);
      expect(find.text('值得关注').hitTestable(), findsNothing);

      await tester.tap(find.byTooltip('会员'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, '/');
      expect(find.byType(HomeProCard), findsOneWidget);
      await captureReference(
        tester,
        find.byKey(boundary),
        'header-membership-$width',
      );
      await tester.tap(find.text('让账本多一份安全感'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(router.state.uri.path, '/profile/membership');
      expect(find.byType(HomeProCard), findsNothing);
      router.pop();
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tap(find.byTooltip('会员'));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      await tester.tapAt(const Offset(8, 80));
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.byType(HomeProCard), findsNothing);
      expect(router.state.uri.path, '/');
      expect(tester.takeException(), isNull);
    });
  }
}
