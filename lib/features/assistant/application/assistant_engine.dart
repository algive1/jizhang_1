import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/account.dart';
import '../../../core/models/analysis.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/category.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/transaction_record.dart';
import '../../accounts/data/account_repository.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../books/data/book_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../budgets/data/budget_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../../insights/domain/budget_recommendation_service.dart';
import '../../insights/domain/insight_models.dart';
import '../../insights/data/insight_preferences_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../voice/domain/transaction_parser.dart';
import '../../sharing/data/shared_api.dart';
import '../../sharing/data/session_repository.dart';
import 'assistant_scope.dart';
import 'assistant_query.dart';

enum AssistantIntent {
  record,
  help,
  budget,
  summary,
  export,
  membership,
  unknown,
}

class AssistantReply {
  const AssistantReply(
    this.text, {
    this.transactionId,
    this.route,
    this.draftText,
    this.analysisFacts,
    this.statisticsText,
  });
  final String text;
  final String? transactionId;
  final String? route;
  final String? draftText;
  final Map<String, Object?>? analysisFacts;
  final String? statisticsText;
}

abstract interface class AssistantEngine {
  AssistantIntent parseIntent(String text);
  List<String> getSuggestions();
  Future<AssistantReply> sendMessage(String text, {String? requestId});
}

final assistantEngineProvider = Provider<AssistantEngine>((ref) {
  final bookId = ref.watch(activeBookIdProvider);
  final local = RuleBasedAssistantEngine(ref, bookId);
  final baseUrl = const String.fromEnvironment('SHARED_API_BASE_URL');
  final session = ref.watch(sessionProvider).value;
  if (baseUrl.isNotEmpty && session != null) {
    return RemoteAssistantEngine(local, ref.watch(sharedApiProvider));
  }
  return local;
});

/// Local deterministic rules only. No network provider or model is invoked.
class RuleBasedAssistantEngine implements AssistantEngine {
  RuleBasedAssistantEngine(this.ref, this.bookId);
  final Ref ref;
  final String bookId;
  static const help =
      '你可以发送“午餐12元微信支付”；明确的单笔直接保存，多笔或复杂内容先生成待确认清单。也可以问“最近一个月消费了多少”“分析最近消费并给建议”，或选择图片识别、表格导入。';

  @override
  List<String> getSuggestions() => ['近30天消费多少', '分析最近消费并给建议', '本月预算', '怎么记账'];

  @override
  AssistantIntent parseIntent(String text) {
    final value = text.trim();
    if (value == '怎么记账' || value == '快速记账') return AssistantIntent.help;
    if (value == '本月预算') return AssistantIntent.budget;
    if (value == '本月收支') return AssistantIntent.summary;
    if (assistantQueryFeature(value) == 'export') return AssistantIntent.export;
    if (RegExp(r'会员|权益|套餐').hasMatch(value)) return AssistantIntent.membership;
    if (assistantQueryFeature(value) == 'summary')
      return AssistantIntent.summary;
    if (RegExp(r'预算').hasMatch(value)) return AssistantIntent.budget;
    if (RegExp(r'不要|别记|假如|如果|多少|查询|吗|？|\?|退款|报销|转账|借|还款|明天|下周|美元|美金|港币|日元|欧元')
        .hasMatch(value))
      return AssistantIntent.unknown;
    if (RegExp(r'\d+(?:\.\d{1,2})?\s*(?:元|块)').hasMatch(value))
      return AssistantIntent.record;
    if (RegExp(r'\d').hasMatch(value) &&
        RegExp(r'记一笔|记账|早餐|午饭|午餐|晚餐|吃饭|咖啡|奶茶|地铁|打车|购物|工资|唱歌').hasMatch(value))
      return AssistantIntent.record;
    return AssistantIntent.unknown;
  }

