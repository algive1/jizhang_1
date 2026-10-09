import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_inbox.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_strategy.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_settings.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_page.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_permissions_page.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_visuals.dart';
import 'package:jizhang_app/features/settings/data/app_settings_repository.dart';

import 'autobookkeeping_strategy_test.dart' show MemoryStrategySettings;

const flags = {
  'enabled': true,
  'accessibilityGranted': true,
  'accessibilityConnected': true,
  'overlayGranted': true,
  'notificationGranted': true,
  'foregroundRunning': true,
  'notificationListenerGranted': true,
  'notificationListenerEnabled': true,
  'notificationListenerConnected': true,
};

class PrototypeBridge extends MethodChannelAutoBookkeepingSettings {
  PrototypeBridge(this.flags);
  final Map<String, Object> flags;
  @override
  Future<AutoBookkeepingRuntimeStatus> runtimeStatus() async =>
      flags['readFails'] == true
      ? throw StateError('runtime unavailable')
      : AutoBookkeepingRuntimeStatus.fromMap(flags);
}

final now = DateTime.now();
final records = [
  for (var i = 0; i < 1; i++)
    TransactionRecord(
      id: 'auto-$i',
      bookId: 'book-personal',
      type: TransactionType.expense,
      amount: i == 0 ? 32 : 28.5,
      accountId: 'wechat',
      merchant: i == 0 ? '星巴克' : '麦当劳',
      occurredAt: DateTime(now.year, now.month, now.day, 14, 28),
      createdAt: now,
      updatedAt: now,
      source: TransactionSource.auto,
      metadataJson: '{"autobookkeeping":{"paymentMethod":"微信支付"}}',
    ),
];
Widget harness({
  Map<String, Object> status = flags,
  double scale = 1,
  bool dark = false,
}) {
  final router = GoRouter(
    initialLocation: '/profile/autobookkeeping',
    routes: [
      GoRoute(
        path: '/profile/autobookkeeping',
        builder: (_, _) => const Scaffold(body: AutoBookkeepingPage()),
        routes: [
          GoRoute(
            path: 'check',
            builder: (_, _) =>
                const Scaffold(body: AutoBookkeepingPermissionsPage()),
          ),
        ],
      ),
    ],
  );
  return ProviderScope(
    overrides: [
      autoBookkeepingSettingsProvider.overrideWithValue(
        PrototypeBridge(status),
      ),
      appSettingsRepositoryProvider.overrideWithValue(
        MemoryStrategySettings()
          ..values[AutoBookkeepingStrategy.settingKey] =
              AutoBookkeepingStrategy.smart.name,
      ),
      recentAutoBookkeepingProvider.overrideWith(
        (ref) => Stream.value(records),
      ),
      pendingPaymentInboxProvider.overrideWith(
        (ref) async => [
          PendingPaymentReview(
            PendingAutoBookkeepingCandidate(
              fingerprint: 'mcd-pending',
              amountInCents: 2850,
              merchant: '麦当劳',
              paymentMethod: '支付宝',
              timestamp: DateTime(now.year, now.month, now.day - 1, 18, 3),
              sourceApp: 'ALIPAY',
              scene: 'PAYMENT_SUCCESS',
              transactionType: 'EXPENSE',
            ),
          ),
        ],
      ),
    ],
    child: MaterialApp.router(
      routerConfig: router,
      theme:
          (dark
                  ? AppTheme.dark(BuiltInThemes.liquidGlass)
                  : AppTheme.light(BuiltInThemes.liquidGlass))
              .copyWith(
                textTheme: ThemeData().textTheme.apply(
                  fontFamily: Platform.environment['AUTOBK_CAPTURE'] == null
                      ? null
                      : 'Microsoft YaHei',
                ),
              ),
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(scale),
          padding: const EdgeInsets.only(top: 24),
          viewPadding: const EdgeInsets.only(top: 24),
        ),
        child: RepaintBoundary(
          key: const ValueKey('prototype-capture'),
          child: child!,
        ),
      ),
    ),
  );
}

