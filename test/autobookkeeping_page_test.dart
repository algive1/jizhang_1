import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_settings.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_confirm_page.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_page.dart';

void main() {
  testWidgets('自动记账页展示权限与常驻通知说明', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoBookkeepingSettingsProvider.overrideWithValue(
            const _FakeAutoBookkeepingBridge(),
          ),
        ],
        child: const MaterialApp(home: AutoBookkeepingPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('自动记账'), findsNWidgets(2));
    expect(find.text('无障碍服务'), findsOneWidget);
    expect(find.text('悬浮窗权限'), findsOneWidget);
    expect(find.text('常驻通知权限'), findsOneWidget);
    expect(find.text('支付通知兜底'), findsOneWidget);
    expect(find.textContaining('常驻通知'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('没有待确认支付时不会显示空的确认账单', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoBookkeepingPendingBridgeProvider.overrideWithValue(
            const _FakePendingBridge(),
          ),
        ],
        child: const MaterialApp(home: AutoBookkeepingConfirmPage()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('没有待确认的交易记录'), findsOneWidget);
    expect(find.text('确认并完成'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

class _FakeAutoBookkeepingBridge implements AutoBookkeepingSettingsBridge {
  const _FakeAutoBookkeepingBridge();

  @override
  Future<bool> isAccessibilityGranted() async => false;

  @override
  Future<bool> isEnabled() async => false;

  @override
  Future<bool> isNotificationGranted() async => false;

  @override
  Future<bool> isOverlayGranted() async => false;

  @override
  Future<AutoBookkeepingRuntimeStatus> runtimeStatus() async =>
      const AutoBookkeepingRuntimeStatus(
        enabled: false,
        accessibilityGranted: false,
        accessibilityConnected: false,
        overlayGranted: false,
        notificationGranted: false,
        foregroundRunning: false,
        notificationListenerGranted: false,
        notificationListenerEnabled: false,
      );


  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _FakePendingBridge implements AutoBookkeepingPendingBridge {
  const _FakePendingBridge();

  @override
  Future<AutoBookkeepingEnqueueResult> enqueue(
    PendingAutoBookkeepingCandidate candidate,
  ) async => AutoBookkeepingEnqueueResult.busy;

  @override
  Future<void> complete() async {}

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() async => null;
}
