import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_definition.dart';
import '../../../core/config/testing_access.dart';
import '../../membership/data/membership_repository.dart';
import '../../../core/models/membership.dart';
import '../../sharing/data/session_repository.dart';
import '../data/app_settings_repository.dart';

const _themeSettingKey = 'appearance.theme.preferred.v1';
const _themeCatalogCacheKey = 'appearance.theme.catalog.cache.v1';

class ThemeCatalog {
  const ThemeCatalog(this.themes);
  final List<AppThemeDefinition> themes;

  AppThemeDefinition byId(String? id) => themes.where((t) => t.id == id).firstOrNull ?? BuiltInThemes.freshGreen;
}

class ThemeController extends AsyncNotifier<String> {
  @override
  Future<String> build() async {
    return await ref.read(appSettingsRepositoryProvider).get(_themeSettingKey) ?? BuiltInThemes.freshGreen.id;
  }

  Future<void> select(String id) async {
    await ref.read(appSettingsRepositoryProvider).set(_themeSettingKey, id);
    state = AsyncData(id);
  }
}

final preferredThemeProvider = AsyncNotifierProvider<ThemeController, String>(ThemeController.new);

final themeCatalogProvider = FutureProvider<ThemeCatalog>((ref) async {
  final session = ref.watch(sessionRepositoryProvider);
  final settings = ref.read(appSettingsRepositoryProvider);

  ThemeCatalog? parseCatalog(Map<String, dynamic> data) {
    try {
      final version = (data['version'] as num?)?.toInt() ?? 1;
      final items = (data['themes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AppThemeDefinition.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (version < 2 &&
          !items.any((e) => e.id == BuiltInThemes.liquidGlass.id)) {
        items.add(BuiltInThemes.liquidGlass);
      }
      if (items.any((e) => e.id == BuiltInThemes.freshGreen.id)) {
        return ThemeCatalog(items);
      }
    } on Object {
      // Invalid remote/cache data must never make appearance unavailable.
    }
    return null;
  }

  try {
    final data = await ref.read(sharedApiProvider).request('/themes/catalog');
    final remote = parseCatalog(data);
    if (remote != null) {
      await settings.set(_themeCatalogCacheKey, jsonEncode(data));
      return remote;
    }
  } on Object {
    // Remote appearance config is best-effort. Fall through to last-known-good.
  }

  try {
    final cached = await settings.get(_themeCatalogCacheKey);
    if (cached != null) {
      final decoded = jsonDecode(cached);
      if (decoded is Map) {
        final local = parseCatalog(Map<String, dynamic>.from(decoded));
        if (local != null) return local;
      }
    }
  } on Object {
    // Corrupt cache is ignored in favor of the bundled safe catalog.
  }

  // Keep the dependency alive so a login/logout refresh can rebuild this provider.
  session.user;
  return const ThemeCatalog(BuiltInThemes.all);
});

final effectiveThemeProvider = Provider<AppThemeDefinition>((ref) {
  final catalog = ref.watch(themeCatalogProvider).value ?? const ThemeCatalog(BuiltInThemes.all);
  final preferred = ref.watch(preferredThemeProvider).value;
  final selected = catalog.byId(preferred);
  if (kAllFeaturesFreeForTesting || !selected.premium) return selected;
  final membership = ref.watch(membershipProvider).value;
  if (membership != null && membership.has(EntitlementKey.customTheme)) {
    return selected;
  }
  // Preserve the preferred id locally. If membership is restored the chosen
  // premium theme becomes effective again without silently changing preference.
  return BuiltInThemes.freshGreen;
});


enum AppBrightnessPreference { light, dark }

const _brightnessSettingKey = 'appearance.brightness.preferred.v1';

class BrightnessController
    extends AsyncNotifier<AppBrightnessPreference> {
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
    final previous = state.value ?? AppBrightnessPreference.light;
    state = AsyncData(value);
    try {
      await ref
          .read(appSettingsRepositoryProvider)
          .set(_brightnessSettingKey, value.name);
    } on Object {
      state = AsyncData(previous);
      rethrow;
    }
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
