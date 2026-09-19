import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../push/application/push_registration_service.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../application/payment_notification_service.dart';

class NotificationSettingsPage extends ConsumerStatefulWidget {
  const NotificationSettingsPage({super.key});

  @override
  ConsumerState<NotificationSettingsPage> createState() =>
      _NotificationSettingsPageState();
}

class _NotificationSettingsPageState
    extends ConsumerState<NotificationSettingsPage> {
  static const _iosNotificationChannel =
      MethodChannel('jizhang/recurring_notifications');

  bool _loading = true;
  bool _registered = false;
  bool _guest = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_refresh);
  }

  Future<void> _refresh() async {
    try {
      final session = ref.read(sessionRepositoryProvider);
      await session.initialize();
      if (session.userId == null) {
        if (mounted) {
          setState(() {
            _guest = true;
            _registered = false;
            _loading = false;
          });
        }
        return;
      }
      final data = await ref.read(sharedApiProvider).request('/push/devices');
      final devices = data['devices'];
      final registered = devices is List &&
          devices.whereType<Map>().any((item) => item['currentSession'] == true);
      if (mounted) {
        setState(() {
          _guest = false;
          _registered = registered;
          _loading = false;
        });
      }
    } on Object {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _enablePush() async {
    setState(() => _loading = true);
    try {
      if (Platform.isAndroid) {
        await ref
            .read(paymentNotificationBridgeProvider)
            .requestNotificationPermission();
      } else if (Platform.isIOS) {
        await _iosNotificationChannel.invokeMethod<bool>('requestPermission');
      }
      final result = await ref
          .read(pushRegistrationServiceProvider)
          .registerIfAvailable(force: true);
      if (!mounted) return;
      if (result == PushRegistrationResult.guest) {
        context.push('/account/login');
        return;
      }
      if (result != PushRegistrationResult.registered) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备暂未取得推送令牌，请确认系统通知权限后重试')),
        );
      }
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('启用失败：$error')),
        );
      }
    } finally {
      await _refresh();
    }
  }

  Future<void> _disablePush() async {
    setState(() => _loading = true);
    final ok = await ref
        .read(pushRegistrationServiceProvider)
        .unregisterCurrentDevice();
    if (mounted && !ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('关闭失败，请检查网络后重试')),
      );
    }
    await _refresh();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('通知设置')),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            Card(
              child: SwitchListTile(
                title: const Text('系统消息推送'),
                subtitle: Text(
                  _guest
                      ? '登录后可接收公告、账号安全和服务通知'
                      : _registered
                      ? '当前设备已注册'
                      : '当前设备未注册',
                ),
                value: _registered,
                onChanged: _loading
                    ? null
                    : (value) => value ? _enablePush() : _disablePush(),
              ),
            ),
            if (_guest)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: FilledButton(
                  onPressed: () => context.push('/account/login'),
                  child: const Text('登录账号'),
                ),
              ),
            if (Platform.isAndroid) ...[
              const SizedBox(height: 12),
              Card(
                child: ListTile(
                  leading: const Icon(Icons.receipt_long_outlined),
                  title: const Text('支付通知自动记账'),
                  subtitle: const Text('读取微信、支付宝等支付通知生成待确认账单'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push('/profile/payment-notifications'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 4),
              child: Text(
                '关闭系统消息推送会从服务端注销当前设备令牌，不影响周期账单的本地提醒，也不会关闭 Android 支付通知监听。',
              ),
            ),
          ],
        ),
      );
}
