import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/features/settings/application/theme_controller.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';
import 'package:jizhang_app/features/settings/presentation/theme_settings_page.dart';

class _Settings implements AppSettingsRepository {
  _Settings([String? id])
    : values = {
        'appearance.theme.preferred.v1': ?id,
        'appearance.theme.catalog.cache.v1':
            '{"themes":[{"id":"almond_warm"}]}',
      };
  final Map<String, String> values;
  @override
  Future<String?> get(String key) async => values[key];
  @override
  Future<void> set(String key, String value) async => values[key] = value;
}

void main() {
  for (final (saved, expected) in [
    (null, 'fresh_green'),
    ('fresh_green', 'fresh_green'),
    ('liquid_glass', 'liquid_glass'),
    ('mist_blue', 'liquid_glass'),
    ('almond_warm', 'fresh_green'),
    ('unknown_remote_theme', 'fresh_green'),
  ]) {
    test(
      'theme preference $saved resolves and persists as $expected',
      () async {
        final settings = _Settings(saved);
        final container = ProviderContainer(
          overrides: [
            appSettingsRepositoryProvider.overrideWithValue(settings),
          ],
        );
        addTearDown(container.dispose);
        final catalog = await container.read(themeCatalogProvider.future);
        expect(catalog.themes.map((theme) => theme.id), [
          'fresh_green',
          'liquid_glass',
        ]);
        expect(catalog.themes.every((theme) => !theme.premium), isTrue);
        expect(await container.read(preferredThemeProvider.future), expected);
        expect(container.read(effectiveThemeProvider).id, expected);
        if (saved != null) {
          expect(settings.values['appearance.theme.preferred.v1'], expected);
        }
      },
    );
  }

  testWidgets('both defaults can be selected without membership', (
    tester,
  ) async {
    final settings = _Settings('fresh_green');
    final container = ProviderContainer(
      overrides: [appSettingsRepositoryProvider.overrideWithValue(settings)],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const ThemeSettingsPage(),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('好好绿'), findsOneWidget);
    expect(find.text('云雾蓝'), findsOneWidget);
    expect(find.text('杏仁暖'), findsNothing);
    expect(find.byIcon(Icons.lock_outline), findsNothing);
    await tester.tap(find.text('云雾蓝'));
    await tester.pumpAndSettle();
    expect(container.read(effectiveThemeProvider), BuiltInThemes.liquidGlass);
    expect(find.byType(BottomSheet), findsNothing);
    await tester.tap(find.text('好好绿'));
    await tester.pumpAndSettle();
    expect(container.read(effectiveThemeProvider), BuiltInThemes.freshGreen);
  });
}
