import 'package:jizhang_app/core/widgets/app_action_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jizhang_app/app/app.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/recurring_bill.dart';
import 'package:jizhang_app/features/bookkeeping/presentation/quick_add_sheet.dart';
import 'package:jizhang_app/features/account/application/account_session_controller.dart';
import 'package:jizhang_app/features/account/domain/account_session.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/intelligence/data/bill_inbox_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/recurring/data/recurring_bill_repository.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/voice/application/speech_recognition_service.dart';

void main() {
  testWidgets('renders the core navigation routes without layout errors', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final errors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      previousErrorHandler?.call(details);
    };

    try {
      await _pumpApp(tester);
      await tester.pumpAndSettle();
      expect(find.text('我的账本'), findsOneWidget);
      expect(find.text('今日可用'), findsOneWidget);

      await tester.tap(find.text('流水').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('收支分析'));
      await tester.pumpAndSettle();
      expect(find.text('收支分析'), findsOneWidget);
      expect(find.text('统计周期'), findsOneWidget);
      await tester.scrollUntilVisible(
        find.text('7×24 消费热力图'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('周日'), findsOneWidget);

      GoRouter.of(tester.element(find.text('周日'))).go('/transactions');
      await tester.pumpAndSettle();
      expect(find.text('本月支出'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.track_changes_outlined));
      await tester.pumpAndSettle();
      expect(find.text('目标'), findsWidgets);

      await tester.tap(find.textContaining('买车计划').first);
      await tester.pumpAndSettle();
      expect(find.text('目标详情'), findsOneWidget);
      await tester.drag(find.byType(CustomScrollView), const Offset(0, -500));
      await tester.pump();
      expect(find.text('最近存入'), findsOneWidget);

      GoRouter.of(tester.element(find.text('最近存入'))).go('/goals');
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.text('普通会员'), findsOneWidget);
      await tester.drag(find.byType(ListView), const Offset(0, -500));
      await tester.pump();
      expect(find.text('帮助与反馈'), findsOneWidget);
    } finally {
      FlutterError.onError = previousErrorHandler;
    }

    expect(
      errors,
      isEmpty,
      reason: errors.map((error) => error.toString()).join('\n'),
    );
  });

  testWidgets('home header follows the selected custom ledger name', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await _pumpApp(tester);
    await tester.pumpAndSettle();

    final family = await DriftBookRepository(
      database,
      LocalOnlyMembershipRepository(),
    ).create(name: '家庭季度规划与长期旅行账本', type: BookType.family);
    await tester.pumpAndSettle();

    final title = find.byKey(const ValueKey('home-book-title'));
    expect(tester.widget<Text>(title).data, '我的账本');
    await tester.tap(title);
    await tester.pumpAndSettle();
    await tester.tap(find.text(family.name).last);
    await tester.pumpAndSettle();

    final selectedTitle = tester.widget<Text>(title);
    expect(selectedTitle.data, '家庭的账本');
    expect(selectedTitle.maxLines, 1);
    expect(selectedTitle.overflow, TextOverflow.ellipsis);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'home long-press edit covers navigation and opens recurring rules',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 1200));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpApp(tester);
      await tester.pumpAndSettle();

      await tester.dragFrom(const Offset(190, 500), const Offset(0, -260));
      await tester.pumpAndSettle();
      await tester.longPress(find.text('瑞幸咖啡').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('编辑流水'));
      await tester.pumpAndSettle();

      final sheet = tester.getRect(find.byType(QuickAddSheet));
      final navigation = tester.getRect(find.byType(AppBottomNavigation));
      expect(sheet.bottom, greaterThanOrEqualTo(navigation.bottom));
      _expectNavigationCoveredByQuickAdd(tester);

      await tester.tap(find.byKey(const ValueKey('quick-recurring-chip')));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const ValueKey('recurring-create-title')),
        findsOneWidget,
      );
      expect(find.text('配置周期规则'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('transaction list edit covers navigation', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('流水').last);
    await tester.pumpAndSettle();
    await tester.longPress(find.text('瑞幸咖啡').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑流水'));
    await tester.pumpAndSettle();

    expect(find.byType(QuickAddSheet), findsOneWidget);
    _expectNavigationCoveredByQuickAdd(tester);
    expect(tester.takeException(), isNull);
  });

  testWidgets('goal can be archived and restored from its detail menu', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester, liveGoals: true);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.track_changes_outlined));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('买车计划').first);
    await tester.pumpAndSettle();

    await tester.tap(find.byType(AppActionMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('编辑目标'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('目标详情'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(AppActionMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('调整节点'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('目标详情'), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.tap(find.byType(AppActionMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('归档目标'), findsOneWidget);
    await tester.tap(find.text('归档目标'));
    await tester.pumpAndSettle();
    expect(find.text('归档这个目标？'), findsOneWidget);
    await tester.tap(find.text('归档'));
    await tester.pumpAndSettle();

    expect(find.text('已归档'), findsOneWidget);
    expect(find.textContaining('买车计划'), findsOneWidget);
    await tester.tap(find.textContaining('买车计划').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byType(AppActionMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('恢复目标'), findsOneWidget);
    await tester.tap(find.text('恢复目标'));
    await tester.pumpAndSettle();
    expect(find.text('目标已恢复'), findsOneWidget);
    await tester.tap(find.byType(AppActionMenuButton<String>));
    await tester.pumpAndSettle();
    expect(find.text('归档目标'), findsOneWidget);
  });

  testWidgets('filters and searches transaction records', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('流水').last);
    await tester.pumpAndSettle();

    await tester.tap(find.text('收入').first);
    await tester.pumpAndSettle();
    expect(find.text('工资'), findsOneWidget);
    expect(find.text('瑞幸咖啡'), findsNothing);

    await tester.tap(find.text('支出').first);
    await tester.pumpAndSettle();
    expect(find.text('瑞幸咖啡'), findsWidgets);
    expect(find.text('工资'), findsNothing);

    await tester.tap(find.text('全部').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索流水'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '瑞幸');
    await tester.pumpAndSettle();
    expect(find.text('找到 2 笔记录'), findsOneWidget);
    expect(find.text('瑞幸咖啡'), findsNWidgets(2));

    await tester.tap(find.byTooltip('返回流水'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('筛选流水'));
    await tester.pumpAndSettle();
    expect(find.text('筛选分类'), findsOneWidget);
    await tester.tap(find.text('餐饮').last);
    await tester.pumpAndSettle();
    expect(find.widgetWithText(InputChip, '餐饮'), findsOneWidget);
  });

  testWidgets('transaction actions expose edit and delete flows', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('流水').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('瑞幸咖啡').first);
    await tester.pumpAndSettle();
    expect(find.text('交易详情'), findsOneWidget);
    await tester.tap(find.byTooltip('更多操作'));
    await tester.pumpAndSettle();
    expect(find.text('编辑流水'), findsOneWidget);
    expect(find.text('删除流水'), findsOneWidget);

    await tester.tap(find.text('删除流水'));
    await tester.pumpAndSettle();
    expect(find.text('删除这笔流水？'), findsOneWidget);
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();
    expect(find.text('流水已删除，账户余额已同步更新'), findsOneWidget);
    expect(
      (await database.transactionDao.getActive()).where(
        (item) => item.id == 'seed-expense-1',
      ),
      isEmpty,
    );
  });

  testWidgets(
    'transaction click opens detail and long press opens action menu',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(320, 700));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpApp(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.text('流水').last);
      await tester.pumpAndSettle();
      final transaction = find.text('瑞幸咖啡').first;

      await tester.tap(transaction);
      await tester.pumpAndSettle();
      expect(find.text('交易详情'), findsOneWidget);
      Navigator.of(tester.element(find.text('交易详情'))).pop();
      await tester.pumpAndSettle();

      await tester.longPress(transaction);
      await tester.pumpAndSettle();
      expect(find.text('编辑流水'), findsOneWidget);
      expect(find.text('删除流水'), findsOneWidget);
    },
  );

  testWidgets('search result can be long-pressed and deleted from the list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    addTearDown(() => tester.pump(const Duration(seconds: 1)));
    final database = await _pumpApp(tester, liveTransactions: true);
    await tester.pumpAndSettle();

    await tester.tap(find.text('流水').last);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('搜索流水'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '瑞幸');
    await tester.pumpAndSettle();
    expect(find.text('找到 2 笔记录'), findsOneWidget);

    await tester.longPress(find.text('瑞幸咖啡').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('删除流水'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认删除'));
    await tester.pumpAndSettle();

    expect(find.text('找到 1 笔记录'), findsOneWidget);
    expect(find.text('瑞幸咖啡'), findsOneWidget);
    expect(
      (await database.transactionDao.getActive()).where(
        (item) => item.id == 'seed-expense-1',
      ),
      isEmpty,
    );
  });

  testWidgets('opens manual bookkeeping entry', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await _pumpApp(tester);
    await tester.pumpAndSettle();
    final before = await database.transactionDao.getActive();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    // 四个类型页签常驻首行；债务页签是本轮新增入口。
    expect(find.byKey(const ValueKey('quick-type-expense')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-income')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-transfer')), findsOneWidget);
    expect(find.byKey(const ValueKey('quick-type-debt')), findsOneWidget);
    expect(find.text('支出'), findsWidgets);
    expect(find.text('收入'), findsWidgets);
    expect(find.text('转账'), findsOneWidget);

    // 键盘常驻，进入页面即可输入，不需要先点金额框。
    await tester.tap(find.byKey(const ValueKey('amount-key-3')));
    await tester.tap(find.byKey(const ValueKey('amount-key-6')));
    await tester.pump();
    expect(find.text('= ¥36.00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pump();
    await tester.pump(const Duration(seconds: 1));
    expect(
      await database.transactionDao.getActive(),
      hasLength(before.length + 1),
    );
    expect(find.text('已保存到本地账本'), findsOneWidget);
  });

  testWidgets('missing amount shows an inline validation prompt', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await _pumpApp(tester);
    await tester.pumpAndSettle();
    final before = await database.transactionDao.getActive();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('quick-done')));
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('quick-amount-error')), findsOneWidget);
    expect(await database.transactionDao.getActive(), hasLength(before.length));
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'amount card is placed after categories and has a full hit area',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await _pumpApp(tester);
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.add));
      await tester.pumpAndSettle();
      final categoryRect = tester.getRect(
        find.byKey(const ValueKey('quick-category-section')),
      );
      final amountRect = tester.getRect(
        find.byKey(const ValueKey('quick-amount-input')),
      );
      expect(amountRect.top, greaterThan(categoryRect.bottom));
      expect(amountRect.height, greaterThanOrEqualTo(56));

      // 键盘常驻：数字、运算符、「再记」和「完成」都在同一屏内。
      expect(find.byKey(const ValueKey('amount-key-1')), findsOneWidget);
      expect(find.byKey(const ValueKey('amount-key-+')), findsOneWidget);
      expect(find.byKey(const ValueKey('amount-key-×')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-repeat')), findsOneWidget);
      expect(find.byKey(const ValueKey('quick-done')), findsOneWidget);

      expect(find.byTooltip('清空金额'), findsNothing);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('membership navigation closes the ledger drawer', (tester) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('我的账本').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('会员').last);
    await tester.pumpAndSettle();

    expect(find.text('开通会员'), findsOneWidget);
    expect(find.text('选择账本'), findsNothing);
    expect(find.text('我的账本'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('quick add and membership share the same back-button target', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.add));
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byTooltip('返回')), const Size(48, 48));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);

    await tester.tap(find.byTooltip('返回'));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('今日可用'))).go('/profile/membership');
    await tester.pumpAndSettle();
    expect(tester.getSize(find.byTooltip('返回')), const Size(48, 48));
    expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final scale in [1.0, 1.6]) {
    testWidgets(
      'home trends and entry adapt to small screens at scale $scale',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(320, 700));
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(() {
          tester.platformDispatcher.clearTextScaleFactorTestValue();
        });
        addTearDown(() => tester.binding.setSurfaceSize(null));
        await _pumpApp(tester);
        await tester.pumpAndSettle();
        await tester.scrollUntilVisible(
          find.byKey(const ValueKey('home-trend-last7Days')),
          160,
          scrollable: find.byType(Scrollable).first,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('home-trend-last7Days')));
        await tester.pumpAndSettle();
        expect(find.textContaining('本期累计支出'), findsOneWidget);
        final chart = find.byKey(const ValueKey('home-trend-chart'));
        await tester.drag(chart, const Offset(-150, 0));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-trend-value')), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('home-trend-currentYear')));
        await tester.pumpAndSettle();
        expect(find.byKey(const ValueKey('home-trend-value')), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byType(FloatingActionButton));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('quick-type-income')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const ValueKey('quick-type-transfer')));
        await tester.pumpAndSettle();
        expect(find.text('转出'), findsOneWidget);
        await tester.tap(find.byKey(const ValueKey('quick-type-expense')));
        await tester.pumpAndSettle();
        for (var i = 0; i < 7; i++) {
          await tester.tap(find.byKey(const ValueKey('amount-key-9')));
        }
        await tester.pumpAndSettle();
        expect(find.text('= ¥9999999.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        // 计算器：表达式与实时结果同屏显示。
        await tester.tap(find.byKey(const ValueKey('amount-key-+')));
        await tester.tap(find.byKey(const ValueKey('amount-key-1')));
        await tester.pumpAndSettle();
        expect(find.text('9999999+1'), findsOneWidget);
        // 大字是「将要入账的金额」，表达式在右侧小灰字。
        expect(find.text('= ¥10000000.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        expect(find.byTooltip('清空金额'), findsNothing);
        await tester.pumpAndSettle();
        tester.view.viewInsets = const FakeViewPadding(bottom: 250);
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        tester.view.resetViewInsets();
        await tester.pumpAndSettle();
      },
    );
  }

  testWidgets('opens account, category and budget management pages', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.person_outline));
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('普通会员'))).go('/profile/accounts');
    await tester.pumpAndSettle();
    expect(find.text('查看资产、负债与资金形式'), findsOneWidget);

    GoRouter.of(tester.element(find.text('查看资产、负债与资金形式')))
        .go('/profile/categories');
    await tester.pumpAndSettle();
    expect(find.text('支出分类'), findsOneWidget);
    expect(find.text('收入分类'), findsOneWidget);

    await tester.tap(find.text('新增'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('取消'));
    await tester.pumpAndSettle();
    expect(find.text('支出分类'), findsOneWidget);
    expect(tester.takeException(), isNull);

    GoRouter.of(tester.element(find.text('支出分类'))).go('/profile/budgets');
    await tester.pumpAndSettle();
    expect(find.text('本月还剩'), findsOneWidget);
    expect(find.text('分类预算'), findsOneWidget);

    GoRouter.of(tester.element(find.text('分类预算'))).go('/profile/membership');
    await tester.pumpAndSettle();
    expect(find.text('开通会员'), findsOneWidget);

    GoRouter.of(tester.element(find.text('开通会员'))).go('/profile/family');
    await tester.pumpAndSettle();
    expect(find.text('登录后即可共享'), findsOneWidget);

    GoRouter.of(tester.element(find.text('家庭共享'))).go('/transactions/inbox');
    await tester.pumpAndSettle();
    expect(find.text('暂无待确认账单'), findsOneWidget);
  });

  testWidgets('budget settings survives cancel, page back, and save', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final database = await _pumpApp(tester);
    await tester.pumpAndSettle();
    GoRouter.of(tester.element(find.text('今日可用'))).go('/profile/budgets');
    await tester.pumpAndSettle();

    final errors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = errors.add;
    try {
      await tester.tap(find.text('调整').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('取消'));
      await tester.pumpAndSettle();
      expect(find.text('分类预算'), findsOneWidget);

      await tester.tap(find.byIcon(Icons.arrow_back));
      await tester.pumpAndSettle();
      expect(find.text('普通会员'), findsOneWidget);

      GoRouter.of(tester.element(find.text('普通会员'))).go('/profile/budgets');
      await tester.pumpAndSettle();
      await tester.tap(find.text('调整').first);
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField), '1234');
      await tester.tap(find.text('保存'));
      await tester.pumpAndSettle();
      expect(
        (await database.budgetDao.getMonth(budgetMonthKey(DateTime.now())))
            .any((item) => item.amountInCents == 123400),
        isTrue,
      );
    } finally {
      FlutterError.onError = previousErrorHandler;
    }
    expect(errors, isEmpty, reason: errors.map((e) => e.exception).join('\n'));
  });

  testWidgets('long press plus opens editable voice confirmation flow', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester, speechService: const _FakeSpeechService());
    await tester.pumpAndSettle();

    await tester.longPress(find.byType(FloatingActionButton));
    await tester.pumpAndSettle();
    expect(find.text('语音记账'), findsOneWidget);
    await tester.enterText(
      find.byKey(const ValueKey('voice-transcript')),
      '午饭32支付宝',
    );
    await tester.tap(find.text('解析文字'));
    await tester.pumpAndSettle();
    expect(find.textContaining('第 1 笔'), findsOneWidget);
    expect(find.byKey(const ValueKey('voice-confirm')), findsOneWidget);
  });

  testWidgets('finance expansion routes stay usable at narrow width', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    final errors = <FlutterErrorDetails>[];
    final previousErrorHandler = FlutterError.onError;
    FlutterError.onError = (details) {
      errors.add(details);
      previousErrorHandler?.call(details);
    };
    try {
      final database = await _pumpApp(tester);
      await tester.pumpAndSettle();
      final now = DateTime.now();
      await DriftRecurringBillRepository(
        database,
        bookId: SeedIds.personalBook,
      ).create(
        RecurringBill(
          id: 'ui-recurring-bill',
          bookId: SeedIds.personalBook,
          name: 'UI 订阅',
          type: RecurringBillType.subscription,
          amount: 15,
          cycle: RecurringBillCycle.monthly,
          startDate: now,
          nextDate: now,
          accountId: SeedIds.bankAccount,
          categoryId: 'expense-food',
          createdAt: now,
          updatedAt: now,
        ),
      );
      final router = GoRouter.of(tester.element(find.text('今日可用')));
      for (final route in [
        '/transactions/reimbursements',
        '/transactions/calendar',
        '/profile/recurring-bills',
        '/profile/installments',
        '/profile/accounts/account-bank',
      ]) {
        router.go(route);
        await tester.pumpAndSettle();
        expect(
          find.byType(AppBottomNavigation),
          findsNothing,
          reason: 'secondary route $route should not show global navigation',
        );
        expect(
          find.byType(FloatingActionButton),
          findsNothing,
          reason: 'secondary route $route should not show global add action',
        );
        expect(
          errors,
          isEmpty,
          reason:
              'route $route: ${errors.map((error) => error.toString()).join('\\n')}',
        );
        errors.clear();
        if (route == '/profile/recurring-bills') {
          expect(find.text('UI 订阅'), findsOneWidget);
        }
      }
      expect(
        find.byKey(const ValueKey('account-detail-title')),
        findsOneWidget,
      );
    } finally {
      FlutterError.onError = previousErrorHandler;
    }
    expect(
      errors,
      isEmpty,
      reason: errors.map((error) => error.toString()).join('\n'),
    );
  });
}

