import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/platform/app_notice.dart';
import '../auto_bookkeeping_settings.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../membership/application/membership_feature_guard.dart';
import '../../app_runtime/application/device_heartbeat_service.dart';
import '../../membership/presentation/membership_upgrade_prompt.dart';

class AutoBookkeepingPermissionsPage extends ConsumerStatefulWidget {
  const AutoBookkeepingPermissionsPage({super.key});

  @override
  ConsumerState<AutoBookkeepingPermissionsPage> createState() =>
      _AutoBookkeepingPageState();
}

class _AutoBookkeepingPageState
    extends ConsumerState<AutoBookkeepingPermissionsPage>
    with WidgetsBindingObserver {
  AutoBookkeepingRuntimeStatus? get _runtime =>
      ref.read(autoBookkeepingRuntimeProvider).value;
  bool? get _accessibilityGranted => _runtime?.accessibilityGranted;
  bool? get _overlayGranted => _runtime?.overlayGranted;
  bool? get _notificationGranted => _runtime?.notificationGranted;
  bool? get _paymentNotificationAccessGranted =>
      _runtime?.notificationListenerGranted;
  bool get _paymentNotificationEnabled =>
      _runtime?.notificationListenerEnabled == true;
  bool get _paymentNotificationConnected =>
      _runtime?.notificationListenerConnected == true;
  bool get _accessibilityConnected => _runtime?.accessibilityConnected == true;
  bool get _foregroundRunning => _runtime?.foregroundRunning == true;
  bool get _miuiFamily => _runtime?.miuiFamily == true;
  bool get _batteryOptimizationIgnored =>
      _runtime?.batteryOptimizationIgnored == true;
  bool get _backgroundRestricted => _runtime?.backgroundRestricted == true;
  bool get _screenshotSupported => _runtime?.screenshotSupported == true;
  bool get _screenshotEnabled => _runtime?.screenshotEnabled == true;
  int get _ruleSchemaVersion => _runtime?.ruleSchemaVersion ?? 0;
  String get _ruleVersions => _runtime?.ruleVersions ?? '';
  String get _ruleSource => _runtime?.ruleSource ?? 'unknown';
  bool get _enabled => _runtime?.enabled == true;
  bool _shortcutAvailable = false;
  bool _loading = true;
  String? _message;
  bool _diagnosing = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Platform.isIOS)
      _load();
    else
      _diagnose();
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
    final status = await ref
        .read(autoBookkeepingRuntimeProvider.notifier)
        .refresh();
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (status == null || !status.available) _message = '无法读取服务状态，请重新检测';
    });
  }

  Future<void> _diagnose() async {
    if (_diagnosing) return;
    setState(() => _diagnosing = true);
    await _load();
    if (!mounted) return;
    final issues = _runtime?.diagnosisIssues ?? ['无法读取权限状态，请重试'];
    final result = issues.isEmpty
        ? (_enabled ? '自动记账权限与服务正常' : '权限检查通过，自动记账尚未开启')
        : '检测发现 ${issues.length} 项问题：${issues.join('；')}';
    setState(() {
      _diagnosing = false;
      _message = result;
    });
    await AppNotice.show(context, result);
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
        final granted = await bridge.requestNotificationPermission();
        if (!mounted) return;
        await _load();
        if (!granted) {
          if (mounted) {
            setState(() => _message = '请允许通知，并确保系统中的「自动记账状态」通知渠道已开启，然后返回本页。');
          }
          return;
        }
      } on Object catch (error) {
        if (mounted) setState(() => _message = '$error');
        return;
      }
    }
    await _setEnabled(bridge, true);
  }

  Future<void> _reconnectNotifications() async {
    try {
      await ref
          .read(autoBookkeepingSettingsProvider)
          .reconnectNotificationListener();
      if (!mounted) return;
      setState(() => _message = '正在重新连接支付通知监听…');
      for (var attempt = 0; attempt < 10; attempt++) {
        await Future<void>.delayed(const Duration(seconds: 1));
        if (!mounted) return;
        await _load();
        if (_paymentNotificationConnected) break;
      }
      if (mounted)
        setState(
          () => _message = _paymentNotificationConnected
              ? '支付通知监听已连接。'
              : '仍未连接。请允许自启动并解除后台省电限制，然后返回重试。',
        );
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
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
      unawaited(ref.read(deviceHeartbeatServiceProvider).sendIfDue(force: true));
      setState(() {
        _message = enabled ? '已开启。识别结果将按所选入账策略处理。' : '已关闭自动记账。';
      });
      if (enabled) {
        for (var attempt = 0; attempt < 4; attempt++) {
          await _load();
          if (!mounted || (_foregroundRunning && _accessibilityConnected)) {
            break;
          }
          await Future<void>.delayed(const Duration(milliseconds: 350));
        }
      } else {
        await _load();
      }
    } on Object catch (error) {
      if (mounted) {
        setState(() => _message = '$error');
        if (error is MembershipFeatureDenied && error.access.requiresUpgrade) {
          await showMembershipUpgradePrompt(context, error.access.feature);
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final runtime = ref.watch(autoBookkeepingRuntimeProvider);
    if (Platform.isIOS) return _buildIos(context);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
        children: [
          Row(
            children: [
              IconButton(onPressed: context.pop, icon: Icon(Icons.arrow_back)),
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
                  '识别交易结果，少填一遍账',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '自动记账支持微信、支付宝、云闪付、美团、京东、拼多多和抖音。在本机识别交易结果，根据所选策略入账；需要补充信息的账单会保留待确认。',
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
                                : _paymentNotificationEnabled &&
                                      !_paymentNotificationConnected
                                ? '已开启 · 通知兜底未连接，请检查后台设置'
                                : _backgroundRestricted
                                ? '已开启 · 系统限制后台运行'
                                : _foregroundRunning &&
                                      _accessibilityConnected &&
                                      _notificationGranted == true
                                ? '已开启 · 后台服务运行中 · 常驻通知可见'
                                : '已开启 · 运行条件不完整，请检查下方状态',
                          ),
                          value: _enabled,
                          onChanged: _toggle,
                        ),
                        const Divider(height: 1),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _runtime?.healthy == true
                                ? Icons.check_circle_outline
                                : Icons.error_outline,
                            color: _runtime?.healthy == true
                                ? context.appPrimary
                                : AppColors.warning,
                          ),
                          title: const Text('运行状态'),
                          subtitle: Text(
                            runtime.isLoading
                                ? '正在检测服务状态…'
                                : _runtime?.summary ?? '无法读取服务状态，请重新检测',
                          ),
                          trailing: TextButton(
                            onPressed: _diagnosing ? null : _diagnose,
                            child: Text(_diagnosing ? '检测中…' : '诊断'),
                          ),
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
                          onTap: () async {
                            final bridge = ref.read(
                              autoBookkeepingSettingsProvider,
                            );
                            try {
                              final granted = await bridge
                                  .requestNotificationPermission();
                              if (!mounted) return;
                              await _load();
                              setState(
                                () => _message = granted
                                    ? '通知权限已允许，自动记账开启后会显示常驻状态。'
                                    : '请在系统通知设置中允许通知，并开启「自动记账状态」渠道。',
                              );
                            } on Object catch (error) {
                              if (mounted) {
                                setState(() => _message = '$error');
                              }
                            }
                          },
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: Icon(
                            _paymentNotificationConnected
                                ? Icons.check_circle_outline
                                : Icons.notifications_active_outlined,
                            color: _paymentNotificationConnected
                                ? context.appPrimary
                                : AppColors.warning,
                          ),
                          title: const Text('支付通知兜底'),
                          subtitle: Text(
                            _paymentNotificationAccessGranted != true
                                ? '未授权通知读取权限'
                                : !_paymentNotificationEnabled
                                ? '已授权 · 未开启'
                                : _paymentNotificationConnected
                                ? '已开启 · 监听服务已连接'
                                : '已授权但监听未连接，请检查自启动和省电设置',
                          ),
                          trailing: TextButton(
                            onPressed:
                                _paymentNotificationEnabled &&
                                    _paymentNotificationAccessGranted == true &&
                                    !_paymentNotificationConnected
                                ? _reconnectNotifications
                                : () => context.push(
                                    '/profile/payment-notifications',
                                  ),
                            child: Text(
                              _paymentNotificationEnabled &&
                                      _paymentNotificationAccessGranted ==
                                          true &&
                                      !_paymentNotificationConnected
                                  ? '重连'
                                  : '设置',
                            ),
                          ),
                        ),
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.battery_saver_outlined),
                          title: const Text('后台运行保护'),
                          subtitle: Text(
                            _backgroundRestricted
                                ? '系统限制后台运行，请将省电策略设为无限制'
                                : _batteryOptimizationIgnored
                                ? '已关闭系统电池优化；仍需检查厂商后台设置'
                                : '系统电池优化仍启用；厂商省电策略请在设置中确认',
                          ),
                          trailing: TextButton(
                            onPressed: () => _openSettings(
                              ref
                                  .read(autoBookkeepingSettingsProvider)
                                  .openBackgroundSettings,
                              '请允许后台运行；小米手机请在应用信息 → 省电策略中选择「无限制」。',
                            ),
                            child: const Text('设置'),
                          ),
                        ),
                        if (_miuiFamily)
                          ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.restart_alt),
                            title: const Text('小米自启动'),
                            subtitle: const Text('请允许好好记账自启动，避免付款通知监听被系统拦截'),
                            trailing: TextButton(
                              onPressed: () => _openSettings(
                                ref
                                    .read(autoBookkeepingSettingsProvider)
                                    .openAutoStartSettings,
                                '请开启好好记账自启动，返回后点击通知兜底的「重连」。',
                              ),
                              child: const Text('设置'),
                            ),
                          ),
                        SwitchListTile(
                          contentPadding: EdgeInsets.zero,
                          secondary: Icon(
                            Icons.photo_camera_outlined,
                            color: _screenshotEnabled
                                ? context.appPrimary
                                : context.appSecondaryText,
                          ),
                          title: const Text('保存支付结果截图'),
                          subtitle: Text(
                            !_screenshotSupported
                                ? '需要 Android 11 或更高版本'
                                : _screenshotEnabled
                                ? '已开启 · 仅在无障碍识别成功页本机截图'
                                : '可选 · 忽略交易时截图会自动删除',
                          ),
                          value: _screenshotEnabled,
                          onChanged: !_screenshotSupported
                              ? null
                              : (value) async {
                                  final bridge = ref.read(
                                    autoBookkeepingSettingsProvider,
                                  );
                                  final actual = await bridge
                                      .setScreenshotEnabled(value);
                                  if (!mounted) return;
                                  setState(() {
                                    _message = actual
                                        ? '支付截图已开启。识别与临时截图只在本机处理；确认保留后会成为普通账单附件，若已开启云备份，会按现有附件规则备份。'
                                        : '支付截图已关闭。';
                                  });
                                  await _load();
                                },
                        ),
                        const Divider(height: 1),
                        ListTile(
                          key: const ValueKey('autobookkeeping-runtime-logs'),
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.article_outlined),
                          title: const Text('运行日志'),
                          subtitle: const Text('查看交易识别、策略与入账结果'),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.push('/profile/autobookkeeping/logs'),
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
                leading: const Icon(Icons.rule_folder_outlined),
                title: const Text('页面识别规则'),
                subtitle: Text(
                  _ruleVersions.isEmpty
                      ? '规则服务尚未连接；开启无障碍服务后会显示当前规则版本'
                      : 'schema v$_ruleSchemaVersion · $_ruleVersions · ${_ruleSource == 'asset' ? '随 App 发布规则' : '内置回退规则'}',
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Material(
              color: Colors.transparent,
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.extension_outlined),
                title: const Text('自定义应用'),
                subtitle: const Text('内置规则以外的应用可以手动加入识别范围'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/profile/autobookkeeping/apps'),
              ),
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Text(
              '双通道说明：无障碍负责实时读取交易结果页面；“支付通知兜底”会在页面结构变化或漏识别时，用高置信度交易通知补充候选。两条通道会在本机去重，只保留一条待确认记录。',
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
              '隐私说明：自动识别只处理支持的交易结果页面和高置信度交易通知中的必要信息；解析与去重均在本机完成。支付截图默认关闭，临时截图只在本机保存，忽略或过期会自动删除；用户确认保留后会成为普通账单附件，若已开启云备份，会随其他附件按现有规则备份。',
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
              IconButton(onPressed: context.pop, icon: Icon(Icons.arrow_back)),
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
              style: TextStyle(height: 1.5, color: context.appSecondaryText),
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