  @override
  Future<AssistantReply> sendMessage(String text, {String? requestId}) async {
    switch (parseIntent(text)) {
      case AssistantIntent.help:
        return const AssistantReply(help);
      case AssistantIntent.export:
        return const AssistantReply(
          '可在数据管理中选择范围并导出真实账单。',
          route: '/profile/data',
        );
      case AssistantIntent.membership:
        return const AssistantReply(
          '查看当前会员状态与权益。',
          route: '/profile/membership',
        );
      case AssistantIntent.summary:
        return _summary(text);
      case AssistantIntent.budget:
        if (RegExp(r'上月|去年|上周|本周|昨天|明天').hasMatch(text))
          return const AssistantReply(
            '目前助手支持查询本月预算，其他预算周期请打开预算页面查看。',
            route: '/profile/budgets',
          );
        final now = DateTime.now();
        final repository = ref.read(budgetRepositoryProvider);
        final categoriesRepository = ref.read(categoryRepositoryProvider);
        final transactions = await ref
            .read(transactionRepositoryProvider)
            .getRange(
              start: DateTime(now.year, now.month),
              endExclusive: DateTime(now.year, now.month + 1),
            );
        final budgets = await repository.getMonth(
          '${now.year}-${now.month.toString().padLeft(2, '0')}',
        );
        final overview = repository.calculateOverview(
          budgets: budgets,
          transactions: transactions,
          categories: await categoriesRepository.getAll(),
          now: now,
        );
        final total = overview.total;
        return AssistantReply(
          total == null
              ? '本月尚未设置总预算${overview.categories.isEmpty ? '。' : '，已设置 ${overview.categories.length} 项分类预算。'}'
              : '本月预算 ¥${total.budget.amount.toStringAsFixed(2)}\n已用 ¥${total.used.toStringAsFixed(2)} · 剩余 ¥${total.remaining.toStringAsFixed(2)}',
          route: '/profile/budgets',
        );
      case AssistantIntent.unknown:
        return const AssistantReply('暂时无法按规则确定这条指令，未创建账单。\n$help');
      case AssistantIntent.record:
        return _record(text);
    }
  }

  Future<AssistantReply> _record(String text) async {
    // Restrict automatic writes to exactly one amount, avoiding decimal/date/card
    // suffix ambiguity in the existing voice parser (which is review-first).
    final numbers = RegExp(r'\d+(?:\.\d+)?').allMatches(text).toList();
    if (numbers.length > 1 &&
        !RegExp(r'还是|或者|负|[-]\s*\d|\d[,，]\d').hasMatch(text))
      return AssistantReply(
        '已收到多笔或复杂记账内容，请检查每笔金额、时间、分类和账户后确认保存。',
        draftText: text,
      );
    if (numbers.length != 1 ||
        !RegExp(r'^\d+(?:\.\d{1,2})?$').hasMatch(numbers.single.group(0)!) ||
        RegExp(r'[-负]\s*\d|\d,\d|\d，\d').hasMatch(text)) {
      return const AssistantReply('检测到多个数字，请每次发送一笔金额；复杂日期或卡号请使用快速记账填写。未创建账单。');
    }
    final normalized = text
        .replaceAll('午餐', '午饭')
        .replaceAll('晚餐', '晚饭')
        .replaceAll('中午', '午饭')
        .replaceAll(RegExp(r'再帮我记一笔[，,]?|帮我记一笔[，,]?'), '');
    final accountRepository = ref.read(accountRepositoryProvider);
    final categoryRepository = ref.read(categoryRepositoryProvider);
    final service = ref.read(quickBookkeepingServiceProvider);
    final result = await const RuleBasedTransactionParser().parse(normalized);
    if (result.transactions.length != 1 ||
        result.unresolvedFragments.isNotEmpty)
      return const AssistantReply('信息还不够明确，未创建账单。\n$help');
    final item = result.transactions.single;
    final accounts = await accountRepository.getActive();
    final categories = await categoryRepository.getActive();
    final accountTypes = <AccountType>{
      if (text.contains('微信')) AccountType.wechat,
      if (text.contains('支付宝')) AccountType.alipay,
      if (text.contains('现金')) AccountType.cash,
      if (text.contains('银行卡') || text.contains('银行')) AccountType.debitCard,
    };
    final matches = accounts
        .where((a) => accountTypes.contains(a.type) && a.currency == 'CNY')
        .toList();
    final categoryMatches = categories
        .where(
          (c) =>
              c.parentId == null &&
              c.type ==
                  (item.type == TransactionType.income
                      ? CategoryType.income
                      : CategoryType.expense) &&
              (c.id == item.categoryId || c.name == item.categoryName),
        )
        .toList();
    if (accountTypes.length != 1 ||
        matches.length != 1 ||
        categoryMatches.length != 1) {
      return AssistantReply('请在确认清单中补全账户和分类；补全并确认前不会创建账单。', draftText: text);
    }
    final request = QuickBookkeepingRequest(
      type: item.type,
      amount: item.amount,
      bookId: bookId,
      accountId: matches.single.id,
      categoryId: categoryMatches.single.id,
      categoryName: categoryMatches.single.name,
      occurredAt: item.occurredAt,
      note: text.contains('地铁')
          ? '地铁出行'
          : text.contains('中午') || text.contains('午餐')
          ? '午餐'
          : item.merchant ?? text,
      metadata: const {'assistantEngine': 'rules_v1'},
    );
    try {
      final record = await service.save(request);
      return AssistantReply('已为你记账成功！ ✅', transactionId: record.id);
    } on BookkeepingCommittedException catch (error) {
      return AssistantReply(
        '账单已保存，后续处理未完成，请查看详情；不要重复记账。',
        transactionId: error.records.single.id,
      );
    }
  }

