import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/widgets/app_liquid_glass_surface.dart';
import '../../books/presentation/book_selector.dart';
import '../application/profile_quick_actions_controller.dart';

class ProfileQuickActionSpec {
  const ProfileQuickActionSpec({
    required this.id,
    required this.label,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.group,
    this.route,
  });

  final String id;
  final String label;
  final String subtitle;
  final IconData icon;
  final Color color;
  final String group;
  final String? route;
}

const profileQuickActionSpecs = <ProfileQuickActionSpec>[
  ProfileQuickActionSpec(
    id: 'books',
    label: '我的账本',
    subtitle: '多账本管理',
    icon: Icons.menu_book_rounded,
    color: Color(0xFF59C56A),
    group: '账本与资产',
  ),
  ProfileQuickActionSpec(
    id: 'assets',
    label: '账户资产',
    subtitle: '资产账户',
    icon: Icons.account_balance_wallet_rounded,
    color: Color(0xFF4CA3F5),
    group: '账本与资产',
    route: '/profile/assets',
  ),
  ProfileQuickActionSpec(
    id: 'family',
    label: '共享账本',
    subtitle: '家庭共享',
    icon: Icons.people_alt_rounded,
    color: Color(0xFF8D75E8),
    group: '账本与资产',
    route: '/profile/family',
  ),
  ProfileQuickActionSpec(
    id: 'bill_import',
    label: '账单导入',
    subtitle: '多平台导入',
    icon: Icons.file_download_rounded,
    color: Color(0xFF4A9CF7),
    group: '记账工具',
    route: '/profile/bill-import',
  ),
  ProfileQuickActionSpec(
    id: 'receipt_ocr',
    label: '小票识别',
    subtitle: '本地识别',
    icon: Icons.document_scanner_rounded,
    color: Color(0xFF39B69D),
    group: '记账工具',
    route: '/profile/receipt-ocr',
  ),
  ProfileQuickActionSpec(
    id: 'autobookkeeping',
    label: '自动记账',
    subtitle: '智能识别',
    icon: Icons.smart_toy_rounded,
    color: Color(0xFF4DC8A5),
    group: '记账工具',
    route: '/profile/autobookkeeping',
  ),
  ProfileQuickActionSpec(
    id: 'recurring_bills',
    label: '周期账单',
    subtitle: '周期提醒',
    icon: Icons.event_repeat_rounded,
    color: Color(0xFF5E9BEF),
    group: '记账工具',
    route: '/profile/recurring-bills',
  ),
  ProfileQuickActionSpec(
    id: 'categories',
    label: '分类管理',
    subtitle: '收支分类',
    icon: Icons.grid_view_rounded,
    color: Color(0xFF8C61F2),
    group: '规划与管理',
    route: '/profile/categories',
  ),
  ProfileQuickActionSpec(
    id: 'budgets',
    label: '预算与目标',
    subtitle: '预算规划',
    icon: Icons.track_changes_rounded,
    color: Color(0xFFFF8C3F),
    group: '规划与管理',
    route: '/profile/budgets',
  ),
  ProfileQuickActionSpec(
    id: 'goals',
    label: '目标管理',
    subtitle: '生活目标',
    icon: Icons.flag_rounded,
    color: Color(0xFFEF8B5D),
    group: '规划与管理',
    route: '/goals',
  ),
  ProfileQuickActionSpec(
    id: 'finance_center',
    label: '财税账单',
    subtitle: '财税管理',
    icon: Icons.receipt_long_rounded,
    color: Color(0xFFE19B42),
    group: '规划与管理',
    route: '/profile/finance-center',
  ),
  ProfileQuickActionSpec(
    id: 'installments',
    label: '信用分期',
    subtitle: '分期计划',
    icon: Icons.credit_card_rounded,
    color: Color(0xFF6E92E8),
    group: '规划与管理',
    route: '/profile/installments',
  ),
  ProfileQuickActionSpec(
    id: 'appearance',
    label: '主题中心',
    subtitle: '个性主题',
    icon: Icons.palette_rounded,
    color: Color(0xFFF45E7A),
    group: '设置与数据',
    route: '/profile/appearance',
  ),
  ProfileQuickActionSpec(
    id: 'data',
    label: '数据安全',
    subtitle: '备份导出',
    icon: Icons.cloud_done_rounded,
    color: Color(0xFF5AAECA),
    group: '设置与数据',
    route: '/profile/data',
  ),
  ProfileQuickActionSpec(
    id: 'payment_notifications',
    label: '支付通知',
    subtitle: '通知记账',
    icon: Icons.notifications_active_rounded,
    color: Color(0xFFEA8B4D),
    group: '设置与数据',
    route: '/profile/payment-notifications',
  ),
];

ProfileQuickActionSpec profileQuickActionSpec(String id) =>
    profileQuickActionSpecs.firstWhere(
      (item) => item.id == id,
      orElse: () => profileQuickActionSpecs.first,
    );

class ProfileQuickActionsPage extends ConsumerStatefulWidget {
  const ProfileQuickActionsPage({super.key});

  @override
  ConsumerState<ProfileQuickActionsPage> createState() =>
      _ProfileQuickActionsPageState();
}

