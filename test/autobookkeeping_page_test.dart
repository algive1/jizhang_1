import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/book.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_learning.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_settings.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_confirm_page.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_permissions_page.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/components/number_keyboard.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/intelligence/domain/merchant_classification_service.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/components/category_grid.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/quick_add_sheet.dart';

void main() {
  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('jizhang/autobookkeeping_logs'),
          (_) async => null,
        );
  });
  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(
          const MethodChannel('jizhang/autobookkeeping_logs'),
          null,
        );
  });
  test('独立浮层 Activity 路由从平台初始地址打开', () {
    const route = '/profile/autobookkeeping/confirm?overlay=1';
    expect(appInitialLocation(route), route);
    expect(isAutoBookkeepingOverlayRoute(route), isTrue);
    expect(
      isAutoBookkeepingOverlayRoute('/profile/autobookkeeping/confirm'),
      isFalse,
    );
    expect(appInitialLocation('/'), '/');
  });

  testWidgets('自动记账页展示权限与常驻通知说明', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoBookkeepingSettingsProvider.overrideWithValue(
            const _FakeAutoBookkeepingBridge(),
          ),
        ],
        child: const MaterialApp(home: AutoBookkeepingPermissionsPage()),
      ),
    );
    for (var frame = 0; frame < 30; frame++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(find.text('自动记账'), findsNWidgets(2));
    expect(find.text('无障碍服务'), findsOneWidget);
    expect(find.text('悬浮窗权限'), findsOneWidget);
    expect(find.text('常驻通知权限'), findsOneWidget);
    expect(find.text('支付通知兜底'), findsOneWidget);
    expect(find.text('保存支付结果截图'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('页面识别规则'),
      260,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('页面识别规则'), findsOneWidget);
    expect(find.textContaining('常驻通知'), findsWidgets);
    expect(tester.takeException(), isNull);
  });

  testWidgets('通知已授权但未连接时展示重连和小米后台保护', (tester) async {
    final status = AutoBookkeepingRuntimeStatus.fromMap({
      'enabled': true,
      'accessibilityGranted': true,
      'accessibilityConnected': true,
      'overlayGranted': true,
      'notificationGranted': true,
      'foregroundRunning': true,
      'notificationListenerGranted': true,
      'notificationListenerEnabled': true,
      'notificationListenerConnected': false,
      'miuiFamily': true,
      'backgroundRestricted': true,
    });
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoBookkeepingSettingsProvider.overrideWithValue(
            _FakeAutoBookkeepingBridge(status: status),
          ),
        ],
        child: const MaterialApp(home: AutoBookkeepingPermissionsPage()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('已开启 · 通知兜底未连接，请检查后台设置'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('重连'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('已授权但监听未连接，请检查自启动和省电设置'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('小米自启动'),
      240,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('系统限制后台运行，请将省电策略设为无限制'), findsOneWidget);
    expect(find.text('小米自启动'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('pending candidate keeps optional screenshot metadata', () {
    final candidate = PendingAutoBookkeepingCandidate.fromMap({
      'fingerprint': 'screen-1',
      'amountInCents': 1880,
      'merchant': '测试商户',
      'paymentMethod': '支付宝',
      'timestamp': DateTime(2026, 9, 20, 12).millisecondsSinceEpoch,
      'sourceApp': 'ALIPAY',
      'scene': 'ALIPAY_PAYMENT_SUCCESS',
      'transactionType': 'EXPENSE',
      'screenshotPath': '/data/user/0/app/files/payment.png',
    });
    expect(candidate.screenshotPath, '/data/user/0/app/files/payment.png');
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

  testWidgets('跨应用确认模式显示约55%高度的取消完成面板且不出现键盘', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(400, 800);
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoBookkeepingPendingBridgeProvider.overrideWithValue(
            const _FakePendingBridge(),
          ),
        ],
        child: MaterialApp(
          color: Colors.transparent,
          theme: AppTheme.light(BuiltInThemes.liquidGlass),
          home: const AutoBookkeepingConfirmPage(overlayMode: true),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final panel = tester.getSize(
      find.byKey(const ValueKey('autobookkeeping-overlay-panel')),
    );
    expect(panel.height, inInclusiveRange(400, 480));
    expect(find.text('没有待确认的交易记录'), findsOneWidget);
    expect(find.byType(EditableText), findsNothing);
    expect(find.text('确认并完成'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('跨应用确认加载时可关闭且保留待确认账单', (tester) async {
    const channel = MethodChannel('jizhang/autobookkeeping_overlay');
    MethodCall? closeCall;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          closeCall = call;
          return null;
        });
    addTearDown(
      () => TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(channel, null),
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          autoBookkeepingPendingBridgeProvider.overrideWithValue(
            _HangingPendingBridge(),
          ),
        ],
        child: const MaterialApp(
          home: AutoBookkeepingConfirmPage(overlayMode: true),
        ),
      ),
    );
    await tester.pump();

    final close = find.byKey(const ValueKey('autobookkeeping-loading-close'));
    expect(close, findsOneWidget);
    await tester.tap(close);
    await tester.pump();

    expect(closeCall?.method, 'close');
    expect(closeCall?.arguments, {'preservePending': true});
    await tester.pump(const Duration(seconds: 7));
  });

  for (final (size, scale, dark) in const [
    (Size(412, 860), 1.0, false),
    (Size(320, 640), 1.0, false),
    (Size(360, 800), 1.0, false),
    (Size(393, 844), 1.3, false),
    (Size(320, 640), 1.6, false),
    (Size(600, 960), 1.6, false),
    (Size(393, 844), 1.0, true),
  ]) {
    testWidgets('付款浮层 $size 字号 $scale 深色 $dark 不撑开且固定操作可用', (tester) async {
      tester.view.devicePixelRatio = 1;
      tester.view.physicalSize = size;
      tester.view.padding = const FakeViewPadding(top: 54, bottom: 24);
      addTearDown(tester.view.resetPadding);
      tester.platformDispatcher.textScaleFactorTestValue = scale;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final now = DateTime(2026, 9, 27, 18);
      final database = createMemoryDatabase();
      addTearDown(database.close);
      await DatabaseSeeder(database).seedIfNeeded();
      final repositoryCategories = await DriftCategoryRepository(database)
          .getActive();
      final expectedExpenseRoots =
          repositoryCategories
              .where(
                (category) =>
                    category.type.name == 'expense' &&
                    category.parentId == null,
              )
              .toList()
            ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
      final books = [
        LedgerBook(
          id: 'book-personal',
          name: '日常账本',
          type: BookType.personal,
          ownerUserId: 'local-user',
          createdAt: now,
          updatedAt: now,
          isArchived: false,
        ),
      ];
      final candidate = PendingAutoBookkeepingCandidate(
        fingerprint: 'overlay-widget-1',
        amountInCents: 2880,
        merchant: '浮层测试商户',
        paymentMethod: '支付宝',
        timestamp: DateTime(2026, 9, 27, 18),
        sourceApp: 'ALIPAY',
        scene: 'ALIPAY_PAYMENT_SUCCESS',
        transactionType: 'EXPENSE',
        screenshotPath: '/tmp/payment-success.png',
        note: '工作餐备注',
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(database),
            databaseBootstrapProvider.overrideWith((ref) async {}),
            booksProvider.overrideWithValue(AsyncData(books)),
            autoBookkeepingLearningServiceProvider.overrideWithValue(
              const _FakeLearningService(),
            ),
            autoBookkeepingPendingBridgeProvider.overrideWithValue(
              _FakePendingBridge(candidate: candidate),
            ),
          ],
          child: MaterialApp(
            color: Colors.transparent,
            theme: dark
                ? AppTheme.dark(BuiltInThemes.liquidGlass)
                : AppTheme.light(BuiltInThemes.liquidGlass),
            home: const AutoBookkeepingConfirmPage(overlayMode: true),
          ),
        ),
      );
      await tester.pump();
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 200)),
      );
      for (var frame = 0; frame < 20; frame++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        find.byKey(const ValueKey('autobookkeeping-quick-add-review')),
        findsOneWidget,
      );
      final reviewSheet = tester.widget<QuickAddSheet>(
        find.byKey(const ValueKey('autobookkeeping-quick-add-review')),
      );
      expect(
        reviewSheet.reviewBottomSafeArea,
        isFalse,
        reason: '原生浮层已经处理系统底部安全区，确认按钮不能重复抬高',
      );
      expect(
        find.byKey(const ValueKey('quick-category-section')),
        findsOneWidget,
      );
      final categoryCard = find.byKey(const ValueKey('quick-category-card'));
      final categoryViewport = find.byKey(
        const ValueKey('quick-category-section'),
      );
      expect(
        tester.getSize(categoryCard).height,
        closeTo(scale > 1.3 ? 230.4 : 182.4, .1),
      );
      expect(tester.getSize(categoryViewport).height, scale > 1.3 ? 216 : 168);
      expect(
        tester
            .getTopLeft(
              find.byKey(
                ValueKey('quick-category-${expectedExpenseRoots.first.id}'),
              ),
            )
            .dy,
        closeTo(tester.getTopLeft(categoryViewport).dy, .1),
        reason: '分类从顶部开始，不能因数量不足而沉到底部',
      );
      final columns = scale > 1.3 ? (size.width < 380 ? 3 : 4) : 5;
      final lastRowFirst =
          expectedExpenseRoots[(expectedExpenseRoots.length - 1) ~/
              columns *
              columns];
      expect(
        tester
            .getTopLeft(
              find.byKey(ValueKey('quick-category-${lastRowFirst.id}')),
            )
            .dx,
        closeTo(tester.getTopLeft(categoryViewport).dx, .1),
        reason: '末行应从左边连续排列，不能补空位',
      );
      final grid = tester.widget<CategoryGrid>(find.byType(CategoryGrid));
      expect(
        grid.categories.map((category) => category.id).toList(),
        expectedExpenseRoots.map((category) => category.id).toList(),
        reason: '自动确认分类从餐饮开始，其他在最后',
      );
      expect(find.byKey(const ValueKey('quick-ai-entry')), findsNothing);
      expect(find.byKey(const ValueKey('quick-voice-entry')), findsNothing);
      expect(find.byKey(const ValueKey('quick-detail-card')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-amount-input')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-account-chip')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-book-selector')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-attachment-chip')),
        findsOneWidget,
      );
      expect(
        find.byKey(const ValueKey('quick-ledger-only-chip')),
        findsOneWidget,
      );
      expect(find.byKey(const ValueKey('quick-date-chip')), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-recurring-chip')),
        findsOneWidget,
      );
      expect(find.text('= ¥28.80'), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('quick-note-field')))
            .controller!
            .text,
        '浮层测试商户',
      );
      final screenshotToggle = find.byKey(
        const ValueKey('quick-review-screenshot-toggle'),
      );
      expect(screenshotToggle, findsOneWidget);
      expect(find.text('自动截图'), findsOneWidget);
      expect(
        tester.getBottomRight(find.text('自动截图')).dy,
        lessThan(tester.getTopLeft(screenshotToggle).dy),
        reason: '自动截图文字与开关上下排列，不能重叠',
      );
      expect(tester.widget<Switch>(screenshotToggle).value, isTrue);
      await tester.tap(screenshotToggle);
      await tester.pump();
      expect(tester.widget<Switch>(screenshotToggle).value, isFalse);

      await tester.ensureVisible(
        find.byKey(const ValueKey('quick-amount-input')),
      );
      await tester.tap(find.byKey(const ValueKey('quick-amount-input')));
      await tester.pumpAndSettle();
      final amountEditor = find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      );
      await tester.enterText(amountEditor, '31.25');
      await tester.tap(find.text('确定'));
      await tester.pumpAndSettle();
      expect(find.text('= ¥31.25'), findsOneWidget);
      expect(
        find.byKey(const ValueKey('quick-review-complete')),
        findsOneWidget,
      );
      expect(find.text('取消'), findsOneWidget);
      expect(find.text('完成'), findsOneWidget);
      final detailBottom = tester
          .getBottomRight(find.byKey(const ValueKey('quick-detail-card')))
          .dy;
      final cancelTop = tester
          .getTopLeft(find.byKey(const ValueKey('quick-review-cancel')))
          .dy;
      expect(cancelTop, greaterThan(0));
      expect(detailBottom.isFinite, isTrue);
      expect(find.byType(NumberKeyboard), findsNothing);
      expect(find.byType(EditableText), findsOneWidget);
      final panel = tester.getRect(
        find.byKey(const ValueKey('autobookkeeping-overlay-panel')),
      );
      expect(panel.height, lessThanOrEqualTo(size.height * .60));
      expect(
        tester.getTopLeft(find.text('支出').first).dy,
        lessThan(panel.top + 45),
        reason: '嵌入面板不能重复添加状态栏留白',
      );
      expect(panel.width, lessThanOrEqualTo(size.width));
      final detail = find.byKey(const ValueKey('quick-detail-card'));
      final originalDetailSize = tester.getSize(detail);
      final note = find.byKey(const ValueKey('quick-note-field'));
      await tester.ensureVisible(note);
      await tester.enterText(note, List.filled(100, '超长付款备注').join());
      await tester.pump();
      expect(tester.getSize(detail), originalDetailSize);
      expect(tester.getSize(detail).width, lessThan(panel.width));
      await tester.ensureVisible(
        find.byKey(const ValueKey('quick-category-expense-other')),
      );

      await tester.tap(
        find.byKey(const ValueKey('quick-category-expense-other')),
      );
      await tester.pumpAndSettle();
      expect(find.text('手续费'), findsOneWidget);
      expect(find.text('杂项支出'), findsOneWidget);
      await tester.tapAt(const Offset(1, 1));
      await tester.pumpAndSettle();
      await _checkReviewFooter(tester);
      for (final tab in ['income', 'transfer', 'debt']) {
        await tester.tap(find.byKey(ValueKey('quick-type-$tab')));
        await tester.pumpAndSettle();
        if (tab != 'transfer') {
          final grid = tester.widget<CategoryGrid>(find.byType(CategoryGrid));
          final viewport = find.byKey(const ValueKey('quick-category-section'));
          expect(
            tester.getTopLeft(
              find.byKey(
                ValueKey('quick-category-${grid.categories.first.id}'),
              ),
            ),
            tester.getTopLeft(viewport),
          );
          if (scale == 1) {
            expect(
              tester.getSize(categoryCard).height,
              lessThan(150),
              reason: '六个收入分类只占两行，不应保留第三行空白',
            );
          }
        } else {
          final source = tester.getRect(
            find.byKey(const ValueKey('quick-account-chip')),
          );
          final destination = tester.getRect(
            find.byKey(const ValueKey('quick-destination-chip')),
          );
          expect(source.top, destination.top);
          expect(source.height, destination.height);
          expect(find.byType(CategoryGrid), findsNothing);
        }
        await _checkReviewFooter(tester);
      }

      expect(tester.takeException(), isNull);
    });
  }
}