  Future<AssistantReply> _summary(String text, {AssistantQuery? query}) async {
    final now = DateTime.now();
    query ??= AssistantQuery.parse(text, now);
    if (query == null)
      return const AssistantReply(
        '暂时无法确定查询条件，请说明日期范围和币种，或使用“近30天消费多少”“本月收支”。',
        route: '/analysis',
      );
    final categoryRepository = ref.read(categoryRepositoryProvider);
    final budgetRepository = ref.read(budgetRepositoryProvider);
    final service = ref.read(statisticalAnalysisServiceProvider);
    final db = ref.read(databaseProvider);
    final goalRepository = DriftGoalRepository(db, bookId: bookId);
    final preferences = query.advice
        ? ref.read(insightPreferencesProvider).value ??
              const InsightPreferences()
        : const InsightPreferences();
    final categories = await categoryRepository.getAll();
    final matches = categories.where((c) => text.contains(c.name)).toList()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    final category = query.categoryId == null
        ? matches.firstOrNull
        : categories.where((c) => c.id == query!.categoryId).firstOrNull;
    if (query.categoryId != null && category == null) {
      return const AssistantReply('没有找到这项分类，请使用当前账本的分类名称。');
    }
    final categoryIds = {
      if (category != null) category.id,
      for (final c in categories)
        if (category != null && c.parentId == category.id) c.id,
    };
    final period = query.period ?? AnalysisPeriod.last30Days;
    final standardRange = service.rangeFor(period, now);
    final customRange =
        query.period == null ||
            standardRange.start != query.range.start ||
            standardRange.endExclusive != query.range.endExclusive
        ? query.range
        : null;
    final comparison = service.comparisonRangesFor(
      period: period,
      now: now,
      dateRange: customRange,
    );
    final historyStart = DateTime(now.year, now.month, now.day - 180);
    final repository = DriftTransactionRepository(db, bookId: bookId);
    final rows =
        (await repository
                .watchRanges(
                  ranges: [
                    (
                      start: comparison.range.start,
                      endExclusive: comparison.range.endExclusive,
                    ),
                    (
                      start: comparison.previousRange.start,
                      endExclusive: comparison.previousRange.endExclusive,
                    ),
                    (
                      start: historyStart,
                      endExclusive: DateTime(now.year, now.month, now.day + 1),
                    ),
                  ],
                )
                .first)
            .where(
              (r) =>
                  r.currency.toUpperCase() == query!.currency &&
                  !r.occurredAt.isAfter(now) &&
                  r.deletedAt == null,
            )
            .toList();
    final selected = rows
        .where(
          (r) =>
              category == null ||
              categoryIds.contains(r.categoryId) ||
              categoryIds.contains(r.subcategoryId),
        )
        .toList();
    final threshold = await db.transactionDao
        .watchLargeExpenseThresholdInCents(
          bookId: bookId,
          currency: query.currency,
        )
        .first;
    final snapshot = service.analyze(
      selected,
      period: period,
      now: now,
      currency: query.currency,
      dateRange: customRange,
      largeExpenseThreshold: threshold / 100,
    );
    final previous = selected
        .where(
          (r) =>
              r.isConsumptionExpense &&
              comparison.previousRange.contains(r.occurredAt),
        )
        .toList();
    final previousExpense =
        previous.fold<int>(
          0,
          (sum, r) => sum + (r.netExpenseAmount * 100).round(),
        ) /
        100;
    final top = snapshot.expenseCategories.take(3).toList();
    final symbol = query.currency == 'CNY' ? '¥' : '${query.currency} ';
    final startDate = assistantDate(snapshot.range.start);
    final endDate = assistantDate(
      snapshot.range.endExclusive.subtract(const Duration(days: 1)),
    );
    final statistics = [
      '${category?.name ?? '当前账本'}消费统计 · ${query.currency}',
      '$startDate 至 $endDate',
      '收入 $symbol${snapshot.totalIncome.toStringAsFixed(2)}',
      '支出 $symbol${snapshot.totalExpense.toStringAsFixed(2)} · ${snapshot.expenseCount} 笔',
      '结余 $symbol${snapshot.netCashflow.toStringAsFixed(2)}',
      '日均消费 $symbol${(snapshot.totalExpense / snapshot.range.dayCount).toStringAsFixed(2)}',
      if (top.isNotEmpty)
        '主要分类：${top.map((c) => '${c.name} $symbol${c.amount.toStringAsFixed(2)}').join('、')}',
      '依据当前账本已保存流水统计，消费扣除退款，不含转账、还款和投资买入。',
    ].join('\n');
    final observations = [
      if (snapshot.expenseCount == 0)
        '这段时间没有已记录的消费，暂时无法给出个人消费建议。'
      else if (previous.isEmpty)
        '前一可比周期没有消费记录，比较依据有限，暂不判断增长趋势。'
      else
        '前一可比周期（${assistantDate(comparison.previousRange.start)} 至 ${assistantDate(comparison.previousRange.endExclusive.subtract(const Duration(days: 1)))}）支出 $symbol${previousExpense.toStringAsFixed(2)}。',
      for (final insight in snapshot.insights.take(2)) insight.description,
    ];
    final suggestions = <String>[];
    Map<String, Object?>? budgetFact;
    if (query.advice && snapshot.expenseCount > 0) {
      if (query.currency == 'CNY') {
        final budgets = await budgetRepository.getMonth(
          '${now.year}-${now.month.toString().padLeft(2, '0')}',
        );
        final overview = budgetRepository.calculateOverview(
          budgets: budgets,
          transactions: rows,
          categories: categories,
          now: now,
          goalReservation:
              (await goalRepository.getAll())
                  .where((g) => g.status == GoalStatus.active)
                  .fold<int>(
                    0,
                    (sum, g) => sum + (g.monthlyReservation * 100).round(),
                  ) /
              100,
        );
        final budget = category == null
            ? overview.total
            : overview.categories
                  .where((b) => b.budget.categoryId == category.id)
                  .firstOrNull;
        if (budget != null) {
          budgetFact = {
            'period': '本月',
            'amount': budget.budget.amount,
            'used': budget.used,
          };
          observations.add(
            '本月${category?.name ?? '总'}预算 ¥${budget.budget.amount.toStringAsFixed(2)}，已用 ¥${budget.used.toStringAsFixed(2)}，预算按退款、报销后的个人承担计算。'
            '${budget.goalReservation > 0 ? '储蓄目标预留 ¥${budget.goalReservation.toStringAsFixed(2)}，本月可安排余额 ¥${budget.remaining.toStringAsFixed(2)}。' : ''}',
          );
          suggestions.add(
            budget.remaining <= 0
                ? '本月可安排预算已无余额，可以先检查可调整的消费，并预留必要生活开支。'
                : '安排余下开支时，可参考本月剩余预算 ¥${budget.remaining.toStringAsFixed(2)}。',
          );
        } else {
          final recommendation = category == null
              ? const BudgetRecommendationService().recommendTotal(
                  transactions: rows,
                  preferences: preferences,
                  now: now,
                )
              : const BudgetRecommendationService().recommendCategory(
                  transactions: rows,
                  categories: categories,
                  categoryId: category.id,
                  preferences: preferences,
                  now: now,
                );
          if (recommendation != null)
            suggestions.add('可参考历史消费设置预算：${recommendation.reason}');
        }
      }
      if (snapshot.insights.isNotEmpty)
        suggestions.add('先检查支出增长较多的分类，区分必要开支和可调整消费。');
      if (suggestions.isEmpty && top.isNotEmpty)
        suggestions.add('可以从${top.first.name}分类开始检查明细，为可调整的消费设置预算。');
    }
    final advice = query.advice
        ? '\n\n消费建议\n${[...observations, ...suggestions.take(3)].join('\n')}'
        : '';
    final incomeOnly =
        RegExp(r'收入').hasMatch(text) && !RegExp(r'消费|支出|收支|结余').hasMatch(text);
    return AssistantReply(
      '$statistics$advice',
      route: query.detailsRoute(
        bookId,
        categoryId: category?.id,
        kind: incomeOnly
            ? 'income'
            : RegExp(r'收支|结余').hasMatch(text)
            ? 'cashflow'
            : 'expense',
      ),
      statisticsText: query.advice
          ? '$statistics\n\n消费分析\n${observations.join('\n')}'
          : statistics,
      analysisFacts: query.advice
          ? {
              'startDate': startDate,
              'endDate': endDate,
              'currency': query.currency,
              'totalExpense': snapshot.totalExpense,
              'expenseCount': snapshot.expenseCount,
              'previousExpense': previous.isEmpty ? null : previousExpense,
              'categories': [
                for (final c in top)
                  {'name': c.name, 'amount': c.amount, 'count': c.count},
              ],
              'budget': budgetFact,
              'observations': observations,
              'suggestions': suggestions.take(3).toList(),
            }
          : null,
    );
  }
}

