import 'dart:async';

import '../../../core/widgets/app_bottom_sheet.dart';
import 'recurring_bill_editor.dart';
import 'recurring_bill_create_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/models/recurring_bill.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../application/recurring_bill_notification_service.dart';
import '../data/recurring_bill_repository.dart';

class RecurringBillsPage extends ConsumerStatefulWidget {
  const RecurringBillsPage({super.key, this.focusBillId});

  final String? focusBillId;

  @override
  ConsumerState<RecurringBillsPage> createState() => _RecurringBillsPageState();
}

class _RecurringBillsPageState extends ConsumerState<RecurringBillsPage> {
  int _tab = 0;
  bool _focusOpened = false;

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
    final focusBill = widget.focusBillId == null
        ? null
        : all.where((bill) => bill.id == widget.focusBillId).firstOrNull;
    if (focusBill != null && !_focusOpened) {
      _focusOpened = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _detail(focusBill);
      });
    }
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
                icon: Icon(Icons.arrow_back),
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
                icon: Icon(Icons.play_circle_outline),
                tooltip: '执行自动记账',
              ),
              IconButton(
                onPressed: () => _openCreate(context, ref),
                icon: Icon(Icons.add_circle_outline),
                tooltip: '新增周期账单',
              ),
            ],
          ),
          AppCard(
            color: context.appPrimarySoft,
            child: Row(
              children: [
                Icon(
                  Icons.loop_rounded,
                  color: context.appPrimary,
                  size: 30,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '本月固定支出',
                      style: TextStyle(color: context.appSecondaryText),
                    ),
                    const SizedBox(height: 4),
                    MoneyText(
                      monthlyOut,
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                        color: context.appPrimary,
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
                  Icon(Icons.error_outline, color: AppColors.warning),
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
              style: TextStyle(color: context.appSecondaryText),
            ),
          ),
          if (bills.isEmpty)
            AppCard(
              child: Text(
                '还没有周期账单，添加房租、订阅或固定收入',
                style: TextStyle(color: context.appSecondaryText),
              ),
            )
          else
            for (final bill in bills) ...[
              _RecurringBillCard(
                bill: bill,
                account:
                    ref
                        .watch(accountsProvider)
                        .value
                        ?.where((a) => a.id == bill.accountId)
                        .firstOrNull
                        ?.displayName ??
                    '未指定账户',
                onTap: () => _detail(bill),
                onLongPress: () => _actions(bill),
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

  Future<void> _toggleStatus(RecurringBill bill) async {
    final status = bill.status == RecurringBillStatus.active
        ? RecurringBillStatus.paused
        : RecurringBillStatus.active;
    final updated = bill.copyWith(status: status, updatedAt: DateTime.now());
    await ref.read(recurringBillRepositoryProvider).update(updated);
    unawaited(_syncNotification(updated));
    _refresh();
  }

  Future<void> _endBill(RecurringBill bill) async {
    if (!await AppConfirmDialog.show(
          context,
          title: '删除周期账单？',
          message: '停止未来计划，已有流水和余额保持不变。',
        ) ||
        !mounted)
      return;
    await ref.read(recurringBillRepositoryProvider).archive(bill.id);
    unawaited(
      ref.read(recurringBillNotificationSchedulerProvider).cancel(bill.id),
    );
    _refresh();
  }

  Future<void> _recordBill(RecurringBill bill) async {
    try {
      await ref.read(recurringBillExecutionServiceProvider).recordDue(bill);
      unawaited(_syncNotifications());
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
    unawaited(_syncNotifications());
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
    final now = DateTime.now();
    final bill = await RecurringBillCreateSheet.show(
      context,
      RecurringBill(
        id: 'recurring-${newEntityId()}',
        bookId: ref.read(activeBookIdProvider),
        name: '',
        type: RecurringBillType.other,
        amount: 0,
        cycle: RecurringBillCycle.monthly,
        startDate: now,
        nextDate: now,
        createdAt: now,
        updatedAt: now,
      ),
    );
    if (bill == null || !mounted) return;
    try {
      await ref.read(recurringBillRepositoryProvider).create(bill);
      unawaited(_syncNotification(bill));
      _refresh();
    } on Object catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(this.context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
      }
    }
  }

  Future<void> _edit(RecurringBill bill, {bool create = false}) async {
    final edited = await RecurringBillEditor.show(context, bill);
    if (edited == null || !mounted) return;
    try {
      final repository = ref.read(recurringBillRepositoryProvider);
      if (create) {
        await repository.create(edited);
      } else {
        await repository.update(edited);
      }
      unawaited(_syncNotification(edited));
      _refresh();
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('保存失败：$error')));
    }
  }

  Future<void> _syncNotification(RecurringBill bill) async {
    try {
      final scheduler = ref.read(recurringBillNotificationSchedulerProvider);
      if (bill.reminder) await scheduler.requestPermission();
      await scheduler.syncBill(bill);
    } on Object catch (error) {
      debugPrint('周期账单通知同步失败：$error');
    }
  }

  Future<void> _syncNotifications() async {
    try {
      final scheduler = ref.read(recurringBillNotificationSchedulerProvider);
      final bills = await ref
          .read(recurringBillRepositoryProvider)
          .getAllForNotification();
      if (bills.any((bill) => bill.reminder)) {
        await scheduler.requestPermission();
      }
      await scheduler.syncBills(bills);
    } on Object catch (error) {
      debugPrint('周期账单通知同步失败：$error');
    }
  }

  Future<void> _actions(RecurringBill bill) async {
    final action = await AppBottomSheet.show<String>(
      context: context,
      builder: (sheet) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              bill.name,
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
          ),
          AppSheetOption(
            title: '编辑周期账单',
            icon: Icons.edit_outlined,
            onTap: () => Navigator.pop(sheet, 'edit'),
          ),
          if (bill.status != RecurringBillStatus.ended)
            AppSheetOption(
              title: bill.status == RecurringBillStatus.active
                  ? '暂停周期账单'
                  : '恢复周期账单',
              icon: Icons.pause_circle_outline,
              onTap: () => Navigator.pop(sheet, 'pause'),
            ),
          AppSheetOption(
            title: '复制周期账单',
            icon: Icons.copy_outlined,
            onTap: () => Navigator.pop(sheet, 'copy'),
          ),
          AppSheetOption(
            title: '删除周期账单',
            destructive: true,
            icon: Icons.delete_outline,
            onTap: () => Navigator.pop(sheet, 'delete'),
          ),
          AppSheetOption(title: '取消', onTap: () => Navigator.pop(sheet)),
        ],
      ),
    );
    if (!mounted) return;
    try {
      switch (action) {
        case 'edit':
          await _edit(bill);
        case 'pause':
          await _toggleStatus(bill);
        case 'copy':
          await _edit(
            bill.copyWith(
              id: 'recurring-${newEntityId()}',
              completedCount: 0,
              status: RecurringBillStatus.active,
            ),
            create: true,
          );
        case 'delete':
          await _endBill(bill);
      }
    } on Object catch (error) {
      if (mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }

  Future<void> _detail(RecurringBill bill) => AppBottomSheet.show<void>(
    context: context,
    builder: (_) => Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            bill.name,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          MoneyText(bill.amount),
          Text(bill.scheduleLabel),
          Text(
            '下一次：${bill.nextDate.year}-${bill.nextDate.month}-${bill.nextDate.day}',
          ),
          Text(bill.autoRecord ? '自动入账' : '到期后待确认，确认前不影响余额'),
          if (bill.status == RecurringBillStatus.active)
            FilledButton(
              onPressed: bill.nextDate.isAfter(DateTime.now())
                  ? null
                  : () async {
                      Navigator.pop(context);
                      await _recordBill(bill);
                    },
              child: Text(
                bill.nextDate.isAfter(DateTime.now()) ? '到期后确认本期入账' : '确认本期入账',
              ),
            ),
        ],
      ),
    ),
  );
}

class _RecurringBillCard extends StatelessWidget {
  const _RecurringBillCard({
    required this.bill,
    required this.account,
    required this.onTap,
    required this.onLongPress,
    required this.onToggleStatus,
    required this.onEnd,
    this.onRecord,
  });

  final RecurringBill bill;
  final String account;
  final VoidCallback onTap, onLongPress;
  final VoidCallback onToggleStatus;
  final VoidCallback onEnd;
  final VoidCallback? onRecord;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      onLongPress: onLongPress,
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 10),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  Icons.event_repeat_outlined,
                  color: context.appPrimary,
                  size: 28,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.name,
                        style: TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${bill.scheduleLabel} · $account\n下次 ${bill.nextDate.month}月${bill.nextDate.day}日 · ${bill.status == RecurringBillStatus.active
                            ? (bill.nextDate.isAfter(DateTime.now()) ? '进行中' : '待确认')
                            : bill.status == RecurringBillStatus.paused
                            ? '已暂停'
                            : '已结束'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: context.appSecondaryText,
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
      ),
    );
  }
}
