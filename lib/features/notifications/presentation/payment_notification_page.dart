import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/app_card.dart';
import '../application/payment_notification_service.dart';
import 'notification_target_card.dart';
import '../../../app/theme/app_theme_tokens.dart';

class PaymentNotificationPage extends ConsumerStatefulWidget {
  const PaymentNotificationPage({super.key});

  @override
  ConsumerState<PaymentNotificationPage> createState() =>
      _PaymentNotificationPageState();
}

class _PaymentNotificationPageState
    extends ConsumerState<PaymentNotificationPage> {
  bool? _accessGranted;
  bool _enabled = false;
  bool _loading = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final bridge = ref.read(paymentNotificationBridgeProvider);
    final accessGranted = await bridge.isAccessGranted();
    final enabled = accessGranted && await bridge.isEnabled();
    if (!mounted) return;
    setState(() {
      _accessGranted = accessGranted;
      _enabled = enabled;
      _loading = false;
    });
    if (enabled) await _processPending(showFeedback: false);
  }

  Future<void> _enableOrOpenSettings() async {
    final bridge = ref.read(paymentNotificationBridgeProvider);
    if (!(_accessGranted ?? false)) {
      try {
        await bridge.openAccessSettings();
        if (mounted) {
          setState(() => _message = '请在系统设置中允许「好好记账」读取通知，然后返回本页开启。');
        }
      } on Object catch (error) {
        if (mounted) setState(() => _message = '$error');
      }
      return;
    }
    try {
      await bridge.setEnabled(!_enabled);
      if (!mounted) return;
      setState(() {
        _enabled = !_enabled;
        _message = _enabled ? '已开启，识别到的支付通知会先进入待确认，不会静默写入流水。' : '已关闭自动记账。';
      });
      if (_enabled) {
        if (!await bridge.isNotificationGranted()) {
          await bridge.requestNotificationPermission();
        }
        await _processPending(showFeedback: true);
      }
    } on Object catch (error) {
      if (mounted) setState(() => _message = '$error');
    }
  }

  Future<void> _processPending({required bool showFeedback}) async {
    try {
      final result = await ref
          .read(paymentNotificationAutoBookkeepingProvider)
          .processPending();
      if (!mounted || !showFeedback) return;
      setState(
        () => _message = result.created == 0 && result.queued == 0
            ? '没有新的可识别支付通知。'
            : '待确认 ${result.queued} 笔，历史重复 ${result.duplicates} 笔，等待账户或权限处理 ${result.waiting} 笔。',
      );
    } on Object catch (error) {
      if (mounted) setState(() => _message = '处理通知失败：$error');
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
                icon: Icon(Icons.arrow_back),
              ),
              const SizedBox(width: 4),
              Text('支付通知记账', style: Theme.of(context).textTheme.headlineSmall),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            color: context.appPrimarySoft,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.notifications_active_outlined,
                  color: context.appPrimary,
                  size: 34,
                ),
                SizedBox(height: 10),
                Text(
                  '让付款自动变成记录',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                SizedBox(height: 8),
                Text(
                  '支持微信、支付宝、云闪付和美团付款通知；金额与商户会先在本机解析、去重并进入待确认，不会静默写入流水。',
                  style: TextStyle(height: 1.5),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          AppCard(
            child: _loading
                ? Center(child: CircularProgressIndicator())
                : Column(
                    children: [
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                          _accessGranted == true
                              ? Icons.check_circle_outline
                              : Icons.info_outline,
                          color: _accessGranted == true
                              ? context.appPrimary
                              : AppColors.warning,
                        ),
                        title: Text(
                          _accessGranted == true ? '系统通知权限已授权' : '尚未授权系统通知权限',
                        ),
                        subtitle: Text(
                          _accessGranted == true
                              ? '可在本页开启或关闭自动记账'
                              : '需要先在 Android 系统设置中允许读取通知',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动记账支付通知'),
                        subtitle: Text(_enabled ? '已开启' : '已关闭'),
                        value: _enabled,
                        onChanged: (_) => _enableOrOpenSettings(),
                      ),
                    ],
                  ),
          ),
          const SizedBox(height: 14),
          const NotificationTargetCard(),
          if (ref.watch(notificationProcessingErrorProvider) != null)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Text(ref.watch(notificationProcessingErrorProvider)!),
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
            child: Text(
              '隐私说明：通知只在本机转换为待确认数据，确认或忽略后才会清理。收款、到账、退款等入账类通知不会按支出处理。',
              style: TextStyle(height: 1.5, color: context.appSecondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
