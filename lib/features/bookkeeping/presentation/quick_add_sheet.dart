import 'package:image_picker/image_picker.dart';
import 'package:open_filex/open_filex.dart';

import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_media_picker.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/models/recurring_bill.dart';
import '../../../core/utils/entity_id.dart';
import '../../recurring/data/recurring_bill_repository.dart';
import '../../recurring/application/recurring_bill_notification_service.dart';
import '../../recurring/presentation/recurring_bill_create_sheet.dart';
import 'components/number_keyboard.dart';
import 'components/category_grid.dart';

import 'dart:async';

import 'components/amount_input_view.dart';
import 'components/time_selector.dart';
import 'components/business_fields.dart';

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
import '../../../core/models/family.dart';
import '../../categories/presentation/category_management_page.dart';
import '../../family/data/shared_family_service.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/book_color_dot.dart';
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
    this.copyFrom,
    this.initialType = TransactionType.expense,
    this.initialOccurredAt,
    this.initialBookId,
  });

  final TransactionType initialType;

  final TransactionRecord? initialTransaction;
  final TransactionRecord? copyFrom;
  final DateTime? initialOccurredAt;
  final String? initialBookId;

  @override
  ConsumerState<QuickAddSheet> createState() => _QuickAddSheetState();
}

/// Opens the bookkeeping sheet above the app shell.
///
/// Pages rendered by [ShellRoute] have their own navigator below the root
/// navigator. Using that nested navigator leaves the shell's bottom bar above
/// the modal route, so the bar can remain visible over the keypad. All entry
/// points use this helper to keep the stacking order consistent.
Future<void> showQuickAddSheet(
  BuildContext context, {
  TransactionRecord? initialTransaction,
  TransactionRecord? copyFrom,
  TransactionType initialType = TransactionType.expense,
  DateTime? initialOccurredAt,
  String? initialBookId,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    useRootNavigator: true,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => QuickAddSheet(
      initialTransaction: initialTransaction,
      copyFrom: copyFrom,
      initialType: initialType,
      initialOccurredAt: initialOccurredAt,
      initialBookId: initialBookId,
    ),
  );
}

