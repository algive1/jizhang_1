import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart' show FileType;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/models/book.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/book_color_dot.dart';
import '../../../core/widgets/category_icon.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../books/presentation/book_selector.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transaction_attachment_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../voice/presentation/voice_bookkeeping_sheet.dart';
import '../application/amount_input.dart';
import '../application/attachment_storage_service.dart';
import '../application/quick_bookkeeping_service.dart';

/// The four top-level entry groups in the quick-add header.
///
/// `debt` is a UI group rather than a [TransactionType]; it fans out to the
/// existing borrowing/lending/repayment types through [_keypadType].
enum _EntryTab { expense, income, transfer, debt }

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({
    super.key,
    this.initialTransaction,
    this.initialType = TransactionType.expense,
  });

  final TransactionType initialType;

  final TransactionRecord? initialTransaction;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagsController = TextEditingController();
  final _reimbursementNoteController = TextEditingController();

  AmountInput _amount = const AmountInput();
  TransactionType _type = TransactionType.expense;

  /// Last debt group chosen inside the 债务 tab. Kept so switching away and
  /// back does not silently change 借入/借出/还款.
  TransactionType _debtType = TransactionType.borrow;
  String? _bookId;
  String? _categoryId;
  String? _subcategoryId;
  String? _accountId;
  String? _destinationAccountId;
  DateTime _occurredAt = DateTime.now();
  bool _isPlanned = false;
  bool _isOneTime = true;
  bool _isRecurring = false;
  bool _isSaving = false;
  bool _amountError = false;
  ReimbursementStatus _reimbursementStatus = ReimbursementStatus.none;
  bool _attachmentsChanged = false;
  bool _attachmentsBusy = false;
  Future<void>? _attachmentsLoad;
  final List<StoredAttachment> _attachments = [];

  bool get _isEditing => widget.initialTransaction != null;

  @override
  void initState() {
    super.initState();
    final transaction = widget.initialTransaction;
    _type = widget.initialType;
    if (_type == TransactionType.borrow ||
        _type == TransactionType.lend ||
        _type == TransactionType.repayment) {
      _debtType = _type;
    }
    _bookId = transaction?.bookId ?? ref.read(activeBookIdProvider);
    if (transaction == null) {
      Future<void>(() async {
        final lastAccount = await ref
            .read(quickBookkeepingServiceProvider)
            .getLastAccountId();
        if (mounted && lastAccount != null) {
          setState(() => _accountId = lastAccount);
        }
      });
      return;
    }
    _amount = AmountInput(transaction.amount.toStringAsFixed(2));
    _type = transaction.type;
    if (_type == TransactionType.borrow ||
        _type == TransactionType.lend ||
        _type == TransactionType.repayment) {
      _debtType = _type;
    }
    _categoryId = transaction.categoryId;
    _subcategoryId = transaction.subcategoryId;
    _accountId = transaction.accountId;
    _destinationAccountId = transaction.destinationAccountId;
    _occurredAt = transaction.occurredAt;
    _isPlanned = transaction.isPlanned;
    _isOneTime = transaction.isOneTime;
    _isRecurring = transaction.isRecurring;
    _merchantController.text = transaction.merchant ?? '';
    _noteController.text = transaction.note ?? '';
    _reimbursementStatus = transaction.reimbursementStatus;
    _reimbursementNoteController.text = transaction.reimbursementNote ?? '';
    final metadata = _decodeMetadata(transaction.metadataJson);
    final tags = metadata['tags'];
    if (tags is List) {
      _tagsController.text = tags.map((item) => item.toString()).join(', ');
    }
    _attachmentsLoad = _loadExistingAttachments(transaction);
    unawaited(_attachmentsLoad!);
  }

  Future<void> _loadExistingAttachments(TransactionRecord transaction) async {
    List<StoredAttachment>? restored;
    try {
      final persisted = await ref
          .read(transactionAttachmentRepositoryProvider)
          .getForTransaction(transaction.id, bookId: transaction.bookId);
      if (persisted.isNotEmpty) {
        restored = [
          for (final attachment in persisted)
            StoredAttachment(name: attachment.name, path: attachment.path),
        ];
      }
    } on Object {
      // Fall back to the legacy metadata shape for databases not yet upgraded.
    }
    restored ??= _legacyAttachments(transaction.metadataJson);
    if (!mounted || _attachmentsChanged) return;
    setState(() {
      _attachments
        ..clear()
        ..addAll(restored!.take(4));
    });
  }

  List<StoredAttachment> _legacyAttachments(String? metadataJson) {
    final raw = _decodeMetadata(metadataJson)['attachments'];
    if (raw is! List) return const [];
    return [
      for (final path in raw.whereType<String>())
        if (path.trim().isNotEmpty)
          StoredAttachment(name: p.basename(path), path: path.trim()),
    ];
  }

  @override
  void dispose() {
    _merchantController.dispose();
    _noteController.dispose();
    _tagsController.dispose();
    _reimbursementNoteController.dispose();
    super.dispose();
  }

  /// The header tab the current type belongs to, or null for the legacy types
  /// that have no tab (退款 / 报销回款 / 资产购买 / 余额校准). Those keep their
  /// persisted type untouched so editing an old record cannot rewrite it.
  _EntryTab? get _tab => switch (_type) {
    TransactionType.expense => _EntryTab.expense,
    TransactionType.income => _EntryTab.income,
    TransactionType.transfer => _EntryTab.transfer,
    TransactionType.borrow ||
    TransactionType.lend ||
    TransactionType.repayment => _EntryTab.debt,
    _ => null,
  };

  /// 转账 and 还款 move money between two accounts and carry no category.
  bool get _usesAccountPair =>
      _type == TransactionType.transfer || _type == TransactionType.repayment;

  bool get _supportsReimbursement =>
      _type == TransactionType.expense ||
      _type == TransactionType.lend ||
      _type == TransactionType.assetPurchase;

  @override
  Widget build(BuildContext context) {
    final activeBookId = ref.watch(activeBookIdProvider);
    final selectedBookId = _bookId ?? activeBookId;
    final books = ref.watch(booksProvider).value ?? const <LedgerBook>[];
    final selectedBook = books
        .where((book) => book.id == selectedBookId)
        .firstOrNull;
    var accounts = selectedBookId == activeBookId
        ? ref.watch(accountsProvider).value ?? const <Account>[]
        : ref.watch(accountsByBookProvider(selectedBookId)).value ??
              const <Account>[];
    var categories = selectedBookId == activeBookId
        ? ref.watch(categoriesProvider).value ?? const <Category>[]
        : ref.watch(categoriesByBookProvider(selectedBookId)).value ??
              const <Category>[];
    final initial = widget.initialTransaction;
    if (initial != null) {
      if (!accounts.any((item) => item.id == initial.accountId)) {
        accounts = [...accounts, _archivedAccount(initial, initial.accountId)];
      }
      for (final id in [initial.destinationAccountId]) {
        if (id != null && !accounts.any((item) => item.id == id)) {
          accounts = [...accounts, _archivedAccount(initial, id)];
        }
      }
      if (initial.categoryId != null &&
          !categories.any((item) => item.id == initial.categoryId)) {
        categories = [
          ...categories,
          Category(
            bookId: initial.bookId,
            id: initial.categoryId!,
            name: initial.categoryName ?? '已归档分类（原引用）',
            icon: 'category_outlined',
            type: initial.isIncome ? CategoryType.income : CategoryType.expense,
            sortOrder: 0,
            isDefault: false,
            isArchived: true,
          ),
        ];
      }
    }
    final transactions = selectedBookId == activeBookId
        ? ref.watch(transactionsProvider).value ?? const <TransactionRecord>[]
        : ref.watch(transactionsByBookProvider(selectedBookId)).value ??
              const <TransactionRecord>[];
    final activeCategories = _sortedCategories(categories, transactions);
    final selectedCategory = _selectedCategory(activeCategories);
    // 子分类条必须在未裁剪的分类全集里查找，否则永远查不到子级。
    final subcategories = _subcategoriesFor(
      categories,
      selectedCategory,
      initial,
    );
    final effectiveSubcategoryId =
        subcategories.any((item) => item.id == _subcategoryId)
        ? _subcategoryId
        : null;
    final sourceAccount = _selectedAccount(accounts, _accountId);
    final destinationAccount = _destinationAccount(accounts, sourceAccount);
    final keyboardVisible = MediaQuery.viewInsetsOf(context).bottom > 0;
    final input = _amount;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: .98,
          child: Material(
            color: AppColors.background,
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(4, 6, 8, 6),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: '返回',
                        constraints: const BoxConstraints.tightFor(
                          width: 48,
                          height: 48,
                        ),
                        padding: EdgeInsets.zero,
                        icon: const Icon(
                          Icons.arrow_back_rounded,
                          color: AppColors.textPrimary,
                          size: 24,
                        ),
                      ),
                      Expanded(
                        child: _EntryTabs(
                          selected: _tab,
                          onChanged: _changeTab,
                        ),
                      ),
                      SizedBox(width: 56, child: Center(child: _headerNote())),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 2, 16, 10),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_tab == _EntryTab.debt) ...[
                          _DebtTabs(
                            selected: _debtType,
                            onChanged: (value) => setState(() {
                              _debtType = value;
                              _type = value;
                              _categoryId = null;
                              _subcategoryId = null;
                              _reimbursementStatus = ReimbursementStatus.none;
                            }),
                          ),
                          const SizedBox(height: 10),
                        ],
                        if (!_usesAccountPair)
                          _CategoryCard(
                            categories: activeCategories,
                            selected: selectedCategory,
                            subcategories: subcategories,
                            selectedSubcategoryId: effectiveSubcategoryId,
                            onSelected: (category) => setState(() {
                              _categoryId = category.id;
                              _subcategoryId = null;
                            }),
                            onSubcategorySelected: (category) =>
                                setState(() => _subcategoryId = category.id),
                            onMore: () => _showAllCategories(activeCategories),
                          )
                        else
                          _AccountPairCard(
                            isRepayment: _type == TransactionType.repayment,
                            source: sourceAccount,
                            destination: destinationAccount,
                            onSourceTap: () =>
                                _chooseAccount(accounts, isDestination: false),
                            onDestinationTap: () =>
                                _chooseAccount(accounts, isDestination: true),
                          ),
                        const SizedBox(height: 10),
                        _buildDetailCard(
                          context,
                          input: input,
                          accounts: accounts,
                          selectedBook: selectedBook,
                          sourceAccount: sourceAccount,
                        ),
                      ],
                    ),
                  ),
                ),
                if (!keyboardVisible)
                  _Keypad(
                    canRepeat: !_isEditing,
                    isSaving: _isSaving,
                    onKey: (key) => _updateAmount(_amount.enter(key)),
                    onBackspace: () => _updateAmount(_amount.backspace()),
                    onDone: () => _submit(
                      bookId: selectedBookId,
                      sourceAccount: sourceAccount,
                      destinationAccount: destinationAccount,
                      selectedCategory: selectedCategory,
                      subcategoryId: effectiveSubcategoryId,
                      keepOpen: false,
                    ),
                    onRepeat: () => _submit(
                      bookId: selectedBookId,
                      sourceAccount: sourceAccount,
                      destinationAccount: destinationAccount,
                      selectedCategory: selectedCategory,
                      subcategoryId: effectiveSubcategoryId,
                      keepOpen: true,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Account _archivedAccount(TransactionRecord initial, String id) => Account(
    id: id,
    name: '已归档账户（原引用）',
    type: AccountType.other,
    balance: 0,
    currency: initial.currency,
    icon: 'account_balance_wallet_outlined',
    color: 0xff7b7f72,
    sortOrder: 0,
    isArchived: true,
    createdAt: initial.createdAt,
    updatedAt: initial.updatedAt,
  );

  Widget _headerNote() {
    if (_tab == null) {
      return Text(
        _transactionTypeLabel(_type),
        textAlign: TextAlign.center,
        style: const TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    if (_isEditing) {
      return const Text(
        '编辑中',
        textAlign: TextAlign.center,
        style: TextStyle(
          color: AppColors.textSecondary,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      );
    }
    return const SizedBox.shrink();
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required AmountInput input,
    required List<Account> accounts,
    required LedgerBook? selectedBook,
    required Account? sourceAccount,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Icon(
                Icons.edit_outlined,
                size: 18,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  key: const ValueKey('quick-note-field'),
                  controller: _noteController,
                  style: const TextStyle(
                    fontSize: 14,
                    color: AppColors.textPrimary,
                  ),
                  decoration: const InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    hintText: '添加备注...',
                    hintStyle: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                    ),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              _QuickChip(
                key: const ValueKey('quick-ai-entry'),
                label: 'AI帮我记',
                icon: Icons.auto_awesome_outlined,
                iconColor: const Color(0xFF765A94),
                onTap: _openAi,
              ),
              const SizedBox(width: 6),
              _IconChip(
                key: const ValueKey('quick-voice-entry'),
                icon: Icons.mic_none_rounded,
                tooltip: '语音记账',
                onTap: _openVoice,
              ),
            ],
          ),
          const SizedBox(height: 10),
          Container(
            key: const ValueKey('quick-amount-input'),
            padding: const EdgeInsets.fromLTRB(14, 10, 6, 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Expanded(
                  flex: 3,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      input.hasOperator
                          ? input.value
                          : '${_currencySymbol(sourceAccount)} ${input.displayValue}',
                      key: const ValueKey('quick-amount-display'),
                      style: const TextStyle(
                        color: AppColors.textPrimary,
                        fontSize: 30,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                ),
                if (input.hasOperator) ...[
                  const SizedBox(width: 8),
                  // 表达式与结果都要能缩放：320dp + 大字号下固定宽度会横向溢出。
                  Flexible(
                    flex: 2,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        '= ${_currencySymbol(sourceAccount)}${input.displayValue}',
                        key: const ValueKey('quick-amount-result'),
                        style: const TextStyle(
                          color: AppColors.primaryDark,
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ],
                IconButton(
                  onPressed: () => setState(() {
                    _amount = const AmountInput();
                    _amountError = false;
                  }),
                  tooltip: '清空金额',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(
                    Icons.cancel,
                    size: 20,
                    color: Color(0xFFBCC3B4),
                  ),
                ),
              ],
            ),
          ),
          if (_amountError)
            const Padding(
              padding: EdgeInsets.only(left: 4, top: 6),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  '请输入金额',
                  key: ValueKey('quick-amount-error'),
                  style: TextStyle(
                    color: AppColors.warning,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          const SizedBox(height: 10),
          _ChipRow(
            children: [
              if (!_usesAccountPair)
                _QuickChip(
                  key: const ValueKey('quick-account-chip'),
                  label: sourceAccount?.displayName ?? '请选择账户',
                  icon: _accountVisual(sourceAccount?.type).$1,
                  iconColor: _accountVisual(sourceAccount?.type).$2,
                  showChevron: true,
                  onTap: () => _chooseAccount(accounts, isDestination: false),
                ),
              if (_supportsReimbursement)
                _QuickChip(
                  key: const ValueKey('quick-reimbursement-chip'),
                  label: _reimbursementLabel,
                  icon: Icons.receipt_long_outlined,
                  selected: _reimbursementStatus != ReimbursementStatus.none,
                  showChevron: true,
                  onTap: _pickReimbursement,
                ),
              if (!_isEditing)
                _QuickChip(
                  key: const ValueKey('quick-book-selector'),
                  label: selectedBook?.name ?? '选择账本',
                  leading: selectedBook == null
                      ? const Icon(
                          Icons.menu_book_outlined,
                          size: 16,
                          color: AppColors.primary,
                        )
                      : BookColorDot(book: selectedBook, size: 12),
                  showChevron: true,
                  onTap: () => _chooseBook(ref.read(booksProvider).value ?? const []),
                )
              else
                _QuickChip(
                  key: const ValueKey('quick-book-selector'),
                  label: selectedBook?.name ?? '当前账本',
                  leading: selectedBook == null
                      ? const Icon(
                          Icons.menu_book_outlined,
                          size: 16,
                          color: AppColors.primary,
                        )
                      : BookColorDot(book: selectedBook, size: 12),
                  onTap: null,
                ),
            ],
          ),
          const SizedBox(height: 8),
          _ChipRow(
            children: [
              _QuickChip(
                key: const ValueKey('quick-attachment-chip'),
                label: _attachments.isEmpty
                    ? '附件'
                    : '附件 ${_attachments.length}/4',
                icon: Icons.attach_file,
                selected: _attachments.isNotEmpty,
                onTap: _onAttachmentChip,
              ),
              _QuickChip(
                key: const ValueKey('quick-image-chip'),
                label: '图片',
                icon: Icons.image_outlined,
                onTap: _pickImageAttachment,
              ),
              _QuickChip(
                key: const ValueKey('quick-date-chip'),
                label: _dateLabel,
                icon: Icons.calendar_today_outlined,
                selected: _isToday,
                onTap: _pickDateTime,
              ),
              _QuickChip(
                key: const ValueKey('quick-recurring-chip'),
                label: '定期付',
                icon: Icons.schedule_outlined,
                selected: _isRecurring,
                onTap: () => setState(() {
                  _isRecurring = !_isRecurring;
                  if (_isRecurring) _isOneTime = false;
                }),
              ),
              _QuickChip(
                key: const ValueKey('quick-more-chip'),
                label: '更多',
                icon: Icons.tune,
                selected:
                    _isPlanned ||
                    _merchantController.text.trim().isNotEmpty ||
                    _tagsController.text.trim().isNotEmpty,
                onTap: _openMoreOptions,
              ),
            ],
          ),
        ],
      ),
    );
  }

  String get _reimbursementLabel =>
      _reimbursementLabelFor(_reimbursementStatus);

  bool get _isToday => DateUtils.isSameDay(_occurredAt, DateTime.now());

  String get _dateLabel {
    final now = DateTime.now();
    final target = DateTime(
      _occurredAt.year,
      _occurredAt.month,
      _occurredAt.day,
    );
    final today = DateTime(now.year, now.month, now.day);
    final difference = target.difference(today).inDays;
    return switch (difference) {
      0 => '今天',
      -1 => '昨天',
      1 => '明天',
      _ =>
        _occurredAt.year == now.year
            ? '${_occurredAt.month}月${_occurredAt.day}日'
            : '${_occurredAt.year}年${_occurredAt.month}月${_occurredAt.day}日',
    };
  }

  String _currencySymbol(Account? account) =>
      account == null || account.currency == 'CNY' ? '¥' : account.currency;

  void _changeTab(_EntryTab tab) {
    if (_isSaving) return;
    setState(() {
      switch (tab) {
        case _EntryTab.expense:
          _type = TransactionType.expense;
        case _EntryTab.income:
          _type = TransactionType.income;
        case _EntryTab.transfer:
          _type = TransactionType.transfer;
        case _EntryTab.debt:
          _type = _debtType;
      }
      _categoryId = null;
      _subcategoryId = null;
      if (!_supportsReimbursement) {
        _reimbursementStatus = ReimbursementStatus.none;
      }
    });
  }

  Future<void> _pickReimbursement() async {
    final selected = await showModalBottomSheet<ReimbursementStatus>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
          children: [
            for (final status in ReimbursementStatus.values)
              ListTile(
                key: ValueKey('quick-reimbursement-${status.name}'),
                title: Text(_reimbursementLabelFor(status)),
                trailing: status == _reimbursementStatus
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, status),
              ),
            if (_reimbursementStatus != ReimbursementStatus.none)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                child: TextField(
                  controller: _reimbursementNoteController,
                  decoration: const InputDecoration(
                    isDense: true,
                    prefixIcon: Icon(Icons.receipt_long_outlined),
                    hintText: '报销备注（可选）',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() => _reimbursementStatus = selected);
  }

  String _reimbursementLabelFor(ReimbursementStatus status) =>
      switch (status) {
        ReimbursementStatus.none => '不报销',
        ReimbursementStatus.pending => '待报销',
        ReimbursementStatus.reimbursed => '已报销',
        ReimbursementStatus.partial => '部分报销',
      };

  Future<void> _openVoice() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceBookkeepingSheet(bookId: _bookId),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _openAi() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceBookkeepingSheet(textOnly: true, bookId: _bookId),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _onAttachmentChip() async {
    if (_attachments.isEmpty) {
      await _pickAttachment();
      return;
    }
    await _openAttachmentManager();
  }

  Future<void> _openAttachmentManager() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void refresh(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '附件 ${_attachments.length}/4',
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    '长按拖动可排序，最多 4 个附件',
                    style: TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  if (_attachmentsBusy)
                    const LinearProgressIndicator(minHeight: 2),
                  ReorderableListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    buildDefaultDragHandles: false,
                    itemCount: _attachments.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final reordered = [..._attachments];
                      final item = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, item);
                      refresh(() {
                        _attachmentsChanged = true;
                        _attachments
                          ..clear()
                          ..addAll(reordered);
                      });
                    },
                    itemBuilder: (context, index) {
                      final attachment = _attachments[index];
                      return ListTile(
                        key: ValueKey('${attachment.path}-$index'),
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: SizedBox(
                          width: 44,
                          height: 44,
                          child: _AttachmentThumbnail(attachment: attachment),
                        ),
                        title: Text(
                          attachment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        subtitle: Text(
                          switch (attachment.status) {
                            AttachmentUploadStatus.uploading => '保存中…',
                            AttachmentUploadStatus.uploaded =>
                              '已保存 · 长按拖动排序',
                            AttachmentUploadStatus.failed =>
                              '${attachment.errorMessage ?? '保存失败'} · 可重试',
                          },
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        trailing: Wrap(
                          spacing: 0,
                          children: [
                            if (attachment.status ==
                                AttachmentUploadStatus.failed)
                              IconButton(
                                onPressed: _attachmentsBusy
                                    ? null
                                    : () async {
                                        await _retryAttachment(attachment);
                                        setSheetState(() {});
                                      },
                                icon: const Icon(Icons.refresh),
                                tooltip: '重试保存',
                              )
                            else ...[
                              IconButton(
                                onPressed: _attachmentsBusy
                                    ? null
                                    : () async {
                                        await _replaceAttachment(attachment);
                                        setSheetState(() {});
                                      },
                                icon: const Icon(Icons.refresh),
                                tooltip: '替换附件',
                              ),
                              ReorderableDragStartListener(
                                index: index,
                                child: const Padding(
                                  padding: EdgeInsets.all(12),
                                  child: Icon(Icons.drag_handle),
                                ),
                              ),
                            ],
                            IconButton(
                              onPressed: _attachmentsBusy
                                  ? null
                                  : () => refresh(() {
                                      _attachmentsChanged = true;
                                      _attachments.remove(attachment);
                                    }),
                              icon: const Icon(Icons.close),
                              tooltip: '移除附件',
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: _attachments.length >= 4 || _attachmentsBusy
                        ? null
                        : () async {
                            await _pickAttachment();
                            setSheetState(() {});
                          },
                    icon: const Icon(Icons.attach_file),
                    label: const Text('添加附件'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Future<void> _openMoreOptions() async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (context, setSheetState) {
          void refresh(VoidCallback change) {
            setState(change);
            setSheetState(() {});
          }

          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '更多选项',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _merchantController,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.storefront_outlined),
                      hintText: '商户（可选）',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile.adaptive(
                      key: const ValueKey('quick-planned-toggle'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('计划内消费'),
                      value: _isPlanned,
                      onChanged: (value) => refresh(() => _isPlanned = value),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile.adaptive(
                      key: const ValueKey('quick-one-time-toggle'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('一次性消费'),
                      value: _isOneTime,
                      onChanged: (value) => refresh(() {
                        _isOneTime = value;
                        if (value) _isRecurring = false;
                      }),
                    ),
                  ),
                  Material(
                    color: Colors.transparent,
                    child: SwitchListTile.adaptive(
                      key: const ValueKey('quick-recurring-toggle'),
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: const Text('周期消费'),
                      value: _isRecurring,
                      onChanged: (value) => refresh(() {
                        _isRecurring = value;
                        if (value) _isOneTime = false;
                      }),
                    ),
                  ),
                  TextField(
                    controller: _tagsController,
                    decoration: const InputDecoration(
                      isDense: true,
                      prefixIcon: Icon(Icons.sell_outlined),
                      hintText: '标签，用逗号分隔',
                    ),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () {
                      Navigator.pop(context);
                      unawaited(_openAttachmentManager());
                    },
                    icon: const Icon(Icons.attach_file),
                    label: Text('管理附件 ${_attachments.length}/4'),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  List<Category> _subcategoriesOf(List<Category> categories, Category? parent) {
    if (parent == null) return const [];
    final children = categories
        .where(
          (category) =>
              category.parentId == parent.id && category.type == parent.type,
        )
        .toList();
    children.sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
    return children;
  }

  /// Children of [parent], plus the persisted sub-category of the record being
  /// edited when it has since been archived — otherwise the editor would show
  /// no selection and saving could silently drop the stored value.
  List<Category> _subcategoriesFor(
    List<Category> categories,
    Category? parent,
    TransactionRecord? initial,
  ) {
    final children = [..._subcategoriesOf(categories, parent)];
    final persisted = initial?.subcategoryId;
    if (parent != null &&
        persisted != null &&
        initial?.categoryId == parent.id &&
        !children.any((item) => item.id == persisted)) {
      children.add(
        Category(
          bookId: parent.bookId,
          id: persisted,
          parentId: parent.id,
          name: '已归档子分类',
          icon: 'category_outlined',
          type: parent.type,
          sortOrder: 1 << 20,
          isDefault: false,
          isArchived: true,
        ),
      );
    }
    return children;
  }

  List<Category> _sortedCategories(
    List<Category> categories,
    List<TransactionRecord> transactions,
  ) {
    final desiredType = switch (_type) {
      TransactionType.income ||
      TransactionType.refund ||
      TransactionType.reimbursement ||
      TransactionType.borrow => CategoryType.income,
      _ => CategoryType.expense,
    };
    final usage = <String, int>{};
    for (final transaction in transactions) {
      final categoryId = transaction.categoryId;
      if (categoryId != null) {
        usage.update(categoryId, (value) => value + 1, ifAbsent: () => 1);
      }
    }
    final result = categories
        .where(
          (category) =>
              category.type == desiredType && category.parentId == null,
        )
        .toList();
    result.sort((a, b) {
      final usageComparison = (usage[b.id] ?? 0).compareTo(usage[a.id] ?? 0);
      return usageComparison != 0
          ? usageComparison
          : a.sortOrder.compareTo(b.sortOrder);
    });
    return result;
  }

  Category? _selectedCategory(List<Category> categories) {
    for (final category in categories) {
      if (category.id == _categoryId) return category;
    }
    return categories.firstOrNull;
  }

  Map<String, dynamic> _decodeMetadata(String? value) {
    if (value == null || value.trim().isEmpty) return const {};
    try {
      final decoded = jsonDecode(value);
      return decoded is Map
          ? decoded.map((key, item) => MapEntry(key.toString(), item))
          : const {};
    } on Object {
      return const {};
    }
  }

  Account? _selectedAccount(List<Account> accounts, String? selectedId) {
    for (final account in accounts) {
      if (account.id == selectedId) return account;
    }
    return accounts.firstOrNull;
  }

  Account? _destinationAccount(List<Account> accounts, Account? sourceAccount) {
    for (final account in accounts) {
      if (account.id == _destinationAccountId &&
          account.id != sourceAccount?.id) {
        return account;
      }
    }
    return accounts.where((item) => item.id != sourceAccount?.id).firstOrNull;
  }

  Future<void> _showAllCategories(List<Category> categories) async {
    final selected = await showModalBottomSheet<Category>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text('全部分类', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 8),
            ...categories.map(
              (category) => ListTile(
                title: Text(category.name),
                trailing: category.id == _categoryId
                    ? const Icon(Icons.check, color: AppColors.primary)
                    : null,
                onTap: () => Navigator.pop(context, category),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _categoryId = selected.id;
        _subcategoryId = null;
      });
    }
  }

  Future<void> _chooseBook(List<LedgerBook> books) async {
    final selected = await showBookChoiceSheet(
      context,
      books: books,
      selectedId: _bookId ?? ref.read(activeBookIdProvider),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _bookId = selected.id;
      _categoryId = null;
      _subcategoryId = null;
      _accountId = null;
      _destinationAccountId = null;
    });
  }

  Future<void> _chooseAccount(
    List<Account> accounts, {
    required bool isDestination,
  }) async {
    final sourceId = _selectedAccount(accounts, _accountId)?.id;
    final available = isDestination
        ? accounts.where((account) => account.id != sourceId).toList()
        : accounts;
    final selected = await showModalBottomSheet<Account>(
      context: context,
      backgroundColor: AppColors.surface,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            Text(
              _isDestinationPickerTitle(isDestination),
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...available.map(
              (account) => ListTile(
                leading: Icon(
                  _accountVisual(account.type).$1,
                  color: _accountVisual(account.type).$2,
                ),
                title: Text(account.displayName),
                subtitle: Text(
                  '${_accountTypeLabel(account.type)} · ${MoneyFormatter.decimal(account.balance)}',
                ),
                onTap: () => Navigator.pop(context, account),
              ),
            ),
          ],
        ),
      ),
    );
    if (selected == null || !mounted) return;
    setState(() {
      if (isDestination) {
        _destinationAccountId = selected.id;
      } else {
        _accountId = selected.id;
        if (_destinationAccountId == selected.id) {
          _destinationAccountId = null;
        }
      }
    });
  }

  String _isDestinationPickerTitle(bool isDestination) {
    if (!isDestination) return '选择账户';
    return _type == TransactionType.repayment ? '选择债务账户' : '选择转入账户';
  }

  Future<void> _pickDateTime() async {
    final date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime.now().add(const Duration(days: 366)),
    );
    if (date == null || !mounted) return;
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) return;
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _pickImageAttachment() =>
      _pickAttachment(type: FileType.image, dialogTitle: '选择图片附件');

  Future<void> _pickAttachment({
    FileType type = FileType.any,
    String dialogTitle = '选择账单附件',
  }) async {
    if (_attachments.length >= 4 || _attachmentsBusy) {
      if (_attachments.length >= 4) _showMessage('一笔流水最多添加 4 个附件');
      return;
    }
    final pending = const StoredAttachment(
      name: '选择附件…',
      path: '',
      status: AttachmentUploadStatus.uploading,
    );
    setState(() {
      _attachments.add(pending);
      _attachmentsBusy = true;
    });
    try {
      final attachment = await ref
          .read(attachmentStorageServiceProvider)
          .pickAndStore(type: type, dialogTitle: dialogTitle);
      if (mounted) {
        setState(() {
          final index = _attachments.indexOf(pending);
          if (index < 0) return;
          if (attachment == null) {
            _attachments.removeAt(index);
          } else {
            _attachmentsChanged = true;
            _attachments[index] = attachment;
          }
        });
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _attachments.remove(pending);
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('附件读取失败，请重新选择：$error')));
    } finally {
      if (mounted) setState(() => _attachmentsBusy = false);
    }
  }

  Future<void> _replaceAttachment(StoredAttachment existing) async {
    if (_attachmentsBusy) return;
    final index = _attachments.indexOf(existing);
    if (index < 0) return;
    final pending = const StoredAttachment(
      name: '替换附件…',
      path: '',
      status: AttachmentUploadStatus.uploading,
    );
    setState(() {
      _attachments[index] = pending;
      _attachmentsBusy = true;
    });
    try {
      final replacement = await ref
          .read(attachmentStorageServiceProvider)
          .pickAndStore();
      if (!mounted) return;
      setState(() {
        final pendingIndex = _attachments.indexOf(pending);
        if (pendingIndex < 0) return;
        if (replacement == null) {
          _attachments[pendingIndex] = existing;
        } else {
          _attachmentsChanged = true;
          _attachments[pendingIndex] = replacement;
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        final pendingIndex = _attachments.indexOf(pending);
        if (pendingIndex >= 0) _attachments[pendingIndex] = existing;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('附件替换失败，请重试：$error')));
    } finally {
      if (mounted) setState(() => _attachmentsBusy = false);
    }
  }

  Future<void> _retryAttachment(StoredAttachment failed) async {
    if (_attachmentsBusy) return;
    final index = _attachments.indexOf(failed);
    if (index < 0) return;
    final pending = StoredAttachment(
      name: failed.name,
      path: '',
      status: AttachmentUploadStatus.uploading,
      sourceFile: failed.sourceFile,
    );
    setState(() {
      _attachments[index] = pending;
      _attachmentsBusy = true;
    });
    try {
      final replacement = await ref
          .read(attachmentStorageServiceProvider)
          .retry(failed);
      if (!mounted) return;
      if (replacement == null) {
        setState(() {
          final pendingIndex = _attachments.indexOf(pending);
          if (pendingIndex >= 0) _attachments[pendingIndex] = failed;
        });
        _showMessage('无法重试：原文件已不可用');
        return;
      }
      setState(() {
        final pendingIndex = _attachments.indexOf(pending);
        if (pendingIndex < 0) return;
        _attachmentsChanged = true;
        _attachments[pendingIndex] = replacement;
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        final pendingIndex = _attachments.indexOf(pending);
        if (pendingIndex >= 0) _attachments[pendingIndex] = failed;
      });
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('附件重试失败，请稍后再试：$error')));
    } finally {
      if (mounted) setState(() => _attachmentsBusy = false);
    }
  }

  Future<void> _submit({
    required String bookId,
    required Account? sourceAccount,
    required Account? destinationAccount,
    required Category? selectedCategory,
    required String? subcategoryId,
    required bool keepOpen,
  }) async {
    if (_isSaving) return;
    if (_attachmentsBusy) {
      _showMessage('附件仍在保存，请稍候');
      return;
    }
    if (_attachments.any(
      (item) => item.status == AttachmentUploadStatus.failed,
    )) {
      _showMessage('有附件保存失败，请重试或移除后再保存');
      return;
    }
    if (!_amount.isValid) {
      setState(() => _amountError = true);
      _showMessage(_amount.isComplete ? '金额需大于 0' : '请先完成金额计算');
      return;
    }
    if (sourceAccount == null) {
      _showMessage('请选择账户');
      return;
    }
    if (_usesAccountPair && destinationAccount == null) {
      _showMessage(
        _type == TransactionType.repayment ? '请选择债务账户' : '请选择转入账户',
      );
      return;
    }
    if (!_usesAccountPair && selectedCategory == null) {
      _showMessage('请选择分类');
      return;
    }

    setState(() => _isSaving = true);
    try {
      await _attachmentsLoad;
      final tags = _tagsController.text
          .split(RegExp(r'[,，]'))
          .map((item) => item.trim())
          .where((item) => item.isNotEmpty)
          .toSet()
          .toList();
      final persisted = widget.initialTransaction;
      final categoryUnchanged = persisted?.categoryId == selectedCategory?.id;
      final request = QuickBookkeepingRequest(
        bookId: bookId,
        type: _type,
        amount: _amount.amount!,
        currency: sourceAccount.currency,
        categoryId: _usesAccountPair ? null : selectedCategory!.id,
        subcategoryId: _usesAccountPair
            ? null
            : (subcategoryId ??
                  (categoryUnchanged ? persisted?.subcategoryId : null)),
        categoryName: _usesAccountPair ? null : selectedCategory!.name,
        accountId: sourceAccount.id,
        destinationAccountId: _usesAccountPair ? destinationAccount!.id : null,
        merchant: _merchantController.text,
        note: _noteController.text,
        occurredAt: _occurredAt,
        isPlanned: _isPlanned,
        isOneTime: _isOneTime,
        isRecurring: _isRecurring,
        isLargeTransaction:
            widget.initialTransaction?.isLargeTransaction ?? false,
        tags: tags,
        attachmentPaths: _attachments.map((item) => item.path).toList(),
        reimbursementStatus: _reimbursementStatus,
        reimbursementAmount: _reimbursementStatus == ReimbursementStatus.none
            ? null
            : _amount.amount,
        reimbursementNote: _reimbursementStatus == ReimbursementStatus.none
            ? null
            : _reimbursementNoteController.text,
        clearReimbursement:
            _reimbursementStatus == ReimbursementStatus.none &&
            widget.initialTransaction?.reimbursementStatus !=
                ReimbursementStatus.none,
      );
      final service = ref.read(quickBookkeepingServiceProvider);
      if (widget.initialTransaction == null) {
        await service.save(request);
      } else {
        await service.update(widget.initialTransaction!, request);
      }
      unawaited(HapticFeedback.lightImpact());
      if (!mounted) return;
      if (keepOpen) {
        setState(() {
          _isSaving = false;
          _amount = const AmountInput();
          _amountError = false;
          _noteController.clear();
          _merchantController.clear();
          _tagsController.clear();
          _reimbursementNoteController.clear();
          _attachments.clear();
          _attachmentsChanged = false;
        });
        _showMessage('已保存，继续记下一笔');
        return;
      }
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            widget.initialTransaction == null ? '已保存到本地账本' : '已更新本地账本',
          ),
        ),
      );
    } on BookkeepingCommittedException catch (error) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      final messenger = ScaffoldMessenger.of(context);
      Navigator.pop(context);
      messenger.showSnackBar(
        SnackBar(content: Text('已入账，但${error.stage}失败，请稍后检查')),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _isSaving = false);
      _showMessage('保存失败，请检查账户和金额');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  void _updateAmount(AmountInput value) {
    setState(() {
      _amount = value;
      if (value.isValid) _amountError = false;
    });
  }
}

/// Visual identity for one account type, shared by chips and the picker.
(IconData, Color) _accountVisual(AccountType? type) => switch (type) {
  AccountType.wechat => (Icons.chat_bubble_rounded, const Color(0xFF07C160)),
  AccountType.alipay => (
    Icons.account_balance_wallet_rounded,
    const Color(0xFF1677FF),
  ),
  AccountType.cash => (Icons.payments_rounded, const Color(0xFFD9A03C)),
  AccountType.debitCard => (Icons.credit_card_rounded, const Color(0xFF539AF2)),
  AccountType.creditCard => (Icons.credit_card_rounded, const Color(0xFFEF789E)),
  AccountType.liability => (Icons.trending_down_rounded, AppColors.warning),
  _ => (
    Icons.account_balance_wallet_outlined,
    AppColors.textSecondary,
  ),
};

String _transactionTypeLabel(TransactionType type) => switch (type) {
  TransactionType.expense => '支出',
  TransactionType.income => '收入',
  TransactionType.transfer => '转账',
  TransactionType.refund => '退款',
  TransactionType.reimbursement => '报销回款',
  TransactionType.borrow => '借入',
  TransactionType.lend => '借出',
  TransactionType.repayment => '还款',
  TransactionType.assetPurchase => '资产购买',
  TransactionType.adjustment => '余额校准',
};

/// The prototype's four-item type switch: the active tab is a solid capsule.
class _EntryTabs extends StatelessWidget {
  const _EntryTabs({required this.selected, required this.onChanged});

  final _EntryTab? selected;
  final ValueChanged<_EntryTab> onChanged;

  static const _items = [
    (_EntryTab.expense, '支出'),
    (_EntryTab.income, '收入'),
    (_EntryTab.transfer, '转账'),
    (_EntryTab.debt, '债务'),
  ];

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 200);
    return Container(
      height: 40,
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: Semantics(
                selected: item.$1 == selected,
                button: true,
                child: InkWell(
                  key: ValueKey('quick-type-${item.$1.name}'),
                  borderRadius: BorderRadius.circular(19),
                  onTap: () => onChanged(item.$1),
                  child: AnimatedContainer(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.$1 == selected
                          ? AppColors.primary
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(19),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.$2,
                        maxLines: 1,
                        style: TextStyle(
                          fontSize: 14,
                          color: item.$1 == selected
                              ? Colors.white
                              : AppColors.textSecondary,
                          fontWeight: item.$1 == selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// 借入 / 借出 / 还款, shown only inside the 债务 tab.
class _DebtTabs extends StatelessWidget {
  const _DebtTabs({required this.selected, required this.onChanged});

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  static const _items = [
    (TransactionType.borrow, '借入'),
    (TransactionType.lend, '借出'),
    (TransactionType.repayment, '还款'),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          for (final item in _items)
            Expanded(
              child: Semantics(
                selected: item.$1 == selected,
                button: true,
                child: InkWell(
                  key: ValueKey('quick-debt-${item.$1.name}'),
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => onChanged(item.$1),
                  child: Container(
                    height: 34,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: item.$1 == selected
                          ? AppColors.primarySoft
                          : Colors.transparent,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        item.$2,
                        style: TextStyle(
                          fontSize: 13,
                          color: item.$1 == selected
                              ? AppColors.primaryDark
                              : AppColors.textSecondary,
                          fontWeight: item.$1 == selected
                              ? FontWeight.w600
                              : FontWeight.w400,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The 5-column primary grid plus the optional sub-category strip.
class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.categories,
    required this.selected,
    required this.subcategories,
    required this.selectedSubcategoryId,
    required this.onSelected,
    required this.onSubcategorySelected,
    required this.onMore,
  });

  final List<Category> categories;
  final Category? selected;
  final List<Category> subcategories;
  final String? selectedSubcategoryId;
  final ValueChanged<Category> onSelected;
  final ValueChanged<Category> onSubcategorySelected;
  final VoidCallback onMore;

  /// Three rows of five tiles before the 更多 tile takes over.
  static const _maxTiles = 15;

  @override
  Widget build(BuildContext context) {
    final showsMore = categories.length > _maxTiles;
    final visible = categories
        .take(showsMore ? _maxTiles - 1 : _maxTiles)
        .toList();
    if (selected != null &&
        !visible.any((item) => item.id == selected!.id) &&
        visible.isNotEmpty) {
      visible[visible.length - 1] = selected!;
    }
    return Container(
      padding: const EdgeInsets.fromLTRB(6, 8, 6, 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = MediaQuery.textScalerOf(context).scale(14) > 19
                  ? 4
                  : 5;
              return Wrap(
                key: const ValueKey('quick-category-section'),
                children: [
                  for (final category in visible)
                    _CategoryTile(
                      key: ValueKey('quick-category-${category.id}'),
                      width: constraints.maxWidth / columns,
                      name: category.name,
                      iconKey: category.icon,
                      selected: selected?.id == category.id,
                      onTap: () => onSelected(category),
                    ),
                  if (showsMore)
                    _CategoryTile(
                      key: const ValueKey('quick-more-categories'),
                      width: constraints.maxWidth / columns,
                      name: '更多',
                      iconKey: 'more_horiz',
                      selected: false,
                      onTap: onMore,
                    ),
                  if (categories.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Text('暂无可用分类，请先在分类管理中添加'),
                    ),
                ],
              );
            },
          ),
          if (subcategories.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              child: Divider(height: 1, color: AppColors.divider),
            ),
            SizedBox(
              height: 62,
              child: ListView.separated(
                key: const ValueKey('quick-subcategory-strip'),
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                itemCount: subcategories.length,
                separatorBuilder: (context, index) => const SizedBox(width: 6),
                itemBuilder: (context, index) {
                  final child = subcategories[index];
                  return _SubcategoryTile(
                    key: ValueKey('quick-subcategory-${child.id}'),
                    category: child,
                    selected: child.id == selectedSubcategoryId,
                    onTap: () => onSubcategorySelected(child),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CategoryTile extends StatelessWidget {
  const _CategoryTile({
    super.key,
    required this.width,
    required this.name,
    required this.iconKey,
    required this.selected,
    required this.onTap,
  });

  final double width;
  final String name;
  final String iconKey;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : const Duration(milliseconds: 180);
    final accent = CategoryIcon.accentFor(name, iconKey: iconKey);
    return SizedBox(
      width: width,
      child: Semantics(
        selected: selected,
        button: true,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Column(
              children: [
                AnimatedScale(
                  scale: selected ? 1.06 : 1,
                  duration: duration,
                  curve: Curves.easeOutCubic,
                  child: AnimatedContainer(
                    duration: duration,
                    padding: const EdgeInsets.all(3),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: selected
                            ? accent.withValues(alpha: .55)
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: CategoryIcon(
                      category: name,
                      iconKey: iconKey,
                      size: 40,
                      vivid: true,
                    ),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubcategoryTile extends StatelessWidget {
  const _SubcategoryTile({
    super.key,
    required this.category,
    required this.selected,
    required this.onTap,
  });

  final Category category;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: 62,
          padding: const EdgeInsets.symmetric(vertical: 4),
          decoration: BoxDecoration(
            color: selected ? AppColors.primarySoft : Colors.transparent,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: selected ? AppColors.primary : Colors.transparent,
              width: 1.2,
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CategoryIcon(
                category: category.name,
                iconKey: category.icon,
                size: 28,
                vivid: selected,
              ),
              const SizedBox(height: 2),
              Text(
                category.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  color: selected
                      ? AppColors.primaryDark
                      : AppColors.textSecondary,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 转出 → 转入 (or 还款账户 → 债务账户) shown where the category grid would be.
class _AccountPairCard extends StatelessWidget {
  const _AccountPairCard({
    required this.isRepayment,
    required this.source,
    required this.destination,
    required this.onSourceTap,
    required this.onDestinationTap,
  });

  final bool isRepayment;
  final Account? source;
  final Account? destination;
  final VoidCallback onSourceTap;
  final VoidCallback onDestinationTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Row(
        children: [
          Expanded(
            child: _AccountPairButton(
              key: const ValueKey('quick-account-chip'),
              label: isRepayment ? '还款账户' : '转出',
              account: source,
              onTap: onSourceTap,
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 8),
            child: Icon(
              Icons.arrow_forward_rounded,
              color: AppColors.primary,
              size: 18,
            ),
          ),
          Expanded(
            child: _AccountPairButton(
              key: const ValueKey('quick-destination-chip'),
              label: isRepayment ? '债务账户' : '转入',
              account: destination,
              onTap: onDestinationTap,
            ),
          ),
        ],
      ),
    );
  }
}

class _AccountPairButton extends StatelessWidget {
  const _AccountPairButton({
    super.key,
    required this.label,
    required this.account,
    required this.onTap,
  });

  final String label;
  final Account? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final visual = _accountVisual(account?.type);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceSoft,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Icon(visual.$1, size: 16, color: visual.$2),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    account?.displayName ?? '请选择',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            children[index],
          ],
        ],
      ),
    );
  }
}

class _QuickChip extends StatelessWidget {
  const _QuickChip({
    super.key,
    required this.label,
    this.icon,
    this.iconColor,
    this.leading,
    this.selected = false,
    this.showChevron = false,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final bool selected;
  final bool showChevron;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? AppColors.primarySoft : Colors.white,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (leading != null) ...[
                leading!,
                const SizedBox(width: 6),
              ] else if (icon != null) ...[
                Icon(
                  icon,
                  size: 16,
                  color: iconColor ?? AppColors.textSecondary,
                ),
                const SizedBox(width: 6),
              ],
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 120),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    color: selected
                        ? AppColors.primaryDark
                        : AppColors.textPrimary,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
              ),
              if (showChevron) ...[
                const SizedBox(width: 2),
                const Icon(
                  Icons.keyboard_arrow_down_rounded,
                  size: 16,
                  color: AppColors.textSecondary,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _IconChip extends StatelessWidget {
  const _IconChip({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(18),
          child: Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.divider),
            ),
            child: Icon(icon, size: 18, color: AppColors.textSecondary),
          ),
        ),
      ),
    );
  }
}

/// The always-visible calculator keypad that replaces the old save button.
class _Keypad extends StatelessWidget {
  const _Keypad({
    required this.canRepeat,
    required this.isSaving,
    required this.onKey,
    required this.onBackspace,
    required this.onDone,
    required this.onRepeat,
  });

  final bool canRepeat;
  final bool isSaving;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onDone;
  final VoidCallback onRepeat;

  @override
  Widget build(BuildContext context) {
    final height = (MediaQuery.sizeOf(context).height * .25).clamp(
      176.0,
      210.0,
    );
    return Container(
      height: height,
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.divider)),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                _digit('1'),
                _digit('2'),
                _digit('3'),
                Expanded(
                  child: _KeypadKey(
                    key: const ValueKey('amount-key-backspace'),
                    icon: Icons.backspace_outlined,
                    semanticLabel: '删除金额字符',
                    onTap: onBackspace,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _digit('4'),
                _digit('5'),
                _digit('6'),
                _operatorPair('+', '-'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                _digit('7'),
                _digit('8'),
                _digit('9'),
                _operatorPair('×', '÷'),
              ],
            ),
          ),
          Expanded(
            child: Row(
              children: [
                if (canRepeat)
                  Expanded(
                    child: _KeypadKey(
                      key: const ValueKey('quick-repeat'),
                      label: '再记',
                      fontSize: 15,
                      onTap: isSaving ? null : onRepeat,
                    ),
                  ),
                Expanded(
                  child: _KeypadKey(
                    key: const ValueKey('amount-key-0'),
                    label: '0',
                    onTap: () => onKey('0'),
                  ),
                ),
                Expanded(
                  child: _KeypadKey(
                    key: const ValueKey('amount-key-.'),
                    label: '.',
                    onTap: () => onKey('.'),
                  ),
                ),
                Expanded(
                  flex: canRepeat ? 1 : 2,
                  child: _KeypadKey(
                    key: const ValueKey('quick-done'),
                    label: '完成',
                    fontSize: 15,
                    primary: true,
                    busy: isSaving,
                    onTap: isSaving ? null : onDone,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _digit(String value) => Expanded(
    child: _KeypadKey(
      key: ValueKey('amount-key-$value'),
      label: value,
      onTap: () => onKey(value),
    ),
  );

  Widget _operatorPair(String multiplication, String division) => Expanded(
    child: Row(
      children: [
        Expanded(
          child: _KeypadKey(
            key: ValueKey('amount-key-$multiplication'),
            label: multiplication,
            onTap: () => onKey(multiplication == '×' ? '*' : '+'),
          ),
        ),
        Expanded(
          child: _KeypadKey(
            key: ValueKey('amount-key-$division'),
            label: division,
            onTap: () => onKey(division == '÷' ? '/' : '-'),
          ),
        ),
      ],
    ),
  );
}

class _KeypadKey extends StatelessWidget {
  const _KeypadKey({
    super.key,
    this.label,
    this.icon,
    this.semanticLabel,
    this.fontSize = 20,
    this.primary = false,
    this.busy = false,
    this.onTap,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final double fontSize;
  final bool primary;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(3),
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: Material(
          color: primary ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(14),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(14),
            child: Ink(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                border: primary
                    ? null
                    : Border.all(color: AppColors.divider),
              ),
              child: Center(
                child: busy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : icon != null
                    ? Icon(icon, color: AppColors.textPrimary, size: 20)
                    : Text(
                        label!,
                        style: TextStyle(
                          fontSize: fontSize,
                          fontWeight: FontWeight.w500,
                          color: primary ? Colors.white : AppColors.textPrimary,
                        ),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _AttachmentThumbnail extends StatelessWidget {
  const _AttachmentThumbnail({required this.attachment});

  final StoredAttachment attachment;

  @override
  Widget build(BuildContext context) {
    if (attachment.status == AttachmentUploadStatus.failed) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          color: Color(0xffffe5dc),
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Icon(Icons.cloud_off_outlined, color: AppColors.warning),
      );
    }
    if (attachment.status == AttachmentUploadStatus.uploading) {
      return const DecoratedBox(
        decoration: BoxDecoration(
          color: AppColors.primarySoft,
          borderRadius: BorderRadius.all(Radius.circular(10)),
        ),
        child: Padding(
          padding: EdgeInsets.all(12),
          child: CircularProgressIndicator(strokeWidth: 2),
        ),
      );
    }
    final extension = p.extension(attachment.name).toLowerCase();
    final isImage = const {
      '.bmp',
      '.gif',
      '.heic',
      '.heif',
      '.jpeg',
      '.jpg',
      '.png',
      '.webp',
    }.contains(extension);
    if (!isImage) {
      return GestureDetector(
        onTap: () => _preview(context, isImage: false),
        child: const DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.all(Radius.circular(10)),
          ),
          child: Icon(
            Icons.insert_drive_file_outlined,
            color: AppColors.primary,
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: () => _preview(context, isImage: true),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(10),
        child: Image.file(
          File(attachment.path),
          fit: BoxFit.cover,
          errorBuilder: (context, error, stack) => const DecoratedBox(
            decoration: BoxDecoration(color: AppColors.primarySoft),
            child: Icon(Icons.broken_image_outlined, color: AppColors.primary),
          ),
        ),
      ),
    );
  }

  void _preview(BuildContext context, {required bool isImage}) {
    showDialog<void>(
      context: context,
      builder: (_) => Dialog(
        child: isImage
            ? InteractiveViewer(child: Image.file(File(attachment.path)))
            : Padding(
                padding: const EdgeInsets.all(24),
                child: Text(attachment.name),
              ),
      ),
    );
  }
}

String _accountTypeLabel(AccountType type) => switch (type) {
  AccountType.cash => '现金',
  AccountType.wechat => '微信',
  AccountType.alipay => '支付宝',
  AccountType.debitCard => '储蓄卡',
  AccountType.creditCard => '信用卡',
  AccountType.other => '其他',
  AccountType.liability => '负债',
};