void main() {
  for (final readFails in [false, true]) {
    testWidgets('检测结果直接同步主页面，读取失败=$readFails', (tester) async {
      final status = {...flags};
      await tester.pumpWidget(harness(status: status));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AutoBookkeepingHero>(find.byType(AutoBookkeepingHero))
            .healthy,
        isTrue,
      );
      status['accessibilityConnected'] = false;
      status['readFails'] = readFails;
      await tester.tap(find.byKey(const ValueKey('autobookkeeping-check')));
      await tester.pumpAndSettle();
      final issue = readFails ? '无法读取服务状态，请重新检测' : '无障碍已授权但服务未连接';
      expect(find.text(issue), findsOneWidget);
      // Assert the underlying page updated before it is popped or refreshed.
      final hero = tester.widget<AutoBookkeepingHero>(
        find.byType(AutoBookkeepingHero, skipOffstage: false),
      );
      expect(hero.healthy, isFalse);
      expect(hero.statusMessage, issue);
      if (!readFails) {
        status['accessibilityConnected'] = true;
        await tester.tap(find.text('诊断'));
        await tester.pumpAndSettle();
        expect(
          ProviderScope.containerOf(
            tester.element(find.byType(AutoBookkeepingPermissionsPage)),
          ).read(autoBookkeepingRuntimeProvider).value?.healthy,
          isTrue,
        );
      }
      GoRouter.of(tester.element(find.byType(AutoBookkeepingPermissionsPage)))
          .pop();
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<AutoBookkeepingHero>(find.byType(AutoBookkeepingHero))
            .healthy,
        !readFails,
      );
      expect(tester.takeException(), isNull);
    });
  }
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() async {
    if (Platform.environment['AUTOBK_CAPTURE'] == null) return;
    for (final entry in {
      'Microsoft YaHei': 'C:/Windows/Fonts/msyh.ttc',
      'MaterialIcons': 'E:/jizhang_1/tools/flutter_sdk/flutter/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
    }.entries) {
      final bytes = await File(entry.value).readAsBytes();
      await (FontLoader(
        entry.key,
      )..addFont(Future.value(ByteData.sublistView(bytes)))).load();
    }
  });
  for (final (width, scale, dark) in [
    (390.0, 1.0, false),
    (320.0, 1.0, false),
    (430.0, 1.3, true),
  ]) {
    testWidgets('原型布局 $width / $scale 保持底部按钮居中且无溢出', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = Size(width, 871);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      await tester.pumpWidget(harness(scale: scale, dark: dark));
      await tester.runAsync(() async {
        final context = tester.element(find.byType(AutoBookkeepingPage));
        for (final path in [
          'assets/images/liquid_glass_profile_background.webp',
          'assets/images/autobookkeeping/hero-robot.png',
          'assets/images/autobookkeeping/starbucks.png',
          ...autoSources.map((item) => item.$2),
        ]) {
          await precacheImage(AssetImage(path), context);
        }
      });
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      expect(find.text('立即测试'), findsNothing);
      final button = tester.getRect(
        find.byKey(const ValueKey('autobookkeeping-check')),
      );
      expect(button.center.dx, closeTo(width / 2, .5));
      expect(button.width, closeTo(170, 2));
      expect(find.byIcon(Icons.check_circle_rounded), findsNWidgets(6));
      final path = Platform.environment['AUTOBK_CAPTURE'];
      if (path != null && width == 390) {
        final classes = [
          AutoBookkeepingHero,
          RecognitionSources,
          RecognitionRules,
          AutoConfirmationStrategies,
          RecognitionExample,
        ];
        await tester.runAsync(
          () => File('$path/layout-measurements.txt').writeAsString(
            [
              for (final type in classes)
                '$type: ${tester.getRect(find.byType(type))}',
              'Recent: ${tester.getRect(find.ancestor(of: find.text('最近自动记账记录'), matching: find.byType(AutoSection)))}',
              'Button: $button',
            ].join('\n'),
          ),
        );
      }
      if (path != null)
        await tester.runAsync(() async {
          final boundary = tester.renderObject<RenderRepaintBoundary>(
            find.byKey(const ValueKey('prototype-capture')),
          );
          final image = await boundary.toImage(pixelRatio: 2);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          await File('$path/page-$width-$scale.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          image.dispose();
        });
      await tester.drag(
        find.byKey(const ValueKey('autobookkeeping-scroll')),
        const Offset(0, -220),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.byKey(const ValueKey('autobookkeeping-check'))),
        button,
      );
      expect(tester.takeException(), isNull);
    });
  }
  testWidgets('关闭或权限异常隐藏绿色勾，四项规则关闭', (tester) async {
    for (final status in [
      {...flags, 'enabled': false},
      {...flags, 'accessibilityConnected': false},
    ]) {
      await tester.pumpWidget(harness(status: status));
      await tester.pumpAndSettle();
      expect(find.byIcon(Icons.check_circle_rounded), findsNothing);
      expect(find.text('已关闭'), findsNWidgets(10));
      expect(tester.takeException(), isNull);
    }
  });
  testWidgets('一键检测进入权限卡片，诊断发悬浮通知，日志在卡片底部', (tester) async {
    final notices = <String>[];
    const channel = MethodChannel('jizhang/notice_theme');
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'show')
            notices.add((call.arguments as Map)['message'] as String);
          return true;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('autobookkeeping-check')));
    await tester.pumpAndSettle();
    expect(find.byType(AutoBookkeepingPermissionsPage), findsOneWidget);
    expect(notices, isNotEmpty);
    await tester.tap(find.text('诊断'));
    await tester.pumpAndSettle();
    expect(notices.length, 2);
    await tester.scrollUntilVisible(
      find.byKey(const ValueKey('autobookkeeping-runtime-logs')),
      200,
      scrollable: find.byType(Scrollable).last,
    );
    expect(find.text('运行日志'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('来源可横滑到京东，规则和来源点击均进入检测', (tester) async {
    await tester.pumpWidget(harness());
    await tester.pumpAndSettle();
    await tester.drag(
      find.byKey(const ValueKey('autobookkeeping-sources')),
      const Offset(-250, 0),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.text('京东'));
    await tester.pumpAndSettle();
    expect(find.byType(AutoBookkeepingPermissionsPage), findsOneWidget);
    final checkContext = tester.element(
      find.byType(AutoBookkeepingPermissionsPage),
    );
    GoRouter.of(checkContext).pop();
    await tester.pumpAndSettle();
    await tester.tap(find.text('商户识别'));
    await tester.pumpAndSettle();
    expect(find.byType(AutoBookkeepingPermissionsPage), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