Future<AppDatabase> _pumpApp(
  WidgetTester tester, {
  SpeechRecognitionService? speechService,
  bool liveTransactions = false,
  bool liveGoals = false,
}) async {
  final database = createMemoryDatabase();
  await DatabaseSeeder(database).seedIfNeeded(includeDemoData: true);
  final transactions = await DriftTransactionRepository(database).getAll();
  final accounts = await DriftAccountRepository(database).getActive();
  final categories = await DriftCategoryRepository(database).getActive();
  final goals = await DriftGoalRepository(database).getAll();
  final budgets = await DriftBudgetRepository(
    database,
    const SafeToSpendService(),
  ).getMonth(budgetMonthKey(DateTime.now()));
  final membership = await LocalOnlyMembershipRepository().getCurrent();
  addTearDown(database.close);
  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(database),
      if (liveTransactions)
        transactionsProvider.overrideWith((ref) async* {
          yield await DriftTransactionRepository(database).getAll();
        })
      else
        transactionsProvider.overrideWithValue(AsyncData(transactions)),
      accountsProvider.overrideWithValue(AsyncData(accounts)),
      allAccountsProvider.overrideWithValue(AsyncData(accounts)),
      categoriesProvider.overrideWithValue(AsyncData(categories)),
      allCategoriesProvider.overrideWithValue(AsyncData(categories)),
      if (liveGoals)
        goalsProvider.overrideWith(
          (ref) => DriftGoalRepository(
            database,
            bookId: ref.watch(activeBookIdProvider),
          ).watchAll(),
        )
      else
        goalsProvider.overrideWithValue(AsyncData(goals)),
      currentMonthBudgetsProvider.overrideWithValue(AsyncData(budgets)),
      pendingInboxProvider.overrideWithValue(const AsyncData([])),
      membershipProvider.overrideWithValue(AsyncData(membership)),
      accountSessionProvider.overrideWithValue(
        AsyncData(AccountSession.guest(baseUrl: 'http://127.0.0.1:8787')),
      ),
      if (speechService != null)
        speechRecognitionServiceProvider.overrideWithValue(speechService),
    ],
  );
  addTearDown(() async {
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    container.dispose();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 1));
  });
  await tester.pumpWidget(
    UncontrolledProviderScope(container: container, child: const JizhangApp()),
  );
  return database;
}

void _expectNavigationCoveredByQuickAdd(WidgetTester tester) {
  final navigation = find.byType(AppBottomNavigation);
  final navigationRenderObject = tester.renderObject(navigation);
  final hit = tester.hitTestOnBinding(tester.getCenter(navigation));
  expect(
    hit.path.any(
      (entry) => _isDescendantOf(entry.target, navigationRenderObject),
    ),
    isFalse,
    reason: '记一笔弹层必须位于全局底部导航之上',
  );
}

bool _isDescendantOf(Object target, RenderObject ancestor) {
  if (target is! RenderObject) return false;
  for (
    RenderObject? current = target;
    current != null;
    current = current.parent
  ) {
    if (identical(current, ancestor)) return true;
  }
  return false;
}

class _FakeSpeechService implements SpeechRecognitionService {
  const _FakeSpeechService();

  @override
  Stream<SpeechRecognitionEvent> get events => const Stream.empty();

  @override
  Future<void> cancel() async {}

  @override
  Future<bool> initialize() async => true;

  @override
  Future<void> start() async {}

  @override
  Future<void> stop() async {}
}
