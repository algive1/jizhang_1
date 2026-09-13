import '../../analysis/domain/statistical_analysis_service.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../budgets/data/budget_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../voice/domain/transaction_parser.dart';
import '../../sharing/data/shared_api.dart';
import '../../sharing/data/session_repository.dart';

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
  const AssistantReply(this.text, {this.transactionId, this.route});
  final String text;
  final String? transactionId;
  final String? route;
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
      '你可以直接发送“今天中午吃饭微信支付12元”或“地铁6元支付宝”。目前使用本地规则，每次支持一笔明确的收支；请写明金额、用途和支付账户。';

  @override
  List<String> getSuggestions() => ['怎么记账', '本月预算', '导出数据', '会员权益'];

  @override
  AssistantIntent parseIntent(String text) {
    final value = text.trim();
    if (value == '怎么记账' || value == '快速记账') return AssistantIntent.help;
    if (value == '本月预算') return AssistantIntent.budget;
    if (value == '本月收支') return AssistantIntent.summary;
    if (value == '导出数据') return AssistantIntent.export;
    if (value == '会员权益') return AssistantIntent.membership;
    if (RegExp(r'不要|别记|假如|如果|多少|查询|吗|？|\?|退款|报销|转账|借|还款|明天|下周|美元|美金|港币|日元|欧元')
        .hasMatch(value))
      return AssistantIntent.unknown;
    if (RegExp(r'\d+(?:\.\d{1,2})?\s*(?:元|块)').hasMatch(value))
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
      case AssistantIntent.budget:
      case AssistantIntent.summary:
        final now = DateTime.now();
        final repository = ref.read(budgetRepositoryProvider);
        final categoriesRepository = ref.read(categoryRepositoryProvider);
        final transactions = await ref
            .read(transactionRepositoryProvider)
            .getAll();
        if (parseIntent(text) == AssistantIntent.budget) {
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
        }
        final summary = const StatisticalAnalysisService().analyze(
          transactions,
          now: now,
        );
        return AssistantReply(
          '本月人民币收支\n收入 ¥${summary.totalIncome.toStringAsFixed(2)}\n支出 ¥${summary.totalExpense.toStringAsFixed(2)}\n结余 ¥${summary.netCashflow.toStringAsFixed(2)}',
          route: '/analysis',
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
      return const AssistantReply('当前账本中无法唯一确定账户或分类，未创建账单。请通过快速记账选择具体账户和分类。');
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
