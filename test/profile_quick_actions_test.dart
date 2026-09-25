import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/profile/application/profile_quick_actions_controller.dart';
import 'package:jizhang_app/features/settings/application/theme_controller.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';

void main() {
  testWidgets(
    'liquid glass profile renders prototype sections and switches dark mode',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 874));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final db = createMemoryDatabase();
      await DatabaseSeeder(db).seedIfNeeded(includeDemoData: true);
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sessionProvider.overrideWithValue(const AsyncData(null)),
        ],
      );
      addTearDown(() async {
        container.dispose();
        await db.close();
      });

      final router = container.read(appRouterProvider);
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              final brightness =
                  ref.watch(brightnessModeProvider).value ??
                  AppBrightnessPreference.light;
              return MaterialApp.router(
                theme: AppTheme.light(BuiltInThemes.liquidGlass),
                darkTheme: AppTheme.dark(BuiltInThemes.liquidGlass),
                themeMode: brightness == AppBrightnessPreference.dark
                    ? ThemeMode.dark
                    : ThemeMode.light,
                routerConfig: router,
              );
            },
          ),
        ),
      );

      router.go('/profile');
      await tester.pumpAndSettle();

      expect(find.text('常用功能'), findsOneWidget);
      final sectionTitle = tester.widget<Text>(find.text('常用功能'));
      expect(sectionTitle.style?.fontSize, 16);
      expect(sectionTitle.style?.fontWeight, FontWeight.w700);

      expect(find.text('多账本管理'), findsOneWidget);
      expect(find.text('多平台导入'), findsOneWidget);
      expect(find.text('收支分类'), findsOneWidget);
      expect(find.text('预算规划'), findsOneWidget);
      expect(find.text('个性主题'), findsOneWidget);
      expect(find.text('智能识别'), findsOneWidget);

      final billImportTitle = tester.widget<Text>(find.text('账单导入'));
      expect(billImportTitle.style?.fontSize, 11.5);
      final billImportSubtitle = tester.widget<Text>(find.text('多平台导入'));
      expect(billImportSubtitle.maxLines, 1);
      expect(billImportSubtitle.style?.fontSize, 8.5);

      expect(find.byKey(const ValueKey('profile-dark-mode')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-progressive-haze')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-notifications')), findsOneWidget);
      expect(find.byKey(const ValueKey('profile-settings')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('profile-dark-mode')));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.text('常用功能'))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);

      for (final target in const [
        ('/transactions', '流水'),
        ('/analysis', '收支分析'),
        ('/profile/quick-actions', '全部功能'),
        ('/profile/services', '更多服务'),
      ]) {
        router.go(target.$1);
        await tester.pumpAndSettle();
        final label = find.text(target.$2);
        expect(label, findsWidgets);
        expect(
          Theme.of(tester.element(label.first)).brightness,
          Brightness.dark,
          reason: '${target.$1} must keep the global night preference',
        );
        expect(tester.takeException(), isNull);
      }

      router.go('/profile');
      await tester.pumpAndSettle();
      await tester.drag(
        find.byType(ListView).first,
        const Offset(0, -560),
      );
      await tester.pumpAndSettle();
      expect(find.text('推荐APP'), findsOneWidget);
      expect(find.text('更多服务'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  test('profile quick actions persist drag order', () async {
    final settings = _MemorySettings();
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(profileQuickActionsProvider.future),
      profileQuickActionDefaults,
    );

    await container
        .read(profileQuickActionsProvider.notifier)
        .reorder(0, 2);

    expect(
      container.read(profileQuickActionsProvider).value,
      [
        'bill_import',
        'categories',
        'books',
        'budgets',
        'appearance',
        'autobookkeeping',
      ],
    );
    expect(
      await settings.get('profile.quickActions.order.v1'),
      'bill_import,categories,books,budgets,appearance,autobookkeeping',
    );
  });


  test('brightness preference persists real day and night mode', () async {
    final settings = _MemorySettings();
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(brightnessModeProvider.future),
      AppBrightnessPreference.light,
    );

    await container
        .read(brightnessModeProvider.notifier)
        .select(AppBrightnessPreference.dark);

    expect(
      container.read(brightnessModeProvider).value,
      AppBrightnessPreference.dark,
    );
    expect(
      await settings.get('appearance.brightness.preferred.v1'),
      'dark',
    );
  });

  test('profile quick actions preserve selected subset and normalize invalid ids', () async {
    final settings = _MemorySettings({
      'profile.quickActions.order.v1':
          'appearance,unknown,appearance,books',
    });
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(profileQuickActionsProvider.future),
      ['appearance', 'books'],
    );
  });

  test('profile quick actions support add remove and six item limit', () async {
    final settings = _MemorySettings();
    final container = ProviderContainer(
      overrides: [
        appSettingsRepositoryProvider.overrideWithValue(settings),
      ],
    );
    addTearDown(container.dispose);

    await container.read(profileQuickActionsProvider.future);
    expect(
      await container
          .read(profileQuickActionsProvider.notifier)
          .toggle('bill_import'),
      ProfileQuickActionToggleResult.removed,
    );
    expect(
      await container
          .read(profileQuickActionsProvider.notifier)
          .toggle('assets'),
      ProfileQuickActionToggleResult.added,
    );
    expect(container.read(profileQuickActionsProvider).value, contains('assets'));
    expect(
      await container
          .read(profileQuickActionsProvider.notifier)
          .toggle('family'),
      ProfileQuickActionToggleResult.atLimit,
    );
  });

  testWidgets('all functions page exposes selection and separate sort mode', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = createMemoryDatabase();
    await DatabaseSeeder(db).seedIfNeeded(includeDemoData: true);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionProvider.overrideWithValue(const AsyncData(null)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(BuiltInThemes.liquidGlass),
          darkTheme: AppTheme.dark(BuiltInThemes.liquidGlass),
          routerConfig: router,
        ),
      ),
    );

    router.go('/profile/quick-actions');
    await tester.pumpAndSettle();

    expect(find.text('全部功能'), findsOneWidget);
    expect(find.text('账户资产'), findsOneWidget);
    expect(find.byKey(const ValueKey('profile-quick-actions-sort')), findsOneWidget);

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-quick-toggle-bill_import')),
      160,
    );
    await tester.tap(
      find.byKey(const ValueKey('profile-quick-toggle-bill_import')),
    );
    await tester.pumpAndSettle();

    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('profile-quick-toggle-assets')),
      -160,
    );
    await tester.tap(find.byKey(const ValueKey('profile-quick-toggle-assets')));
    await tester.pumpAndSettle();

    expect(container.read(profileQuickActionsProvider).value, contains('assets'));

    await tester.tap(find.byKey(const ValueKey('profile-quick-actions-sort')));
    await tester.pumpAndSettle();
    expect(find.text('常用功能排序'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('profile services route exposes complete service center', (tester) async {
    await tester.binding.setSurfaceSize(const Size(390, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final db = createMemoryDatabase();
    await DatabaseSeeder(db).seedIfNeeded(includeDemoData: true);
    final container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionProvider.overrideWithValue(const AsyncData(null)),
      ],
    );
    addTearDown(() async {
      container.dispose();
      await db.close();
    });

    final router = container.read(appRouterProvider);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(BuiltInThemes.liquidGlass),
          routerConfig: router,
        ),
      ),
    );

    router.go('/profile/services');
    await tester.pumpAndSettle();
    expect(find.text('更多服务'), findsOneWidget);
    expect(find.text('通知设置'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('服务协议'), 180);
    expect(find.text('服务协议'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

class _MemorySettings implements AppSettingsRepository {
  _MemorySettings([Map<String, String>? initial])
      : values = {...?initial};

  final Map<String, String> values;

  @override
  Future<String?> get(String key) async => values[key];

  @override
  Future<void> set(String key, String value) async {
    values[key] = value;
  }
}
