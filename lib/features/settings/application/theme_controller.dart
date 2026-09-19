import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_definition.dart';
import '../../membership/data/membership_repository.dart';
import '../../../core/models/membership.dart';
import '../../sharing/data/session_repository.dart';
import '../data/app_settings_repository.dart';

const _themeSettingKey = 'appearance.theme.preferred.v1';

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
  const baseUrl = String.fromEnvironment('SHARED_API_BASE_URL');
  if (baseUrl.isNotEmpty) {
    try {
      final data = await ref.read(sharedApiProvider).request('/themes/catalog');
      final items = (data['themes'] as List? ?? const [])
          .whereType<Map>()
          .map((e) => AppThemeDefinition.fromJson(Map<String, dynamic>.from(e)))
          .toList();
      if (items.any((e) => e.id == BuiltInThemes.freshGreen.id)) return ThemeCatalog(items);
    } on Object {
      // Remote appearance config is best-effort. Never block app startup.
    }
  }
  // Keep the dependency alive so a login/logout refresh can rebuild this provider.
  session.user;
  return const ThemeCatalog(BuiltInThemes.all);
});

final effectiveThemeProvider = Provider<AppThemeDefinition>((ref) {
  final catalog = ref.watch(themeCatalogProvider).value ?? const ThemeCatalog(BuiltInThemes.all);
  final preferred = ref.watch(preferredThemeProvider).value;
  final selected = catalog.byId(preferred);
  if (!selected.premium) return selected;
  final membership = ref.watch(membershipProvider).value;
  if (membership != null && membership.has(EntitlementKey.customTheme)) {
    return selected;
  }
  // Preserve the preferred id locally. If membership is restored the chosen
  // premium theme becomes effective again without silently changing preference.
  return BuiltInThemes.freshGreen;
});