class _ProfileQuickActionsPageState
    extends ConsumerState<ProfileQuickActionsPage> {
  bool _sorting = false;

  @override
  Widget build(BuildContext context) {
    final order = ref.watch(profileQuickActionsProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: Text(_sorting ? '常用功能排序' : '全部功能'),
        actions: [
          TextButton(
            key: const ValueKey('profile-quick-actions-sort'),
            onPressed: order.hasValue
                ? () => setState(() => _sorting = !_sorting)
                : null,
            child: Text(_sorting ? '完成' : '排序'),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: order.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, _) => Center(
          child: FilledButton.icon(
            onPressed: () => ref.invalidate(profileQuickActionsProvider),
            icon: const Icon(Icons.refresh_rounded),
            label: const Text('重新读取'),
          ),
        ),
        data: (ids) => _sorting
            ? _SortView(ids: ids)
            : _AllFunctionsView(
                ids: ids,
                onOpen: (spec) => _openAction(context, spec),
                onToggle: (spec) => _toggle(spec),
              ),
      ),
    );
  }

  Future<void> _toggle(ProfileQuickActionSpec spec) async {
    final result = await ref
        .read(profileQuickActionsProvider.notifier)
        .toggle(spec.id);
    if (!mounted) return;
    final message = switch (result) {
      ProfileQuickActionToggleResult.atLimit => '常用功能最多保留 6 个',
      ProfileQuickActionToggleResult.minimumRequired => '至少保留 1 个常用功能',
      _ => null,
    };
    if (message != null) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void _openAction(BuildContext context, ProfileQuickActionSpec spec) {
    if (spec.id == 'books') {
      showBookSelectorSheet(context, ref);
      return;
    }
    final route = spec.route;
    if (route != null) context.push(route);
  }
}

class _AllFunctionsView extends StatelessWidget {
  const _AllFunctionsView({
    required this.ids,
    required this.onOpen,
    required this.onToggle,
  });

  final List<String> ids;
  final ValueChanged<ProfileQuickActionSpec> onOpen;
  final ValueChanged<ProfileQuickActionSpec> onToggle;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<ProfileQuickActionSpec>>{};
    for (final spec in profileQuickActionSpecs) {
      groups.putIfAbsent(spec.group, () => []).add(spec);
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 28),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                '常用功能',
                style: TextStyle(
                  color: context.appPrimaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            Text(
              '${ids.length}/$profileQuickActionLimit',
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 12,
              ),
            ),
          ],
        ),
        const SizedBox(height: 5),
        Text(
          '点击功能直接进入；右侧按钮决定是否显示在“我的”页。排序只调整已加入的常用功能。',
          style: TextStyle(color: context.appSecondaryText, fontSize: 12),
        ),
        const SizedBox(height: 14),
        for (final entry in groups.entries) ...[
          Text(
            entry.key,
            style: TextStyle(
              color: context.appSecondaryText,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 7),
          AppLiquidGlassSurface(
            borderRadius: 22,
            themeColorAccents: false,
            glassOpacity: MediaQuery.highContrastOf(context)
                ? .78
                : Theme.of(context).brightness == Brightness.dark
                ? .62
                : .56,
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Column(
              children: [
                for (var i = 0; i < entry.value.length; i++) ...[
                  _FunctionRow(
                    spec: entry.value[i],
                    selected: ids.contains(entry.value[i].id),
                    onTap: () => onOpen(entry.value[i]),
                    onToggle: () => onToggle(entry.value[i]),
                  ),
                  if (i != entry.value.length - 1)
                    Divider(
                      height: 1,
                      indent: 58,
                      color: context.appDivider.withValues(alpha: .56),
                    ),
                ],
              ],
            ),
          ),
          const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _FunctionRow extends StatelessWidget {
  const _FunctionRow({
    required this.spec,
    required this.selected,
    required this.onTap,
    required this.onToggle,
  });

  final ProfileQuickActionSpec spec;
  final bool selected;
  final VoidCallback onTap;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) => ListTile(
        onTap: onTap,
        minTileHeight: 54,
        contentPadding: const EdgeInsets.fromLTRB(12, 2, 6, 2),
        leading: _ActionIcon(spec: spec, size: 36),
        title: Text(
          spec.label,
          style: TextStyle(
            color: context.appPrimaryText,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          spec.subtitle,
          style: TextStyle(
            color: context.appSecondaryText,
            fontSize: 11,
          ),
        ),
        trailing: IconButton(
          key: ValueKey('profile-quick-toggle-${spec.id}'),
          tooltip: selected ? '移出常用功能' : '加入常用功能',
          onPressed: onToggle,
          icon: Icon(
            selected ? Icons.check_circle_rounded : Icons.add_circle_outline,
            color: selected ? context.appPrimary : context.appSecondaryText,
          ),
        ),
      );
}

class _SortView extends ConsumerWidget {
  const _SortView({required this.ids});

  final List<String> ids;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '按住右侧拖拽按钮调整首页常用功能顺序。',
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
                          ? .78
                          : Theme.of(context).brightness == Brightness.dark
                          ? .62
                          : .56,
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
      );
}

class _ActionIcon extends StatelessWidget {
  const _ActionIcon({required this.spec, this.size = 44});

  final ProfileQuickActionSpec spec;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(size * .32),
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
        child: Icon(spec.icon, color: Colors.white, size: size * .55),
      );
}
