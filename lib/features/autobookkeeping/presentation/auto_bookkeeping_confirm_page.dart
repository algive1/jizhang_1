import '../../../core/widgets/app_form.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/platform/bookkeeping_feedback.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../auto_bookkeeping_pending.dart';
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
      if (!mounted) return;
      setState(() {
        _candidate = candidate;
        _loading = false;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _message = '无法读取待确认账单：$error';
      });
    }
  }

  Future<void> _completePending() async {
    if (_closing) return;
    _closing = true;
    await ref.read(autoBookkeepingPendingBridgeProvider).complete();
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
      await ref
          .read(quickBookkeepingServiceProvider)
          .save(
            QuickBookkeepingRequest(
              transactionId: 'auto-${candidate.fingerprint}',
              bookId: bookId,
              type: TransactionType.expense,
              amount: candidate.amountInCents / 100,
              accountId: account.id,
              categoryId: category.id,
              categoryName: category.name,
              merchant: candidate.merchant,
              occurredAt: candidate.timestamp,
              source: TransactionSource.auto,
              userCorrected: true,
              metadata: {
                'autobookkeeping': {
                  'fingerprint': candidate.fingerprint,
                  'sourceApp': candidate.sourceApp,
                  'scene': candidate.scene,
                  'paymentMethod': candidate.paymentMethod,
                  'confirmedIn': 'autobookkeeping_confirm_page',
                },
              },
            ),
          );
      await _completePending();
      await BookkeepingFeedback.notifySuccess(count: 1);
      if (!mounted) return;
      final messenger = ScaffoldMessenger.of(context);
      context.pop();
      messenger.showSnackBar(const SnackBar(content: Text('已保存到本地账本')));
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
      return _EmptyState(message: _message ?? '没有待确认的支付记录', onClose: _close);
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
    final expenseCategories = categories
        .where((item) => item.type == CategoryType.expense)
        .where((item) => item.parentId == null)
        .toList(growable: false);
    final selectedAccountId = _validAccountId(accounts);
    final selectedCategoryId = _validCategoryId(expenseCategories);

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
                '已识别支付结果',
                style: TextStyle(color: context.appSecondaryText),
              ),
              const SizedBox(height: 8),
              Text(
                '¥${(candidate.amountInCents / 100).toStringAsFixed(2)}',
                style: const TextStyle(
                  color: AppColors.expense,
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
                  decoration: appFieldDecoration('账本'),
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
                        }),
                ),
                const SizedBox(height: 12),
                AppSelect<String>(
                  initialValue: selectedAccountId,
                  decoration: appFieldDecoration('支付账户'),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(account.displayName),
                      ),
                  ],
                  onChanged: _saving || selectedBook == null
                      ? null
                      : (value) => setState(() => _accountId = value),
                ),
                const SizedBox(height: 12),
                AppSelect<String>(
                  initialValue: selectedCategoryId,
                  decoration: appFieldDecoration('支出分类'),
                  items: [
                    for (final category in expenseCategories)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: _saving || selectedBook == null
                      ? null
                      : (value) => setState(() => _categoryId = value),
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
                  final category = expenseCategories
                      .where((item) => item.id == selectedCategoryId)
                      .firstOrNull;
                  if (account == null || category == null) {
                    setState(() => _message = '请选择支付账户和支出分类');
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
