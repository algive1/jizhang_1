import 'dart:convert';

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
      child: CustomScrollView(
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
                      icon: Icon(Icons.upload_file, size: 18),
                      label: Text('选择文件'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '支持微信支付、支付宝官方 CSV，以及木木记账导出的 XLSX。导入前会预览；木木分类、账户、转账和报销语义会尽量保留。',
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
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving || _selected.isEmpty
                        ? null
                        : () => _save(categories),
                    icon: _saving
                        ? const SizedBox.square(
                            dimension: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check),
                    label: Text(
                      _saving ? '正在导入…' : '导入已选 ${_selected.length} 笔',
                    ),
                  ),
                ],
              ]),
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
    final isMumu = result?.provider == BillImportProvider.mumu;
    final accountNames = isMumu && result != null
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
            isMumu
                ? '木木账户按名称逐项映射；分类会自动匹配到当前分类树，无法识别的记录使用下方兜底分类。'
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
              labelText: isMumu ? '未标账户兜底' : '默认账户',
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
          if (isMumu) ...[
            const SizedBox(height: 4),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              childrenPadding: EdgeInsets.zero,
              initiallyExpanded: unmappedAccounts > 0,
              title: Text('木木账户映射 · ${accountNames.length} 个'),
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
                    labelText: isMumu ? '未识别支出兜底' : '支出默认分类',
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
                    labelText: isMumu ? '未识别收入兜底' : '收入默认分类',
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
    final mapped = row.provider == BillImportProvider.mumu
        ? const BillImportCategoryMapper().resolve(row, categories)
        : null;
    final mappedCategory = mapped?.category == null
        ? ''
        : [
            mapped!.category!.name,
            if (mapped.subcategory != null) mapped.subcategory!.name,
          ].join(' / ');
    final fallbackTitle = row.type == TransactionType.transfer
        ? '转账'
        : (row.sourceSubcategory?.trim().isNotEmpty == true
              ? row.sourceSubcategory!.trim()
              : row.sourceCategory?.trim().isNotEmpty == true
              ? row.sourceCategory!.trim()
              : '未命名交易');
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
              color: row.type == TransactionType.expense
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
    _accountId ??= accounts.where((item) => !item.isArchived).firstOrNull?.id;
    _expenseCategoryId ??=
        _preferred(_rootCategories(categories, CategoryType.expense))?.id;
    _incomeCategoryId ??=
        _preferred(_rootCategories(categories, CategoryType.income))?.id;

    final result = _result;
    if (result?.provider != BillImportProvider.mumu) return;
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
        allowedExtensions: const ['csv', 'txt', 'xlsx'],
      );
      if (file == null || file.path == null) return;
      final result = await const BillImportService().parseFile(file.path!);
      if (!mounted) return;
      setState(() {
        _fileName = file.name;
        _result = result;
        _accountMappings.clear();
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

  Future<void> _save(List<Category> categories) async {
    final result = _result;
    final accountId = _accountId;
    if (result == null || accountId == null) {
      setState(() => _error = '请选择默认账户');
      return;
    }
    final expenseCategory = categories
        .where((item) => item.id == _expenseCategoryId)
        .firstOrNull;
    final incomeCategory = categories
        .where((item) => item.id == _incomeCategoryId)
        .firstOrNull;
    if (expenseCategory == null || incomeCategory == null) {
      setState(() => _error = '请选择收入和支出的默认分类');
      return;
    }

    final importedIds = <String>{};
    final transactions = ref.read(allTransactionsProvider).value ?? const [];
    for (final transaction in transactions) {
      if (transaction.source != TransactionSource.import ||
          transaction.metadataJson == null) {
        continue;
      }
      try {
        final metadata = jsonDecode(transaction.metadataJson!);
        if (metadata is Map && metadata['externalId'] is String) {
          importedIds.add(metadata['externalId'] as String);
        }
      } on Object {
        // Historical malformed metadata must not block a new import.
      }
    }

    final requests = <QuickBookkeepingRequest>[];
    var duplicates = 0;
    for (final index in _selected.toList()..sort()) {
      final row = result.rows[index];
      if (row.externalId != null && importedIds.contains(row.externalId)) {
        duplicates++;
        continue;
      }
      final category = row.type == TransactionType.expense
          ? expenseCategory
          : incomeCategory;
      requests.add(
        QuickBookkeepingRequest(
          type: row.type,
          amount: row.amount,
          accountId: accountId,
          bookId: ref.read(activeBookIdProvider),
          occurredAt: row.occurredAt,
          categoryId: category.id,
          categoryName: category.name,
          merchant: row.merchant.isEmpty ? null : row.merchant,
          note: row.note.isEmpty ? null : row.note,
          source: TransactionSource.import,
          metadata: {
            'importProvider': row.provider.name,
            if (row.externalId != null) 'externalId': row.externalId!,
            if (row.paymentMethod != null)
              'paymentMethod': row.paymentMethod!,
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
      ref.invalidate(allTransactionsProvider);
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
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '导入失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

String _dateTime(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')} '
    '${value.hour.toString().padLeft(2, '0')}:'
    '${value.minute.toString().padLeft(2, '0')}';

String _amountPrefix(TransactionType type) => switch (type) {
  TransactionType.expense ||
  TransactionType.lend ||
  TransactionType.assetPurchase => '-',
  TransactionType.transfer => '↔',
  _ => '+',
};


String _providerLabel(BillImportProvider provider) => switch (provider) {
  BillImportProvider.wechat => '微信支付',
  BillImportProvider.alipay => '支付宝',
  BillImportProvider.mumu => '木木记账',
};
