import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';

import '../../voice/presentation/voice_bookkeeping_sheet.dart';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/finance_ui.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/sliding_segmented_control.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../accounts/data/account_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../application/amount_input.dart';
import '../application/attachment_storage_service.dart';
import '../application/quick_bookkeeping_service.dart';
import '../../transactions/data/transaction_attachment_repository.dart';

class QuickAddSheet extends ConsumerStatefulWidget {
  const QuickAddSheet({super.key, this.initialTransaction});

  final TransactionRecord? initialTransaction;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();
  final _tagsController = TextEditingController();

  AmountInput _amount = const AmountInput();
  TransactionType _type = TransactionType.expense;
  String? _categoryId;
  String? _accountId;
  String? _destinationAccountId;
  DateTime _occurredAt = DateTime.now();
  bool _isPlanned = false;
  bool _isOneTime = true;
  bool _isRecurring = false;
  bool _isSaving = false;
  bool _showNumberPad = false;
  bool _attachmentsChanged = false;
  Future<void>? _attachmentsLoad;
  final List<StoredAttachment> _attachments = [];

  @override
  void initState() {
    super.initState();
    final transaction = widget.initialTransaction;
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
    _categoryId = transaction.categoryId;
    _accountId = transaction.accountId;
    _destinationAccountId = transaction.destinationAccountId;
    _occurredAt = transaction.occurredAt;
    _isPlanned = transaction.isPlanned;
    _isOneTime = transaction.isOneTime;
    _isRecurring = transaction.isRecurring;
    _merchantController.text = transaction.merchant ?? '';
    _noteController.text = transaction.note ?? '';
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
        ..addAll(restored!);
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    var categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    final initial = widget.initialTransaction;
    if (initial != null) {
      if (!accounts.any((item) => item.id == initial.accountId)) {
        accounts = [
          ...accounts,
          Account(
            id: initial.accountId,
            name: '已归档账户（原引用）',
            type: AccountType.other,
            balance: 0,
            currency: initial.currency,
            icon: 'account_balance_wallet_outlined',
            color: 0xff7b7f72,
            sortOrder: accounts.length,
            isArchived: true,
            createdAt: initial.createdAt,
            updatedAt: initial.updatedAt,
          ),
        ];
      }
      for (final id in [initial.destinationAccountId]) {
        if (id != null && !accounts.any((item) => item.id == id)) {
          accounts = [
            ...accounts,
            Account(
              id: id,
              name: '已归档账户（原引用）',
              type: AccountType.other,
              balance: 0,
              currency: initial.currency,
              icon: 'account_balance_wallet_outlined',
              color: 0xff7b7f72,
              sortOrder: accounts.length,
              isArchived: true,
              createdAt: initial.createdAt,
              updatedAt: initial.updatedAt,
            ),
          ];
        }
      }
      if (initial.categoryId != null &&
          !categories.any((item) => item.id == initial.categoryId)) {
        categories = [
          ...categories,
          Category(
            id: initial.categoryId!,
            parentId: null,
            name: initial.categoryName ?? '已归档分类（原引用）',
            icon: 'category_outlined',
            type: initial.isIncome ? CategoryType.income : CategoryType.expense,
            sortOrder: categories.length,
            isDefault: false,
            isArchived: true,
          ),
        ];
      }
    }
    final transactions =
        ref.watch(transactionsProvider).value ?? const <TransactionRecord>[];
    final activeCategories = _sortedCategories(categories, transactions);
    final selectedCategory = _selectedCategory(activeCategories);
    final sourceAccount = _selectedAccount(accounts, _accountId);
    final destinationAccount = _destinationAccount(accounts, sourceAccount);

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: .98,
          child: Material(
            color: const Color(0xFFF8FCFD),
            clipBehavior: Clip.antiAlias,
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 6, 10, 2),
                  child: Row(
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        tooltip: '关闭',
                        icon: const Icon(
                          Icons.chevron_left,
                          color: FinanceUi.ink,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          widget.initialTransaction == null ? '记一笔' : '编辑流水',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: FinanceUi.ink,
                          ),
                        ),
                      ),
                      const SizedBox(width: 48),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: _TypeSelector(
                    selected: _type,
                    onChanged: (type) {
                      if (!_isSaving) {
                        setState(() {
                          _type = type;
                          _categoryId = null;
                        });
                      }
                    },
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(26, 18, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: Semantics(
                          button: true,
                          label: '输入金额',
                          child: InkWell(
                            key: const ValueKey('quick-amount-input'),
                            onTap: () {
                              FocusScope.of(context).unfocus();
                              setState(() => _showNumberPad = !_showNumberPad);
                            },
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                child: Text(
                                  '${sourceAccount == null || sourceAccount.currency == "CNY" ? "¥" : sourceAccount.currency} ${_amount.displayValue}',
                                  key: const ValueKey('quick-amount-display'),
                                  style: const TextStyle(
                                    color: FinanceUi.ink,
                                    fontSize: 52,
                                    fontWeight: FontWeight.w600,
                                    height: 1.1,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () =>
                            setState(() => _amount = const AmountInput()),
                        tooltip: '清空金额',
                        icon: const Icon(
                          Icons.cancel,
                          size: 20,
                          color: Color(0xFFBCCADB),
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        if (_type != TransactionType.transfer)
                          _CategorySection(
                            categories: activeCategories,
                            selected: selectedCategory,
                            onSelected: (category) =>
                                setState(() => _categoryId = category.id),
                            onMore: () => _showAllCategories(activeCategories),
                          )
                        else
                          _TransferAccounts(
                            source: sourceAccount,
                            destination: destinationAccount,
                            onSourceTap: () =>
                                _chooseAccount(accounts, isDestination: false),
                            onDestinationTap: () =>
                                _chooseAccount(accounts, isDestination: true),
                          ),
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(22),
                            border: Border.all(color: FinanceUi.line),
                          ),
                          child: Column(
                            children: [
                              if (_type != TransactionType.transfer) ...[
                                _SettingRow(
                                  icon: Icons.account_balance_wallet_outlined,
                                  label: '账户',
                                  value: sourceAccount == null
                                      ? '请选择'
                                      : '${sourceAccount.name}  ${sourceAccount.currency == "CNY" ? "¥" : sourceAccount.currency}${MoneyFormatter.decimal(sourceAccount.balance)}',
                                  onTap: () => _chooseAccount(
                                    accounts,
                                    isDestination: false,
                                  ),
                                ),
                                const Divider(color: FinanceUi.line),
                              ],
                              _SettingRow(
                                icon: Icons.calendar_today_outlined,
                                label: '日期',
                                value:
                                    '${_occurredAt.year}年${_occurredAt.month}月${_occurredAt.day}日${DateUtils.isSameDay(_occurredAt, DateTime.now()) ? "（今天）" : ""}',
                                onTap: _pickDateTime,
                              ),
                              const Divider(color: FinanceUi.line),
                              TextField(
                                controller: _noteController,
                                onTap: () =>
                                    setState(() => _showNumberPad = false),
                                decoration: const InputDecoration(
                                  prefixIcon: Icon(
                                    Icons.notes_rounded,
                                    color: FinanceUi.ink,
                                    size: 21,
                                  ),
                                  hintText: '备注 · 写点什么吧…',
                                  fillColor: Colors.white,
                                  contentPadding: EdgeInsets.symmetric(
                                    vertical: 15,
                                    horizontal: 10,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 12),
                        if (widget.initialTransaction == null)
                          InkWell(
                            onTap: _openVoice,
                            borderRadius: BorderRadius.circular(22),
                            child: Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: FinanceUi.mint,
                                borderRadius: BorderRadius.circular(22),
                              ),
                              child: Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(10),
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(15),
                                    ),
                                    child: const Icon(
                                      Icons.mic_rounded,
                                      color: FinanceUi.teal,
                                      size: 25,
                                    ),
                                  ),
                                  const SizedBox(width: 10),
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '语音记账 · 试试这样说',
                                          style: TextStyle(
                                            color: FinanceUi.ink,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        SizedBox(height: 6),
                                        Text(
                                          '“早餐25元”  “午餐56”  “打车32块”',
                                          style: TextStyle(
                                            color: FinanceUi.muted,
                                            fontSize: 10,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.chevron_right,
                                    size: 18,
                                    color: FinanceUi.tealDark,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        if (widget.initialTransaction == null) ...[
                          const SizedBox(height: 10),
                          SizedBox(
                            width: MediaQuery.sizeOf(context).width - 40,
                            child: InkWell(
                              onTap: _openAi,
                              borderRadius: BorderRadius.circular(22),
                              child: Container(
                                padding: const EdgeInsets.all(14),
                                decoration: BoxDecoration(
                                  color: const Color(0xFFF1EAF8),
                                  borderRadius: BorderRadius.circular(22),
                                ),
                                child: const Row(
                                  children: [
                                    Icon(
                                      Icons.auto_awesome_outlined,
                                      color: Color(0xFF765A94),
                                      size: 30,
                                    ),
                                    SizedBox(width: 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'AI 记账 · 用一句话记多笔',
                                            style: TextStyle(
                                              color: FinanceUi.ink,
                                              fontSize: 13,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          SizedBox(height: 6),
                                          Text(
                                            '例如：今天午餐35元，咖啡18元',
                                            style: TextStyle(
                                              color: FinanceUi.muted,
                                              fontSize: 10,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    Icon(
                                      Icons.chevron_right,
                                      size: 18,
                                      color: Color(0xFF765A94),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                        if (widget.initialTransaction == null &&
                            !_showNumberPad &&
                            MediaQuery.viewInsetsOf(context).bottom == 0) ...[
                          const SizedBox(height: 14),
                          Center(
                            child: IconButton(
                              onPressed: _openVoice,
                              tooltip: '语音记账',
                              style: IconButton.styleFrom(
                                backgroundColor: Colors.white,
                                padding: const EdgeInsets.all(15),
                              ),
                              icon: const Icon(
                                Icons.mic_none_rounded,
                                color: FinanceUi.ink,
                                size: 27,
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '点击说话，识别后确认记入',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: FinanceUi.muted,
                              fontSize: 11,
                            ),
                          ),
                        ],
                        const SizedBox(height: 6),
                        _MoreOptions(
                          merchantController: _merchantController,
                          onTextFocus: () =>
                              setState(() => _showNumberPad = false),
                          isPlanned: _isPlanned,
                          isOneTime: _isOneTime,
                          isRecurring: _isRecurring,
                          tagsController: _tagsController,
                          attachments: _attachments,
                          onPlannedChanged: (value) =>
                              setState(() => _isPlanned = value),
                          onOneTimeChanged: (value) => setState(() {
                            _isOneTime = value;
                            if (value) _isRecurring = false;
                          }),
                          onRecurringChanged: (value) => setState(() {
                            _isRecurring = value;
                            if (value) _isOneTime = false;
                          }),
                          onAddAttachment: _pickAttachment,
                          onRemoveAttachment: (attachment) => setState(() {
                            _attachmentsChanged = true;
                            _attachments.remove(attachment);
                          }),
                        ),
                      ],
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : FinanceUi.motion,
                  curve: Curves.easeOutCubic,
                  child:
                      _showNumberPad &&
                          MediaQuery.viewInsetsOf(context).bottom == 0
                      ? Padding(
                          padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                          child: SizedBox(
                            height: 190,
                            child: _NumberPad(
                              isSaving: _isSaving,
                              onKey: (key) =>
                                  setState(() => _amount = _amount.enter(key)),
                              onBackspace: () =>
                                  setState(() => _amount = _amount.backspace()),
                              onDone: () =>
                                  setState(() => _showNumberPad = false),
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 10, 20, 14),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: FinanceUi.primaryGradient,
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: const [
                        BoxShadow(
                          color: Color(0x2200AC9E),
                          blurRadius: 18,
                          offset: Offset(0, 6),
                        ),
                      ],
                    ),
                    child: SizedBox(
                      width: double.infinity,
                      height: 54,
                      child: FilledButton(
                        key: const ValueKey('quick-done'),
                        onPressed: _isSaving
                            ? null
                            : () => _save(
                                sourceAccount: sourceAccount,
                                destinationAccount: destinationAccount,
                                selectedCategory: selectedCategory,
                              ),
                        style: FilledButton.styleFrom(
                          backgroundColor: Colors.transparent,
                          disabledBackgroundColor: Colors.transparent,
                          shadowColor: Colors.transparent,
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : Text(
                                widget.initialTransaction == null
                                    ? '保存记账'
                                    : '保存修改',
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openVoice() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceBookkeepingSheet(),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _openAi() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const VoiceBookkeepingSheet(textOnly: true),
    );
    if (saved == true && mounted) Navigator.pop(context);
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
        .where((category) => category.type == desiredType)
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
      setState(() => _categoryId = selected.id);
    }
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
              isDestination ? '选择转入账户' : '选择账户',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            ...available.map(
              (account) => ListTile(
                leading: const Icon(
                  Icons.account_balance_wallet_outlined,
                  color: AppColors.primary,
                ),
                title: Text(account.name),
                subtitle: Text(_accountTypeLabel(account.type)),
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

  Future<void> _pickAttachment() async {
    try {
      final attachment = await ref
          .read(attachmentStorageServiceProvider)
          .pickAndStore();
      if (attachment != null && mounted) {
        setState(() {
          _attachmentsChanged = true;
          _attachments.add(attachment);
        });
      }
    } on Object {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('附件读取失败，请重新选择')));
    }
  }

  Future<void> _save({
    required Account? sourceAccount,
    required Account? destinationAccount,
    required Category? selectedCategory,
  }) async {
    if (_isSaving) return;
    if (!_amount.isValid) {
      _showMessage('请输入有效金额');
      return;
    }
    if (sourceAccount == null) {
      _showMessage('请选择账户');
      return;
    }
    if (_type == TransactionType.transfer && destinationAccount == null) {
      _showMessage('请选择转入账户');
      return;
    }
    if (_type != TransactionType.transfer && selectedCategory == null) {
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
      final request = QuickBookkeepingRequest(
        type: _type,
        amount: _amount.amount!,
        currency: sourceAccount.currency,
        categoryId: _type == TransactionType.transfer
            ? null
            : selectedCategory!.id,
        subcategoryId: widget.initialTransaction?.subcategoryId,
        categoryName: _type == TransactionType.transfer
            ? null
            : selectedCategory!.name,
        accountId: sourceAccount.id,
        destinationAccountId: _type == TransactionType.transfer
            ? destinationAccount!.id
            : null,
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
      );
      final service = ref.read(quickBookkeepingServiceProvider);
      if (widget.initialTransaction == null) {
        await service.save(request);
      } else {
        await service.update(widget.initialTransaction!, request);
      }
      unawaited(HapticFeedback.lightImpact());
      if (!mounted) return;
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
}

class _TypeSelector extends StatelessWidget {
  const _TypeSelector({required this.selected, required this.onChanged});

  final TransactionType selected;
  final ValueChanged<TransactionType> onChanged;

  @override
  Widget build(BuildContext context) {
    return SlidingSegmentedControl<TransactionType>(
      items: const [
        (TransactionType.expense, '支出'),
        (TransactionType.income, '收入'),
        (TransactionType.transfer, '转账'),
      ],
      selected: selected,
      onChanged: onChanged,
      keyPrefix: 'quick-type',
      colors: selected == TransactionType.expense
          ? const [FinanceUi.coral, Color(0xFFFF9078)]
          : selected == TransactionType.transfer
          ? const [Color(0xFF5999EB), Color(0xFF81BAF8)]
          : const [FinanceUi.teal, Color(0xFF54D3BB)],
    );
  }
}

class _CategorySection extends StatelessWidget {
  const _CategorySection({
    required this.categories,
    required this.selected,
    required this.onSelected,
    required this.onMore,
  });

  final List<Category> categories;
  final Category? selected;
  final ValueChanged<Category> onSelected;
  final VoidCallback onMore;

  @override
  Widget build(BuildContext context) {
    final visible = categories.take(categories.length > 10 ? 9 : 10).toList();
    if (selected != null &&
        !visible.any((c) => c.id == selected!.id) &&
        visible.isNotEmpty) {
      visible[visible.length - 1] = selected!;
    }
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = MediaQuery.textScalerOf(context).scale(14) > 19 ? 4 : 5;
        final duration = MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : FinanceUi.motion;
        Widget item(
          String name,
          String iconName,
          bool active,
          VoidCallback onTap,
          Key key,
        ) => SizedBox(
          width: constraints.maxWidth / columns,
          child: Semantics(
            selected: active,
            button: true,
            child: InkWell(
              key: key,
              onTap: onTap,
              borderRadius: BorderRadius.circular(18),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 7),
                child: Column(
                  children: [
                    AnimatedScale(
                      scale: active ? 1.06 : 1,
                      duration: duration,
                      curve: Curves.easeOutCubic,
                      child: AnimatedContainer(
                        duration: duration,
                        padding: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          border: Border.all(
                            color: active
                                ? CategoryIcon.accentFor(
                                    name,
                                    iconKey: iconName,
                                  ).withValues(alpha: .5)
                                : Colors.transparent,
                            width: 1.5,
                          ),
                        ),
                        child: CategoryIcon(
                          category: name,
                          iconKey: iconName,
                          size: 42,
                          vivid: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11,
                        color: FinanceUi.ink,
                        fontWeight: active ? FontWeight.w600 : FontWeight.w400,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
        return Wrap(
          children: [
            ...visible.map(
              (category) => item(
                category.name,
                category.name,
                selected?.id == category.id,
                () => onSelected(category),
                ValueKey('quick-category-${category.id}'),
              ),
            ),
            if (categories.length > 10)
              item(
                '更多',
                '其他',
                false,
                onMore,
                const ValueKey('quick-more-categories'),
              ),
            if (categories.isEmpty)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text('暂无可用分类，请先在分类管理中添加'),
              ),
          ],
        );
      },
    );
  }
}

class _TransferAccounts extends StatelessWidget {
  const _TransferAccounts({
    required this.source,
    required this.destination,
    required this.onSourceTap,
    required this.onDestinationTap,
  });

  final Account? source;
  final Account? destination;
  final VoidCallback onSourceTap;
  final VoidCallback onDestinationTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _AccountButton(
            label: '转出',
            account: source,
            onTap: onSourceTap,
          ),
        ),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 10),
          child: Icon(Icons.arrow_forward, color: AppColors.primary),
        ),
        Expanded(
          child: _AccountButton(
            label: '转入',
            account: destination,
            onTap: onDestinationTap,
          ),
        ),
      ],
    );
  }
}

class _AccountButton extends StatelessWidget {
  const _AccountButton({
    required this.label,
    required this.account,
    required this.onTap,
  });

  final String label;
  final Account? account;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
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
            const SizedBox(height: 2),
            Text(
              account?.name ?? '请选择',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.label,
    required this.value,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final String value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
        ),
        child: Row(
          children: [
            Icon(icon, color: FinanceUi.ink, size: 21),
            const SizedBox(width: 9),
            Text(label),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                value,
                textAlign: TextAlign.right,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(color: FinanceUi.ink, fontSize: 12),
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

class _MoreOptions extends StatelessWidget {
  const _MoreOptions({
    required this.merchantController,
    required this.onTextFocus,
    required this.isPlanned,
    required this.isOneTime,
    required this.isRecurring,
    required this.tagsController,
    required this.attachments,
    required this.onPlannedChanged,
    required this.onOneTimeChanged,
    required this.onRecurringChanged,
    required this.onAddAttachment,
    required this.onRemoveAttachment,
  });

  final TextEditingController merchantController;
  final VoidCallback onTextFocus;
  final bool isPlanned;
  final bool isOneTime;
  final bool isRecurring;
  final TextEditingController tagsController;
  final List<StoredAttachment> attachments;
  final ValueChanged<bool> onPlannedChanged;
  final ValueChanged<bool> onOneTimeChanged;
  final ValueChanged<bool> onRecurringChanged;
  final VoidCallback onAddAttachment;
  final ValueChanged<StoredAttachment> onRemoveAttachment;

  @override
  Widget build(BuildContext context) {
    return ExpansionTile(
      tilePadding: const EdgeInsets.symmetric(horizontal: 4),
      childrenPadding: const EdgeInsets.only(bottom: 8),
      title: const Text('更多选项', style: TextStyle(fontSize: 14)),
      leading: const Icon(Icons.tune, color: AppColors.primary),
      children: [
        TextField(
          controller: merchantController,
          onTap: onTextFocus,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.storefront_outlined),
            hintText: '商户（可选）',
          ),
        ),
        const SizedBox(height: 8),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('计划内消费'),
          value: isPlanned,
          onChanged: onPlannedChanged,
        ),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('一次性消费'),
          value: isOneTime,
          onChanged: onOneTimeChanged,
        ),
        SwitchListTile.adaptive(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('周期消费'),
          value: isRecurring,
          onChanged: onRecurringChanged,
        ),
        TextField(
          controller: tagsController,
          onTap: onTextFocus,
          decoration: const InputDecoration(
            isDense: true,
            prefixIcon: Icon(Icons.sell_outlined),
            hintText: '标签，用逗号分隔',
          ),
        ),
        const SizedBox(height: 8),
        Align(
          alignment: Alignment.centerLeft,
          child: OutlinedButton.icon(
            onPressed: onAddAttachment,
            icon: const Icon(Icons.attach_file),
            label: const Text('添加附件'),
          ),
        ),
        ...attachments.map(
          (attachment) => ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.insert_drive_file_outlined),
            title: Text(
              attachment.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            trailing: IconButton(
              onPressed: () => onRemoveAttachment(attachment),
              icon: const Icon(Icons.close),
              tooltip: '移除附件',
            ),
          ),
        ),
      ],
    );
  }
}

class _NumberPad extends StatelessWidget {
  const _NumberPad({
    required this.isSaving,
    required this.onKey,
    required this.onBackspace,
    required this.onDone,
  });

  final bool isSaving;
  final ValueChanged<String> onKey;
  final VoidCallback onBackspace;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    const rows = [
      ['1', '2', '3'],
      ['4', '5', '6'],
      ['7', '8', '9'],
    ];
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          flex: 3,
          child: Column(
            children: [
              ...rows.map(
                (row) => Expanded(
                  child: Row(
                    children: row
                        .map(
                          (key) => Expanded(
                            child: _NumberKey(
                              label: key,
                              onTap: () => onKey(key),
                            ),
                          ),
                        )
                        .toList(),
                  ),
                ),
              ),
              Expanded(
                child: Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: _NumberKey(label: '0', onTap: () => onKey('0')),
                    ),
                    Expanded(
                      child: _NumberKey(label: '.', onTap: () => onKey('.')),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 6),
        Expanded(
          child: Column(
            children: [
              Expanded(
                child: _NumberKey(
                  icon: Icons.backspace_outlined,
                  onTap: onBackspace,
                  semanticLabel: '删除金额数字',
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                flex: 3,
                child: SizedBox.expand(
                  child: FilledButton(
                    key: const ValueKey('quick-keyboard-done'),
                    onPressed: isSaving ? null : onDone,
                    style: FilledButton.styleFrom(
                      backgroundColor: FinanceUi.teal,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: isSaving
                        ? const SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('收起'),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _NumberKey extends StatelessWidget {
  const _NumberKey({
    required this.onTap,
    this.label,
    this.icon,
    this.semanticLabel,
  });

  final String? label;
  final IconData? icon;
  final String? semanticLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(2.5),
      child: Semantics(
        label: semanticLabel,
        button: true,
        child: InkWell(
          key: label == null ? null : ValueKey('amount-key-$label'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(14),
          child: Ink(
            decoration: BoxDecoration(
              color: AppColors.surfaceSoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: icon != null
                  ? Icon(icon, color: AppColors.textPrimary)
                  : Text(
                      label!,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
            ),
          ),
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
