import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/config/testing_access.dart';
import 'package:jizhang_app/features/accounts/data/receivable_repository.dart';
import 'package:jizhang_app/features/accounts/domain/account_management.dart';
import 'package:jizhang_app/features/profile/presentation/profile_cards.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';

void main() {
  for (final (width, textScale) in [(320.0, 1.6), (393.0, 1.0)]) {
    testWidgets(
      'account management fits width $width at text scale $textScale',
      (tester) async {
        await _pumpRoute(
          tester,
          route: '/profile/accounts',
          size: Size(width, 874),
          textScale: textScale,
        );

        expect(find.text('账户资金总额'), findsOneWidget);
        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets('profile settings sheet scrolls on a compact large-text screen', (
    tester,
  ) async {
    await _pumpRoute(
      tester,
      route: '/profile',
      size: const Size(320, 520),
      textScale: 1.6,
    );

    await tester.tap(find.byTooltip('设置'));
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);

    final lastDestination = find.text('关于好好记账');
    expect(lastDestination, findsOneWidget);
    await tester.ensureVisible(lastDestination);
    await tester.pumpAndSettle();

    final sheetRect = tester.getRect(find.byType(BottomSheet).last);
    final destinationRect = tester.getRect(lastDestination);
    expect(destinationRect.top, greaterThanOrEqualTo(sheetRect.top));
    expect(destinationRect.bottom, lessThanOrEqualTo(sheetRect.bottom));
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile account sheet fits a compact large-text screen', (
    tester,
  ) async {
    await _pumpRoute(
      tester,
      route: '/profile',
      size: const Size(320, 520),
      textScale: 1.6,
    );

    await tester.tap(find.byType(ProfileHero));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(BottomSheet), findsOneWidget);
    expect(find.text('本地使用中'), findsWidgets);
  });

  testWidgets(
    'theme membership prompt fits a compact large-text screen',
    (tester) async {
      await _pumpRoute(
        tester,
        route: '/profile/appearance',
        size: const Size(320, 520),
        textScale: 1.6,
      );

      final premiumTheme = find.text('云雾蓝');
      await tester.ensureVisible(premiumTheme);
      await tester.tap(premiumTheme);
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('会员主题'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
    skip: kAllFeaturesFreeForTesting,
  );

  testWidgets('receivable reminder sheet fits a compact large-text screen', (
    tester,
  ) async {
    final container = await _pumpRoute(
      tester,
      route: '/profile',
      size: const Size(320, 520),
      textScale: 1.6,
    );
    final now = DateTime(2026, 9, 24);
    await container
        .read(receivableRepositoryProvider)
        .create(
          Receivable(
            id: 'overflow-reminder',
            bookId: SeedIds.personalBook,
            name: '测试应收',
            type: ReceivableType.lend,
            counterparty: '测试往来人',
            totalAmount: 1000,
            receivedAmount: 0,
            occurredAt: now,
            reminderAt: now,
            status: ReceivableStatus.pending,
            businessStatus: '待回收',
            createdAt: now,
            updatedAt: now,
          ),
        );

    container
        .read(appRouterProvider)
        .go('/profile/accounts/receivables/overflow-reminder');
    await tester.pumpAndSettle();
    expect(find.text('应收详情'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.scrollUntilVisible(
      find.text('提醒'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('提醒'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('应收提醒'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

Future<ProviderContainer> _pumpRoute(
  WidgetTester tester, {
  required String route,
  required Size size,
  required double textScale,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final database = createMemoryDatabase();
  await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      sessionProvider.overrideWithValue(const AsyncData(null)),
    ],
  );
  final router = container.read(appRouterProvider);
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    container.dispose();
    await database.close();
  });

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
      ),
    ),
  );
  router.go(route);
  await tester.pumpAndSettle();
  return container;
}
