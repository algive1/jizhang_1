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
import '../../../core/platform/bookkeeping_feedback.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../bookkeeping/presentation/components/bookkeeping_card_style.dart';
import '../auto_bookkeeping_pending.dart';

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

    return Stack(
      key: const ValueKey('auto-confirm-stage'),
      fit: StackFit.expand,
      children: [
        const ColoredBox(color: Color(0x1A000000)),
        Align(
          alignment: Alignment.bottomCenter,
          child: FractionallySizedBox(
            key: const ValueKey('auto-confirm-sheet'),
            heightFactor: BookkeepingCardStyle.autoConfirmHeightFactor,
            widthFactor: 1,
            child: Material(
              color: AppColors.background,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.vertical(
                  top: Radius.circular(BookkeepingCardStyle.sheetRadius),
                ),
              ),
              child: SafeArea(
                top: false,
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 14),
                  children: [
                    Row(
                      children: [
                        IconButton(
                          onPressed: _saving ? null : _close,
                          tooltip: '忽略这笔账单',
                          constraints: const BoxConstraints.tightFor(
                            width: 44,
                            height: 44,
                          ),
                          padding: EdgeInsets.zero,
                          icon: const Icon(Icons.close_rounded),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '确认记一笔',
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                        ),
                        const Text(
                          '自动识别',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Container(
                      key: const ValueKey('auto-confirm-entry-card'),
                      padding: BookkeepingCardStyle.outerPadding,
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(
                          BookkeepingCardStyle.outerRadius,
                        ),
                        border: Border.all(color: AppColors.divider),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Row(
                            children: [
                              const Icon(
                                Icons.receipt_long_outlined,
                                size: 18,
                                color: AppColors.textSecondary,
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  candidate.merchant,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                              Text(
                                _sourceLabel(candidate.sourceApp),
                                style: const TextStyle(
                                  color: AppColors.textSecondary,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(
                            height: BookkeepingCardStyle.sectionGap,
                          ),
                          Container(
                            key: const ValueKey('auto-confirm-amount'),
                            height: BookkeepingCardStyle.amountHeight,
                            padding: const EdgeInsets.symmetric(
                              horizontal:
                                  BookkeepingCardStyle.amountHorizontalPadding,
                            ),
                            decoration: BoxDecoration(
                              color: BookkeepingCardStyle.amountBackground,
                              borderRadius: BorderRadius.circular(
                                BookkeepingCardStyle.amountRadius,
                              ),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '¥${(candidate.amountInCents / 100).toStringAsFixed(2)}',
                                    maxLines: 1,
                                    overflow: TextOverflow.fade,
                                    softWrap: false,
                                    style: const TextStyle(
                                      color: AppColors.textPrimary,
                                      fontSize: 30,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 10),
                                Text(
                                  DateFormat('HH:mm').format(
                                    candidate.timestamp,
                                  ),
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(
                            height: BookkeepingCardStyle.sectionGap,
                          ),
                          AppSelect<String>(
                            initialValue: selectedBookId,
                            decoration: const InputDecoration(
                              labelText: '账本',
                              isDense: true,
                            ),
                            items: [
                              for (final book in books)
                                DropdownMenuItem(
                                  value: book.id,
                                  child: Text(book.name),
                                ),
                            ],
                            onChanged: _saving
                                ? null
                                : (value) => setState(() {
                                    _bookId = value;
                                    _accountId = null;
                                    _categoryId = null;
                                  }),
                          ),
                          const SizedBox(
                            height: BookkeepingCardStyle.rowGap,
                          ),
                          Row(
                            children: [
                              Expanded(
                                child: AppSelect<String>(
                                  initialValue: selectedAccountId,
                                  decoration: const InputDecoration(
                                    labelText: '支付账户',
                                    isDense: true,
                                  ),
                                  items: [
                                    for (final account in accounts)
                                      DropdownMenuItem(
                                        value: account.id,
                                        child: Text(account.displayName),
                                      ),
                                  ],
                                  onChanged:
                                      _saving || selectedBook == null
                                      ? null
                                      : (value) => setState(
                                          () => _accountId = value,
                                        ),
                                ),
                              ),
                              const SizedBox(
                                width: BookkeepingCardStyle.rowGap,
                              ),
                              Expanded(
                                child: AppSelect<String>(
                                  initialValue: selectedCategoryId,
                                  decoration: const InputDecoration(
                                    labelText: '支出分类',
                                    isDense: true,
                                  ),
                                  items: [
                                    for (final category
                                        in expenseCategories)
                                      DropdownMenuItem(
                                        value: category.id,
                                        child: Text(category.name),
                                      ),
                                  ],
                                  onChanged:
                                      _saving || selectedBook == null
                                      ? null
                                      : (value) => setState(
                                          () => _categoryId = value,
                                        ),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    if (_message != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          _message!,
                          style: const TextStyle(
                            color: AppColors.warning,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    const SizedBox(height: 10),
                    SizedBox(
                      height: 46,
                      child: FilledButton.icon(
                        onPressed: _saving || selectedBook == null
                            ? null
                            : () {
                                final account = accounts
                                    .where(
                                      (item) =>
                                          item.id == selectedAccountId,
                                    )
                                    .firstOrNull;
                                final category = expenseCategories
                                    .where(
                                      (item) =>
                                          item.id == selectedCategoryId,
                                    )
                                    .firstOrNull;
                                if (account == null || category == null) {
                                  setState(
                                    () => _message = '请选择支付账户和支出分类',
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
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              )
                            : const Icon(Icons.check_rounded),
                        label: Text(_saving ? '保存中…' : '确认并完成'),
                      ),
                    ),
                    SizedBox(
                      height: 38,
                      child: TextButton(
                        onPressed: _saving ? null : _close,
                        child: const Text('忽略这笔识别结果'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ],
    );

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