Future<void> _checkReviewFooter(WidgetTester tester) async {
  final scroll = tester.state<ScrollableState>(
    find
        .descendant(
          of: find.byKey(const ValueKey('quick-detail-scroll')),
          matching: find.byType(Scrollable),
        )
        .first,
  );
  final actions = find.byKey(const ValueKey('quick-review-actions'));
  final bounds = tester.getRect(actions);
  scroll.position.jumpTo(scroll.position.maxScrollExtent);
  await tester.pump();
  await tester.ensureVisible(
    find.byKey(const ValueKey('quick-recurring-chip')),
  );
  await tester.pump();
  expect(
    tester.getBottomRight(find.byKey(const ValueKey('quick-detail-card'))).dy,
    lessThanOrEqualTo(bounds.top),
  );
  expect(tester.getRect(actions), bounds, reason: '滚动内容不能移动底部操作按钮');
  expect(
    find.byKey(const ValueKey('quick-recurring-chip')).hitTestable(),
    findsOneWidget,
  );
  scroll.position.jumpTo(0);
  await tester.pump();
}

class _FakeLearningService implements AutoBookkeepingLearningService {
  const _FakeLearningService();

  @override
  MerchantNormalizer get normalizer => const MerchantNormalizer();

  @override
  Future<AutoBookkeepingRecommendation> recommend({
    required PendingAutoBookkeepingCandidate candidate,
    required String fallbackBookId,
    required TransactionType transactionType,
  }) async => AutoBookkeepingRecommendation(bookId: fallbackBookId);

