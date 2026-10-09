import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_definition.dart';
import '../../../app/theme/app_theme.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_page_background.dart';
import '../application/theme_controller.dart';

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(themeCatalogProvider);
    final preferred =
        ref.watch(preferredThemeProvider).value ?? BuiltInThemes.freshGreen.id;
    return Scaffold(
      appBar: AppBar(title: const Text('主题外观')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('主题暂时无法读取')),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text(
              '选择你喜欢的界面气质',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 6),
            Text(
              '好好绿与液态玻璃云雾蓝，两款默认主题免费使用。',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 22),
            for (final theme in value.themes) ...[
              _ThemeCard(
                theme: theme,
                selected: preferred == theme.id,
                onTap: () async {
                  try {
                    await ref
                        .read(preferredThemeProvider.notifier)
                        .select(theme.id);
                  } on Object {
                    if (context.mounted)
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('主题保存失败，请重试')),
                      );
                  }
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  const _ThemeCard({
    required this.theme,
    required this.selected,
    required this.onTap,
  });
  final AppThemeDefinition theme;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: onTap,
    child: Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: selected ? theme.primary : context.appDivider,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          _ThemePreview(theme: theme),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        theme.name,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: context.appPrimaryText),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  theme.description,
                  style: Theme.of(context).textTheme.bodyMedium
                      ?.copyWith(color: context.appSecondaryText),
                ),
              ],
            ),
          ),
          if (selected) Icon(Icons.check_circle, color: theme.primary),
        ],
      ),
    ),
  );
}

class _ThemePreview extends StatelessWidget {
  const _ThemePreview({required this.theme});

  final AppThemeDefinition theme;

  @override
  Widget build(BuildContext context) {
    final dark = context.appIsDark;
    final glass = dark || theme.style == AppThemeStyle.liquidGlass;
    final preview = Container(
      width: 74,
      height: 74,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: dark ? Colors.transparent : theme.background,
        gradient: glass && !dark
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [theme.background, theme.primarySoft, theme.surface],
              )
            : null,
        borderRadius: BorderRadius.circular(18),
      ),
      padding: const EdgeInsets.all(8),
      child: glass
          ? Stack(
              children: [
                Positioned(
                  left: 2,
                  right: 2,
                  top: 2,
                  height: 15,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: dark ? .12 : .62),
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: dark ? .24 : .82),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  left: 3,
                  right: 3,
                  bottom: 2,
                  height: 20,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF111111).withValues(alpha: .5)
                          : Colors.white.withValues(alpha: .68),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Colors.white.withValues(alpha: dark ? .24 : .90),
                      ),
                    ),
                    child: Center(
                      child: Container(
                        width: 12,
                        height: 4,
                        decoration: BoxDecoration(
                          color: theme.primary,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                    ),
                  ),
                ),
                Center(
                  child: Container(
                    width: 28,
                    height: 22,
                    decoration: BoxDecoration(
                      color: dark
                          ? const Color(0xFF111111)
                          : theme.surface.withValues(alpha: .88),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: dark ? Colors.transparent : theme.divider,
                      ),
                    ),
                  ),
                ),
              ],
            )
          : Column(
              children: [
                Container(
                  height: 12,
                  decoration: BoxDecoration(
                    color: theme.primarySoft,
                    borderRadius: BorderRadius.circular(8),
                  ),
                ),
                const SizedBox(height: 7),
                Expanded(
                  child: Row(
                    children: [
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Container(
                          decoration: BoxDecoration(
                            color: theme.surfaceSoft,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
    );
    if (!dark) return preview;
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Theme(
        data: AppTheme.dark(theme),
        child: AppPageBackground(child: preview),
      ),
    );
  }
}
