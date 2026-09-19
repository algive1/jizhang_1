import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_definition.dart';
import '../../membership/data/membership_repository.dart';
import '../../../core/models/membership.dart';
import '../application/theme_controller.dart';

class ThemeSettingsPage extends ConsumerWidget {
  const ThemeSettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalog = ref.watch(themeCatalogProvider);
    final preferred = ref.watch(preferredThemeProvider).value ?? BuiltInThemes.freshGreen.id;
    final member = ref.watch(membershipProvider).value;
    final premium = member != null && member.has(EntitlementKey.customTheme);
    return Scaffold(
      appBar: AppBar(title: const Text('主题外观')),
      body: catalog.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => const Center(child: Text('主题暂时无法读取')),
        data: (value) => ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
          children: [
            Text('选择你喜欢的界面气质', style: Theme.of(context).textTheme.headlineMedium),
            const SizedBox(height: 6),
            Text('默认主题永久免费。会员可使用更多主题；会员到期后会暂时恢复默认主题，但会保留你的选择。', style: Theme.of(context).textTheme.bodyMedium),
            const SizedBox(height: 22),
            for (final theme in value.themes) ...[
              _ThemeCard(
                theme: theme,
                selected: preferred == theme.id,
                locked: theme.premium && !premium,
                onTap: () async {
                  if (theme.premium && !premium) {
                    final upgrade = await showModalBottomSheet<bool>(
                      context: context,
                      showDragHandle: true,
                      builder: (context) => Padding(
                        padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
                        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text('会员主题', style: Theme.of(context).textTheme.titleLarge),
                          const SizedBox(height: 8),
                          const Text('该主题属于会员个性化权益。开通会员后即可使用；会员到期后会暂时恢复默认主题，并保留本机主题偏好。'),
                          const SizedBox(height: 18),
                          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('查看会员')),
                        ]),
                      ),
                    );
                    if (upgrade == true && context.mounted) context.push('/profile/membership');
                    return;
                  }
                  await ref.read(preferredThemeProvider.notifier).select(theme.id);
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
  const _ThemeCard({required this.theme, required this.selected, required this.locked, required this.onTap});
  final AppThemeDefinition theme;
  final bool selected;
  final bool locked;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    borderRadius: BorderRadius.circular(22),
    onTap: onTap,
    child: Ink(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: selected ? theme.primary : theme.divider, width: selected ? 2 : 1),
      ),
      child: Row(children: [
        Container(
          width: 74, height: 74,
          decoration: BoxDecoration(color: theme.background, borderRadius: BorderRadius.circular(18)),
          padding: const EdgeInsets.all(10),
          child: Column(children: [
            Container(height: 12, decoration: BoxDecoration(color: theme.primarySoft, borderRadius: BorderRadius.circular(8))),
            const SizedBox(height: 7),
            Expanded(child: Row(children: [
              Expanded(child: Container(decoration: BoxDecoration(color: theme.primary, borderRadius: BorderRadius.circular(8)))),
              const SizedBox(width: 6),
              Expanded(child: Container(decoration: BoxDecoration(color: theme.surfaceSoft, borderRadius: BorderRadius.circular(8)))),
            ])),
          ]),
        ),
        const SizedBox(width: 14),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [Flexible(child: Text(theme.name, style: Theme.of(context).textTheme.titleMedium)), if (theme.premium) ...[const SizedBox(width: 6), const Icon(Icons.workspace_premium_outlined, size: 18)]]),
          const SizedBox(height: 4),
          Text(theme.description, style: Theme.of(context).textTheme.bodyMedium),
        ])),
        if (locked) const Icon(Icons.lock_outline, size: 20) else if (selected) Icon(Icons.check_circle, color: theme.primary),
      ]),
    ),
  );
}
