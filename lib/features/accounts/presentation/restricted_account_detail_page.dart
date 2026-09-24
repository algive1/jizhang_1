import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/app_card.dart';
import '../../books/data/book_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/account_management_repository.dart';
import '../data/account_repository.dart';
import '../domain/account_management.dart';

class RestrictedAccountDetailPage extends ConsumerStatefulWidget {
  const RestrictedAccountDetailPage({required this.accountId, super.key});

  final String accountId;

  @override
  ConsumerState<RestrictedAccountDetailPage> createState() =>
      _RestrictedAccountDetailPageState();
}

class _RestrictedAccountDetailPageState
    extends ConsumerState<RestrictedAccountDetailPage> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(managedAccountsProvider);
    final item = (accountState.value ?? const <ManagedAccount>[])
        .where((entry) => entry.account.id == widget.accountId)
        .firstOrNull;
    if (accountState.isLoading && item == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (item == null) {
      return const SafeArea(child: Center(child: Text('账户不存在')));
    }

    final allTransactions =
        ref.watch(allTransactionsProvider).value ?? const <TransactionRecord>[];
    final transactions = allTransactions
        .where(
          (record) =>
              record.accountId == item.account.id ||
              record.destinationAccountId == item.account.id,
        )
        .where((record) => _matches(record, item.account.id))
        .toList()
      ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final showOpening =
        item.account.openingBalance != 0 && _filter != 2;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/profile/accounts'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '账户详情',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => _edit(item),
                child: const Text('编辑'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _IdentityCard(item: item),
          const SizedBox(height: 10),
          AppCard(
            color: context.appPrimarySoft.withValues(alpha: .66),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '当前余额（元）',
                  style: TextStyle(color: context.appSecondaryText, fontSize: 12),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥ ${MoneyFormatter.decimal(item.account.balance)}',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          _InfoCard(item: item),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.add_rounded,
                  label: '追加',
                  color: const Color(0xff54A85D),
                  onTap: () => _transfer(
                    item,
                    incoming: true,
                    title: '追加受限资金',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.undo_rounded,
                  label: '退回',
                  color: const Color(0xffE88B37),
                  onTap: () => _transfer(
                    item,
                    incoming: false,
                    title: '退回资金',
                    markReturnedWhenEmpty: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.remove_rounded,
                  label: '扣除',
                  color: const Color(0xffE05C5C),
                  onTap: () => _deduct(item),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.swap_horiz_rounded,
                  label: '转账',
                  color: const Color(0xff5B8DEF),
                  onTap: () => _transfer(
                    item,
                    incoming: false,
                    title: '转账',
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '资金变动记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('全部')),
              ButtonSegment(value: 1, label: Text('转入')),
              ButtonSegment(value: 2, label: Text('转出')),
            ],
            selected: {_filter},
            onSelectionChanged: (value) => setState(() => _filter = value.first),
          ),
          const SizedBox(height: 10),
          if (transactions.isEmpty && !showOpening)
            AppCard(
              child: Text(
                '暂无资金变动记录',
                style: TextStyle(color: context.appSecondaryText),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
              child: Column(
                children: [
                  for (var index = 0; index < transactions.length; index++) ...[
                    _TransactionRow(
                      record: transactions[index],
                      accountId: item.account.id,
                    ),
                    if (index != transactions.length - 1 || showOpening)
                      Divider(height: 1, color: context.appDivider),
                  ],
                  if (showOpening)
                    _OpeningBalanceRow(account: item.account),
                ],
              ),
            ),
        ],
      ),
    );
  }

  bool _matches(TransactionRecord record, String accountId) => switch (_filter) {
    1 => record.destinationAccountId == accountId ||
        (record.accountId == accountId &&
            record.type == TransactionType.adjustment &&
            record.amount > 0),
    2 => record.accountId == accountId &&
        record.destinationAccountId != accountId &&
        record.type != TransactionType.adjustment,
    _ => true,
  };

  Future<void> _transfer(
    ManagedAccount restricted, {
    required bool incoming,
    required String title,
    bool markReturnedWhenEmpty = false,
  }) async {
    final all = ref
            .read(managedAccountsProvider)
            .value
            ?.where(
              (item) =>
                  item.account.id != restricted.account.id &&
                  !item.account.type.isDebt &&
                  item.account.assetForm != AssetForm.investment &&
                  item.account.currency == restricted.account.currency,
            )
            .toList() ??
        const <ManagedAccount>[];
    if (all.isEmpty) {
      _message('没有可用于转账的同币种账户');
      return;
    }
    final result = await showModalBottomSheet<_MoneyMoveResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _MoneyMoveSheet(
        title: title,
        accounts: all,
        maxAmount: incoming ? null : restricted.account.balance,
      ),
    );
    if (result == null) return;
    try {
      final now = DateTime.now();
      final sourceId =
          incoming ? result.accountId : restricted.account.id;
      final destinationId =
          incoming ? restricted.account.id : result.accountId;
      await ref.read(transactionRepositoryProvider).create(
        TransactionRecord(
          id: 'restricted-transfer-${newEntityId()}',
          bookId: ref.read(activeBookIdProvider),
          type: TransactionType.transfer,
          amount: result.amount,
          currency: restricted.account.currency,
          accountId: sourceId,
          destinationAccountId: destinationId,
          merchant: restricted.platform,
          note: title,
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (markReturnedWhenEmpty &&
          (restricted.account.balance - result.amount).abs() < .005) {
        await ref.read(accountManagementRepositoryProvider).updateMeta(
          accountId: restricted.account.id,
          category: AccountFundCategory.restricted,
          platform: restricted.platform,
          restrictedStatus: RestrictedFundStatus.returned,
          expectedReturnAt: restricted.expectedReturnAt,
          includeInTotal: restricted.includeInTotal,
          note: restricted.note,
        );
      }
      if (mounted) _message('已完成$title');
    } on Object catch (error) {
      if (mounted) _message('$title失败：$error');
    }
  }

  Future<void> _deduct(ManagedAccount item) async {
    final amount = await _askAmount(
      title: '扣除受限资金',
      maxAmount: item.account.balance,
    );
    if (amount == null) return;
    try {
      final now = DateTime.now();
      await ref.read(transactionRepositoryProvider).create(
        TransactionRecord(
          id: 'restricted-deduct-${newEntityId()}',
          bookId: ref.read(activeBookIdProvider),
          type: TransactionType.expense,
          amount: amount,
          currency: item.account.currency,
          accountId: item.account.id,
          merchant: item.platform,
          note: '受限资金扣除',
          occurredAt: now,
          createdAt: now,
          updatedAt: now,
        ),
      );
      if (mounted) _message('扣除完成');
    } on Object catch (error) {
      if (mounted) _message('扣除失败：$error');
    }
  }

  Future<double?> _askAmount({
    required String title,
    double? maxAmount,
  }) async {
    final controller = TextEditingController();
    final result = await showDialog<double>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: controller,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '金额',
            prefixText: '¥ ',
            helperText: maxAmount == null
                ? null
                : '最多 ¥${MoneyFormatter.decimal(maxAmount)}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = double.tryParse(controller.text.trim());
              if (value == null ||
                  value <= 0 ||
                  (maxAmount != null && value - maxAmount > .000001)) {
                return;
              }
              Navigator.pop(dialogContext, value);
            },
            child: const Text('确认'),
          ),
        ],
      ),
    );
    controller.dispose();
    return result;
  }

  Future<void> _edit(ManagedAccount item) async {
    final name = TextEditingController(text: item.account.name);
    final note = TextEditingController(text: item.note ?? '');
    var platform = item.platform ?? '其他';
    var status = item.restrictedStatus ?? RestrictedFundStatus.locked;
    var expected = item.expectedReturnAt;
    var include = item.includeInTotal;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('编辑账户'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '账户名称'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<String>(
                  initialValue: ['淘宝', '抖音', '拼多多', '京东', '房东', '其他']
                          .contains(platform)
                      ? platform
                      : '其他',
                  decoration: const InputDecoration(labelText: '平台 / 机构'),
                  items: const [
                    DropdownMenuItem(value: '淘宝', child: Text('淘宝')),
                    DropdownMenuItem(value: '抖音', child: Text('抖音')),
                    DropdownMenuItem(value: '拼多多', child: Text('拼多多')),
                    DropdownMenuItem(value: '京东', child: Text('京东')),
                    DropdownMenuItem(value: '房东', child: Text('房东')),
                    DropdownMenuItem(value: '其他', child: Text('其他')),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => platform = value ?? '其他'),
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<RestrictedFundStatus>(
                  initialValue: status,
                  decoration: const InputDecoration(labelText: '资金状态'),
                  items: [
                    for (final value in RestrictedFundStatus.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => status = value ?? status),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('预计退回日期'),
                  subtitle: Text(expected == null ? '未设置' : _date(expected!)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final result = await showDatePicker(
                      context: context,
                      initialDate: expected ?? DateTime.now(),
                      firstDate: DateTime(DateTime.now().year - 1),
                      lastDate: DateTime(DateTime.now().year + 20),
                    );
                    if (result != null) {
                      setLocalState(() => expected = result);
                    }
                  },
                ),
                TextField(
                  controller: note,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('计入总资产'),
                  value: include,
                  onChanged: (value) =>
                      setLocalState(() => include = value),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('保存'),
            ),
          ],
        ),
      ),
    );
    if (confirmed != true) {
      name.dispose();
      note.dispose();
      return;
    }

    try {
      final old = item.account;
      await ref.read(accountRepositoryProvider).update(
        Account(
          bookId: old.bookId,
          id: old.id,
          name: name.text.trim().isEmpty ? old.name : name.text.trim(),
          type: old.type,
          balance: old.balance,
          openingBalance: old.openingBalance,
          currency: old.currency,
          icon: old.icon,
          color: old.color,
          sortOrder: old.sortOrder,
          isArchived: old.isArchived,
          createdAt: old.createdAt,
          updatedAt: DateTime.now(),
          assetForm: old.assetForm,
          identifierSuffix: old.identifierSuffix,
        ),
      );
      await ref.read(accountManagementRepositoryProvider).updateMeta(
        accountId: old.id,
        category: AccountFundCategory.restricted,
        platform: platform,
        restrictedStatus: status,
        expectedReturnAt: expected,
        includeInTotal: include,
        note: note.text,
      );
      if (mounted) _message('账户已更新');
    } on Object catch (error) {
      if (mounted) _message('保存失败：$error');
    } finally {
      name.dispose();
      note.dispose();
    }
  }

  void _message(String value) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(value)));
  }

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _IdentityCard extends StatelessWidget {
  const _IdentityCard({required this.item});
  final ManagedAccount item;

  @override
  Widget build(BuildContext context) => Column(
    children: [
      CircleAvatar(
        radius: 28,
        backgroundColor: const Color(0xffF2E8D7),
        child: Text(
          _restrictedMark(item.platform),
          style: const TextStyle(
            color: Color(0xffD66A2C),
            fontSize: 22,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      const SizedBox(height: 8),
      Text(
        item.account.displayName,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 2),
      Text(
        '平台账户',
        style: TextStyle(fontSize: 12, color: context.appSecondaryText),
      ),
    ],
  );
}

String _restrictedMark(String? value) {
  final text = value?.trim();
  if (text == null || text.isEmpty) return '限';
  return text.substring(0, 1);
}

class _InfoCard extends StatelessWidget {
  const _InfoCard({required this.item});
  final ManagedAccount item;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        _line(context, '账户类型', '受限资金'),
        _line(context, '平台 / 机构', item.platform ?? '未设置'),
        _line(
          context,
          '资金状态',
          item.restrictedStatus?.label ?? RestrictedFundStatus.locked.label,
          valueColor: const Color(0xffE88B37),
        ),
        _line(
          context,
          '预计退回日期',
          item.expectedReturnAt == null
              ? '未设置'
              : _RestrictedAccountDetailPageState._date(item.expectedReturnAt!),
        ),
        _line(context, '是否计入总资产', item.includeInTotal ? '是' : '否'),
        _line(context, '备注', item.note?.trim().isNotEmpty == true ? item.note! : '—'),
      ],
    ),
  );

  Widget _line(
    BuildContext context,
    String label,
    String value, {
    Color? valueColor,
  }) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 7),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 105,
          child: Text(
            label,
            style: TextStyle(color: context.appSecondaryText, fontSize: 12),
          ),
        ),
        Expanded(
          child: Text(
            value,
            textAlign: TextAlign.right,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: valueColor,
            ),
          ),
        ),
      ],
    ),
  );
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    borderRadius: 16,
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 11),
        child: Column(
          children: [
            Icon(icon, color: color),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 12)),
          ],
        ),
      ),
    ),
  );
}