class _QuickAddSheetState extends ConsumerState<QuickAddSheet> {
  final _invoiceController = TextEditingController();
  final _customerController = TextEditingController();
  final _projectController = TextEditingController();
  final _supplierController = TextEditingController();

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
  String? _payerUserId;
  String? _payerLabel;
  bool _payerLabelLoading = false;
  DateTime _occurredAt = DateTime.now();
  bool _isPlanned = false;
  bool _isOneTime = true;
  bool _isRecurring = false;
  RecurringBill? _recurringDraft;
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
    final transaction = widget.initialTransaction ?? widget.copyFrom;
    _type = widget.initialType;
    if (_type == TransactionType.borrow ||
        _type == TransactionType.lend ||
        _type == TransactionType.repayment) {
      _debtType = _type;
    }
    _bookId = transaction?.bookId ?? widget.initialBookId ?? ref.read(activeBookIdProvider);
    if (transaction == null) {
      final initialDate = widget.initialOccurredAt;
      if (initialDate != null) {
        final now = DateTime.now();
        _occurredAt = DateTime(
          initialDate.year,
          initialDate.month,
          initialDate.day,
          now.hour,
          now.minute,
        );
      }
      return;
    }
    final formula = _decodeMetadata(transaction.metadataJson)['formula'];
    final restoredAmount = AmountInput(formula is String ? formula : '');
    _amount =
        restoredAmount.isValid && restoredAmount.amount == transaction.amount
        ? restoredAmount
        : AmountInput(transaction.amount.toStringAsFixed(2));
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
    _payerUserId = transaction.userId;
    if (_payerUserId != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _restorePayerLabel());
    }
    _occurredAt = transaction.occurredAt;
    _isPlanned = transaction.isPlanned;
    _isOneTime = transaction.isOneTime;
    _isRecurring = transaction.isRecurring;
    _merchantController.text = transaction.merchant ?? '';
    _noteController.text = transaction.note ?? '';
    _reimbursementStatus = transaction.reimbursementStatus;
    _reimbursementNoteController.text = transaction.reimbursementNote ?? '';
    final metadata = _decodeMetadata(transaction.metadataJson);
    final business = metadata['business'];
    if (business is Map) {
      _invoiceController.text = business['invoice']?.toString() ?? '';
      _customerController.text = business['customer']?.toString() ?? '';
      _projectController.text = business['project']?.toString() ?? '';
      _supplierController.text = business['supplier']?.toString() ?? '';
    }
    final tags = metadata['tags'];
    if (tags is List) {
      _tagsController.text = tags.map((item) => item.toString()).join(', ');
    }
    if (widget.copyFrom != null) {
      _occurredAt = DateTime.now();
      _isRecurring = false;
      _isOneTime = true;
      _reimbursementStatus = ReimbursementStatus.none;
      _reimbursementNoteController.clear();
      return;
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
            StoredAttachment(
              name: attachment.name,
              path: attachment.path,
              sizeInBytes: attachment.sizeInBytes,
            ),
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
    _invoiceController.dispose();
    _customerController.dispose();
    _projectController.dispose();
    _supplierController.dispose();
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
      // Keep the sheet background opaque through the system gesture area.
      // The keypad gets its own inner SafeArea below, so controls stay clear
      // without exposing the app shell/navigation underneath the modal.
      bottom: false,
      // Modal routes may remove MediaQuery's top padding. Read the actual
      // window inset so every entry point stays below the status bar.
      minimum: EdgeInsets.only(
        top: MediaQueryData.fromView(View.of(context)).padding.top + 8,
      ),
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: FractionallySizedBox(
          heightFactor: 1,
          child: Material(
            key: const ValueKey('quick-sheet-surface'),
            color: const Color(0xFFF8F7F1),
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
                  child: LayoutBuilder(
                    builder: (context, constraints) => SingleChildScrollView(
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
                            SizedBox(
                              height: (constraints.maxHeight - 242).clamp(
                                150.0,
                                360.0,
                              ),
                              child: CategoryGrid(
                                categories: activeCategories,
                                selected: selectedCategory,
                                subcategories: subcategories,
                                selectedSubcategoryId: effectiveSubcategoryId,
                                onSelected: (category) => setState(() {
                                  _categoryId = category.id;
                                  _subcategoryId = null;
                                }),
                                onSubcategorySelected: (category) => setState(
                                  () => _subcategoryId = category.id,
                                ),
                              ),
                            )
                          else
                            _AccountPairCard(
                              isRepayment: _type == TransactionType.repayment,
                              source: sourceAccount,
                              destination: destinationAccount,
                              onSourceTap: () => _chooseAccount(
                                accounts,
                                isDestination: false,
                              ),
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
                ),
                if (!keyboardVisible)
                  SafeArea(
                    top: false,
                    child: NumberKeyboard(
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
                      ),
                      onRepeat: _resetForNextEntry,
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
    return TextButton(
      key: const ValueKey('quick-edit-categories'),
      style: TextButton.styleFrom(
        backgroundColor: AppColors.primarySoft,
        foregroundColor: AppColors.textPrimary,
        padding: EdgeInsets.zero,
      ),
      onPressed: () => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => Scaffold(
            backgroundColor: AppColors.background,
            body: CategoryManagementPage(
              bookId: _bookId,
              onBack: () => Navigator.of(context).pop(),
            ),
          ),
        ),
      ),
      child: const Text('编辑'),
    );
  }

  Widget _buildDetailCard(
    BuildContext context, {
    required AmountInput input,
    required List<Account> accounts,
    required LedgerBook? selectedBook,
    required Account? sourceAccount,
  }) {
    return Container(
      key: const ValueKey('quick-detail-card'),
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _NoteRow(
            controller: _noteController,
            onAi: _openAi,
            onVoice: _openVoice,
          ),
          const SizedBox(height: 10),
          AmountInputView(
            input: input,
            currency: _currencySymbol(sourceAccount),
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
                  // 账户、报销状态、账本在进页面时就已有确定取值，
                  // 因此默认就呈选中态，而不是等用户改过才高亮。
                  selected: sourceAccount != null,
                  showChevron: true,
                  onTap: () => _chooseAccount(accounts, isDestination: false),
                ),
              if (_supportsReimbursement)
                _QuickChip(
                  key: const ValueKey('quick-reimbursement-chip'),
                  label: _reimbursementLabel,
                  icon: Icons.receipt_long_outlined,
                  // 「不报销」本身也是一个已确定的选择。
                  selected: true,
                  showChevron: true,
                  onTap: _pickReimbursement,
                ),
              if (selectedBook?.type == BookType.family &&
                  selectedBook?.isShared == true)
                _QuickChip(
                  key: const ValueKey('quick-family-payer-chip'),
                  label: _payerLabel ?? '本人付款',
                  icon: Icons.person_outline_rounded,
                  selected: true,
                  showChevron: true,
                  onTap: () => _chooseFamilyPayer(selectedBook!),
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
                  selected: selectedBook != null,
                  showChevron: true,
                  onTap: () =>
                      _chooseBook(ref.read(booksProvider).value ?? const []),
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
                  selected: selectedBook != null,
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
                label: _dateChipLabel,
                icon: Icons.calendar_today_outlined,
                selected: true,
                onTap: _pickDateTime,
              ),
              _QuickChip(
                key: const ValueKey('quick-recurring-chip'),
                label: '定期付',
                icon: Icons.schedule_outlined,
                selected: _isRecurring,
                onTap: _configureRecurring,
              ),
            ],
          ),
          if (_recurringDraft != null)
            Padding(
              padding: const EdgeInsets.only(top: 8, left: 4),
              child: Text(
                '已设置${_recurringDraft!.scheduleLabel}，点击完成会同时保存首笔流水和周期规则',
                key: const ValueKey('quick-recurring-summary'),
                style: const TextStyle(
                  fontSize: 12,
                  color: AppColors.primaryDark,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          if (selectedBook?.type == BookType.enterprise)
            BusinessFields(
              invoice: _invoiceController,
              customer: _customerController,
              project: _projectController,
              supplier: _supplierController,
            ),
        ],
      ),
    );
  }

  Future<void> _restorePayerLabel() async {
    if (_payerLabelLoading || _payerUserId == null || !mounted) return;
    final books = ref.read(booksProvider).value ?? const <LedgerBook>[];
    final book = books.where((item) => item.id == _bookId).firstOrNull;
    if (book == null || book.type != BookType.family || !book.isShared) return;
    _payerLabelLoading = true;
    try {
      final members = await ref
          .read(familyServiceProvider)
          .memberDetails(book.sharedId!);
      if (!mounted) return;
      final payer = members
          .where((member) => member['user_id'] == _payerUserId)
          .firstOrNull;
      setState(() {
        if (payer == null) {
          _payerLabel = '已退出成员付款';
        } else {
          final displayName =
              (payer['display_name'] as String?)?.trim().isNotEmpty == true
              ? payer['display_name'] as String
              : payer['username'] as String;
          _payerLabel = '$displayName付款';
        }
      });
    } on Object {
      // Attribution itself remains intact. A temporary member-list failure must
      // never rewrite an existing transaction's payer.
    } finally {
      _payerLabelLoading = false;
    }
  }

  Future<void> _chooseFamilyPayer(LedgerBook book) async {
    final sharedId = book.sharedId;
    if (sharedId == null) return;
    try {
      final service = ref.read(familyServiceProvider);
      final members = await service.memberDetails(sharedId);
      if (!mounted) return;
      final selected = await showModalBottomSheet<Map<String, dynamic>>(
        context: context,
        backgroundColor: AppColors.surface,
        showDragHandle: true,
        builder: (context) => SafeArea(
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
            children: [
              const Padding(
                padding: EdgeInsets.fromLTRB(16, 4, 16, 8),
                child: Text(
                  '这笔钱由谁支付？',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ),
              for (final member in members)
                ListTile(
                  leading: const CircleAvatar(
                    child: Icon(Icons.person_outline_rounded),
                  ),
                  title: Text(
                    (member['display_name'] as String?)?.trim().isNotEmpty == true
                        ? member['display_name'] as String
                        : member['username'] as String,
                  ),
                  subtitle: Text(switch (member['role']) {
                    'owner' => '所有者',
                    'admin' => '管理员',
                    _ => '家庭成员',
                  }),
                  trailing: member['user_id'] == _payerUserId
                      ? const Icon(Icons.check, color: AppColors.primary)
                      : null,
                  onTap: () => Navigator.pop(context, member),
                ),
            ],
          ),
        ),
      );
      if (selected == null || !mounted) return;
      final name =
          (selected['display_name'] as String?)?.trim().isNotEmpty == true
          ? selected['display_name'] as String
          : selected['username'] as String;
      setState(() {
        _payerUserId = selected['user_id'] as String;
        _payerLabel = '$name付款';
      });
    } on Object {
      if (mounted) _showMessage('家庭成员加载失败，请稍后重试');
    }
  }

  String get _reimbursementLabel =>
      _reimbursementLabelFor(_reimbursementStatus);

  String get _dateChipLabel {
    final now = DateTime.now();
    if (DateUtils.isSameDay(_occurredAt, now)) return '今天';
    final yesterday = DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(const Duration(days: 1));
    if (DateUtils.isSameDay(_occurredAt, yesterday)) return '昨天';
    return '${_occurredAt.month}/${_occurredAt.day}';
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

  String _reimbursementLabelFor(ReimbursementStatus status) => switch (status) {
    ReimbursementStatus.none => '不报销',
    ReimbursementStatus.pending => '待报销',
    ReimbursementStatus.reimbursed => '已报销',
    ReimbursementStatus.partial => '部分报销',
  };

  Future<void> _openVoice() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceBookkeepingSheet(bookId: _bookId),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _openAi() async {
    final saved = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => VoiceBookkeepingSheet(textOnly: true, bookId: _bookId),
    );
    if (saved == true && mounted) Navigator.pop(context);
  }

  Future<void> _onAttachmentChip() => _openAttachmentManager(images: false);

  Future<void> _openAttachmentManager({required bool images}) async {
    await AppBottomSheet.show<void>(
      context: context,
      builder: (sheet) => StatefulBuilder(
        builder: (context, refresh) {
          final entries = _attachments
              .where((a) => a.isImage == images)
              .toList();
          return Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '${images ? '图片' : '附件'} ${entries.length} · 合计最多 4 项',
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Text('文件保存在本机；保存失败可重试，表单会保留。'),
                if (_attachmentsBusy) const LinearProgressIndicator(),
                for (final attachment in entries)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Column(
                      children: [
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: SizedBox(
                            width: 48,
                            height: 48,
                            child: _AttachmentThumbnail(attachment: attachment),
                          ),
                          title: Text(
                            attachment.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(
                            '${attachment.sizeInBytes == null ? '' : '${(attachment.sizeInBytes! / 1024).toStringAsFixed(1)} KB · '}${switch (attachment.status) {
                              AttachmentUploadStatus.idle => '待保存',
                              AttachmentUploadStatus.uploading => '保存中…',
                              AttachmentUploadStatus.uploaded => '已保存',
                              AttachmentUploadStatus.failed => attachment.errorMessage ?? '保存失败',
                            }}',
                          ),
                        ),
                        Wrap(
                          spacing: 8,
                          children: [
                            if (attachment.status ==
                                AttachmentUploadStatus.failed)
                              TextButton.icon(
                                icon: const Icon(Icons.refresh),
                                label: const Text('重新保存'),
                                onPressed: _attachmentsBusy
                                    ? null
                                    : () async {
                                        await _retryAttachment(attachment);
                                        if (context.mounted) refresh(() {});
                                      },
                              ),
                            if (attachment.status ==
                                AttachmentUploadStatus.uploaded)
                              TextButton.icon(
                                icon: const Icon(Icons.open_in_new),
                                label: const Text('查看'),
                                onPressed: () async {
                                  final result = await OpenFilex.open(
                                    attachment.path,
                                  );
                                  if (result.type != ResultType.done && mounted)
                                    _showMessage(result.message);
                                },
                              ),
                            TextButton.icon(
                              icon: const Icon(Icons.swap_horiz),
                              label: const Text('重新选择'),
                              onPressed: _attachmentsBusy
                                  ? null
                                  : () async {
                                      await _replaceAttachment(attachment);
                                      if (context.mounted) refresh(() {});
                                    },
                            ),
                            TextButton.icon(
                              icon: const Icon(Icons.close),
                              label: const Text('删除'),
                              onPressed: _attachmentsBusy
                                  ? null
                                  : () {
                                      setState(() {
                                        _attachments.remove(attachment);
                                        _attachmentsChanged = true;
                                      });
                                      refresh(() {});
                                    },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                FilledButton.icon(
                  icon: Icon(
                    images ? Icons.photo_library_outlined : Icons.attach_file,
                  ),
                  label: Text(images ? '从相册选择' : '选择文件'),
                  onPressed: _attachmentsBusy || _attachments.length >= 4
                      ? null
                      : () async {
                          await _pickAttachment(
                            type: images ? FileType.image : FileType.any,
                            imageSource: images ? ImageSource.gallery : null,
                          );
                          if (context.mounted) refresh(() {});
                        },
                ),
                if (images)
                  TextButton.icon(
                    icon: const Icon(Icons.camera_alt_outlined),
                    label: const Text('拍照'),
                    onPressed: _attachmentsBusy || _attachments.length >= 4
                        ? null
                        : () async {
                            await _pickAttachment(
                              type: FileType.image,
                              imageSource: ImageSource.camera,
                            );
                            if (context.mounted) refresh(() {});
                          },
                  ),
              ],
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
    return accounts
            .where((item) => item.type == AccountType.wechat)
            .firstOrNull ??
        accounts.firstOrNull;
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

  Future<void> _chooseBook(List<LedgerBook> books) async {
    final selected = await showBookChoiceSheet(
      context,
      books: books,
      selectedId: _bookId ?? ref.read(activeBookIdProvider),
    );
    if (selected == null || !mounted) return;
    setState(() {
      _invoiceController.clear();
      _customerController.clear();
      _projectController.clear();
      _supplierController.clear();
      _bookId = selected.id;
      _categoryId = null;
      _subcategoryId = null;
      _accountId = null;
      _destinationAccountId = null;
      // Payer attribution belongs to a specific shared family ledger.
      // Never carry it across ledger switches.
      _payerUserId = null;
      _payerLabel = null;
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

  Future<void> _configureRecurring() async {
    if (_type != TransactionType.expense && _type != TransactionType.income) {
      _showMessage('周期账单支持支出和收入');
      return;
    }
    final activeBookId = ref.read(activeBookIdProvider);
    final selectedBookId = _bookId ?? activeBookId;
    final accounts = selectedBookId == activeBookId
        ? ref.read(accountsProvider).value ?? const <Account>[]
        : ref.read(accountsByBookProvider(selectedBookId)).value ??
              const <Account>[];
    final categories = selectedBookId == activeBookId
        ? ref.read(categoriesProvider).value ?? const <Category>[]
        : ref.read(categoriesByBookProvider(selectedBookId)).value ??
              const <Category>[];
    final sourceAccount = _selectedAccount(accounts, _accountId);
    final activeCategories = _sortedCategories(categories, const []);
    final selectedCategory = _selectedCategory(activeCategories);
    if (sourceAccount == null || selectedCategory == null) {
      _showMessage('请先选择扣款账户和分类');
      return;
    }
    final subcategoryId =
        categories.any(
          (category) =>
              category.id == _subcategoryId &&
              category.parentId == selectedCategory.id,
        )
        ? _subcategoryId
        : null;
    final now = DateTime.now();
    final draft = _recurringDraft ?? await _linkedRecurringBill();
    if (!mounted) return;
    final bill = RecurringBill(
      id: draft?.id ?? 'recurring-${newEntityId()}',
      bookId: selectedBookId,
      name: _merchantController.text.trim().isEmpty
          ? selectedCategory.name
          : _merchantController.text.trim(),
      type: _type == TransactionType.income
          ? RecurringBillType.income
          : RecurringBillType.other,
      amount: _amount.amount ?? 0,
      cycle: draft?.cycle ?? RecurringBillCycle.monthly,
      startDate: draft?.startDate ?? _occurredAt,
      endDate: draft?.endDate,
      nextDate: draft?.nextDate ?? _occurredAt,
      accountId: sourceAccount.id,
      categoryId: selectedCategory.id,
      subcategoryId: subcategoryId,
      interval: draft?.interval ?? 1,
      weekday: draft?.weekday,
      dayOfMonth: draft?.dayOfMonth,
      month: draft?.month,
      repeatCount: draft?.repeatCount,
      completedCount: draft?.completedCount ?? 0,
      reminderDays: draft?.reminderDays ?? 1,
      customIntervalDays: draft?.customIntervalDays,
      autoRecord: draft?.autoRecord ?? false,
      reminder: draft?.reminder ?? true,
      status: draft?.status ?? RecurringBillStatus.active,
      createdAt: draft?.createdAt ?? now,
      updatedAt: now,
    );
    final result = await RecurringBillCreateSheet.showRules(
      context,
      bill,
      onDisable: draft == null || widget.initialTransaction != null
          ? null
          : () => setState(() {
              _recurringDraft = null;
              _isRecurring = false;
              _isOneTime = true;
            }),
    );
    if (result != null && mounted)
      setState(() {
        _recurringDraft = result;
        _isRecurring = true;
        _isOneTime = false;
      });
  }

  Future<RecurringBill?> _linkedRecurringBill() async {
    final transaction = widget.initialTransaction;
    if (transaction == null) return null;
    final metadata = _decodeMetadata(transaction.metadataJson);
    final id = metadata['recurring_bill_id'];
    if (id is! String || id.isEmpty) return null;
    final bills = await ref.read(recurringBillsAllProvider.future);
    return bills.where((bill) => bill.id == id).firstOrNull;
  }

  Future<void> _pickDateTime() async {
    final value = await TimeSelector.show(context, _occurredAt);
    if (value != null && mounted) setState(() => _occurredAt = value);
  }

  Future<void> _pickImageAttachment() => _openAttachmentManager(images: true);

  Future<void> _pickAttachment({
    FileType type = FileType.any,
    ImageSource? imageSource,
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
      final storage = ref.read(attachmentStorageServiceProvider);
      final attachment = imageSource == ImageSource.gallery
          ? await AppImagePicker.gallery(storage)
          : imageSource == ImageSource.camera
          ? await AppImagePicker.camera(storage)
          : await AppFilePicker.pick(storage);
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
          .pickAndStore(type: existing.isImage ? FileType.image : FileType.any);
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
      _showMessage(_type == TransactionType.repayment ? '请选择债务账户' : '请选择转入账户');
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
        payerUserId:
            ref
                    .read(booksProvider)
                    .value
                    ?.where((book) => book.id == bookId)
                    .firstOrNull
                    ?.type ==
                BookType.family
            ? _payerUserId
            : null,
        type: _type,
        amount: _amount.amount!,
        metadata: {
          'formula': _amount.value,
          'amount_formula': _amount.value,
          if (_recurringDraft != null) 'recurring_bill_id': _recurringDraft!.id,
          'transaction_date':
              '${_occurredAt.year}-${_occurredAt.month.toString().padLeft(2, '0')}-${_occurredAt.day.toString().padLeft(2, '0')}',
          'transaction_time':
              '${_occurredAt.hour.toString().padLeft(2, '0')}:${_occurredAt.minute.toString().padLeft(2, '0')}',
          'timezone_offset_minutes': _occurredAt.timeZoneOffset.inMinutes,
          'business':
              ref
                      .read(booksProvider)
                      .value
                      ?.where((book) => book.id == bookId)
                      .firstOrNull
                      ?.type ==
                  BookType.enterprise
              ? {
                  'invoice': _invoiceController.text.trim(),
                  'customer': _customerController.text.trim(),
                  'project': _projectController.text.trim(),
                  'supplier': _supplierController.text.trim(),
                }
              : null,
        },
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
        if (_recurringDraft == null) {
          await service.save(request);
        } else {
          final draft = _recurringDraft!;
          if (_type != TransactionType.expense &&
              _type != TransactionType.income) {
            throw ArgumentError('周期账单仅支持收入和支出');
          }
          var next = draft.firstOccurrence();
          final currentDay = DateTime(
            _occurredAt.year,
            _occurredAt.month,
            _occurredAt.day,
          );
          while (!next.isAfter(currentDay)) {
            next = draft.nextOccurrence(next);
          }
          final ended =
              (draft.repeatCount != null && draft.repeatCount! <= 1) ||
              (draft.endDate != null && next.isAfter(draft.endDate!));
          final plan = RecurringBill(
            id: draft.id,
            bookId: bookId,
            name: _merchantController.text.trim().isNotEmpty
                ? _merchantController.text.trim()
                : selectedCategory!.name,
            type: _type == TransactionType.income
                ? RecurringBillType.income
                : RecurringBillType.other,
            amount: request.amount,
            cycle: draft.cycle,
            startDate: draft.startDate,
            endDate: draft.endDate,
            nextDate: next,
            accountId: sourceAccount.id,
            categoryId: request.categoryId,
            subcategoryId: request.subcategoryId,
            interval: draft.interval,
            weekday: draft.weekday,
            dayOfMonth: draft.dayOfMonth,
            month: draft.month,
            repeatCount: draft.repeatCount,
            completedCount: 1,
            reminderDays: draft.reminderDays,
            reminder: draft.reminder,
            autoRecord: draft.autoRecord,
            customIntervalDays: draft.customIntervalDays,
            status: ended
                ? RecurringBillStatus.ended
                : RecurringBillStatus.active,
            createdAt: draft.createdAt,
            updatedAt: DateTime.now(),
          );
          await RecurringBillExecutionService(
            ref.read(databaseProvider),
            service,
            ref.read(transactionRepositoryProvider),
            DriftRecurringBillRepository(
              ref.read(databaseProvider),
              bookId: bookId,
            ),
          ).createWithInitial(plan, request);
          unawaited(_syncRecurringNotification(plan));
          ref.invalidate(recurringBillsAllProvider);
        }
      } else {
        await service.update(widget.initialTransaction!, request);
        final draft = _recurringDraft;
        if (draft != null) {
          final repository = DriftRecurringBillRepository(
            ref.read(databaseProvider),
            bookId: bookId,
          );
          final existing = (await repository.getAll())
              .where((bill) => bill.id == draft.id)
              .firstOrNull;
          final updated = RecurringBill(
            id: draft.id,
            bookId: bookId,
            name: _merchantController.text.trim().isNotEmpty
                ? _merchantController.text.trim()
                : selectedCategory!.name,
            type: _type == TransactionType.income
                ? RecurringBillType.income
                : RecurringBillType.other,
            amount: request.amount,
            cycle: draft.cycle,
            startDate: draft.startDate,
            endDate: draft.endDate,
            nextDate: draft.nextDate,
            accountId: sourceAccount.id,
            categoryId: request.categoryId,
            subcategoryId: request.subcategoryId,
            interval: draft.interval,
            weekday: draft.weekday,
            dayOfMonth: draft.dayOfMonth,
            month: draft.month,
            repeatCount: draft.repeatCount,
            completedCount: draft.completedCount,
            reminderDays: draft.reminderDays,
            reminder: draft.reminder,
            autoRecord: draft.autoRecord,
            customIntervalDays: draft.customIntervalDays,
            status: draft.status,
            createdAt: draft.createdAt,
            updatedAt: DateTime.now(),
          );
          if (existing == null) {
            await repository.create(updated);
          } else {
            await repository.update(updated);
          }
          unawaited(_syncRecurringNotification(updated));
          ref.invalidate(recurringBillsAllProvider);
        }
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

  Future<void> _syncRecurringNotification(RecurringBill bill) async {
    try {
      final scheduler = ref.read(recurringBillNotificationSchedulerProvider);
      if (bill.reminder) await scheduler.requestPermission();
      await scheduler.syncBill(bill);
    } on Object catch (error) {
      debugPrint('周期账单通知同步失败：$error');
    }
  }

  void _resetForNextEntry({String? showMessage}) {
    if (!mounted || _isSaving) return;
    setState(() {
      _amount = const AmountInput();
      _occurredAt = DateTime.now();
      _isRecurring = false;
      _recurringDraft = null;
      _isOneTime = true;
      _reimbursementStatus = ReimbursementStatus.none;
      _categoryId = null;
      _subcategoryId = null;
      _amountError = false;
      _invoiceController.clear();
      _customerController.clear();
      _projectController.clear();
      _supplierController.clear();
      _noteController.clear();
      _merchantController.clear();
      _tagsController.clear();
      _reimbursementNoteController.clear();
      _attachments.clear();
      _attachmentsChanged = false;
    });
    if (showMessage != null) _showMessage(showMessage);
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
  AccountType.creditCard => (
    Icons.credit_card_rounded,
    const Color(0xFFEF789E),
  ),
  AccountType.liability => (Icons.trending_down_rounded, AppColors.warning),
  _ => (Icons.account_balance_wallet_outlined, AppColors.textSecondary),
};

String _transactionTypeLabel(TransactionType type) => switch (type) {
  TransactionType.assetSale => '资产卖出',
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

/// 备注行：常规字号下是「备注 + AI + 麦克风」一行；
/// 大字号/窄屏下 AI 与麦克风换到第二行，避免备注输入框被挤成一个字。
class _NoteRow extends StatelessWidget {
  const _NoteRow({
    required this.controller,
    required this.onAi,
    required this.onVoice,
  });

  final TextEditingController controller;
  final VoidCallback onAi;
  final VoidCallback onVoice;

  @override
  Widget build(BuildContext context) {
    final stacks = MediaQuery.textScalerOf(context).scale(14) > 19;
    final field = SizedBox(
      height: 40,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
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
              controller: controller,
              minLines: 1,
              maxLines: 1,
              textAlignVertical: TextAlignVertical.center,
              onTapOutside: (_) =>
                  FocusManager.instance.primaryFocus?.unfocus(),
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
              decoration: const InputDecoration(
                // This is an integrated row, not a standalone form field.
                // Explicitly neutralize the app-wide 52dp outlined field theme
                // so the note area stays borderless and compact like the
                // reference bookkeeping card.
                isDense: true,
                isCollapsed: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                disabledBorder: InputBorder.none,
                errorBorder: InputBorder.none,
                focusedErrorBorder: InputBorder.none,
                hintText: '添加备注...',
                hintStyle: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
                contentPadding: EdgeInsets.zero,
                constraints: BoxConstraints.tightFor(height: 40),
              ),
            ),
          ),
        ],
      ),
    );
    final aiAction = _QuickChip(
      key: const ValueKey('quick-ai-entry'),
      label: 'AI帮我记',
      icon: Icons.auto_awesome_outlined,
      iconColor: AppColors.primaryDark,
      selected: true,
      height: 36,
      horizontalPadding: 6,
      iconGap: 4,
      fontSize: 12,
      onTap: onAi,
    );
    final voiceAction = _NoteIconAction(
      key: const ValueKey('quick-voice-entry'),
      icon: Icons.mic_none_rounded,
      tooltip: '语音记账',
      onTap: onVoice,
    );
    final actions = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        aiAction,
        const SizedBox(width: 4),
        voiceAction,
      ],
    );

    if (stacks) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          field,
          const SizedBox(height: 8),
          Align(alignment: Alignment.centerRight, child: actions),
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Expanded(child: field),
        const SizedBox(width: 6),
        actions,
      ],
    );
  }
}

class _NoteIconAction extends StatelessWidget {
  const _NoteIconAction({
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

class _ChipRow extends StatelessWidget {
  const _ChipRow({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.textScalerOf(context).scale(12.5) <= 15) {
      return Row(
        children: [
          for (var index = 0; index < children.length; index++) ...[
            if (index > 0) const SizedBox(width: 8),
            Expanded(child: children[index]),
          ],
        ],
      );
    }
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
    this.height = 40,
    this.horizontalPadding = 8,
    this.iconGap = 6,
    this.fontSize = 12.5,
    this.onTap,
  });

  final String label;
  final IconData? icon;
  final Color? iconColor;
  final Widget? leading;
  final bool selected;
  final bool showChevron;
  final double height;
  final double horizontalPadding;
  final double iconGap;
  final double fontSize;
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
          height: height,
          padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: selected ? AppColors.primary : AppColors.divider,
              width: selected ? 1.2 : 1,
            ),
          ),
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (leading != null) ...[
                  leading!,
                  SizedBox(width: iconGap),
                ] else if (icon != null) ...[
                  Icon(
                    icon,
                    size: 16,
                    color: iconColor ?? AppColors.textSecondary,
                  ),
                  SizedBox(width: iconGap),
                ],
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 120),
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: fontSize,
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
      ),
    );
  }
}

/// The always-visible calculator keypad that replaces the old save button.
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
