import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/recurring_bill.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../data/recurring_bill_repository.dart';

class RecurringBillsPage extends ConsumerStatefulWidget {
  const RecurringBillsPage({super.key});

  @override
  ConsumerState<RecurringBillsPage> createState() => _RecurringBillsPageState();
}

class _RecurringBillsPageState extends ConsumerState<RecurringBillsPage> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final active =
        ref.watch(recurringBillsProvider).value ?? const <RecurringBill>[];
    final all = ref.watch(recurringBillsAllProvider).value ?? active;
    final autoRecordError = ref.watch(recurringAutoRecordErrorProvider);
    final now = DateTime.now();
    final bills = switch (_tab) {
      0 => active,
      1 => all,
      _ =>
        all.where((bill) => bill.status == RecurringBillStatus.ended).toList(),
    };
    final monthlyOut = active
        .where(
          (bill) =>
              !bill.isIncome &&
              bill.nextDate.year == now.year &&
              bill.nextDate.month == now.month,
        )
        .fold<double>(0, (sum, bill) => sum + bill.amount);
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        children: [
          Row(
            children: [
              IconButton(
                onPressed: () =>
                    context.canPop() ? context.pop() : context.go('/'),
                icon: const Icon(Icons.arrow_back),
                tooltip: '返回首页',
              ),
              Expanded(
                child: Text(
                  '周期账单',
                  style: Theme.of(context).textTheme.headlineMedium,
                ),
              ),
              IconButton(
                onPressed: active.any((bill) => bill.autoRecord)
                    ? () => _recordDue(active)
                    : null,
                icon: const Icon(Icons.play_circle_outline),
                tooltip: '执行自动记账',
              ),
              IconButton(
                onPressed: () => _openCreate(context, ref),
                icon: const Icon(Icons.add_circle_outline),
                tooltip: '新增周期账单',
              ),
            ],
          ),
          AppCard(
            color: AppColors.primarySoft,
            child: Row(
              children: [
                const Icon(
                  Icons.loop_rounded,
                  color: AppColors.primaryDark,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '本月固定支出',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 4),
                    MoneyText(
                      monthlyOut,
                      style: const TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primaryDark,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (autoRecordError != null) ...[
            const SizedBox(height: 10),
            AppCard(
              color: AppColors.warning.withValues(alpha: .14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.error_outline, color: AppColors.warning),
                  const SizedBox(width: 10),
                  Expanded(child: Text(autoRecordError)),
                  IconButton(
                    onPressed: () => ref
                        .read(recurringAutoRecordErrorProvider.notifier)
                        .setError(null),
                    icon: const Icon(Icons.close),
                    tooltip: '关闭提示',
                  ),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 0, label: Text('即将扣款')),
              ButtonSegment(value: 1, label: Text('全部')),
              ButtonSegment(value: 2, label: Text('已结束')),
            ],
            selected: {_tab},
            onSelectionChanged: (value) => setState(() => _tab = value.first),
          ),
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: Text(
              '${bills.length} 项',
              style: const TextStyle(color: AppColors.textSecondary),
            ),
          ),
          if (bills.isEmpty)
            const AppCard(
              child: Text(
                '还没有周期账单，添加房租、订阅或固定收入',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            )
          else
            for (final bill in bills) ...[
              _RecurringBillCard(
                bill: bill,
                onToggleStatus: () => _toggleStatus(bill),
                onEnd: () => _endBill(bill),
                onRecord:
                    bill.status == RecurringBillStatus.active &&
                        bill.accountId != null
                    ? () => _recordBill(bill)
                    : null,
              ),
              const SizedBox(height: 10),
            ],
        ],
      ),
    );
  }

  RecurringBill _withStatus(RecurringBill bill, RecurringBillStatus status) =>
      RecurringBill(
        id: bill.id,
        bookId: bill.bookId,
        name: bill.name,
        type: bill.type,
        amount: bill.amount,
        cycle: bill.cycle,
        startDate: bill.startDate,
        endDate: bill.endDate,
        nextDate: bill.nextDate,
        accountId: bill.accountId,
        categoryId: bill.categoryId,
        customIntervalDays: bill.customIntervalDays,
        autoRecord: bill.autoRecord,
        reminder: bill.reminder,
        status: status,
        createdAt: bill.createdAt,
        updatedAt: DateTime.now(),
      );

  Future<void> _toggleStatus(RecurringBill bill) async {
    final status = bill.status == RecurringBillStatus.active
        ? RecurringBillStatus.paused
        : RecurringBillStatus.active;
    await ref
        .read(recurringBillRepositoryProvider)
        .update(_withStatus(bill, status));
    _refresh();
  }

  Future<void> _endBill(RecurringBill bill) async {
    await ref.read(recurringBillRepositoryProvider).archive(bill.id);
    _refresh();
  }

  Future<void> _recordBill(RecurringBill bill) async {
    try {
      await ref.read(recurringBillExecutionServiceProvider).recordDue(bill);
      _refresh();
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('${bill.name} 已记账')));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('记账失败：$error')));
    }
  }

  Future<void> _recordDue(List<RecurringBill> bills) async {
    final today = DateTime.now();
    final due = bills.where(
      (bill) =>
          bill.autoRecord &&
          bill.accountId != null &&
          !bill.nextDate.isAfter(today),
    );
    var count = 0;
    for (final bill in due) {
      try {
        await ref.read(recurringBillExecutionServiceProvider).recordDue(bill);
        count++;
      } on Object {
        // Continue processing other independent bills; the UI reports the
        // successful count and leaves failed items available for repair.
      }
    }
    _refresh();
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text('已执行 $count 项到期自动记账')));
  }

  void _refresh() {
    ref.invalidate(recurringBillsProvider);
    ref.invalidate(recurringBillsAllProvider);
  }

  Future<void> _openCreate(BuildContext context, WidgetRef ref) async {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final categories = ref.read(categoriesProvider).value ?? const <Category>[];
    final created = await showDialog<RecurringBill>(
      context: context,
      builder: (_) => _RecurringBillDialog(
        bookId: ref.read(activeBookIdProvider),
        accounts: accounts,
        categories: categories,
      ),
    );
    if (created == null || !context.mounted) return;
    try {
      await ref.read(recurringBillRepositoryProvider).create(created);
      _refresh();
    } on Object catch (error) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }
}

