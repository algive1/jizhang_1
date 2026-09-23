import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/widgets/app_card.dart';
import '../data/account_management_repository.dart';
import '../data/receivable_repository.dart';
import '../domain/account_management.dart';

class ReceivableDetailPage extends ConsumerWidget {
  const ReceivableDetailPage({required this.receivableId, super.key});

  final String receivableId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final itemsState = ref.watch(receivablesProvider);
    final eventsState = ref.watch(receivableEventsProvider(receivableId));
    final item = (itemsState.value ?? const <Receivable>[])
        .where((entry) => entry.id == receivableId)
        .firstOrNull;

    if (itemsState.isLoading && item == null) {
      return const SafeArea(child: Center(child: CircularProgressIndicator()));
    }
    if (item == null) {
      return const SafeArea(child: Center(child: Text('应收记录不存在')));
    }

    final events = eventsState.value ?? const <ReceivableEvent>[];
    final ended = item.status == ReceivableStatus.completed ||
        item.status == ReceivableStatus.writtenOff;

    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 28),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () => context.canPop()
                    ? context.pop()
                    : context.go('/profile/accounts/receivables'),
                icon: const Icon(Icons.arrow_back),
              ),
              Expanded(
                child: Text(
                  '应收详情',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              TextButton(
                onPressed: ended ? null : () => _edit(context, ref, item),
                child: const Text('编辑'),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Column(
            children: [
              CircleAvatar(
                radius: 28,
                backgroundColor: const Color(0xffE7F0FF),
                child: Icon(
                  _icon(item.type),
                  color: const Color(0xff5B8DEF),
                  size: 26,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                item.name,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                item.counterparty,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appSecondaryText,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AppCard(
            color: context.appPrimarySoft.withValues(alpha: .62),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '待收金额（元）',
                  style: TextStyle(
                    fontSize: 12,
                    color: context.appSecondaryText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '¥ ${MoneyFormatter.decimal(item.remainingAmount)}',
                  style: const TextStyle(
                    fontSize: 30,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          AppCard(
            child: Column(
              children: [
                _line(context, '应收类型', item.type.label),
                _line(context, '往来对象', item.counterparty),
                _line(context, '发生日期', _date(item.occurredAt)),
                _line(
                  context,
                  '预计到账',
                  item.expectedAt == null ? '未设置' : _date(item.expectedAt!),
                ),
                _line(
                  context,
                  '当前状态',
                  item.visibleStatus,
                  valueColor:
                      item.effectiveStatus == ReceivableStatus.overdue
                      ? const Color(0xffE05C5C)
                      : const Color(0xffE79B3A),
                ),
                _line(
                  context,
                  '已收回',
                  '¥${MoneyFormatter.decimal(item.receivedAmount)}',
                ),
                _line(
                  context,
                  '剩余待收',
                  '¥${MoneyFormatter.decimal(item.remainingAmount)}',
                ),
                _line(
                  context,
                  '备注',
                  item.remark?.trim().isNotEmpty == true ? item.remark! : '—',
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _ActionButton(
                  icon: Icons.south_rounded,
                  label: '收回',
                  color: const Color(0xff3D9B5C),
                  enabled: !ended && item.remainingAmount > 0,
                  onTap: () => _collect(
                    context,
                    ref,
                    item,
                    full: true,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.pie_chart_outline_rounded,
                  label: '部分收回',
                  color: const Color(0xff5B8DEF),
                  enabled: !ended && item.remainingAmount > 0,
                  onTap: () => _collect(
                    context,
                    ref,
                    item,
                    full: false,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.notifications_none_rounded,
                  label: '提醒',
                  color: const Color(0xffE79B3A),
                  enabled: !ended,
                  onTap: () => _remind(context, ref, item),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _ActionButton(
                  icon: Icons.check_box_outlined,
                  label: '核销',
                  color: const Color(0xff8867D8),
                  enabled: !ended,
                  onTap: () => _writeOff(context, ref, item),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '跟进记录',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (eventsState.isLoading && events.isEmpty)
            const Center(child: CircularProgressIndicator())
          else if (events.isEmpty)
            AppCard(
              child: Text(
                '暂无跟进记录',
                style: TextStyle(color: context.appSecondaryText),
              ),
            )
          else
            AppCard(
              padding: const EdgeInsets.fromLTRB(14, 8, 14, 8),
              child: Column(
                children: [
                  for (var index = 0; index < events.length; index++)
                    _TimelineRow(
                      event: events[index],
                      isLast: index == events.length - 1,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  static Future<void> _collect(
    BuildContext context,
    WidgetRef ref,
    Receivable item, {
    required bool full,
  }) async {
    final accounts =
        ref
            .read(managedAccountsProvider)
            .value
            ?.where(
              (entry) =>
                  !entry.account.type.isDebt &&
                  entry.account.assetForm != AssetForm.investment &&
                  entry.category != AccountFundCategory.restricted,
            )
            .toList() ??
        const <ManagedAccount>[];
    if (accounts.isEmpty) {
      _message(context, '没有可接收回款的账户');
      return;
    }

    final result = await showModalBottomSheet<_CollectResult>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CollectSheet(
        accounts: accounts,
        fixedAmount: full ? item.remainingAmount : null,
        maxAmount: item.remainingAmount,
      ),
    );
    if (result == null) return;

    try {
      await ref.read(receivableRepositoryProvider).collect(
        receivableId: item.id,
        amount: result.amount,
        destinationAccountId: result.accountId,
      );
      ref.invalidate(receivablesProvider);
      ref.invalidate(receivableEventsProvider(item.id));
      ref.invalidate(receivableMonthCollectedProvider);
      if (context.mounted) _message(context, '回款已记录');
    } on Object catch (error) {
      if (context.mounted) _message(context, '回款失败：$error');
    }
  }

  static Future<void> _remind(
    BuildContext context,
    WidgetRef ref,
    Receivable item,
  ) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: item.expectedAt?.isAfter(now) == true
          ? item.expectedAt!
          : now.add(const Duration(days: 1)),
      firstDate: now,
      lastDate: DateTime(now.year + 5),
    );
    if (picked == null) return;
    try {
      await ref.read(receivableRepositoryProvider).addEvent(
        receivableId: item.id,
        eventType: 'reminder',
        title: '设置提醒',
        description: '提醒日期 ${_date(picked)}',
      );
      ref.invalidate(receivableEventsProvider(item.id));
      if (context.mounted) {
        _message(context, '提醒日期已记录');
      }
    } on Object catch (error) {
      if (context.mounted) _message(context, '设置失败：$error');
    }
  }

  static Future<void> _writeOff(
    BuildContext context,
    WidgetRef ref,
    Receivable item,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('核销这笔应收？'),
        content: Text(
          '剩余 ¥${MoneyFormatter.decimal(item.remainingAmount)} 将不再计入待收金额，历史记录会保留。',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('确认核销'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ref.read(receivableRepositoryProvider).writeOff(item.id);
      ref.invalidate(receivablesProvider);
      ref.invalidate(receivableEventsProvider(item.id));
      if (context.mounted) _message(context, '已核销');
    } on Object catch (error) {
      if (context.mounted) _message(context, '核销失败：$error');
    }
  }

  static Future<void> _edit(
    BuildContext context,
    WidgetRef ref,
    Receivable item,
  ) async {
    final name = TextEditingController(text: item.name);
    final counterparty = TextEditingController(text: item.counterparty);
    final amount = TextEditingController(
      text: item.totalAmount.toStringAsFixed(2),
    );
    final remark = TextEditingController(text: item.remark ?? '');
    final businessStatusController = TextEditingController(
      text: item.businessStatus,
    );
    var type = item.type;
    var occurredAt = item.occurredAt;
    var expectedAt = item.expectedAt;
    var businessStatus = item.businessStatus;

    final save = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setLocalState) => AlertDialog(
          title: const Text('编辑应收'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<ReceivableType>(
                  initialValue: type,
                  decoration: const InputDecoration(labelText: '应收类型'),
                  items: [
                    for (final value in ReceivableType.values)
                      DropdownMenuItem(
                        value: value,
                        child: Text(value.label),
                      ),
                  ],
                  onChanged: (value) =>
                      setLocalState(() => type = value ?? type),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: name,
                  decoration: const InputDecoration(labelText: '应收名称'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: counterparty,
                  decoration: const InputDecoration(labelText: '往来对象'),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '应收总额',
                    prefixText: '¥ ',
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: businessStatusController,
                  decoration: const InputDecoration(labelText: '业务状态'),
                  onChanged: (value) => businessStatus = value,
                ),
                const SizedBox(height: 4),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('发生日期'),
                  subtitle: Text(_date(occurredAt)),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: occurredAt,
                      firstDate: DateTime(DateTime.now().year - 10),
                      lastDate: DateTime(DateTime.now().year + 5),
                    );
                    if (value != null) {
                      setLocalState(() => occurredAt = value);
                    }
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('预计到账'),
                  subtitle: Text(
                    expectedAt == null ? '未设置' : _date(expectedAt!),
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: () async {
                    final value = await showDatePicker(
                      context: context,
                      initialDate: expectedAt ?? DateTime.now(),
                      firstDate: DateTime(DateTime.now().year - 5),
                      lastDate: DateTime(DateTime.now().year + 10),
                    );
                    if (value != null) {
                      setLocalState(() => expectedAt = value);
                    }
                  },
                ),
                TextField(
                  controller: remark,
                  maxLines: 3,
                  decoration: const InputDecoration(labelText: '备注'),
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
    if (save != true) {
      name.dispose();
      counterparty.dispose();
      amount.dispose();
      remark.dispose();
      businessStatusController.dispose();
      return;
    }

    final totalAmount = double.tryParse(amount.text.trim());
    if (totalAmount == null || totalAmount <= 0) {
      if (context.mounted) _message(context, '请输入有效金额');
      name.dispose();
      counterparty.dispose();
      amount.dispose();
      remark.dispose();
      businessStatusController.dispose();
      return;
    }

    try {
      await ref.read(receivableRepositoryProvider).update(
        Receivable(
          id: item.id,
          bookId: item.bookId,
          name: name.text.trim(),
          type: type,
          counterparty: counterparty.text.trim(),
          totalAmount: totalAmount,
          receivedAmount: item.receivedAmount,
          occurredAt: occurredAt,
          expectedAt: expectedAt,
          status: item.status,
          businessStatus: businessStatus,
          remark: remark.text.trim(),
          createdAt: item.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
      ref.invalidate(receivablesProvider);
      ref.invalidate(receivableEventsProvider(item.id));
      if (context.mounted) _message(context, '应收已更新');
    } on Object catch (error) {
      if (context.mounted) _message(context, '保存失败：$error');
    } finally {
      name.dispose();
      counterparty.dispose();
      amount.dispose();
      remark.dispose();
      businessStatusController.dispose();
    }
  }

  static Widget _line(
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
          width: 100,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: context.appSecondaryText,
            ),
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

  static IconData _icon(ReceivableType type) => switch (type) {
    ReceivableType.reimbursement => Icons.flight_takeoff_outlined,
    ReceivableType.refund => Icons.shopping_cart_outlined,
    ReceivableType.lend => Icons.person_outline,
    ReceivableType.customer => Icons.receipt_long_outlined,
    ReceivableType.other => Icons.schedule_outlined,
  };

  static String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}-'
      '${value.month.toString().padLeft(2, '0')}-'
      '${value.day.toString().padLeft(2, '0')}';

  static void _message(BuildContext context, String text) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(text)),
    );
  }
}

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => AppCard(
    padding: EdgeInsets.zero,
    borderRadius: 16,
    child: InkWell(
      onTap: enabled ? onTap : null,
      borderRadius: BorderRadius.circular(16),
      child: Opacity(
        opacity: enabled ? 1 : .4,
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
    ),
  );
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({required this.event, required this.isLast});
  final ReceivableEvent event;
  final bool isLast;

  @override
  Widget build(BuildContext context) => IntrinsicHeight(
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 46,
          child: Text(
            '${event.createdAt.month.toString().padLeft(2, '0')}-'
            '${event.createdAt.day.toString().padLeft(2, '0')}',
            style: TextStyle(
              fontSize: 11,
              color: context.appSecondaryText,
            ),
          ),
        ),
        SizedBox(
          width: 20,
          child: Column(
            children: [
              Container(
                width: 9,
                height: 9,
                decoration: BoxDecoration(
                  color: context.appPrimary,
                  shape: BoxShape.circle,
                ),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1,
                    color: context.appDivider,
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  event.title,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (event.description?.trim().isNotEmpty == true)
                  Text(
                    event.description!,
                    style: TextStyle(
                      fontSize: 11,
                      color: context.appSecondaryText,
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    ),
  );
}

class _CollectResult {
  const _CollectResult(this.accountId, this.amount);
  final String accountId;
  final double amount;
}

class _CollectSheet extends StatefulWidget {
  const _CollectSheet({
    required this.accounts,
    required this.maxAmount,
    this.fixedAmount,
  });

  final List<ManagedAccount> accounts;
  final double maxAmount;
  final double? fixedAmount;

  @override
  State<_CollectSheet> createState() => _CollectSheetState();
}

class _CollectSheetState extends State<_CollectSheet> {
  late String _accountId = widget.accounts.first.account.id;
  late final TextEditingController _amount = TextEditingController(
    text: widget.fixedAmount?.toStringAsFixed(2) ?? '',
  );
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
          widget.fixedAmount == null ? '部分收回' : '收回',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 16),
        DropdownButtonFormField<String>(
          initialValue: _accountId,
          decoration: const InputDecoration(labelText: '到账账户'),
          items: [
            for (final account in widget.accounts)
              DropdownMenuItem(
                value: account.account.id,
                child: Text(account.account.displayName),
              ),
          ],
          onChanged: (value) =>
              setState(() => _accountId = value ?? _accountId),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _amount,
          enabled: widget.fixedAmount == null,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            labelText: '到账金额',
            prefixText: '¥ ',
            helperText:
                '剩余待收 ¥${MoneyFormatter.decimal(widget.maxAmount)}',
            errorText: _error,
          ),
        ),
        const SizedBox(height: 18),
        SizedBox(
          width: double.infinity,
          child: FilledButton(
            onPressed: () {
              final value =
                  widget.fixedAmount ?? double.tryParse(_amount.text.trim());
              if (value == null ||
                  value <= 0 ||
                  value - widget.maxAmount > .000001) {
                setState(() => _error = '请输入有效金额');
                return;
              }
              Navigator.pop(
                context,
                _CollectResult(_accountId, value),
              );
            },
            child: const Text('确认'),
          ),
        ),
      ],
    ),
  );
}
