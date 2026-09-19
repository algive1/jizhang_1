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
    extends ConsumerState<PaymentNotificationPage>
    with WidgetsBindingObserver {
  bool? _accessGranted;
  bool _connected = false;
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
    final bridge = ref.read(paymentNotificationBridgeProvider);
    final accessGranted = await bridge.isAccessGranted();
    final enabled = await bridge.isEnabled();
    final connected = accessGranted ? await bridge.isConnected() : false;
    if (!mounted) return;
    setState(() {
      _accessGranted = accessGranted;
      _connected = connected;
      _enabled = enabled;
      _loading = false;
    });
    if (enabled) await _processPending(showFeedback: false);
  }

  Future<void> _enableOrOpenSettings() async {
    final bridge = ref.read(paymentNotificationBridgeProvider);
    if (!(_accessGranted ?? false) && !_enabled) {
      try {
        await bridge.openAccessSettings();
        if (mounted) {
          setState(
            () => _message =
                '请在系统设置中允许「好好记账」读取通知，返回本页后会自动刷新授权状态。',
          );
        }
      } on Object catch (error) {
        if (mounted) setState(() => _message = '$error');
      }
      return;
    }
    try {
      final nextEnabled = !_enabled;
      if (nextEnabled && !await bridge.isNotificationGranted()) {
        final granted = await bridge.requestNotificationPermission();
        if (!mounted) return;
        if (!granted) {
          setState(
            () => _message =
                '请允许「好好记账」发送通知，然后返回本页继续开启。',
          );
          return;
        }
      }
      await bridge.setEnabled(nextEnabled);
      if (!mounted) return;
      setState(() {
        _enabled = nextEnabled;
        _message = _enabled
            ? '已开启，系统通知监听会实时参与交易识别并进入待确认。'
            : '已关闭支付通知兜底。';
      });
      if (_enabled) {
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
            : '待确认 ${result.queued} 笔，历史重复 ${result.duplicates} 笔，暂被其他待确认流水占用 ${result.waiting} 笔。',
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
                  '支持微信、支付宝、云闪付、美团、京东、拼多多和抖音的高置信度交易通知；支出、明确收款和明确退款会在本机解析、去重后进入待确认，不会静默写入流水。',
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
                          _accessGranted == true ? '通知读取权限已授权' : '尚未授权通知读取权限',
                        ),
                        subtitle: Text(
                          _accessGranted == true
                              ? '可在本页开启或关闭自动记账'
                              : '需要先在 Android 系统设置中允许「好好记账」读取通知',
                        ),
                      ),
                      SwitchListTile(
                        contentPadding: EdgeInsets.zero,
                        title: const Text('自动记账支付通知'),
                        subtitle: Text(
                          !_enabled
                              ? '已关闭'
                              : _accessGranted != true
                              ? '已开启，但系统通知读取权限已失效'
                              : _connected
                              ? '已开启 · 监听服务已连接'
                              : '已开启 · 已授权，等待系统连接监听服务',
                        ),
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
              '隐私说明：只有明确完成态、金额和交易对方均可确认的通知才会进入待确认。待支付、营销提醒以及信息不完整的收款/退款会直接过滤；解析与去重均在本机完成。',
              style: TextStyle(height: 1.5, color: context.appSecondaryText),
            ),
          ),
        ],
      ),
    );
  }
}
