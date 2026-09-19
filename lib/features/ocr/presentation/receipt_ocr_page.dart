import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/models/voice_bookkeeping.dart';
import '../../../core/widgets/app_card.dart';
import '../../accounts/data/account_repository.dart';
import '../../bookkeeping/application/quick_bookkeeping_service.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../voice/application/speech_recognition_service.dart';
import '../application/local_ocr_service.dart';

class ReceiptOcrPage extends ConsumerStatefulWidget {
  const ReceiptOcrPage({super.key});

  @override
  ConsumerState<ReceiptOcrPage> createState() => _ReceiptOcrPageState();
}

class _ReceiptOcrPageState extends ConsumerState<ReceiptOcrPage> {
  bool _busy = false;
  bool _saving = false;
  String? _error;
  String? _rawText;
  TransactionParseResult? _parsed;
  String? _fallbackAccountId;
  String? _expenseCategoryId;
  String? _incomeCategoryId;

  @override
  Widget build(BuildContext context) {
    final accounts = ref.watch(allAccountsProvider).value ?? const <Account>[];
    final categories = ref.watch(categoriesProvider).value ?? const <Category>[];
    _initializeDefaults(accounts, categories);

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
                        '小票 / 账单识别',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '图片文字先在设备本地 OCR，再用本地规则解析；会员且需要补充理解时才会调用服务端 AI。保存前始终需要你确认。',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _busy ? null : () => _pick(ImageSource.camera),
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('拍摄小票'),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _busy ? null : () => _pick(ImageSource.gallery),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('从相册选择'),
                      ),
                    ),
                  ],
                ),
                if (_busy) ...[
                  const SizedBox(height: 24),
                  const Center(child: CircularProgressIndicator()),
                ],
                if (_error != null) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: Text(
                      _error!,
                      style: const TextStyle(color: AppColors.warning),
                    ),
                  ),
                ],
                if (_rawText != null) ...[
                  const SizedBox(height: 12),
                  AppCard(
                    child: ExpansionTile(
                      tilePadding: EdgeInsets.zero,
                      childrenPadding: EdgeInsets.zero,
                      title: const Text(
                        '识别文字',
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      subtitle: Text(
                        _parsed?.usedAi == true ? '已使用 AI 补充解析' : '本地 OCR / 规则解析',
                      ),
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: SelectableText(
                            _rawText!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              height: 1.45,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                if (_parsed != null) ...[
                  const SizedBox(height: 12),
                  _mapping(accounts, categories),
                  const SizedBox(height: 12),
                  _candidates(_parsed!),
                  const SizedBox(height: 14),
                  FilledButton.icon(
                    onPressed: _saving || _parsed!.transactions.isEmpty
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
                          ? '正在保存…'
                          : '确认保存 ${_parsed!.transactions.length} 笔',
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

  Widget _mapping(List<Account> accounts, List<Category> categories) {
    final expenses = _rootCategories(categories, CategoryType.expense);
    final incomes = _rootCategories(categories, CategoryType.income);
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('无法匹配时的默认值', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(
            initialValue: accounts.any((a) => a.id == _fallbackAccountId)
                ? _fallbackAccountId
                : null,
            decoration: const InputDecoration(labelText: '默认账户'),
            items: [
              for (final account in accounts.where((a) => !a.isArchived))
                DropdownMenuItem(
                  value: account.id,
                  child: Text(account.displayName),
                ),
            ],
            onChanged: (value) => setState(() => _fallbackAccountId = value),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: expenses.any((c) => c.id == _expenseCategoryId)
                      ? _expenseCategoryId
                      : null,
                  decoration: const InputDecoration(labelText: '支出分类'),
                  items: [
                    for (final category in expenses)
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
                  initialValue: incomes.any((c) => c.id == _incomeCategoryId)
                      ? _incomeCategoryId
                      : null,
                  decoration: const InputDecoration(labelText: '收入分类'),
                  items: [
                    for (final category in incomes)
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

  Widget _candidates(TransactionParseResult parsed) => AppCard(
    padding: EdgeInsets.zero,
    child: Column(
      children: [
        for (var index = 0; index < parsed.transactions.length; index++) ...[
          _candidate(parsed.transactions[index]),
          if (index != parsed.transactions.length - 1)
            const Divider(height: 1),
        ],
        if (parsed.unresolvedFragments.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(
              '仍有未解析内容：${parsed.unresolvedFragments.join(' / ')}',
              style: const TextStyle(color: AppColors.warning),
            ),
          ),
      ],
    ),
  );

  Widget _candidate(ParsedVoiceTransaction item) => ListTile(
    leading: CircleAvatar(
      child: Icon(
        item.type == TransactionType.expense
            ? Icons.remove
            : Icons.add,
      ),
    ),
    title: Row(
      children: [
        Expanded(
          child: Text(
            item.merchant?.trim().isNotEmpty == true
                ? item.merchant!
                : (item.categoryName ?? '待确认'),
          ),
        ),
        Text(
          '${item.type == TransactionType.expense ? '-' : '+'}'
          '¥${item.amount.toStringAsFixed(2)}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
    subtitle: Text(
      '${item.categoryName ?? '未分类'} · '
      '${item.accountName ?? '默认账户'} · '
      '置信度 ${(item.confidence * 100).round()}%',
    ),
  );

  void _initializeDefaults(
    List<Account> accounts,
    List<Category> categories,
  ) {
    _fallbackAccountId ??=
        accounts.where((a) => !a.isArchived).firstOrNull?.id;
    _expenseCategoryId ??=
        _preferred(_rootCategories(categories, CategoryType.expense))?.id;
    _incomeCategoryId ??=
        _preferred(_rootCategories(categories, CategoryType.income))?.id;
  }

  List<Category> _rootCategories(
    List<Category> values,
    CategoryType type,
  ) => values
      .where((c) => c.type == type && c.parentId == null && !c.isArchived)
      .toList(growable: false);

  Category? _preferred(List<Category> values) {
    for (final name in const ['其他', '其他支出', '其他收入']) {
      final found = values.where((item) => item.name == name).firstOrNull;
      if (found != null) return found;
    }
    return values.firstOrNull;
  }

  Future<void> _pick(ImageSource source) async {
    setState(() {
      _busy = true;
      _error = null;
      _rawText = null;
      _parsed = null;
    });
    try {
      final image = await ImagePicker().pickImage(
        source: source,
        imageQuality: 95,
      );
      if (image == null) return;
      final ocr = await const LocalOcrService().recognize(image.path);
      final parsed = await ref
          .read(voiceTransactionParserProvider)
          .parse(ocr.text);
      if (!mounted) return;
      setState(() {
        _rawText = ocr.text;
        _parsed = parsed;
        if (parsed.transactions.isEmpty) {
          _error = '已识别到文字，但没有解析出金额。可换一张更清晰、包含金额与商户信息的图片。';
        }
      });
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '识别失败：$error');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save(
    List<Account> accounts,
    List<Category> categories,
  ) async {
    final parsed = _parsed;
    final fallbackAccount = accounts
        .where((a) => a.id == _fallbackAccountId)
        .firstOrNull;
    final expenseFallback = categories
        .where((c) => c.id == _expenseCategoryId)
        .firstOrNull;
    final incomeFallback = categories
        .where((c) => c.id == _incomeCategoryId)
        .firstOrNull;
    if (parsed == null ||
        fallbackAccount == null ||
        expenseFallback == null ||
        incomeFallback == null) {
      setState(() => _error = '请先选择默认账户和收支分类');
      return;
    }

    final requests = <QuickBookkeepingRequest>[];
    for (final item in parsed.transactions) {
      final account = _resolveAccount(accounts, item) ?? fallbackAccount;
      final fallbackCategory = item.type == TransactionType.expense
          ? expenseFallback
          : incomeFallback;
      final category = _resolveCategory(categories, item) ?? fallbackCategory;
      requests.add(
        QuickBookkeepingRequest(
          type: item.type,
          amount: item.amount,
          accountId: account.id,
          bookId: ref.read(activeBookIdProvider),
          occurredAt: item.occurredAt,
          categoryId: category.id,
          categoryName: category.name,
          merchant: item.merchant,
          note: item.rawFragment.trim().isEmpty ? null : item.rawFragment.trim(),
          source: TransactionSource.ocr,
          userCorrected: true,
          metadata: {
            'ocrParser': item.source.name,
            'ocrConfidence': item.confidence,
          },
        ),
      );
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(quickBookkeepingServiceProvider).saveAll(requests);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('已保存 ${requests.length} 笔 OCR 账单')),
      );
      context.pop();
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _error = '保存失败：$error');
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Account? _resolveAccount(
    List<Account> accounts,
    ParsedVoiceTransaction item,
  ) {
    if (item.accountId != null) {
      final byId = accounts.where((a) => a.id == item.accountId).firstOrNull;
      if (byId != null && !byId.isArchived) return byId;
    }
    final name = item.accountName?.trim();
    if (name == null || name.isEmpty) return null;
    return accounts
        .where((a) =>
            !a.isArchived &&
            (a.name == name || a.displayName == name) &&
            (item.identifierSuffix == null ||
                a.identifierSuffix == item.identifierSuffix))
        .firstOrNull;
  }

  Category? _resolveCategory(
    List<Category> categories,
    ParsedVoiceTransaction item,
  ) {
    if (item.categoryId != null) {
      final byId = categories
          .where((c) => c.id == item.categoryId && !c.isArchived)
          .firstOrNull;
      if (byId != null) return byId;
    }
    final name = item.categoryName?.trim();
    if (name == null || name.isEmpty) return null;
    return categories
        .where((c) => c.name == name && !c.isArchived)
        .firstOrNull;
  }
}
