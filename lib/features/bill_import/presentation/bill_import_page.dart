import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../accounts/data/account_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../application/bill_import_category_mapper.dart';
import '../application/bill_import_duplicate_index.dart';
import '../application/bill_import_service.dart';
import '../../../app/theme/app_theme_tokens.dart';

class BillImportPage extends ConsumerStatefulWidget {
  const BillImportPage({super.key});

  @override
  ConsumerState<BillImportPage> createState() => _BillImportPageState();
}

class _BillImportPageState extends ConsumerState<BillImportPage> {
  BillImportResult? _result;
  Set<int> _selected = {};
  String? _accountId;
  String? _expenseCategoryId;
  String? _incomeCategoryId;
  final Map<String, String?> _accountMappings = {};
  final Map<int, String> _rowSourceAccountOverrides = {};
  final Map<int, String> _rowDestinationAccountOverrides = {};
  bool _preserveCurrentBalances = true;
  String? _fileName;
  bool _loading = false;
  bool _saving = false;
  String? _error;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    _initializeSelections(accounts, categories);

    return SafeArea(
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    Row(
                      children: [
                        IconButton(
                          onPressed: context.pop,
                          icon: const Icon(Icons.arrow_back),
                        ),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            '账单导入',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: _loading ? null : _pick,
                          icon: const Icon(Icons.upload_file, size: 18),
                          label: const Text('选择文件'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        '支持 CSV、TXT、TSV、XLSX；微信/支付宝官方账单会自动识别，'
                        '其他记账 App 按通用表头导入。导入前可预览、确认账户与分类。',
                        style: TextStyle(
                          color: context.appSecondaryText,
                          height: 1.45,
                        ),
                      ),
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 12),
                      AppCard(
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.warning),
                        ),
                      ),
                    ],
                    if (_loading) ...[
                      const SizedBox(height: 24),
                      const Center(child: CircularProgressIndicator()),
                    ],
                    if (_result != null) ...[
                      const SizedBox(height: 14),
                      _summary(_result!),
                      const SizedBox(height: 12),
                      _mapping(accounts, categories),
                      const SizedBox(height: 12),
                      _preview(_result!, categories),
                    ],
                  ]),
                ),
              ),
            ],
          ),
          if (_result != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 12,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: context.appBackground.withValues(alpha: .96),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: .08),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Padding(
                  padding: const EdgeInsets.all(8),
                  child: SizedBox(
                    height: 48,
                    child: FilledButton.icon(
                      onPressed: _saving || _selected.isEmpty
                          ? null
                          : () => _save(accounts, categories),
                      icon: _saving
                          ? const SizedBox.square(
                              dimension: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(Icons.check),
                      label: Text(
                        _saving
                            ? '正在导入…'
                            : '导入已选 ${_selected.length} 笔',
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

  Widget _summary(BillImportResult result) => AppCard(
    child: Row(
      children: [
        const CircleAvatar(child: Icon(Icons.receipt_long_outlined)),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _fileName ?? '账单文件',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 3),
              Text(
                '${_providerLabel(result.provider)}'
                ' · 可导入 ${result.rows.length} 笔'
                '${result.skipped == 0 ? '' : ' · 已跳过 ${result.skipped} 行'}',
                style: TextStyle(
                  color: context.appSecondaryText,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
        Checkbox(
          value: _selected.length == result.rows.length,
          tristate: _selected.isNotEmpty &&
              _selected.length != result.rows.length,
          onChanged: (checked) {
            setState(() {
              _selected = checked == true
                  ? Set<int>.from(
                      List<int>.generate(result.rows.length, (index) => index),
                    )
                  : <int>{};
            });
          },
        ),
      ],
    ),
  );

  Widget _mapping(List<Account> accounts, List<Category> categories) {
    final expense = _rootCategories(categories, CategoryType.expense);
    final income = _rootCategories(categories, CategoryType.income);
    final result = _result;
    final needsAccountMapping = result?.provider.needsAccountMapping == true;
    final accountNames = needsAccountMapping && result != null
        ? _mumuAccountNames(result)
        : const <String>[];
    final unmappedAccounts = accountNames
        .where((name) => _accountMappings[name] == null)
        .length;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('导入映射', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(
            needsAccountMapping
                ? '第三方账单会先按账户名称自动匹配；无法确定时可在这里预设，也可以在导入时逐笔选择“仅此笔”或“全部同来源”。分类会尽量自动匹配。'
                : '微信/支付宝账单使用默认账户，并按收支类型落入下方默认分类。',
            style: TextStyle(
              color: context.appSecondaryText,
              fontSize: 12,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: accounts.any((item) => item.id == _accountId)
                ? _accountId
                : null,
            decoration: InputDecoration(
              labelText: needsAccountMapping ? '未标账户默认（可不选）' : '默认账户',
            ),
            items: [
              for (final account in accounts.where((item) => !item.isArchived))
                DropdownMenuItem(
                  value: account.id,
                  child: Text(account.displayName),
                ),
            ],
            onChanged: (value) => setState(() => _accountId = value),
          ),
          if (needsAccountMapping) ...[
            const SizedBox(height: 4),
            SwitchListTile.adaptive(
              contentPadding: EdgeInsets.zero,
              title: const Text('保持当前账户余额'),
              subtitle: Text(
                '推荐用于历史迁移：流水参与统计，但不会把历史收支再次累计到当前余额。适用于木木及其他记账 App 的历史账单。',
                style: TextStyle(
                  color: context.appSecondaryText,
                  fontSize: 12,
                  height: 1.35,
                ),
              ),
              value: _preserveCurrentBalances,
              onChanged: (value) =>
                  setState(() => _preserveCurrentBalances = value),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              initiallyExpanded: unmappedAccounts > 0,
              title: Text('来源账户映射 · ${accountNames.length} 个'),
              subtitle: Text(
                unmappedAccounts == 0
                    ? '已全部映射'
                    : '还有 $unmappedAccounts 个账户需要选择',
                style: TextStyle(
                  color: unmappedAccounts == 0
                      ? context.appSecondaryText
                      : AppColors.warning,
                  fontSize: 12,
                ),
              ),
              children: [
                for (final name in accountNames)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: DropdownButtonFormField<String>(
                      initialValue: accounts.any(
                        (item) => item.id == _accountMappings[name],
                      )
                          ? _accountMappings[name]
                          : null,
                      isExpanded: true,
                      decoration: InputDecoration(labelText: name),
                      items: [
                        for (final account
                            in accounts.where((item) => !item.isArchived))
                          DropdownMenuItem(
                            value: account.id,
                            child: Text(
                              account.displayName,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                      ],
                      onChanged: (value) => setState(
                        () => _accountMappings[name] = value,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: expense.any((c) => c.id == _expenseCategoryId)
                      ? _expenseCategoryId
                      : null,
                  decoration: InputDecoration(
                    labelText: needsAccountMapping ? '未识别支出兜底' : '支出默认分类',
                  ),
                  items: [
                    for (final category in expense)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _expenseCategoryId = value),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: income.any((c) => c.id == _incomeCategoryId)
                      ? _incomeCategoryId
                      : null,
                  decoration: InputDecoration(
                    labelText: needsAccountMapping ? '未识别收入兜底' : '收入默认分类',
                  ),
                  items: [
                    for (final category in income)
                      DropdownMenuItem(
                        value: category.id,
                        child: Text(category.name),
                      ),
                  ],
                  onChanged: (value) =>
                      setState(() => _incomeCategoryId = value),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  List<String> _mumuAccountNames(BillImportResult result) {
    final values = <String>{};
    for (final row in result.rows) {
      final source = row.sourceAccount?.trim();
      final destination = row.destinationAccount?.trim();
      if (source != null && source.isNotEmpty) values.add(source);
      if (destination != null && destination.isNotEmpty) values.add(destination);
    }
    final sorted = values.toList(growable: false)..sort();
    return sorted;
  }

  Widget _preview(
    BillImportResult result,
    List<Category> categories,
  ) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0;
            index < result.rows.length && index < 200;
            index++) ...[
          _row(index, result.rows[index], categories),
          if (index != result.rows.length - 1 && index != 199)
            const Divider(height: 1),
        ],
        if (result.rows.length > 200)
          Padding(
            padding: EdgeInsets.all(12),
            child: Text(
              '预览仅展示前 200 笔；导入仍按全部已选记录执行。',
              style: TextStyle(color: context.appSecondaryText),
            ),
          ),
      ],
    ),
  );

  Widget _row(
    int index,
    ImportedBillRow row,
    List<Category> categories,
  ) {
    final sourceCategory = [
      row.sourceCategory,
      row.sourceSubcategory,
    ].whereType<String>().where((value) => value.trim().isNotEmpty).join(' / ');
    final mapped = row.provider.needsAccountMapping
        ? const BillImportCategoryMapper().resolve(row, categories)
        : null;
    final mappedCategory = mapped?.category == null
        ? ''
        : [
            mapped!.category!.name,
            if (mapped.subcategory != null) mapped.subcategory!.name,
          ].join(' / ');
    final fallbackTitle =
        row.sourceSubcategory?.trim().isNotEmpty == true
        ? row.sourceSubcategory!.trim()
        : row.sourceCategory?.trim().isNotEmpty == true
        ? row.sourceCategory!.trim()
        : _transactionTypeTitle(row.type);
    final subtitleParts = <String>[
      _dateTime(row.occurredAt),
      if (row.paymentMethod?.trim().isNotEmpty == true) row.paymentMethod!.trim(),
      if (sourceCategory.isNotEmpty)
        mappedCategory.isEmpty
            ? sourceCategory
            : '$sourceCategory → $mappedCategory',
    ];

    return CheckboxListTile(
      value: _selected.contains(index),
      onChanged: (value) {
        setState(() {
          value == true ? _selected.add(index) : _selected.remove(index);
        });
      },
      title: Row(
        children: [
          Expanded(
            child: Text(
              row.merchant.isEmpty
                  ? (row.note.isEmpty ? fallbackTitle : row.note)
                  : row.merchant,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          Text(
            '${_amountPrefix(row.type)}¥${row.amount.toStringAsFixed(2)}',
            style: TextStyle(
              fontWeight: FontWeight.w700,
              color: _isOutflowType(row.type)
                  ? context.appPrimaryText
                  : row.type == TransactionType.transfer
                  ? context.appSecondaryText
                  : context.appPrimary,
            ),
          ),
        ],
      ),
      subtitle: Text(
        subtitleParts.join(' · '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      controlAffinity: ListTileControlAffinity.leading,
    );
  }

  void _initializeSelections(
    List<Account> accounts,
    List<Category> categories,
  ) {
    _expenseCategoryId ??=
        _preferred(_rootCategories(categories, CategoryType.expense))?.id;
    _incomeCategoryId ??=
        _preferred(_rootCategories(categories, CategoryType.income))?.id;

    final result = _result;
    if (result?.provider.needsAccountMapping != true) return;
    for (final name in _mumuAccountNames(result!)) {
      _accountMappings.putIfAbsent(
        name,
        () => _guessAccountId(name, accounts),
      );
    }
  }

  String? _guessAccountId(String sourceName, List<Account> accounts) {
    final active = accounts.where((item) => !item.isArchived).toList();
    final normalized = _normalizeAccountName(sourceName);
    final exact = active
        .where(
          (item) =>
              _normalizeAccountName(item.displayName) == normalized ||
              _normalizeAccountName(item.name) == normalized,
        )
        .toList(growable: false);
    if (exact.length == 1) return exact.single.id;

    final contained = active
        .where((item) {
          final value = _normalizeAccountName(item.name);
          if (normalized.length < 2 || value.length < 2) return false;
          return normalized.contains(value) || value.contains(normalized);
        })
        .toList(growable: false);
    if (contained.length == 1) return contained.single.id;

    final lower = sourceName.toLowerCase();
    if (lower.contains('微信')) {
      final values = active
          .where((item) => item.type == AccountType.wechat)
          .toList(growable: false);
      if (values.length == 1) return values.single.id;
    }
    if (lower.contains('支付宝')) {
      final values = active
          .where((item) => item.type == AccountType.alipay)
          .toList(growable: false);
      if (values.length == 1) return values.single.id;
    }
    return null;
  }

  String _normalizeAccountName(String value) => value
      .trim()
      .toLowerCase()
      .replaceAll(RegExp(r'[\s_\-·/]+'), '')
      .replaceAll(RegExp(r'银行|储蓄卡|信用卡|银行卡|账户'), '');


  List<Category> _rootCategories(
    List<Category> values,
    CategoryType type,
  ) => values
      .where((item) =>
          item.type == type && item.parentId == null && !item.isArchived)
      .toList(growable: false);

  Category? _preferred(List<Category> values) {
    for (final name in const ['其他', '其他支出', '其他收入']) {
      final found = values.where((item) => item.name == name).firstOrNull;
      if (found != null) return found;
    }
    return values.firstOrNull;
  }

  Future<void> _pick() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final file = await FilePicker.pickFile(
        type: FileType.custom,
        allowedExtensions: const ['csv', 'txt', 'tsv', 'xlsx'],
      );
      if (file == null || file.path == null) return;
      final result = await const BillImportService().parseFile(file.path!);
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _result = result;
        _accountMappings.clear();
        _rowSourceAccountOverrides.clear();
        _rowDestinationAccountOverrides.clear();
        _preserveCurrentBalances = true;
        _accountId = null;
        _selected = Set<int>.from(
          List<int>.generate(result.rows.length, (index) => index),
        );
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '读取失败：$error');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save(
    List<Account> accounts,
    List<Category> categories,
  ) async {
    final result = _result;
    if (result == null) return;

    if (!result.provider.needsAccountMapping && _accountId == null) {
      setState(() => _error = '请选择默认账户');
      return;
    }

    if (result.provider.needsAccountMapping) {
      final resolved = await _resolveUncertainAccounts(result, accounts);
      if (!resolved || !mounted) return;
    }

    final expenseFallback = categories
        .where((item) => item.id == _expenseCategoryId)
        .firstOrNull;
    final incomeFallback = categories
        .where((item) => item.id == _incomeCategoryId)
        .firstOrNull;
    if (expenseFallback == null || incomeFallback == null) {
      setState(() => _error = '请选择收入和支出的兜底分类');
      return;
    }

    final activeBookId = ref.read(activeBookIdProvider);
    final existingTransactions =
        await ref.read(transactionRepositoryProvider).getAll();
    if (!mounted) return;
    final duplicateIndex = BillImportDuplicateIndex(existingTransactions);

    final mapper = const BillImportCategoryMapper();
    final requests = <QuickBookkeepingRequest>[];
    var duplicates = 0;
    for (final index in _selected.toList()..sort()) {
      final row = result.rows[index];
      if (duplicateIndex.contains(row)) {
        duplicates++;
        continue;
      }
      duplicateIndex.add(row);

      final accountId = result.provider.needsAccountMapping
          ? _resolvedAccountId(index, row.sourceAccount, destination: false)
          : _accountId;
      if (accountId == null) {
        setState(() => _error = '仍有流水没有选择账户，请重新导入');
        return;
      }

      String? destinationAccountId;
      if (row.type == TransactionType.transfer) {
        destinationAccountId = _resolvedAccountId(
          index,
          row.destinationAccount,
          destination: true,
        );
        if (destinationAccountId == null || destinationAccountId == accountId) {
          setState(() => _error = '转账必须选择两个不同的账户');
          return;
        }
      }

      Category? category;
      Category? subcategory;
      if (row.type != TransactionType.transfer) {
        if (row.provider.needsAccountMapping) {
          final mapped = mapper.resolve(row, categories);
          category = mapped.category;
          subcategory = mapped.subcategory;
        }
        category ??= switch (row.type) {
          TransactionType.expense ||
          TransactionType.lend ||
          TransactionType.repayment ||
          TransactionType.assetPurchase => expenseFallback,
          TransactionType.income ||
          TransactionType.refund ||
          TransactionType.reimbursement ||
          TransactionType.borrow ||
          TransactionType.assetSale => incomeFallback,
          TransactionType.transfer || TransactionType.adjustment => null,
        };
      }

      requests.add(
        QuickBookkeepingRequest(
          type: row.type,
          amount: row.amount,
          accountId: accountId,
          destinationAccountId: destinationAccountId,
          bookId: activeBookId,
          occurredAt: row.occurredAt,
          categoryId: category?.id,
          subcategoryId: subcategory?.id,
          categoryName: category?.name,
          merchant: row.merchant.isEmpty ? null : row.merchant,
          note: row.note.isEmpty ? null : row.note,
          reimbursementStatus: row.reimbursementStatus,
          reimbursementAmount:
              row.reimbursementStatus == ReimbursementStatus.reimbursed
              ? row.amount
              : null,
          tags: row.tags,
          source: TransactionSource.import,
          metadata: {
            'importProvider': row.provider.name,
            'importFingerprint': row.importFingerprint,
            if (row.provider.needsAccountMapping && _preserveCurrentBalances)
              'ignoreAccountBalanceEffect': true,
            if (row.externalId != null) 'externalId': row.externalId!,
            if (row.fingerprintOrderId != null)
              'orderId': row.fingerprintOrderId!,
            if (row.fingerprintPaymentChannel != null)
              'paymentChannel': row.fingerprintPaymentChannel!,
            if (row.paymentMethod != null)
              'paymentMethod': row.paymentMethod!,
            if (row.sourceCategory != null)
              'sourceCategory': row.sourceCategory!,
            if (row.sourceSubcategory != null)
              'sourceSubcategory': row.sourceSubcategory!,
            if (row.sourceBook != null) 'sourceBook': row.sourceBook!,
            if (row.sourceAccount != null)
              'sourceAccount': row.sourceAccount!,
            if (row.destinationAccount != null)
              'destinationAccount': row.destinationAccount!,
            if (row.raw['报销']?.trim().isNotEmpty == true)
              'sourceReimbursementStatus': row.raw['报销']!.trim(),
            if (row.raw['优惠']?.trim().isNotEmpty == true)
              'sourceDiscount': row.raw['优惠']!.trim(),
            if (row.raw['成员']?.trim().isNotEmpty == true)
              'sourceMember': row.raw['成员']!.trim(),
            if (row.raw['账单图片']?.trim().isNotEmpty == true)
              'sourceBillImage': row.raw['账单图片']!.trim(),
            'fileName': _fileName ?? '',
          },
        ),
      );
    }

    if (requests.isEmpty) {
      setState(() {
        _error = duplicates > 0
            ? '所选记录均已导入，无需重复导入'
            : '没有可导入记录';
      });
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(quickBookkeepingServiceProvider).saveAll(requests);
      _refreshTransactionViews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已导入 ${requests.length} 笔'
            '${duplicates == 0 ? '' : '，跳过 $duplicates 笔重复记录'}',
          ),
        ),
      );
      context.pop();
    } on BookkeepingCommittedException catch (error) {
      _refreshTransactionViews();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '已保存 ${error.records.length} 笔流水，但自动分类/重复检查未完全完成。'
            '流水已经入账，请不要重复导入；可稍后到“账单收件箱”核对。',
          ),
        ),
      );
      context.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '导入失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _refreshTransactionViews() {
    ref.invalidate(transactionsProvider);
    ref.invalidate(allTransactionsProvider);
  }

  String? _resolvedAccountId(
    int rowIndex,
    String? sourceName, {
    required bool destination,
  }) {
    final rowOverrides = destination
        ? _rowDestinationAccountOverrides
        : _rowSourceAccountOverrides;
    final rowOverride = rowOverrides[rowIndex];
    if (rowOverride != null) return rowOverride;
    final name = sourceName?.trim();
    if (name != null && name.isNotEmpty) {
      return _accountMappings[name];
    }
    return _accountId;
  }

  Future<bool> _resolveUncertainAccounts(
    BillImportResult result,
    List<Account> accounts,
  ) async {
    final activeAccounts = accounts
        .where((item) => !item.isArchived)
        .toList(growable: false);
    if (activeAccounts.isEmpty) {
      setState(() => _error = '当前没有可用账户，请先创建账户后再导入');
      return false;
    }

    for (final index in _selected.toList()..sort()) {
      final row = result.rows[index];
      var sourceId = _resolvedAccountId(
        index,
        row.sourceAccount,
        destination: false,
      );
      if (sourceId == null) {
        final decision = await _promptAccountAssignment(
          accounts: activeAccounts,
          sourceName: row.sourceAccount,
          row: row,
          destination: false,
        );
        if (decision == null || !mounted) return false;
        _applyAccountDecision(
          index: index,
          sourceName: row.sourceAccount,
          destination: false,
          decision: decision,
        );
        sourceId = decision.accountId;
      }

      if (row.type != TransactionType.transfer) continue;

      var destinationId = _resolvedAccountId(
        index,
        row.destinationAccount,
        destination: true,
      );
      if (destinationId == null || destinationId == sourceId) {
        final decision = await _promptAccountAssignment(
          accounts: activeAccounts
              .where((item) => item.id != sourceId)
              .toList(growable: false),
          sourceName: row.destinationAccount,
          row: row,
          destination: true,
          sameAccountConflict: destinationId == sourceId,
        );
        if (decision == null || !mounted) return false;
        _applyAccountDecision(
          index: index,
          sourceName: row.destinationAccount,
          destination: true,
          decision: decision,
        );
      }
    }
    return true;
  }

  void _applyAccountDecision({
    required int index,
    required String? sourceName,
    required bool destination,
    required _AccountAssignmentDecision decision,
  }) {
    if (decision.applyToAll) {
      final name = sourceName?.trim();
      if (name == null || name.isEmpty) {
        _accountId = decision.accountId;
      } else {
        _accountMappings[name] = decision.accountId;
      }
      return;
    }
    final target = destination
        ? _rowDestinationAccountOverrides
        : _rowSourceAccountOverrides;
    target[index] = decision.accountId;
  }

  Future<_AccountAssignmentDecision?> _promptAccountAssignment({
    required List<Account> accounts,
    required String? sourceName,
    required ImportedBillRow row,
    required bool destination,
    bool sameAccountConflict = false,
  }) {
    String? selectedAccountId;
    final sourceLabel = sourceName?.trim().isNotEmpty == true
        ? sourceName!.trim()
        : '未标账户';
    return showDialog<_AccountAssignmentDecision>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
            title: Text(destination ? '选择转入账户' : '选择流水账户'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sameAccountConflict
                      ? '“$sourceLabel”与转出账户被映射成了同一账户，请重新选择。'
                      : '来源账户“$sourceLabel”无法自动确定归属。',
                ),
                const SizedBox(height: 6),
                Text(
                  '${_dateTime(row.occurredAt)} · ¥${row.amount.toStringAsFixed(2)}'
                  '${row.note.trim().isEmpty ? '' : ' · ${row.note.trim()}'}',
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: selectedAccountId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: '归属账户'),
                  items: [
                    for (final account in accounts)
                      DropdownMenuItem(
                        value: account.id,
                        child: Text(
                          account.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (value) =>
                      setDialogState(() => selectedAccountId = value),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('取消导入'),
              ),
              TextButton(
                onPressed: selectedAccountId == null
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        _AccountAssignmentDecision(
                          accountId: selectedAccountId!,
                          applyToAll: false,
                        ),
                      ),
                child: const Text('仅此笔'),
              ),
              FilledButton(
                onPressed: selectedAccountId == null
                    ? null
                    : () => Navigator.pop(
                        dialogContext,
                        _AccountAssignmentDecision(
                          accountId: selectedAccountId!,
                          applyToAll: true,
                        ),
                      ),
                child: Text(
                  sourceName?.trim().isNotEmpty == true
                      ? '全部同来源'
                      : '全部未标账户',
                ),
              ),
            ],
          );
        },
      ),
    );
  }

}

class _AccountAssignmentDecision {
  const _AccountAssignmentDecision({
    required this.accountId,
    required this.applyToAll,
  });

  final String accountId;
  final bool applyToAll;
}

String _dateTime(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

bool _isOutflowType(TransactionType type) => switch (type) {
  TransactionType.expense ||
  TransactionType.lend ||
  TransactionType.repayment ||
  TransactionType.assetPurchase => true,
  _ => false,
};

String _transactionTypeTitle(TransactionType type) => switch (type) {
  TransactionType.expense => '支出',
  TransactionType.income => '收入',
  TransactionType.transfer => '转账',
  TransactionType.refund => '退款',
  TransactionType.reimbursement => '报销',
  TransactionType.borrow => '借入',
  TransactionType.lend => '借出',
  TransactionType.repayment => '还款',
  TransactionType.assetPurchase => '资产购买',
  TransactionType.assetSale => '资产卖出',
  TransactionType.adjustment => '余额校准',
};

String _amountPrefix(TransactionType type) => switch (type) {
  TransactionType.expense ||
  TransactionType.lend ||
  TransactionType.repayment ||
  TransactionType.assetPurchase => '-',
  TransactionType.transfer => '↔',
  _ => '+',
};


String _providerLabel(BillImportProvider provider) => switch (provider) {
  BillImportProvider.wechat => '微信支付',
  BillImportProvider.alipay => '支付宝',
  BillImportProvider.mumu => '木木记账',
  BillImportProvider.generic => '第三方账单',
};