  @override
  Future<void> remember({
    required String transactionId,
    required PendingAutoBookkeepingCandidate candidate,
    required String bookId,
    required String accountId,
    required String categoryId,
    String? subcategoryId,
    List<String> tags = const [],
    required bool rememberForMerchant,
  }) async {}
}

class _FakeAutoBookkeepingBridge implements AutoBookkeepingSettingsBridge {
  const _FakeAutoBookkeepingBridge({this.status});
  final AutoBookkeepingRuntimeStatus? status;

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
      status ??
      const AutoBookkeepingRuntimeStatus(
        enabled: false,
        accessibilityGranted: false,
        accessibilityConnected: false,
        overlayGranted: false,
        notificationGranted: false,
        foregroundRunning: false,
        notificationListenerGranted: false,
        notificationListenerEnabled: false,
        notificationListenerConnected: false,
        screenshotSupported: true,
        screenshotEnabled: false,
        ruleSchemaVersion: 1,
        ruleVersions: 'WECHAT:v1,ALIPAY:v1',
        ruleSource: 'asset',
      );

  @override
  Future<void> openAccessibilitySettings() async {}

  @override
  Future<void> openOverlaySettings() async {}

  @override
  Future<void> openBackgroundSettings() async {}

  @override
  Future<void> openAutoStartSettings() async {}

  @override
  Future<void> reconnectNotificationListener() async {}

  @override
  Future<bool> requestNotificationPermission() async => false;

  @override
  Future<bool> setScreenshotEnabled(bool enabled) async => enabled;

  @override
  Future<void> setEnabled(bool enabled) async {}
}

class _FakePendingBridge implements AutoBookkeepingPendingBridge {
  const _FakePendingBridge({this.candidate});

  final PendingAutoBookkeepingCandidate? candidate;

  @override
  Future<AutoBookkeepingEnqueueResult> enqueue(
    PendingAutoBookkeepingCandidate candidate,
  ) async => AutoBookkeepingEnqueueResult.busy;

  @override
  Future<String?> promoteScreenshot(String path) async => path;

  @override
  Future<void> complete({
    bool keepScreenshot = false,
    String? fingerprint,
  }) async {}

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() async => candidate;
}

class _HangingPendingBridge extends _FakePendingBridge {
  _HangingPendingBridge();

  final _pending = Completer<PendingAutoBookkeepingCandidate?>();

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() => _pending.future;
}
