import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/router/app_router.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/core/database/database_provider.dart';
import 'package:jizhang_app/core/database/database_seeder.dart';
import 'package:jizhang_app/core/models/transaction_record.dart';
import 'package:jizhang_app/core/models/account.dart';
import 'package:jizhang_app/core/models/family.dart';
import 'package:jizhang_app/core/models/goal.dart';
import 'package:jizhang_app/features/goals/data/goal_repository.dart';
import 'package:jizhang_app/features/accounts/data/account_repository.dart';
import 'package:jizhang_app/features/membership/data/membership_repository.dart';
import 'package:jizhang_app/features/assistant/application/assistant_engine.dart';
import 'package:jizhang_app/features/assistant/application/assistant_query.dart';
import 'package:jizhang_app/features/books/data/book_repository.dart';
import 'package:jizhang_app/features/budgets/data/budget_repository.dart';
import 'package:jizhang_app/features/categories/data/category_repository.dart';
import 'package:jizhang_app/features/sharing/data/shared_api.dart';
import 'package:jizhang_app/features/sharing/data/session_repository.dart';
import 'package:jizhang_app/features/insights/data/insight_preferences_repository.dart';
import 'package:jizhang_app/features/insights/domain/insight_models.dart';
import 'package:jizhang_app/features/transactions/data/transactions_repository.dart';
import 'package:jizhang_app/features/transactions/presentation/transaction_search_page.dart';

