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
      expect(find.byKey(const ValueKey('profile-dark-mode')), findsOneWidget);
      expect(tester.takeException(), isNull);

      await tester.tap(find.byKey(const ValueKey('profile-dark-mode')));
      await tester.pumpAndSettle();

      expect(
        Theme.of(tester.element(find.text('常用功能'))).brightness,
        Brightness.dark,
      );
      expect(tester.takeException(), isNull);

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

  test('profile quick actions normalize incomplete stored order', () async {
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
      [
        'appearance',
        'books',
        'bill_import',
        'categories',
        'budgets',
        'autobookkeeping',
      ],
    );
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
