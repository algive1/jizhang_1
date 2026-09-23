import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/core/widgets/startup_poster.dart';
import 'package:jizhang_app/features/security/application/app_lock_service.dart';
import 'package:jizhang_app/features/security/presentation/app_lock_gate.dart';

class _FakeAppLockService extends AppLockService {
  _FakeAppLockService({
    required this.onIsEnabled,
    required this.onAuthenticate,
  });

  final Future<bool> Function() onIsEnabled;
  final Future<bool> Function() onAuthenticate;

  int isEnabledCalls = 0;
  int authenticateCalls = 0;

  @override
  Future<bool> isEnabled() {
    isEnabledCalls += 1;
    return onIsEnabled();
  }

  @override
  Future<bool> authenticate({
    String reason = '验证身份后进入好好记账',
  }) {
    authenticateCalls += 1;
    return onAuthenticate();
  }
}

Future<void> _pumpGate(
  WidgetTester tester,
  _FakeAppLockService service,
) async {
  await tester.binding.handleAppLifecycleStateChanged(
    AppLifecycleState.resumed,
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        appLockServiceProvider.overrideWithValue(service),
      ],
      child: const MaterialApp(
        home: AppLockGate(
          child: Scaffold(
            body: Center(child: Text('private-home')),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  tearDown(() async {
    await TestWidgetsFlutterBinding.instance.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
  });

  testWidgets(
    'disabled lock never flashes the locked screen while preference is loading',
    (tester) async {
      final enabled = Completer<bool>();
      final service = _FakeAppLockService(
        onIsEnabled: () => enabled.future,
        onAuthenticate: () async => true,
      );

      await _pumpGate(tester, service);

      expect(find.byType(StartupPoster), findsOneWidget);
      expect(find.text('好好记账已锁定'), findsNothing);
      expect(find.text('private-home'), findsNothing);

      enabled.complete(false);
      await tester.pumpAndSettle();

      expect(find.text('private-home'), findsOneWidget);
      expect(find.text('好好记账已锁定'), findsNothing);
      expect(service.authenticateCalls, 0);
    },
  );

  testWidgets('enabled lock authenticates once and then reveals the app', (
    tester,
  ) async {
    final service = _FakeAppLockService(
      onIsEnabled: () async => true,
      onAuthenticate: () async => true,
    );

    await _pumpGate(tester, service);
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 1);
    expect(find.text('private-home'), findsOneWidget);
    expect(find.text('好好记账已锁定'), findsNothing);
  });

  testWidgets('cancelled authentication stays on the real lock screen', (
    tester,
  ) async {
    final service = _FakeAppLockService(
      onIsEnabled: () async => true,
      onAuthenticate: () async => false,
    );

    await _pumpGate(tester, service);
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 1);
    expect(find.text('好好记账已锁定'), findsOneWidget);
    expect(find.text('解锁'), findsOneWidget);
    expect(find.text('private-home'), findsNothing);
  });

  testWidgets('secure storage read failure fails closed without exposing data', (
    tester,
  ) async {
    final service = _FakeAppLockService(
      onIsEnabled: () async => throw StateError('keystore unavailable'),
      onAuthenticate: () async => true,
    );

    await _pumpGate(tester, service);
    await tester.pumpAndSettle();

    expect(find.text('应用锁设置读取失败'), findsOneWidget);
    expect(find.text('重试'), findsOneWidget);
    expect(find.text('private-home'), findsNothing);
    expect(service.authenticateCalls, 0);
  });

  testWidgets('stale background read cannot lock the app after resume', (
    tester,
  ) async {
    final pausedRead = Completer<bool>();
    var read = 0;
    final service = _FakeAppLockService(
      onIsEnabled: () {
        read += 1;
        if (read == 1) return Future<bool>.value(false);
        if (read == 2) return pausedRead.future;
        return Future<bool>.value(false);
      },
      onAuthenticate: () async => true,
    );

    await _pumpGate(tester, service);
    await tester.pumpAndSettle();
    expect(find.text('private-home'), findsOneWidget);

    await tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.pump();

    await tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pumpAndSettle();

    expect(find.text('private-home'), findsOneWidget);

    pausedRead.complete(true);
    await tester.pumpAndSettle();

    expect(find.text('private-home'), findsOneWidget);
    expect(find.text('好好记账已锁定'), findsNothing);
    expect(service.authenticateCalls, 0);
  });

  testWidgets('lifecycle changes during authentication do not duplicate prompt', (
    tester,
  ) async {
    final authentication = Completer<bool>();
    final service = _FakeAppLockService(
      onIsEnabled: () async => true,
      onAuthenticate: () => authentication.future,
    );

    await _pumpGate(tester, service);
    await tester.pump();

    expect(service.authenticateCalls, 1);
    expect(find.text('正在验证设备身份…'), findsOneWidget);

    await tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.paused,
    );
    await tester.binding.handleAppLifecycleStateChanged(
      AppLifecycleState.resumed,
    );
    await tester.pump();

    expect(service.authenticateCalls, 1);

    authentication.complete(true);
    await tester.pumpAndSettle();

    expect(service.authenticateCalls, 1);
    expect(find.text('private-home'), findsOneWidget);
  });
}