/// Uses the local engine for deterministic bookkeeping and business actions.
/// Unknown natural-language questions can be completed by the server-side
/// provider when the app is configured with a shared API session. The model
/// key never enters Flutter or the device.
class RemoteAssistantEngine implements AssistantEngine {
  const RemoteAssistantEngine(this.local, this.api);
  final RuleBasedAssistantEngine local;
  final SharedApi api;

  @override
  AssistantIntent parseIntent(String text) => local.parseIntent(text);

  @override
  List<String> getSuggestions() => local.getSuggestions();

  @override
  Future<AssistantReply> sendMessage(String text, {String? requestId}) async {
    final intent = parseIntent(text);
    if (intent == AssistantIntent.summary && requestId != null) {
      var query = AssistantQuery.parse(text, DateTime.now());
      if (query == null) {
        try {
          final categories = await local.ref
              .read(categoryRepositoryProvider)
              .getAll();
          final data = await api.request(
            '/assistant/query-plan',
            method: 'POST',
            body: {
              'requestId': requestId,
              'text': text.trim(),
              'referenceDate': assistantDate(DateTime.now()),
              'categories': [
                for (final c in categories) {'id': c.id, 'name': c.name},
              ],
            },
          );
          if (data['allowed'] == false)
            return AssistantReply(data['message'] as String? ?? '暂时无法使用此功能。');
          if (data['plan'] == null)
            return AssistantReply(data['message'] as String? ?? '请补充日期范围和分类。');
          query = AssistantQuery.fromJson(
            (data['plan'] as Map).cast<String, dynamic>(),
            DateTime.now(),
          );
        } on Object {
          return local.sendMessage(text, requestId: requestId);
        }
      }
      final reply = await local._summary(text, query: query);
      if (reply.analysisFacts == null ||
          (reply.analysisFacts!['expenseCount'] as int) == 0)
        return reply;
      try {
        final data = await api.request(
          '/assistant/interpret',
          method: 'POST',
          body: {
            'requestId': requestId,
            'text': text.trim(),
            'facts': reply.analysisFacts,
          },
        );
        final message = data['message'] as String?;
        if (data['allowed'] != false &&
            message != null &&
            message.trim().isNotEmpty) {
          return AssistantReply(
            '${reply.statisticsText}\n\nAI消费解读\n$message',
            route: reply.route,
          );
        }
      } on Object {
        // The real statistics and rule-based advice remain available during outages.
      }
      return reply;
    }
    if (intent != AssistantIntent.unknown || requestId == null) {
      return local.sendMessage(text, requestId: requestId);
    }
    try {
      final data = await api.request(
        '/assistant/chat',
        method: 'POST',
        body: {'requestId': requestId, 'text': text.trim()},
      );
      final message = data['message'] as String?;
      if (message == null || message.trim().isEmpty) {
        return await local.sendMessage(text, requestId: requestId);
      }
      return AssistantReply(message, route: data['route'] as String?);
    } on Object {
      // Authorization has already happened on the server. A model outage
      // must degrade to the same deterministic, non-writing local response.
      return local.sendMessage(text, requestId: requestId);
    }
  }
}
