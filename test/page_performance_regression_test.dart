import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/widgets/app_page_background.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_inbox.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_settings.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_strategy.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_page.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_visuals.dart';
import 'package:jizhang_app/features/finance_center/data/finance_center_repository.dart';
import 'package:jizhang_app/features/finance_center/presentation/finance_center_page.dart';
import 'package:jizhang_app/features/insights/application/insight_feed_provider.dart';
import 'package:jizhang_app/features/profile/application/profile_quick_actions_controller.dart';
import 'package:jizhang_app/features/settings/application/theme_controller.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';

class _Settings implements AppSettingsRepository {
  final values = <String, String>{};
  final writes = <({String key, String value, Completer<void> done})>[];
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> set(String key, String value) async {
    final done = Completer<void>();
    writes.add((key: key, value: value, done: done));
    await done.future;
    values[key] = value;
  }
}

AutoBookkeepingRuntimeStatus _status(bool enabled, {bool healthy = true}) =>
    AutoBookkeepingRuntimeStatus.fromMap({
      'enabled': enabled,
      'accessibilityGranted': true,
      'accessibilityConnected': true,
      'overlayGranted': true,
      'notificationGranted': true,
      'foregroundRunning': healthy,
      'notificationListenerGranted': true,
      'notificationListenerEnabled': true,
      'notificationListenerConnected': true,
    });

class _Bridge extends MethodChannelAutoBookkeepingSettings {
  bool enabled = false;
  bool healthy = true;
  bool holdReads = false;
  bool failReads = false;
  final reads = <Completer<AutoBookkeepingRuntimeStatus>>[];
  final writes = <({bool value, Completer<void> done})>[];
  @override
  Future<AutoBookkeepingRuntimeStatus> runtimeStatus() {
    if (failReads) return Future.error(StateError('runtime unavailable'));
    if (!holdReads) return Future.value(_status(enabled, healthy: healthy));
    final done = Completer<AutoBookkeepingRuntimeStatus>();
    reads.add(done);
    return done.future;
  }

  @override
  Future<void> setEnabled(bool value) async {
    final done = Completer<void>();
    writes.add((value: value, done: done));
    await done.future;
    enabled = value;
  }
}

class _Finance implements FinanceCenterRepository {
  int invoiceReads = 0;
  int taxReads = 0;
  @override
  Future<List<FinanceInvoice>> invoices() async {
    invoiceReads++;
    return [];
  }