class _RecurringBillDialog extends StatefulWidget {
  const _RecurringBillDialog({
    required this.bookId,
    required this.accounts,
    required this.categories,
  });

  final String bookId;
  final List<Account> accounts;
  final List<Category> categories;

  @override
  State<_RecurringBillDialog> createState() => _RecurringBillDialogState();
}

class _RecurringBillDialogState extends State<_RecurringBillDialog> {
  final _name = TextEditingController();
  final _amount = TextEditingController();
  final _customInterval = TextEditingController(text: '30');
  RecurringBillType _type = RecurringBillType.subscription;
  RecurringBillCycle _cycle = RecurringBillCycle.monthly;
  bool _autoRecord = false;
  bool _reminder = true;
  String? _accountId;
  String? _categoryId;

  List<Category> get _availableCategories => widget.categories
      .where(
        (category) =>
            category.type ==
            (_type == RecurringBillType.income
                ? CategoryType.income
                : CategoryType.expense),
      )
      .toList();

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _customInterval.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('新增周期账单'),
    content: SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _name,
            decoration: const InputDecoration(labelText: '名称'),
          ),
          TextField(
            controller: _amount,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: '金额'),
          ),
          DropdownButtonFormField<RecurringBillType>(
            initialValue: _type,
            decoration: const InputDecoration(labelText: '类型'),
            items:
                const {
                      RecurringBillType.subscription: '订阅',
                      RecurringBillType.rent: '房租',
                      RecurringBillType.mortgage: '房贷',
                      RecurringBillType.insurance: '保险',
                      RecurringBillType.mobilePlan: '手机套餐',
                      RecurringBillType.income: '固定收入',
                      RecurringBillType.other: '其他',
                    }.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() {
              _type = value ?? _type;
              _categoryId = null;
            }),
          ),
          DropdownButtonFormField<RecurringBillCycle>(
            initialValue: _cycle,
            decoration: const InputDecoration(labelText: '周期'),
            items:
                const {
                      RecurringBillCycle.weekly: '每周',
                      RecurringBillCycle.monthly: '每月',
                      RecurringBillCycle.quarterly: '每季度',
                      RecurringBillCycle.halfYear: '每半年',
                      RecurringBillCycle.yearly: '每年',
                      RecurringBillCycle.custom: '自定义',
                    }.entries
                    .map(
                      (entry) => DropdownMenuItem(
                        value: entry.key,
                        child: Text(entry.value),
                      ),
                    )
                    .toList(),
            onChanged: (value) => setState(() => _cycle = value ?? _cycle),
          ),
          if (_cycle == RecurringBillCycle.custom)
            TextField(
              controller: _customInterval,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '自定义间隔（天）'),
            ),
          DropdownButtonFormField<String?>(
            initialValue: _accountId,
            decoration: const InputDecoration(labelText: '扣款/入账账户'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('暂不指定')),
              ...widget.accounts.map(
                (account) => DropdownMenuItem<String?>(
                  value: account.id,
                  child: Text(account.displayName),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _accountId = value),
          ),
          DropdownButtonFormField<String?>(
            initialValue: _categoryId,
            decoration: const InputDecoration(labelText: '分类'),
            items: [
              const DropdownMenuItem<String?>(value: null, child: Text('暂不指定')),
              ..._availableCategories.map(
                (category) => DropdownMenuItem<String?>(
                  value: category.id,
                  child: Text(category.name),
                ),
              ),
            ],
            onChanged: (value) => setState(() => _categoryId = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('自动记账'),
            value: _autoRecord,
            onChanged: (value) => setState(() => _autoRecord = value),
          ),
          SwitchListTile.adaptive(
            contentPadding: EdgeInsets.zero,
            title: const Text('扣款提醒'),
            value: _reminder,
            onChanged: (value) => setState(() => _reminder = value),
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(onPressed: _submit, child: const Text('保存')),
    ],
  );

  void _submit() {
    final name = _name.text.trim();
    final amount = double.tryParse(_amount.text.trim());
    final customInterval = int.tryParse(_customInterval.text.trim());
    if (name.isEmpty || amount == null || amount <= 0) return;
    if (_cycle == RecurringBillCycle.custom &&
        (customInterval == null || customInterval < 1))
      return;
    if (_autoRecord && _accountId == null) return;
    final now = DateTime.now();
    Navigator.pop(
      context,
      RecurringBill(
        id: 'recurring-${newEntityId()}',
        bookId: widget.bookId,
        name: name,
        type: _type,
        amount: amount,
        cycle: _cycle,
        startDate: now,
        nextDate: now,
        accountId: _accountId,
        categoryId: _categoryId,
        customIntervalDays: _cycle == RecurringBillCycle.custom
            ? customInterval
            : null,
        autoRecord: _autoRecord,
        reminder: _reminder,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}

class _RecurringBillCard extends StatelessWidget {
  const _RecurringBillCard({
    required this.bill,
    required this.onToggleStatus,
    required this.onEnd,
    this.onRecord,
  });

  final RecurringBill bill;
  final VoidCallback onToggleStatus;
  final VoidCallback onEnd;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    final cycle = switch (bill.cycle) {
      RecurringBillCycle.weekly => '每周',
      RecurringBillCycle.monthly => '每月',
      RecurringBillCycle.quarterly => '每季度',
      RecurringBillCycle.halfYear => '每半年',
      RecurringBillCycle.yearly => '每年',
      RecurringBillCycle.custom => '自定义',
    };
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
      child: Column(
        children: [
          Row(
            children: [
              const Icon(
                Icons.event_repeat_outlined,
                color: AppColors.primary,
                size: 28,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      bill.name,
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$cycle · 下次 ${bill.nextDate.month}月${bill.nextDate.day}日${bill.autoRecord ? ' · 自动' : ''}',
                      style: const TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              MoneyText(
                bill.amount,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
            ],
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Wrap(
              alignment: WrapAlignment.end,
              children: [
                if (onRecord != null)
                  TextButton(onPressed: onRecord, child: const Text('记账')),
                if (bill.status != RecurringBillStatus.ended)
                  TextButton(
                    onPressed: onToggleStatus,
                    child: Text(
                      bill.status == RecurringBillStatus.active ? '暂停' : '恢复',
                    ),
                  ),
                if (bill.status != RecurringBillStatus.ended)
                  TextButton(onPressed: onEnd, child: const Text('结束')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