void main() {
  test('近30天与自然月区分，明确范围无法识别时不猜测', () {
    final now = DateTime(2026, 10, 7, 12);
    final recent = AssistantQuery.parse('最近一个月消费了多少', now)!;
    expect(recent.range.start, DateTime(2026, 9, 8));
    expect(recent.range.endExclusive, DateTime(2026, 10, 8));
    expect(
      AssistantQuery.parse('这个月消费多少', now)!.range.start,
      DateTime(2026, 10),
    );
    expect(
      AssistantQuery.parse('上个月餐饮多少', now)!.range.endExclusive,
      DateTime(2026, 10),
    );
    expect(AssistantQuery.parse('最近7天消费', now)!.range.dayCount, 7);
    expect(AssistantQuery.parse('过去一周消费多少', now)!.range.dayCount, 7);
    for (final text in [
      '最近0天消费',
      '最近400天消费',
      '最近2个月消费多少',
      '去年消费多少',
      '9月消费多少',
      '本月美元和人民币消费多少',
      '本月英镑消费多少',
    ]) {
      expect(AssistantQuery.parse(text, now), isNull, reason: text);
    }
    expect(
      () => AssistantQuery.fromJson({
        'startDate': '2026-02-30',
        'endDate': '2026-10-07',
        'currency': 'CNY',
        'categoryId': null,
        'advice': false,
      }, now),
      throwsFormatException,
    );
  });

  late ProviderContainer container;
  late RuleBasedAssistantEngine local;
  late TransactionRepository repository;
  late String foodCategory;
  late String otherBook;
  final now = DateTime.now();
  Future<void> add(
    String id,
    double amount, {
    DateTime? date,
    String currency = 'CNY',
    TransactionType type = TransactionType.expense,
    double? refund,
    String? note,
  }) async {
    await repository.create(
      TransactionRecord(
        id: id,
        bookId: SeedIds.personalBook,
        type: type,
        amount: amount,
        accountId: currency == 'CNY' ? SeedIds.bankAccount : 'test-usd-account',
        occurredAt: date ?? now,
        createdAt: now,
        updatedAt: now,
        currency: currency,
        categoryId: foodCategory,
        refundAmount: refund,
        refundStatus: refund == null ? RefundStatus.none : RefundStatus.partial,
        note: note ?? id,
      ),
    );
  }

  setUp(() async {
    final db = createMemoryDatabase();
    addTearDown(db.close);
    await DatabaseSeeder(db).seedIfNeeded();
    final books = DriftBookRepository(db, LocalOnlyMembershipRepository());
    otherBook = (await books.create(name: '另一账本', type: BookType.family)).id;
    final visibleBooks = await books.getForUser(SeedIds.localUser);
    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWithValue(db),
        sessionProvider.overrideWithValue(const AsyncData(null)),
        booksProvider.overrideWithValue(AsyncData(visibleBooks)),
        insightPreferencesProvider.overrideWithValue(
          const AsyncData(InsightPreferences()),
        ),
      ],
    );
    addTearDown(container.dispose);
    await container.read(databaseBootstrapProvider.future);
    await container
        .read(accountRepositoryProvider)
        .create(
          Account(
            id: 'test-usd-account',
            name: '美元现金',
            type: AccountType.cash,
            balance: 1000,
            currency: 'USD',
            icon: 'payments',
            color: 0xFF123456,
            sortOrder: 100,
            isArchived: false,
            createdAt: now,
            updatedAt: now,
          ),
        );
    local = container.read(assistantEngineProvider) as RuleBasedAssistantEngine;
    foodCategory = (await container.read(categoryRepositoryProvider).getAll())
        .firstWhere((c) => c.name == '餐饮')
        .id;
    repository = container.read(transactionRepositoryProvider);
  });

  test('真实消费排除未来、其他币种和投资，扣退款且查询不写账', () async {
    await add('lunch', 100, refund: 20);
    await add('coffee', .10);
    await add('old', 900, date: now.subtract(const Duration(days: 31)));
    await add('future', 700, date: now.add(const Duration(days: 1)));
    await add('dollars', 600, currency: 'USD');
    await add('investment', 500, type: TransactionType.assetPurchase);
    final count = (await repository.getAll()).length;
    final reply = await local.sendMessage('给我看一下我最近一个月消费了多少');
    expect(reply.text, contains('支出 ¥80.10 · 2 笔'));
    final params = Uri.parse(reply.route!).queryParameters;
    expect(params['bookId'], SeedIds.personalBook);
    expect(params['kind'], 'expense');
    expect((await repository.getAll()).length, count);
    expect(
      await local.sendMessage('本月餐饮消费多少').then((r) => r.text),
      contains('支出 ¥80.10'),
    );
  });

  test('分析消费返回记录依据和可执行建议，无数据不编造建议', () async {
    final empty = await local.sendMessage('帮我看看最近的消费情况给出合理建议');
    expect(empty.text, contains('没有已记录的消费'));
    await add('lunch', 100);
    final reply = await local.sendMessage('帮我看看最近的消费情况给出合理建议');
    expect(reply.text, contains('比较依据有限'));
    expect(reply.text, contains('分类开始检查明细'));
    expect(reply.analysisFacts!['totalExpense'], 100);
  });

  test('预算按个人承担计算，消费汇总与分析页使用同一统计口径', () async {
    await add('reimbursable', 100, refund: 20);
    final original = (await repository.getById('reimbursable'))!;
    await repository.update(
      original.copyWith(
        reimbursementStatus: ReimbursementStatus.partial,
        reimbursementAmount: 40,
      ),
    );
    await container
        .read(budgetRepositoryProvider)
        .setBudget(
          monthKey: '${now.year}-${now.month.toString().padLeft(2, '0')}',
          amount: 1000,
        );
    await container
        .read(goalRepositoryProvider)
        .create(
          goal: Goal(
            id: 'reserved-goal',
            name: '储蓄目标',
            icon: 'savings',
            targetAmount: 1000,
            currentAmount: 0,
            targetDate: now.add(const Duration(days: 100)),
            status: GoalStatus.active,
            createdAt: now,
            milestones: const [],
            monthlyReservation: 200,
          ),
          milestoneAmounts: const [1000],
          initialAmount: 0,
        );
    final reply = await local.sendMessage('分析本月消费并给建议');
    expect(reply.text, contains('支出 ¥80.00'));
    expect(reply.text, contains('已用 ¥40.00'));
    expect(reply.text, contains('本月可安排余额 ¥760.00'));
    expect((reply.analysisFacts!['budget'] as Map)['used'], 40);
    expect(
      reply.statisticsText,
      contains('已用 ¥40.00'),
      reason: 'AI解读也保留程序计算的预算事实',
    );
  });

  test('API接收统计摘要，失败回退，复杂日期解析后在本地查询', () async {
    await add('lunch', 100);
    final api = _AssistantApi(now, foodCategory);
    final calls = api.calls;
    addTearDown(api.close);
    final remote = RemoteAssistantEngine(local, api);
    const requestId = 'assistant-spending-request-0001';
    var reply = await remote.sendMessage('分析最近消费并给建议', requestId: requestId);
    expect(reply.text, contains('AI消费解读'));
    expect(calls.single['facts']['totalExpense'], 100);
    expect(calls.single.containsKey('transactions'), false);
    await remote.sendMessage(
      '最近一个月消费多少',
      requestId: 'assistant-spending-request-0002',
    );
    expect(calls.length, 1, reason: '金额查询不调用模型');
    api.outage = true;
    reply = await remote.sendMessage(
      '分析最近消费并给建议',
      requestId: 'assistant-spending-request-0003',
    );
    expect(reply.text, contains('支出 ¥100.00'));
    expect(reply.text, contains('消费建议'));
    api.outage = false;
    final todayText = '${now.month}月${now.day}日餐饮消费多少';
    reply = await remote.sendMessage(
      todayText,
      requestId: 'assistant-spending-request-0004',
    );
    expect(calls.last['path'], endsWith('query-plan'));
    expect(reply.text, contains('支出 ¥100.00'));
  });

  testWidgets('查看明细保留日期、币种、消费类型与查询账本', (tester) async {
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox());
      await tester.pumpAndSettle();
    });
    await tester.binding.setSurfaceSize(const Size(393, 1000));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await add('visible', 100, note: '本次查询消费');
    await add(
      'old',
      900,
      date: now.subtract(const Duration(days: 31)),
      note: '范围外消费',
    );
    await add('foreign', 600, currency: 'USD', note: '其他币种消费');
    await add('asset', 500, type: TransactionType.assetPurchase, note: '投资买入');
    final reply = await local.sendMessage('最近一个月餐饮消费多少');
    await container.read(activeBookIdProvider.notifier).select(otherBook);
    final router = container.read(appRouterProvider);
    router.go(reply.route!);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 50));
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 50)),
    );
    await tester.pumpAndSettle();
    expect(find.byType(TransactionSearchPage), findsOneWidget);
    final page = tester.widget<TransactionSearchPage>(
      find.byType(TransactionSearchPage),
    );
    expect(page.bookId, SeedIds.personalBook);
    expect(page.range, isNotNull);
    expect(
      find.text('查询明细 · 1 笔'),
      findsOneWidget,
      reason: tester
          .widgetList<Text>(find.byType(Text))
          .map((t) => t.data)
          .join(' | '),
    );
    expect(find.text('本次查询消费'), findsOneWidget);
    expect(find.text('范围外消费'), findsNothing);
    expect(find.text('其他币种消费'), findsNothing);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}

class _AssistantApi extends SharedApi {
  _AssistantApi(this.now, this.categoryId)
    : super(baseUrl: 'http://127.0.0.1:8787');
  final DateTime now;
  final String categoryId;
  final calls = <Map<String, dynamic>>[];
  bool outage = false;
  @override
  Future<Map<String, dynamic>> request(
    String path, {
    String method = 'GET',
    String? bearerToken,
    Object? body,
  }) async {
    calls.add({
      ...jsonDecode(jsonEncode(body)) as Map<String, dynamic>,
      'path': path,
    });
    if (outage) throw const SharedApiException(503, 'test outage');
    return path.endsWith('query-plan')
        ? {
            'allowed': true,
            'plan': {
              'startDate': assistantDate(now),
              'endDate': assistantDate(now),
              'currency': 'CNY',
              'categoryId': categoryId,
              'advice': false,
            },
          }
        : {'allowed': true, 'message': '餐饮是目前已记录的主要消费。可以先检查明细，再决定预算。'};
  }
}
