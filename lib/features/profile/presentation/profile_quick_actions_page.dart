import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_liquid_glass_surface.dart';
import '../application/profile_quick_actions_controller.dart';

class ProfileQuickActionSpec {
  const ProfileQuickActionSpec({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
}

const profileQuickActionSpecs = <ProfileQuickActionSpec>[
  ProfileQuickActionSpec(
    id: 'books',
    label: '我的账本',
    subtitle: '多账本管理',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF59C56A),
  ),
  ProfileQuickActionSpec(
    id: 'bill_import',
    label: '账单导入',
    subtitle: '多平台导入',
    icon: Icons.file_download_rounded,
    color: Color(0xFF4A9CF7),
  ),
  ProfileQuickActionSpec(
    id: 'categories',
    label: '分类管理',
    subtitle: '收支分类',
    icon: Icons.grid_view_rounded,
    color: Color(0xFF8C61F2),
  ),
  ProfileQuickActionSpec(
    id: 'budgets',
    label: '预算与目标',
    subtitle: '预算规划',
    icon: Icons.track_changes_rounded,
    color: Color(0xFFFF8C3F),
  ),
  ProfileQuickActionSpec(
    id: 'appearance',
    label: '主题中心',
    subtitle: '个性主题',
    icon: Icons.palette_rounded,
    color: Color(0xFFF45E7A),
  ),
  ProfileQuickActionSpec(
    id: 'autobookkeeping',
    label: '自动记账',
    subtitle: '智能识别',
    icon: Icons.smart_toy_rounded,
    color: Color(0xFF4DC8A5),
  ),
];

ProfileQuickActionSpec profileQuickActionSpec(String id) =>
    profileQuickActionSpecs.firstWhere(
      (item) => item.id == id,
      orElse: () => profileQuickActionSpecs.first,
    );

class ProfileQuickActionsPage extends ConsumerWidget {
  const ProfileQuickActionsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final order = ref.watch(profileQuickActionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(title: const Text('常用功能管理')),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(profileQuickActionsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新读取'),
          ),
        ),
        data: (ids) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '按住右侧拖拽按钮调整顺序，返回“我的”页面后立即生效。',
                style: TextStyle(
                  color: context.appSecondaryText,
                  fontSize: 13,
                ),
              ),
              const SizedBox(height: 14),
              Expanded(
                child: ReorderableListView.builder(
                  buildDefaultDragHandles: false,
                  itemCount: ids.length,
                  proxyDecorator: (child, index, animation) {
                    if (MediaQuery.disableAnimationsOf(context)) {
                      return Material(
                        color: Colors.transparent,
                        elevation: 0,
                        child: child,
                      );
                    }
                    return Material(
                      color: Colors.transparent,
                      elevation: 0,
                      child: ScaleTransition(
                        scale: Tween<double>(
                          begin: 1,
                          end: 1.025,
                        ).animate(
                          CurvedAnimation(
                            parent: animation,
                            curve: Curves.easeOutCubic,
                          ),
                        ),
                        child: child,
                      ),
                    );
                  },
                  onReorderItem: (oldIndex, newIndex) {
                    unawaited(
                      ref
                          .read(profileQuickActionsProvider.notifier)
                          .reorder(oldIndex, newIndex),
                    );
                  },
                  itemBuilder: (context, index) {
                    final spec = profileQuickActionSpec(ids[index]);
                    return Padding(
                      key: ValueKey('profile-quick-action-${spec.id}'),
                      padding: const EdgeInsets.only(bottom: 10),
                      child: AppLiquidGlassSurface(
                        borderRadius: 22,
                        themeColorAccents: false,
                        glassOpacity: MediaQuery.highContrastOf(context)
                            ? .72
                            : Theme.of(context).brightness == Brightness.dark
                            ? .24
                            : .18,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 10,
                        ),
                        child: Row(
                          children: [
                            _ActionIcon(spec: spec),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    spec.label,
                                    style: TextStyle(
                                      color: context.appPrimaryText,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    spec.subtitle,
                                    style: TextStyle(
                                      color: context.appSecondaryText,
                                      fontSize: 12,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            ReorderableDragStartListener(
                              index: index,
                              child: Padding(
                                padding: const EdgeInsets.all(10),
                                child: Icon(
                                  Icons.drag_indicator_rounded,
                                  color: context.appSecondaryText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.spec});

  final ProfileQuickActionSpec spec;

  @override
  Widget build(BuildContext context) => Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Color.lerp(spec.color, Colors.white, .16)!,
              spec.color,
            ],
          ),
          boxShadow: [
            BoxShadow(
              color: spec.color.withValues(alpha: .24),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Icon(spec.icon, color: Colors.white, size: 24),
      );
}
