import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jizhang_app/app/app.dart';
import 'package:jizhang_app/core/database/app_database.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/budgets/domain/safe_to_spend_service.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/intelligence/data/bill_inbox_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
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
      expect(find.textContaining('我的账本'), findsOneWidget);
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

      await tester.tap(find.text('流水').last);
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

      await tester.tap(find.byIcon(Icons.person_outline));
      await tester.pumpAndSettle();
      expect(find.text('Free 方案'), findsOneWidget);
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

  testWidgets('transaction click and long press open the same action menu', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(320, 700));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await _pumpApp(tester);
    await tester.pumpAndSettle();

    await tester.tap(find.text('流水').last);
    await tester.pumpAndSettle();
    final transaction = find.text('瑞幸咖啡').first;

    await tester.tap(transaction);
    await tester.pumpAndSettle();
    expect(find.text('编辑流水'), findsOneWidget);
    expect(find.text('删除流水'), findsOneWidget);
    Navigator.of(tester.element(find.text('编辑流水'))).pop();
    await tester.pumpAndSettle();

    await tester.longPress(transaction);
    await tester.pumpAndSettle();
    expect(find.text('编辑流水'), findsOneWidget);
    expect(find.text('删除流水'), findsOneWidget);
  });

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
    expect(find.text('记一笔'), findsOneWidget);
    expect(find.text('支出'), findsWidgets);
    expect(find.text('收入'), findsWidgets);
    expect(find.text('转账'), findsOneWidget);

    await tester.tap(find.byKey(const ValueKey('quick-amount-input')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const ValueKey('amount-key-3')));
    await tester.tap(find.byKey(const ValueKey('amount-key-6')));
    await tester.pump();
    expect(find.text('¥ 36.00'), findsOneWidget);
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
        await tester.tap(find.byKey(const ValueKey('quick-amount-input')));
        await tester.pumpAndSettle();
        for (var i = 0; i < 7; i++) {
          await tester.tap(find.byKey(const ValueKey('amount-key-9')));
        }
        await tester.pumpAndSettle();
        expect(find.text('¥ 9999999.00'), findsOneWidget);
        expect(tester.takeException(), isNull);
        await tester.tap(find.byKey(const ValueKey('quick-keyboard-done')));
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
    GoRouter.of(tester.element(find.text('Free 方案'))).go('/profile/accounts');
    await tester.pumpAndSettle();
    expect(find.text('查看资产、负债与资金形式'), findsOneWidget);

    GoRouter.of(tester.element(find.text('查看资产、负债与资金形式')))
        .go('/profile/categories');
    await tester.pumpAndSettle();
    expect(find.text('支出分类'), findsOneWidget);
    expect(find.text('收入分类'), findsOneWidget);

    GoRouter.of(tester.element(find.text('支出分类'))).go('/profile/budgets');
    await tester.pumpAndSettle();
    expect(find.text('本月还剩'), findsOneWidget);
    expect(find.text('分类预算'), findsOneWidget);

    GoRouter.of(tester.element(find.text('分类预算'))).go('/profile/membership');
    await tester.pumpAndSettle();
    expect(find.text('功能开放情况'), findsOneWidget);

    GoRouter.of(tester.element(find.text('功能开放情况'))).go('/profile/family');
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
      expect(find.text('Free 方案'), findsOneWidget);

      GoRouter.of(tester.element(find.text('Free 方案'))).go('/profile/budgets');
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
}

Future<AppDatabase> _pumpApp(
  WidgetTester tester, {
  SpeechRecognitionService? speechService,
  bool liveTransactions = false,
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
      goalsProvider.overrideWithValue(AsyncData(goals)),
      currentMonthBudgetsProvider.overrideWithValue(AsyncData(budgets)),
      pendingInboxProvider.overrideWithValue(const AsyncData([])),
      membershipProvider.overrideWithValue(AsyncData(membership)),
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
