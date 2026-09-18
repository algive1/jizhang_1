import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../auto_bookkeeping_settings.dart';

class AutoBookkeepingPage extends ConsumerStatefulWidget {
  const AutoBookkeepingPage({super.key});

  @override
  ConsumerState<AutoBookkeepingPage> createState() =>
      _AutoBookkeepingPageState();
}

class _AutoBookkeepingPageState extends ConsumerState<AutoBookkeepingPage>
    with WidgetsBindingObserver {
  bool? _accessibilityGranted;
  bool? _overlayGranted;
  bool? _notificationGranted;
  bool _enabled = false;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _load();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load() async {
    final bridge = ref.read(autoBookkeepingSettingsProvider);
    final accessibility = await bridge.isAccessibilityGranted();
    final overlay = await bridge.isOverlayGranted();
    final notification = await bridge.isNotificationGranted();
    final enabled = await bridge.isEnabled();
    if (!mounted) return;
    setState(() {
      _accessibilityGranted = accessibility;
      _overlayGranted = overlay;
      _notificationGranted = notification;
      _enabled = enabled;
      _loading = false;
    });
  }

  Future<void> _toggle(bool value) async {
    final bridge = ref.read(autoBookkeepingSettingsProvider);
    if (!value) {
      await _setEnabled(bridge, false);
      return;
    }
    if (!(_accessibilityGranted ?? false)) {
      await _openSettings(
        bridge.openAccessibilitySettings,
        '请在系统设置中开启「好好记账」无障碍服务，然后返回本页。',
      );
      return;
    }
    if (!(_overlayGranted ?? false)) {
      await _openSettings(bridge.openOverlaySettings, '请允许「好好记账」显示悬浮窗，然后返回本页。');
      return;
    }
    if (!(_notificationGranted ?? false)) {
      try {
        await bridge.requestNotificationPermission();
      } on Object catch (error) {
        if (mounted) setState(() => _message = '$error');
      }
    }
    await _setEnabled(bridge, true);
  }

  Future<void> _openSettings(
    Future<void> Function() action,
    String successMessage,
  ) async {
    try {
      await action();
      if (mounted) setState(() => _message = successMessage);
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Future<void> _setEnabled(
    AutoBookkeepingSettingsBridge bridge,
    bool enabled,
  ) async {
    try {
      await bridge.setEnabled(enabled);
      if (!mounted) return;
      setState(() {
        _enabled = enabled;
        _message = enabled ? '已开启。支付成功页会显示识别结果，确认后才会保存流水。' : '已关闭自动记账。';
      });
      if (enabled) await _load();
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: context.pop,
                icon: const Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Text('自动记账', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 12),
          const AppCard(
            color: AppColors.primarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: AppColors.primary,
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  '识别付款结果，少填一遍账',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '自动记账支持微信、支付宝、云闪付和美团付款页面；识别金额和商户后会先弹出本机确认卡片，未确认前不会写入流水。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : Material(
                    color: Colors.transparent,
                    child: Column(
                      children: [
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text('自动记账'),
                          subtitle: Text(
                            !_enabled
                                ? '已关闭'
                                : _notificationGranted == true
                                ? '已开启 · 系统通知栏会显示运行状态'
                                : '已开启 · 通知权限未允许',
                          ),
                          value: _enabled,
                          onChanged: _toggle,
                        ),
                        const Divider(height: 1),
                        _PermissionRow(
                          icon: Icons.accessibility_new_outlined,
                          title: '无障碍服务',
                          enabled: _accessibilityGranted == true,
                          onTap: () => _openSettings(
                            ref
                                .read(autoBookkeepingSettingsProvider)
                                .openAccessibilitySettings,
                            '请在系统设置中开启「好好记账」无障碍服务，然后返回本页。',
                          ),
                        ),
                        _PermissionRow(
                          icon: Icons.open_in_new_outlined,
                          title: '悬浮窗权限',
                          enabled: _overlayGranted == true,
                          onTap: () => _openSettings(
                            ref
                                .read(autoBookkeepingSettingsProvider)
                                .openOverlaySettings,
                            '请允许「好好记账」显示悬浮窗，然后返回本页。',
                          ),
                        ),
                        _PermissionRow(
                          icon: Icons.notifications_none_outlined,
                          title: '常驻通知权限',
                          enabled: _notificationGranted == true,
                          onTap: () => _openSettings(
                            ref
                                .read(autoBookkeepingSettingsProvider)
                                .requestNotificationPermission,
                            '请在系统设置中允许通知，自动记账开启后才能显示常驻状态。',
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
          if (_message != null)
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Text(
                _message!,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ),
          const SizedBox(height: 14),
          AppCard(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.article_outlined),
                title: const Text('运行日志'),
                subtitle: const Text('查看最近一次支付识别和弹窗处理结果'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/autobookkeeping/logs'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          const AppCard(
            child: Text(
              '通知栏说明：开启后会有一条低打扰的常驻通知。点击通知正文会打开自动记账设置，通知上的“关闭自动记账”按钮可直接关闭。关闭后通知会自动消失。',
              style: TextStyle(height: 1.5, color: AppColors.textSecondary),
            ),
          ),
          const SizedBox(height: 10),
          const AppCard(
            child: Text(
              '隐私说明：自动识别只处理支持的付款页面中的必要信息；识别结果会先显示在悬浮卡片中，需用户确认后才写入本地账本。',
              style: TextStyle(height: 1.5, color: AppColors.textSecondary),
            ),
          ),
        ],
      ),
    );
  }
}

class _PermissionRow extends StatelessWidget {
  const _PermissionRow({
    required this.icon,
    required this.title,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Icon(
        icon,
        color: enabled ? AppColors.primary : AppColors.warning,
      ),
      title: Text(title),
      subtitle: Text(enabled ? '已允许' : '未允许'),
      trailing: TextButton(
        onPressed: onTap,
        child: Text(enabled ? '查看' : '去开启'),
      ),
    );
  }
}
