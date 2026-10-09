import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_definition.dart';
import '../data/app_settings_repository.dart';
import 'optimistic_setting.dart';

const _themeSettingKey = 'appearance.theme.preferred.v1';

class ThemeCatalog {
  const ThemeCatalog(this.themes);
  final List<AppThemeDefinition> themes;

  AppThemeDefinition byId(String? id) {
    final currentId = id == 'mist_blue' ? BuiltInThemes.liquidGlass.id : id;
    return themes.where((t) => t.id == currentId).firstOrNull ??
        BuiltInThemes.freshGreen;
  }
}

class ThemeController extends AsyncNotifier<String> {
  final _writer = OptimisticSetting<String>();
  @override
  Future<String> build() async {
    final settings = ref.read(appSettingsRepositoryProvider);
    final saved = await settings.get(_themeSettingKey);
    final id = const ThemeCatalog(BuiltInThemes.all).byId(saved).id;
    if (saved != null && saved != id) await settings.set(_themeSettingKey, id);
    return id;
  }

  Future<void> select(String id) async {
    final selected = const ThemeCatalog(BuiltInThemes.all).byId(id).id;
    final settings = ref.read(appSettingsRepositoryProvider);
    await _writer.select(
      selected,
      previous: state.value ?? BuiltInThemes.freshGreen.id,
      publish: (value) {
        if (ref.mounted) state = AsyncData(value);
      },
      save: (value) => settings.set(_themeSettingKey, value),
    );
  }
}

final preferredThemeProvider = AsyncNotifierProvider<ThemeController, String>(
  ThemeController.new,
);

// The two bundled defaults are authoritative; legacy remote/cache entries
// cannot reintroduce removed themes or override the glass material.
final themeCatalogProvider = FutureProvider<ThemeCatalog>(
  (ref) async => const ThemeCatalog(BuiltInThemes.all),
);

final effectiveThemeProvider = Provider<AppThemeDefinition>((ref) {
  final catalog =
      ref.watch(themeCatalogProvider).value ??
      const ThemeCatalog(BuiltInThemes.all);
  final preferred = ref.watch(preferredThemeProvider).value;
  return catalog.byId(preferred);
});

enum AppBrightnessPreference { light, dark }

const _brightnessSettingKey = 'appearance.brightness.preferred.v1';

class BrightnessController extends AsyncNotifier<AppBrightnessPreference> {
  final _writer = OptimisticSetting<AppBrightnessPreference>();
  @override
  Future<AppBrightnessPreference> build() async {
    final raw = await ref
        .read(appSettingsRepositoryProvider)
        .get(_brightnessSettingKey);
    return raw == AppBrightnessPreference.dark.name
        ? AppBrightnessPreference.dark
        : AppBrightnessPreference.light;
  }

  Future<void> select(AppBrightnessPreference value) async {
    final settings = ref.read(appSettingsRepositoryProvider);
    await _writer.select(
      value,
      previous: state.value ?? AppBrightnessPreference.light,
      publish: (value) {
        if (ref.mounted) state = AsyncData(value);
      },
      save: (value) => settings.set(_brightnessSettingKey, value.name),
    );
  }

  Future<void> toggle() async {
    final current = state.value ?? AppBrightnessPreference.light;
    await select(
      current == AppBrightnessPreference.light
          ? AppBrightnessPreference.dark
          : AppBrightnessPreference.light,
    );
  }
}

final brightnessModeProvider =
    AsyncNotifierProvider<BrightnessController, AppBrightnessPreference>(
      BrightnessController.new,
    );
