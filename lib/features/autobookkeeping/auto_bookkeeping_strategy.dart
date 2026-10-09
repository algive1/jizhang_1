import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/account.dart';
import '../../core/models/category.dart';
import '../settings/data/app_settings_repository.dart';
import '../settings/application/optimistic_setting.dart';
import 'auto_bookkeeping_learning.dart';
import 'auto_bookkeeping_pending.dart';

enum AutoBookkeepingStrategy {
  conservative('保守模式', '仅生成待确认\n不自动入账'),
  smart('智能模式', '高置信度自动入账\n其他需确认'),
  automatic('完全自动', '所有识别结果\n自动入账');

  const AutoBookkeepingStrategy(this.label, this.description);
  final String label;
  final String description;
  static const settingKey = 'autobookkeeping.strategy.v1';
  static AutoBookkeepingStrategy parse(String? value) =>
      values.where((item) => item.name == value).firstOrNull ?? conservative;
}

class AutoBookkeepingStrategyController
    extends AsyncNotifier<AutoBookkeepingStrategy> {
  final _writer = OptimisticSetting<AutoBookkeepingStrategy>();
  @override
  Future<AutoBookkeepingStrategy> build() async =>
      AutoBookkeepingStrategy.parse(
        await ref
            .read(appSettingsRepositoryProvider)
            .get(AutoBookkeepingStrategy.settingKey),
      );

  Future<void> select(AutoBookkeepingStrategy value) async {
    final settings = ref.read(appSettingsRepositoryProvider);
    await _writer.select(
      value,
      previous: state.value ?? AutoBookkeepingStrategy.conservative,
      publish: (value) {
        if (ref.mounted) state = AsyncData(value);
      },
      save: (value) =>
          settings.set(AutoBookkeepingStrategy.settingKey, value.name),
    );
  }
}

final autoBookkeepingStrategyProvider =
    AsyncNotifierProvider<
      AutoBookkeepingStrategyController,
      AutoBookkeepingStrategy
    >(AutoBookkeepingStrategyController.new);

class AutoBookkeepingDecision {
  const AutoBookkeepingDecision(
    this.reason, {
    this.account,
    this.category,
    this.confidence = 0,
    this.autoRecord = false,
  });
  final String reason;
  final Account? account;
  final Category? category;
  final double confidence;
  final bool autoRecord;
}

/// Resolve a real account; never turn the review UI's first-account fallback
/// into an automatic debit. Ambiguous card suffixes always require review.
Account? resolveAutoBookkeepingAccount(
  PendingAutoBookkeepingCandidate candidate,
  List<Account> accounts, {
  String? preferredId,
}) {
  final active = accounts.where((item) => !item.isArchived).toList();
  final suffix = candidate.identifierSuffix;
  if (suffix != null && suffix.isNotEmpty) {
    final matches = active.where((item) => item.identifierSuffix == suffix);
    return matches.length == 1 ? matches.single : null;
  }
  final preferred = active.where((item) => item.id == preferredId).firstOrNull;
  if (preferred != null) return preferred;
  final method = candidate.paymentMethod.toUpperCase();
  final types = switch (method) {
    final m when RegExp('银行卡|信用卡|储蓄卡|银联|云闪付|BANK|CARD|UNIONPAY').hasMatch(m) =>
      const {AccountType.debitCard, AccountType.creditCard},
    final m when m.contains('微信') || m.contains('WECHAT') => const {
      AccountType.wechat,
    },
    final m when m.contains('支付宝') || m.contains('ALIPAY') => const {
      AccountType.alipay,
    },
    final m when m.contains('现金') || m == 'CASH' => const {AccountType.cash},
    _ => const <AccountType>{},
  };
  final matches = active.where((item) => types.contains(item.type));
  return matches.length == 1 ? matches.single : null;
}

AutoBookkeepingDecision decideAutoBookkeeping({
  required AutoBookkeepingStrategy strategy,
  required PendingAutoBookkeepingCandidate candidate,
  required AutoBookkeepingRecommendation recommendation,
  required List<Account> accounts,
  required List<Category> categories,
  required bool runtimeHealthy,
  required bool bookAvailable,
  bool refundMatched = false,
  bool transferResolved = false,
  String? matchedAccountId,
  String? matchedCategoryId,
}) {
  if (strategy == AutoBookkeepingStrategy.conservative) {
    return const AutoBookkeepingDecision('保守模式，等待确认');
  }
  if (!runtimeHealthy) return const AutoBookkeepingDecision('权限或服务异常');
  if (!bookAvailable) return const AutoBookkeepingDecision('目标账本不可用');
  if (candidate.amountInCents <= 0 ||
      candidate.merchant.trim().isEmpty ||
      candidate.amountInCents > 99999999999 ||
      !{
        'EXPENSE',
        'INCOME',
        'REFUND',
        'REIMBURSEMENT',
        'TRANSFER',
      }.contains(candidate.transactionType)) {
    return const AutoBookkeepingDecision('金额或交易类型不完整');
  }
  if (candidate.transactionType == 'REFUND' && !refundMatched) {
    return const AutoBookkeepingDecision('退款原账单不明确');
  }
  if (candidate.transactionType == 'TRANSFER' && !transferResolved) {
    return const AutoBookkeepingDecision('转入账户不明确');
  }
  final account = resolveAutoBookkeepingAccount(
    candidate,
    accounts,
    preferredId: matchedAccountId ?? recommendation.accountId,
  );
  if (account == null) return const AutoBookkeepingDecision('支付账户不明确');
  final category = categories
      .where(
        (item) =>
            !item.isArchived &&
            item.id == (matchedCategoryId ?? recommendation.categoryId),
      )
      .firstOrNull;
  if (category == null && candidate.transactionType != 'TRANSFER') {
    return const AutoBookkeepingDecision('分类不明确');
  }
  if (category != null &&
      !refundMatched &&
      candidate.transactionType != 'TRANSFER' &&
      category.type !=
          (candidate.transactionType == 'EXPENSE'
              ? CategoryType.expense
              : CategoryType.income)) {
    return const AutoBookkeepingDecision('分类类型不匹配');
  }
  final accountConfidence =
      recommendation.accountId == account.id ||
          candidate.identifierSuffix != null ||
          matchedAccountId != null
      ? 1.0
      : .95;
  final categoryConfidence = refundMatched || transferResolved
      ? 1.0
      : recommendation.categoryConfidence;
  final confidence =
      candidate.amountConfidence * .30 +
      candidate.merchantConfidence * .20 +
      accountConfidence * .15 +
      categoryConfidence * .15 +
      candidate.sceneConfidence * .20;
  final allowed =
      strategy == AutoBookkeepingStrategy.automatic || confidence >= .90;
  return AutoBookkeepingDecision(
    allowed ? '自动入账' : '置信度不足90%，等待确认',
    account: account,
    category: category,
    confidence: confidence,
    autoRecord: allowed,
  );
}
