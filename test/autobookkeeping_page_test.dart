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
import 'package:jizhang_app/core/models/category.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_learning.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_pending.dart';
import 'package:jizhang_app/features/autobookkeeping/auto_bookkeeping_settings.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_confirm_page.dart';
import 'package:jizhang_app/features/autobookkeeping/presentation/auto_bookkeeping_page.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/components/number_keyboard.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/intelligence/domain/merchant_classification_service.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/components/category_grid.dart';

void main() {
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
        child: const MaterialApp(home: AutoBookkeepingPage()),
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

  testWidgets('付款候选使用记一笔结构、分类和固定操作且不创建键盘区', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(412, 860);
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
                  category.type.name == 'expense' && category.parentId == null,
            )
            .toList()
          ..sort((a, b) {
            bool isOther(Category category) =>
                category.id == 'expense-other' ||
                category.name.trim().startsWith('其他');
            final aIsOther = isOther(a);
            final bIsOther = isOther(b);
            if (aIsOther != bIsOther) return aIsOther ? -1 : 1;
            return b.sortOrder.compareTo(a.sortOrder);
          });
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
          theme: AppTheme.light(BuiltInThemes.liquidGlass),
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
    expect(
      find.byKey(const ValueKey('quick-category-section')),
      findsOneWidget,
    );
    final categoryCard = find.byKey(const ValueKey('quick-category-card'));
    final categoryViewport = find.byKey(
      const ValueKey('quick-category-section'),
    );
    expect(tester.getSize(categoryCard).height, 182);
    expect(tester.getSize(categoryViewport).height, 168);
    expect(
      tester
          .getTopLeft(find.byKey(const ValueKey('quick-category-expense-food')))
          .dy,
      greaterThanOrEqualTo(tester.getBottomRight(categoryViewport).dy - 1),
      reason: '第四行分类从分类卡片内部开始滚动',
    );
    final grid = tester.widget<CategoryGrid>(find.byType(CategoryGrid));
    expect(
      grid.categories.map((category) => category.id).toList(),
      expectedExpenseRoots.map((category) => category.id).toList(),
      reason: '自动确认分类顺序应将“其他”置首，其余按 sortOrder 倒序',
    );
    expect(find.byKey(const ValueKey('quick-detail-card')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-amount-input')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-account-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-book-selector')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-attachment-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-image-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-date-chip')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-recurring-chip')), findsOneWidget);
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
    expect(tester.widget<Switch>(screenshotToggle).value, isTrue);
    await tester.tap(screenshotToggle);
    await tester.pump();
    expect(tester.widget<Switch>(screenshotToggle).value, isFalse);

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
    expect(find.byKey(const ValueKey('quick-review-complete')), findsOneWidget);
    expect(find.text('取消'), findsOneWidget);
    expect(find.text('完成'), findsOneWidget);
    final detailBottom = tester
        .getBottomRight(find.byKey(const ValueKey('quick-detail-card')))
        .dy;
    final cancelTop = tester
        .getTopLeft(find.byKey(const ValueKey('quick-review-cancel')))
        .dy;
    expect(cancelTop - detailBottom, inInclusiveRange(0, 32));
    expect(find.byType(NumberKeyboard), findsNothing);
    expect(find.byType(EditableText), findsOneWidget);

    await tester.tap(
      find.byKey(const ValueKey('quick-category-expense-other')),
    );
    await tester.pumpAndSettle();
    expect(find.text('手续费'), findsOneWidget);
    expect(find.text('杂项支出'), findsOneWidget);

    expect(tester.takeException(), isNull);
  });
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
  Future<void> complete({bool keepScreenshot = false}) async {}

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() async => candidate;
}

class _HangingPendingBridge extends _FakePendingBridge {
  _HangingPendingBridge();

  final _pending = Completer<PendingAutoBookkeepingCandidate?>();

  @override
  Future<PendingAutoBookkeepingCandidate?> getPending() => _pending.future;
}
