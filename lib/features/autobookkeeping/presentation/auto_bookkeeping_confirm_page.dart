import '../../../core/widgets/app_form.dart';

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/platform/bookkeeping_feedback.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../auto_bookkeeping_pending.dart';
import '../auto_bookkeeping_learning.dart';
import '../auto_bookkeeping_refund_matcher.dart';
import '../../transactions/data/refund_service.dart';
import '../../transactions/data/transaction_attachment_repository.dart';
import '../../../app/theme/app_theme_tokens.dart';

class AutoBookkeepingConfirmPage extends ConsumerStatefulWidget {
  const AutoBookkeepingConfirmPage({super.key});

  @override
  ConsumerState<AutoBookkeepingConfirmPage> createState() =>
      _AutoBookkeepingConfirmPageState();
}

class _AutoBookkeepingConfirmPageState
    extends ConsumerState<AutoBookkeepingConfirmPage> {
  PendingAutoBookkeepingCandidate? _candidate;
  String? _bookId;
  String? _accountId;
  String? _categoryId;
  String? _message;
  AutoBookkeepingRecommendation? _recommendation;
  TransactionRecord? _matchedRefundOriginal;
  bool _rememberForMerchant = true;
  bool _keepScreenshot = true;
  bool _loading = true;
  bool _saving = false;
  bool _closing = false;

  @override
  void initState() {
    super.initState();
    unawaited(_loadCandidate());
  }

  Future<void> _loadCandidate() async {
    try {
      final candidate = await ref
          .read(autoBookkeepingPendingBridgeProvider)
          .getPending();
      AutoBookkeepingRecommendation? recommendation;
      TransactionRecord? matchedRefundOriginal;
      if (candidate != null) {
        final fallbackBookId = ref.read(activeBookIdProvider);
        recommendation = await ref
            .read(autoBookkeepingLearningServiceProvider)
            .recommend(
              candidate: candidate,
              fallbackBookId: fallbackBookId,
              transactionType: _transactionTypeFor(candidate.transactionType),
            );
        final targetBookId = recommendation.bookId ?? fallbackBookId;
        matchedRefundOriginal = await ref
            .read(autoBookkeepingRefundMatcherProvider)
            .findOriginal(candidate: candidate, bookId: targetBookId);
      }
      if (!mounted) return;
      setState(() {
        _candidate = candidate;
        _recommendation = recommendation;
        _matchedRefundOriginal = matchedRefundOriginal;
        _bookId = recommendation?.bookId;
        _accountId =
            matchedRefundOriginal?.accountId ?? recommendation?.accountId;
        _categoryId = recommendation?.categoryId;
        _loading = false;
      });
      if (candidate != null && candidate.screenshotPath == null) {
        unawaited(_refreshScreenshot(candidate.fingerprint));
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = '无法读取待确认账单：$error';
      });
    }
  }

  Future<void> _refreshScreenshot(String fingerprint) async {
    for (var attempt = 0; attempt < 4; attempt++) {
      await Future<void>.delayed(const Duration(milliseconds: 300));
      if (!mounted || _saving || _closing) return;
      final refreshed = await ref
          .read(autoBookkeepingPendingBridgeProvider)
          .getPending();
      if (!mounted || refreshed == null || refreshed.fingerprint != fingerprint) {
        return;
      }
      if (refreshed.screenshotPath != null) {
        setState(() => _candidate = refreshed);
        return;
      }
    }
  }

  Future<void> _completePending({bool keepScreenshot = false}) async {
    if (_closing) return;
    _closing = true;
    await ref
        .read(autoBookkeepingPendingBridgeProvider)
        .complete(keepScreenshot: keepScreenshot);
  }

  Future<void> _close() async {
    await _completePending();
    if (mounted) context.pop();
  }

  Future<void> _save({
    required String bookId,
    required Account account,
    required Category category,
  }) async {
    final candidate = _candidate;
    if (candidate == null || _saving) return;
    setState(() {
      _saving = true;
      _message = null;
    });
    try {
      final metadata = <String, Object?>{
        'paymentChannel': _paymentChannel(candidate),
        if (candidate.orderId != null) 'orderId': candidate.orderId,
        if (candidate.identifierSuffix != null)
          'cardLastFour': candidate.identifierSuffix,
        'autobookkeeping': {
          'fingerprint': candidate.fingerprint,
          'sourceApp': candidate.sourceApp,
          'scene': candidate.scene,
          'paymentMethod': candidate.paymentMethod,
          'transactionType': candidate.transactionType,
          if (candidate.orderId != null) 'orderId': candidate.orderId,
          if (candidate.identifierSuffix != null)
            'identifierSuffix': candidate.identifierSuffix,
          if (candidate.originalAmountInCents != null)
            'originalAmountInCents': candidate.originalAmountInCents,
          if (candidate.discountAmountInCents != null)
            'discountAmountInCents': candidate.discountAmountInCents,
          'confirmedIn': 'autobookkeeping_confirm_page',
        },
      };
      final screenshotPath =
          _keepScreenshot && candidate.screenshotPath != null
          ? candidate.screenshotPath
          : null;
      final transactionType = _transactionTypeFor(candidate.transactionType);
      final matchedRefund = transactionType == TransactionType.refund &&
              _matchedRefundOriginal?.bookId == bookId
          ? _matchedRefundOriginal
          : null;
      final saved = matchedRefund == null
          ? await ref
                .read(quickBookkeepingServiceProvider)
                .save(
                  QuickBookkeepingRequest(
                    transactionId: 'auto-${candidate.fingerprint}',
                    bookId: bookId,
                    type: transactionType,
                    amount: candidate.amountInCents / 100,
                    accountId: account.id,
                    categoryId: category.id,
                    categoryName: category.name,
                    merchant: candidate.merchant,
                    note: candidate.note,
                    occurredAt: candidate.timestamp,
                    source: TransactionSource.auto,
                    userCorrected: true,
                    metadata: metadata,
                  ),
                )
          : await RefundService(
              ref.read(databaseProvider),
              bookId: bookId,
            ).register(
              original: matchedRefund,
              amount: candidate.amountInCents / 100,
              category: category,
              occurredAt: candidate.timestamp,
              transactionId: 'auto-${candidate.fingerprint}',
              note: candidate.note ?? '自动识别退款：${candidate.merchant}',
              metadataJson: jsonEncode(metadata),
              source: TransactionSource.auto,
            );

      var screenshotWarning = false;
      if (screenshotPath != null) {
        String? promotedPath;
        try {
          promotedPath = await ref
              .read(autoBookkeepingPendingBridgeProvider)
              .promoteScreenshot(screenshotPath);
          if (promotedPath == null) {
            screenshotWarning = true;
          } else {
            await ref
                .read(transactionAttachmentRepositoryProvider)
                .replaceForTransaction(
                  transactionId: saved.id,
                  bookId: saved.bookId,
                  paths: [promotedPath],
                );
          }
        } on Object {
          screenshotWarning = true;
          if (promotedPath != null) {
            try {
              final promotedFile = File(promotedPath);
              if (await promotedFile.exists()) {
                await promotedFile.delete();
              }
            } on Object {
              // Best-effort cleanup only; bookkeeping already succeeded.
            }
          }
        }
      }

      try {
        await ref
            .read(autoBookkeepingLearningServiceProvider)
            .remember(
              transactionId: saved.id,
              candidate: candidate,
              bookId: bookId,
              accountId: saved.accountId,
              categoryId: category.id,
              rememberForMerchant: _rememberForMerchant,
            );
      } on Object {
        // Learning is a secondary local enhancement. A successful transaction
        // must never be rolled back or shown as failed because memory could
        // not be updated.
      }
      await _completePending();
      await BookkeepingFeedback.notifySuccess(count: 1);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            screenshotWarning
                ? '流水已保存，但支付截图未能附加'
                : '已保存到本地账本',
          ),
        ),
      );
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _message = '保存失败：$error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) unawaited(_close());
      },
      child: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : _buildContent(context),
      ),
    );
  }

  Widget _buildContent(BuildContext context) {
    final candidate = _candidate;
    if (candidate == null) {
      return _EmptyState(message: _message ?? '没有待确认的交易记录', onClose: _close);
    }

    final books = ref.watch(booksProvider).value;
    if (books == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (books.isEmpty) {
      return _EmptyState(message: '当前没有可用账本', onClose: _close);
    }
    final activeBookId = ref.watch(activeBookIdProvider);
    final requestedBookId = _bookId ?? activeBookId;
    final selectedBookId = books.any((book) => book.id == requestedBookId)
        ? requestedBookId
        : books.first.id;
    final selectedBook = books
        .where((book) => book.id == selectedBookId)
        .firstOrNull;
    final accounts = ref.watch(accountsByBookProvider(selectedBookId)).value;
    final categories = ref
        .watch(categoriesByBookProvider(selectedBookId))
        .value;
    if (accounts == null || categories == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final transactionType = _transactionTypeFor(candidate.transactionType);
    final categoryType = _categoryTypeFor(transactionType);
    final selectableCategories = categories
        .where((item) => item.type == categoryType)
        .where((item) => item.parentId == null)
        .toList(growable: false);
    final selectedAccountId = _validAccountId(accounts);
    final selectedCategoryId = _validCategoryId(selectableCategories);

    return ListView(
      padding: const EdgeInsets.fromLTRB(18, 12, 18, 28),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: _close,
              tooltip: '忽略这笔账单',
              icon: Icon(Icons.close),
            ),
            const SizedBox(width: 4),
            Text('确认记一笔', style: Theme.of(context).textTheme.headlineSmall),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          color: context.appPrimarySoft,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '已识别${_transactionLabel(transactionType)}',
                style: TextStyle(color: context.appSecondaryText),
              ),
              const SizedBox(height: 8),
              Text(
                '¥${(candidate.amountInCents / 100).toStringAsFixed(2)}',
                style: TextStyle(
                  color: _amountColor(transactionType),
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                candidate.merchant,
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '${_sourceLabel(candidate.sourceApp)} · ${DateFormat('yyyy-MM-dd HH:mm').format(candidate.timestamp)}',
                style: TextStyle(color: context.appSecondaryText),
              ),
              if (candidate.originalAmountInCents != null &&
                  candidate.originalAmountInCents! > candidate.amountInCents) ...[
                const SizedBox(height: 6),
                Text(
                  '原价 ¥${(candidate.originalAmountInCents! / 100).toStringAsFixed(2)}'
                  '${candidate.discountAmountInCents == null ? '' : ' · 优惠 ¥${(candidate.discountAmountInCents! / 100).toStringAsFixed(2)}'}',
                  style: TextStyle(color: context.appSecondaryText),
                ),
              ],
              if (_recommendation?.learnedFromMerchant == true) ...[
                const SizedBox(height: 6),
                Text(
                  '已按该商户历史选择预填',
                  style: TextStyle(color: context.appPrimary),
                ),
              ],
              if (_matchedRefundOriginal != null) ...[
                const SizedBox(height: 6),
                Text(
                  '已按订单号匹配原消费，将同步冲减原消费净支出',
                  style: TextStyle(color: context.appPrimary),
                ),
              ],
              if (candidate.screenshotPath != null) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(candidate.screenshotPath!),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, _, _) => Container(
                      height: 72,
                      alignment: Alignment.center,
                      color: context.appSurfaceSoft,
                      child: Text(
                        '支付截图暂时无法预览',
                        style: TextStyle(color: context.appSecondaryText),
                      ),
                    ),
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('保存这张支付截图'),
                  subtitle: const Text('关闭后，完成记账时会删除临时截图'),
                  value: _keepScreenshot,
                  onChanged: _saving
                      ? null
                      : (value) =>
                            setState(() => _keepScreenshot = value),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Material(
            color: Colors.transparent,
            child: Column(
              children: [
                AppSelect<String>(
                  initialValue: selectedBookId,
                  decoration: const InputDecoration(labelText: '账本'),
                  items: [
                    for (final book in books)
                      DropdownMenuItem(value: book.id, child: Text(book.name)),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _bookId = value;
                          _accountId = null;
                          _categoryId = null;
                          if (_matchedRefundOriginal?.bookId != value) {
                            _matchedRefundOriginal = null;
                          }
                        }),
                ),
                const SizedBox(height: 12),
                AppSelect<String>(
                  initialValue: selectedAccountId,
                  decoration: const InputDecoration(labelText: '支付账户'),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.displayName),
                      ),
                  ],
                  onChanged:
                      _saving ||
                          selectedBook == null ||
                          _matchedRefundOriginal?.bookId == selectedBookId
                      ? null
                      : (value) => setState(() => _accountId = value),
                ),
                if (_matchedRefundOriginal?.bookId == selectedBookId)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '退款将原路返回原消费账户',
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 12),
                AppSelect<String>(
                  initialValue: selectedCategoryId,
                  decoration: InputDecoration(
                    labelText: categoryType == CategoryType.income
                        ? '收入分类'
                        : '支出分类',
                  ),
                  items: [
                    for (final category in selectableCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: _saving || selectedBook == null
                      ? null
                      : (value) => setState(() => _categoryId = value),
                ),
                const SizedBox(height: 6),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('记住这个商户的选择'),
                  subtitle: const Text('下次自动带出账本、账户和分类'),
                  value: _rememberForMerchant,
                  onChanged: _saving
                      ? null
                      : (value) => setState(
                          () => _rememberForMerchant = value,
                        ),
                ),
              ],
            ),
          ),
        ),
        if (_message != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(
              _message!,
              style: const TextStyle(color: AppColors.warning),
            ),
          ),
        const SizedBox(height: 14),
        FilledButton.icon(
          onPressed: _saving || selectedBook == null
              ? null
              : () {
                  final account = accounts
                      .where((item) => item.id == selectedAccountId)
                      .firstOrNull;
                  final category = selectableCategories
                      .where((item) => item.id == selectedCategoryId)
                      .firstOrNull;
                  if (account == null || category == null) {
                    setState(
                      () => _message =
                          '请选择支付账户和${categoryType == CategoryType.income ? '收入' : '支出'}分类',
                    );
                    return;
                  }
                  unawaited(
                    _save(
                      bookId: selectedBookId,
                      account: account,
                      category: category,
                    ),
                  );
                },
          icon: _saving
              ? const SizedBox.square(
                  dimension: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check),
          label: Text(_saving ? '保存中…' : '确认并完成'),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: _saving ? null : _close,
          child: const Text('忽略这笔识别结果'),
        ),
      ],
    );
  }

  String? _validAccountId(List<Account> accounts) {
    if (accounts.any((item) => item.id == _accountId)) return _accountId;

    final suffix = _candidate?.identifierSuffix;
    if (suffix != null && suffix.isNotEmpty) {
      final suffixMatches = accounts
          .where((item) => item.identifierSuffix == suffix)
          .toList(growable: false);
      if (suffixMatches.length == 1) return suffixMatches.single.id;
    }

    final method = _candidate?.paymentMethod ?? '';
    final preferredByMethod = accounts.where((item) {
      if (method.contains('支付宝')) return item.type == AccountType.alipay;
      if (method.contains('微信')) return item.type == AccountType.wechat;
      if (method.contains('银行卡') ||
          method.contains('信用卡') ||
          method.contains('储蓄卡') ||
          method.contains('云闪付')) {
        return item.type == AccountType.debitCard ||
            item.type == AccountType.creditCard;
      }
      return false;
    }).firstOrNull;
    if (preferredByMethod != null) return preferredByMethod.id;

    final preferred = accounts.where((item) {
      final source = _candidate?.sourceApp;
      return switch (source) {
        'WECHAT' => item.type == AccountType.wechat,
        'ALIPAY' => item.type == AccountType.alipay,
        'UNIONPAY' => item.type == AccountType.debitCard ||
            item.type == AccountType.creditCard,
        _ => false,
      };
    }).firstOrNull;
    return (preferred ?? accounts.firstOrNull)?.id;
  }

  String? _validCategoryId(List<Category> categories) {
    if (categories.any((item) => item.id == _categoryId)) return _categoryId;
    return categories.firstOrNull?.id;
  }

  TransactionType _transactionTypeFor(String type) => switch (type) {
    'INCOME' => TransactionType.income,
    'REFUND' => TransactionType.refund,
    'REIMBURSEMENT' => TransactionType.reimbursement,
    _ => TransactionType.expense,
  };

  CategoryType _categoryTypeFor(TransactionType type) => switch (type) {
    TransactionType.income ||
    TransactionType.refund ||
    TransactionType.reimbursement ||
    TransactionType.borrow => CategoryType.income,
    _ => CategoryType.expense,
  };

  String _transactionLabel(TransactionType type) => switch (type) {
    TransactionType.income => '收入',
    TransactionType.refund => '退款',
    TransactionType.reimbursement => '报销回款',
    _ => '支出',
  };

  Color _amountColor(TransactionType type) => switch (type) {
    TransactionType.income ||
    TransactionType.refund ||
    TransactionType.reimbursement ||
    TransactionType.borrow => AppColors.income,
    _ => AppColors.expense,
  };

  String _paymentChannel(PendingAutoBookkeepingCandidate candidate) {
    final method = candidate.paymentMethod;
    if (method.contains('支付宝')) return 'alipay';
    if (method.contains('微信')) return 'wechat';
    if (method.contains('银行卡') ||
        method.contains('信用卡') ||
        method.contains('储蓄卡') ||
        method.contains('云闪付')) {
      return 'bank';
    }
    return switch (candidate.sourceApp) {
      'WECHAT' => 'wechat',
      'ALIPAY' => 'alipay',
      'UNIONPAY' => 'bank',
      'MEITUAN' => 'meituan',
      'JD' => 'jd',
      'PINDUODUO' => 'pinduoduo',
      'DOUYIN' => 'douyin',
      _ => 'payment_app',
    };
  }

  String _sourceLabel(String source) => switch (source) {
    'WECHAT' => '微信支付',
    'ALIPAY' => '支付宝',
    'UNIONPAY' => '云闪付',
    'MEITUAN' => '美团',
    'JD' => '京东',
    'PINDUODUO' => '拼多多',
    'DOUYIN' => '抖音',
    _ => '支付应用',
  };
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message, required this.onClose});

  final String message;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.receipt_long_outlined, size: 44),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: onClose, child: const Text('返回')),
        ],
      ),
    ),
  );
}