class _TransactionRow extends StatelessWidget {
  const _TransactionRow({
    required this.record,
    required this.accountId,
  });

  final TransactionRecord record;
  final String accountId;

  @override
  Widget build(BuildContext context) {
    final incoming =
        record.destinationAccountId == accountId ||
        (record.type == TransactionType.adjustment &&
            record.accountId == accountId &&
            record.amount > 0);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          SizedBox(
            width: 72,
            child: Text(
              _date(record.occurredAt),
              style: TextStyle(fontSize: 11, color: context.appSecondaryText),
            ),
          ),
          Expanded(
            child: Text(
              record.note?.trim().isNotEmpty == true
                  ? record.note!
                  : record.displayCategoryLabel,
              style: const TextStyle(fontSize: 13),
            ),
          ),
          Text(
            '${incoming ? '+' : '-'}¥${MoneyFormatter.decimal(record.amount.abs())}',
            style: TextStyle(
              color: incoming ? const Color(0xff3D9B5C) : const Color(0xffE05C5C),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _OpeningBalanceRow extends StatelessWidget {
  const _OpeningBalanceRow({required this.account});

  final Account account;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 10),
    child: Row(
      children: [
        SizedBox(
          width: 72,
          child: Text(
            _date(account.createdAt),
            style: TextStyle(fontSize: 11, color: context.appSecondaryText),
          ),
        ),
        const Expanded(
          child: Text('初始存入', style: TextStyle(fontSize: 13)),
        ),
        Text(
          '+¥${MoneyFormatter.decimal((account.openingBalance ?? 0).abs())}',
          style: const TextStyle(
            color: Color(0xff3D9B5C),
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    ),
  );

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';
}

class _MoneyMoveResult {
  const _MoneyMoveResult(this.accountId, this.amount);
  final String accountId;
  final double amount;
}

class _MoneyMoveSheet extends StatefulWidget {
  const _MoneyMoveSheet({
    required this.title,
    required this.accounts,
    this.maxAmount,
  });

  final String title;
  final List<ManagedAccount> accounts;
  final double? maxAmount;

  @override
  State<_MoneyMoveSheet> createState() => _MoneyMoveSheetState();
}

class _MoneyMoveSheetState extends State<_MoneyMoveSheet> {
  late String _accountId = widget.accounts.first.account.id;
  final _amount = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      20,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 24,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          widget.title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: const InputDecoration(labelText: '对方账户'),
          items: [
            for (final item in widget.accounts)
              DropdownMenuItem(
                value: item.account.id,
                child: Text(item.account.displayName),
              ),
          ],
          onChanged: (value) =>
              setState(() => _accountId = value ?? _accountId),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '金额',
            prefixText: '¥ ',
            helperText: widget.maxAmount == null
                ? null
                : '最多 ¥${MoneyFormatter.decimal(widget.maxAmount!)}',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final amount = double.tryParse(_amount.text.trim());
              if (amount == null ||
                  amount <= 0 ||
                  (widget.maxAmount != null &&
                      amount - widget.maxAmount! > .000001)) {
                setState(() => _error = '请输入有效金额');
                return;
              }
              Navigator.pop(
                context,
                _MoneyMoveResult(_accountId, amount),
              );
            },
            child: const Text('确认'),
          ),
        ),
      ],
    ),
  );
}
