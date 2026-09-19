import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../auto_bookkeeping_settings.dart';
import '../../notifications/application/payment_notification_service.dart';
import '../../../app/theme/app_theme_tokens.dart';

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
  bool? _paymentNotificationAccessGranted;
  bool _paymentNotificationEnabled = false;
  bool _enabled = false;
  bool _shortcutAvailable = false;
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
    if (Platform.isIOS) {
      var shortcutAvailable = false;
      try {
        shortcutAvailable =
            await const MethodChannel('jizhang/ios_shortcut')
                    .invokeMethod<bool>('isAvailable') ??
                false;
      } on MissingPluginException {
        shortcutAvailable = false;
      }
      if (!mounted) return;
      setState(() {
        _shortcutAvailable = shortcutAvailable;
        _loading = false;
      });
      return;
    }
    final bridge = ref.read(autoBookkeepingSettingsProvider);
    final paymentBridge = ref.read(paymentNotificationBridgeProvider);
    final accessibility = await bridge.isAccessibilityGranted();
    final overlay = await bridge.isOverlayGranted();
    final notification = await bridge.isNotificationGranted();
    final enabled = await bridge.isEnabled();
    final paymentAccess = await paymentBridge.isAccessGranted();
    final paymentEnabled = paymentAccess && await paymentBridge.isEnabled();
    if (!mounted) return;
    setState(() {
      _accessibilityGranted = accessibility;
      _overlayGranted = overlay;
      _notificationGranted = notification;
      _paymentNotificationAccessGranted = paymentAccess;
      _paymentNotificationEnabled = paymentEnabled;
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
    if (Platform.isIOS) return _buildIos(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: context.pop,
                icon: Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Text('自动记账', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            color: context.appPrimarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: context.appPrimary,
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  '识别付款结果，少填一遍账',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '自动记账支持微信、支付宝、云闪付、美团、京东、拼多多和抖音付款页面；识别金额和商户后会先弹出本机确认卡片，未确认前不会写入流水。',
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
                        _PermissionRow(
                          icon: Icons.notifications_active_outlined,
                          title: '支付通知兜底',
                          enabled:
                              _paymentNotificationAccessGranted == true &&
                              _paymentNotificationEnabled,
                          onTap: () =>
                              context.push('/profile/payment-notifications'),
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
                style: TextStyle(color: context.appSecondaryText),
              ),
            ),
          const SizedBox(height: 14),
          AppCard(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.article_outlined),
                title: Text('运行日志'),
                subtitle: Text('查看最近一次支付识别和弹窗处理结果'),
                trailing: Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/autobookkeeping/logs'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Text(
              '双通道说明：无障碍负责实时读取支付成功页面；“支付通知兜底”会在页面结构变化或漏识别时，用高置信度支付通知补充候选。两条通道会在本机去重，只保留一条待确认记录。',
              style: TextStyle(height: 1.5, color: context.appSecondaryText),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Text(
              '通知栏说明：开启后会有一条低打扰的常驻通知。点击通知正文会打开自动记账设置，通知上的“关闭自动记账”按钮可直接关闭。关闭后通知会自动消失。',
              style: TextStyle(height: 1.5, color: context.appSecondaryText),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Text(
              '隐私说明：自动识别只处理支持的付款页面中的必要信息；识别结果会先显示在悬浮卡片中，需用户确认后才写入本地账本。',
              style: TextStyle(height: 1.5, color: context.appSecondaryText),
            ),
          ),
        ],
      ),
    );
  }
  Widget _buildIos(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: context.pop,
                icon: Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Text(
                '自动记账',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            color: context.appPrimarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.auto_awesome_outlined,
                  color: context.appPrimary,
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  'iPhone 使用系统允许的替代流程',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  'iOS 不允许第三方 App 监听微信、支付宝等其他 App 的通知内容或页面。好好记账不会伪造这一能力，而是用快捷指令、截图 OCR 和官方账单导入完成确认式记账。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: ListTile(
              contentPadding: EdgeInsets.zero,
              leading: Icon(
                Icons.shortcut_outlined,
                color: _shortcutAvailable
                    ? context.appPrimary
                    : context.appSecondaryText,
              ),
              title: Text('系统快捷指令记账'),
              subtitle: Text(
                _loading
                    ? '正在检查…'
                    : _shortcutAvailable
                    ? 'iOS 16+ 已注册「记一笔到好好记账」动作'
                    : '当前系统版本不支持 App Intents，使用下方 OCR 或账单导入',
              ),
              trailing: Icon(
                _shortcutAvailable ? Icons.check_circle : Icons.info_outline,
                color: _shortcutAvailable
                    ? context.appPrimary
                    : context.appSecondaryText,
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.document_scanner_outlined),
                  title: const Text('截图 / 小票识别'),
                  subtitle: const Text('本地 OCR 识别文字，确认后再保存'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/receipt-ocr'),
                ),
                const Divider(height: 1),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.upload_file_outlined),
                  title: Text('微信 / 支付宝账单导入'),
                  subtitle: Text('导入官方 CSV，预览去重后批量保存'),
                  trailing: Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/bill-import'),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Text(
              '快捷指令用法：在系统「快捷指令」App 中搜索“好好记账”，选择「记一笔到好好记账」，把剪贴板文字、语音转写或你自己自动化得到的账单文本传入。运行后会打开好好记账的确认页，不会后台静默保存。',
              style: TextStyle(
                height: 1.5,
                color: context.appSecondaryText,
              ),
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
        color: enabled ? context.appPrimary : AppColors.warning,
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