  @override
  Future<List<TaxFiling>> taxFilings() async {
    taxReads++;
    return [];
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  test(
    'theme feedback is immediate and duplicate selections do not write',
    () async {
      final settings = _Settings();
      final container = ProviderContainer(
        overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
      );
      addTearDown(container.dispose);
      await container.read(preferredThemeProvider.future);
      final controller = container.read(preferredThemeProvider.notifier);
      final save = controller.select(BuiltInThemes.liquidGlass.id);
      expect(
        container.read(preferredThemeProvider).value,
        BuiltInThemes.liquidGlass.id,
      );
      await controller.select(BuiltInThemes.liquidGlass.id);
      await _flush();
      expect(settings.writes, hasLength(1));
      settings.writes.single.done.complete();
      await save;
      expect(settings.values.values, contains(BuiltInThemes.liquidGlass.id));
    },
  );

  test('brightness writes are ordered and an old failure cannot undo a newer selection', () async {
    final settings = _Settings();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    await container.read(brightnessModeProvider.future);
    final controller = container.read(brightnessModeProvider.notifier);
    final first = controller.select(AppBrightnessPreference.dark);
    final latest = controller.select(AppBrightnessPreference.light);
    await _flush();
    expect(settings.writes, hasLength(1));
    settings.writes.first.done.completeError(StateError('old save failed'));
    await first;
    await _flush();
    expect(
      container.read(brightnessModeProvider).value,
      AppBrightnessPreference.light,
    );
    expect(settings.writes, hasLength(2));
    settings.writes.last.done.complete();
    await latest;
    expect(settings.values.values, contains('light'));
  });

  test('strategy rolls back to the last persisted value when all queued saves fail', () async {
    final settings = _Settings();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    await container.read(autoBookkeepingStrategyProvider.future);
    final controller = container.read(autoBookkeepingStrategyProvider.notifier);
    final first = controller.select(AutoBookkeepingStrategy.smart);
    final latest = controller.select(AutoBookkeepingStrategy.automatic);
    final failure = expectLater(latest, throwsStateError);
    expect(
      container.read(autoBookkeepingStrategyProvider).value,
      AutoBookkeepingStrategy.automatic,
    );
    await _flush();
    settings.writes.first.done.completeError(StateError('first failed'));
    await first;
    await _flush();
    settings.writes.last.done.completeError(StateError('latest failed'));
    await failure;
    expect(
      container.read(autoBookkeepingStrategyProvider).value,
      AutoBookkeepingStrategy.conservative,
    );
  });

  test('quick action order keeps the latest edit and persists it after an old failure', () async {
    final settings = _Settings();
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    await container.read(profileQuickActionsProvider.future);
    final controller = container.read(profileQuickActionsProvider.notifier);
    final first = controller.setOrder(['books', 'assets']);
    final latest = controller.setOrder(['books', 'categories']);
    await _flush();
    settings.writes.first.done.completeError(StateError('old failed'));
    await first;
    await _flush();
    expect(container.read(profileQuickActionsProvider).value, [
      'books',
      'categories',
    ]);
    settings.writes.last.done.complete();
    await latest;
    expect(settings.values.values, contains('books,categories'));
  });

  testWidgets(
    'profile viewport stays fixed through push/pop and brightness preserves scrolling',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(390, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      final db = createMemoryDatabase();
      await DatabaseSeeder(db).seedIfNeeded(includeDemoData: true);
      final settings = _Settings();
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          appSettingsRepositoryProvider.overrideWithValue(settings),
          sessionProvider.overrideWithValue(const AsyncData(null)),
          confirmedInsightFeedProvider.overrideWith((ref) async => null),
          autoBookkeepingSettingsProvider.overrideWithValue(_Bridge()),
          pendingPaymentInboxProvider.overrideWith((ref) async => []),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });
      await container.read(brightnessModeProvider.future);
      final router = container.read(appRouterProvider);
      router.go('/profile');
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) => MaterialApp.router(
              theme: AppTheme.light(BuiltInThemes.liquidGlass),
              darkTheme: AppTheme.dark(BuiltInThemes.liquidGlass),
              themeMode:
                  ref.watch(brightnessModeProvider).value ==
                      AppBrightnessPreference.dark
                  ? ThemeMode.dark
                  : ThemeMode.light,
              routerConfig: router,
              builder: (context, child) =>
                  AppAppearanceBackground(child: child!),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final view = find.byType(LiquidGlassView, skipOffstage: false);
      final size = tester.getSize(view);
      for (final path in [
        '/profile/autobookkeeping',
        '/profile/categories',
        '/profile/membership',
      ]) {
        final pushed = router.push<void>(path);
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getSize(view), size, reason: path);
        await tester.pumpAndSettle();
        router.pop();
        await tester.pump(const Duration(milliseconds: 80));
        expect(tester.getSize(view), size);
        await tester.pumpAndSettle();
        await pushed;
      }
      final list = find.byKey(const PageStorageKey('profile-scroll'));
      await tester.drag(list, const Offset(0, -420));
      await tester.pumpAndSettle();
      double offset() => tester
          .state<ScrollableState>(
            find.descendant(of: list, matching: find.byType(Scrollable)).first,
          )
          .position
          .pixels;
      final before = offset();
      final navigatorBefore = rootNavigatorKey.currentState;
      expect(before, greaterThan(0));
      final save = container
          .read(brightnessModeProvider.notifier)
          .select(AppBrightnessPreference.dark);
      await tester.pumpAndSettle();
      expect(rootNavigatorKey.currentState, same(navigatorBefore));
      expect(offset(), closeTo(before, .1));
      settings.writes.single.done.complete();
      await save;
      final secondary = router.push<void>('/profile/finance-center');
      await tester.pumpAndSettle();
      await tester.tap(find.text('报税'));
      await tester.pumpAndSettle();
      final pageBefore = tester.state(find.byType(FinanceCenterPage));
      final lightSave = container
          .read(brightnessModeProvider.notifier)
          .select(AppBrightnessPreference.light);
      await tester.pumpAndSettle();
      expect(tester.state(find.byType(FinanceCenterPage)), same(pageBefore));
      expect(
        tester
            .widget<SegmentedButton<int>>(find.byType(SegmentedButton<int>))
            .selected,
        {1},
      );
      settings.writes.last.done.complete();
      await lightSave;
      router.pop();
      await tester.pumpAndSettle();
      await secondary;
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'auto switch gives immediate save feedback and remains usable during connection checks',
    (tester) async {
      final bridge = _Bridge();
      var inboxLoads = 0;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            autoBookkeepingSettingsProvider.overrideWithValue(bridge),
            appSettingsRepositoryProvider.overrideWithValue(_Settings()),
            recentAutoBookkeepingProvider.overrideWith(
              (ref) => Stream.value([]),
            ),
            pendingPaymentInboxProvider.overrideWith((ref) async {
              inboxLoads++;
              return [];
            }),
          ],
          child: const MaterialApp(home: Scaffold(body: AutoBookkeepingPage())),
        ),
      );
      await tester.pumpAndSettle();
      AutoBookkeepingHero hero() =>
          tester.widget(find.byType(AutoBookkeepingHero));
      final initialInboxLoads = inboxLoads;
      hero().onChanged!(true);
      await tester.pump();
      expect(hero().busy, isTrue);
      expect(hero().onChanged, isNull);
      expect(find.text('正在保存设置…'), findsOneWidget);
      bridge.healthy = false;
      bridge.failReads = true;
      bridge.writes.first.done.complete();
      await tester.pump();
      await tester.pump();
      expect(hero().enabled, isTrue);
      expect(hero().connecting, isTrue);
      expect(hero().onChanged, isNotNull);
      hero().onChanged!(false);
      await tester.pump();
      bridge.failReads = false;
      bridge.writes.last.done.complete();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 1500));
      await tester.pumpAndSettle();
      expect(hero().enabled, isFalse);
      expect(hero().connecting, isFalse);
      expect(hero().onChanged, isNotNull);
      expect(bridge.writes.map((item) => item.value), [true, false]);
      expect(
        inboxLoads,
        initialInboxLoads,
        reason: 'health polling must not reload the inbox',
      );
      final filters = tester
          .renderObjectList<RenderBackdropFilter>(find.byType(BackdropFilter))
          .toList();
      expect(
        filters.where((filter) => filter.backdropKey == null),
        hasLength(1),
        reason: 'the overlapping floating button needs an independent filter',
      );
      expect(
        filters
            .where((filter) => filter.backdropKey != null)
            .map((filter) => filter.backdropKey)
            .toSet(),
        hasLength(1),
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('auto runtime refresh ignores an older result arriving last', (
    tester,
  ) async {
    final bridge = _Bridge()..holdReads = true;
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoBookkeepingSettingsProvider.overrideWithValue(bridge),
          appSettingsRepositoryProvider.overrideWithValue(_Settings()),
          recentAutoBookkeepingProvider.overrideWith((ref) => Stream.value([])),
          pendingPaymentInboxProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: Scaffold(body: AutoBookkeepingPage())),
      ),
    );
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(bridge.reads, hasLength(2));
    bridge.reads.last.complete(_status(true));
    await tester.pump();
    bridge.reads.first.complete(_status(false));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<AutoBookkeepingHero>(find.byType(AutoBookkeepingHero))
          .enabled,
      isTrue,
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('finance theme rebuilds and tab changes reuse queries', (
    tester,
  ) async {
    final repo = _Finance();
    final container = ProviderContainer(
      overrides: [financeCenterRepositoryProvider.overrideWithValue(repo)],
    );
    addTearDown(container.dispose);
    Widget app(bool dark) => UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: dark ? AppTheme.dark() : AppTheme.light(),
        home: const Scaffold(body: FinanceCenterPage()),
      ),
    );
    await tester.pumpWidget(app(false));
    await tester.pumpAndSettle();
    expect(repo.invoiceReads, 1);
    await tester.pumpWidget(app(true));
    await tester.pumpAndSettle();
    expect(repo.invoiceReads, 1);
    await tester.tap(find.text('报税'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('发票'));
    await tester.pumpAndSettle();
    expect(repo.invoiceReads, 1);
    expect(repo.taxReads, 1);
    expect(tester.takeException(), isNull);
  });
}
