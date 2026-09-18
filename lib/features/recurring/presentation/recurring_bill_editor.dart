import '../../../core/widgets/app_date_picker.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../accounts/data/account_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../../core/models/category.dart';

import 'package:flutter/material.dart';

import '../../../core/models/recurring_bill.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_form.dart';

/// Shared by quick entry and the recurring plan management page.
class RecurringBillEditor extends ConsumerStatefulWidget {
  const RecurringBillEditor({
    super.key,
    required this.bill,
    this.scheduleOnly = false,
    this.onDisable,
  });
  final RecurringBill bill;
  final bool scheduleOnly;
  final VoidCallback? onDisable;
  static Future<RecurringBill?> show(
    BuildContext context,
    RecurringBill bill, {
    bool scheduleOnly = false,
    VoidCallback? onDisable,
  }) => AppBottomSheet.show(
    context: context,
    builder: (_) => RecurringBillEditor(
      bill: bill,
      scheduleOnly: scheduleOnly,
      onDisable: onDisable,
    ),
  );
  @override
  ConsumerState<RecurringBillEditor> createState() =>
      _RecurringBillEditorState();
}

class _RecurringBillEditorState extends ConsumerState<RecurringBillEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.bill.name);
  late final _amount = TextEditingController(
    text: widget.bill.amount.toStringAsFixed(2),
  );
  late final _interval = TextEditingController(text: '${widget.bill.interval}');
  late final _count = TextEditingController(
    text: '${widget.bill.repeatCount ?? 12}',
  );
  late final _customDays = TextEditingController(
    text: '${widget.bill.customIntervalDays ?? 30}',
  );
  late RecurringBillCycle _cycle = widget.bill.cycle;
  late RecurringBillType _type = widget.bill.type;
  late DateTime _start = DateUtils.dateOnly(widget.bill.startDate);
  late DateTime _end =
      widget.bill.endDate ??
      DateTime(_start.year + 1, _start.month, _start.day);
  late String _endType = widget.bill.endType;
  late int _day = widget.bill.dayOfMonth ?? _start.day;
  late int _weekday = widget.bill.weekday ?? _start.weekday;
  late int _month = widget.bill.month ?? _start.month;
  late int _reminder = widget.bill.reminder ? widget.bill.reminderDays : -1;
  late bool _auto = widget.bill.autoRecord;
  late String? _accountId = widget.bill.accountId;
  late String? _categoryId = widget.bill.categoryId;
  String? _error;
  @override
  void dispose() {
    for (final c in [_name, _amount, _interval, _count, _customDays]) {
      c.dispose();
    }
    super.dispose();
  }

  String? _positive(String? value) =>
      (int.tryParse(value ?? '') ?? 0) < 1 ? '请输入大于 0 的整数' : null;
  String _date(DateTime d) =>
      '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  Widget _select<T>(
    String label,
    T value,
    Map<T, String> options,
    ValueChanged<T> change,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: AppSelect<T>(
      initialValue: value,
      decoration: InputDecoration(labelText: label),
      items: [
        for (final e in options.entries)
          DropdownMenuItem(value: e.key, child: Text(e.value)),
      ],
      onChanged: (v) {
        if (v != null) setState(() => change(v));
      },
    ),
  );
  Future<void> _pick(bool end) async {
    final value = await AppDatePicker.show(context, end ? _end : _start);
    if (value != null)
      setState(() {
        if (end) {
          _end = value;
        } else {
          _start = value;
        }
      });
  }

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
    child: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            widget.bill.name.trim().isEmpty ? '新增周期账单' : '编辑周期账单',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
          ),
          if (widget.onDisable != null)
            TextButton(
              onPressed: () {
                widget.onDisable!();
                Navigator.pop(context);
              },
              child: const Text('关闭定期付'),
            ),
          const SizedBox(height: 16),
          if (!widget.scheduleOnly) ...[
            AppInput(
              controller: _name,
              decoration: const InputDecoration(labelText: '名称'),
              validator: (v) => (v ?? '').trim().isEmpty ? '请输入名称' : null,
            ),
            const SizedBox(height: 12),
            AppInput(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(labelText: '金额'),
              validator: (v) {
                final amount = double.tryParse(v ?? '');
                return amount == null || !amount.isFinite || amount <= 0
                    ? '金额必须大于 0'
                    : null;
              },
            ),
            const SizedBox(height: 12),
            _select('类型', _type, const {
              RecurringBillType.subscription: '订阅',
              RecurringBillType.membership: '会员',
              RecurringBillType.mortgage: '房贷',
              RecurringBillType.rent: '房租',
              RecurringBillType.carLoan: '车贷',
              RecurringBillType.insurance: '保险',
              RecurringBillType.mobilePlan: '手机套餐',
              RecurringBillType.income: '固定收入',
              RecurringBillType.other: '其他',
            }, (v) => _type = v),
          ],
          if (!widget.scheduleOnly) ...[
            _select<String?>('账户', _accountId, {
              for (final a in ref.watch(accountsProvider).value ?? [])
                a.id: a.displayName,
            }, (v) => _accountId = v),
            _select<String?>('分类', _categoryId, {
              for (final c
                  in ref.watch(categoriesProvider).value ?? <Category>[])
                if (c.type ==
                    (widget.bill.isIncome
                        ? CategoryType.income
                        : CategoryType.expense))
                  c.id: c.name,
            }, (v) => _categoryId = v),
          ],
          _select('重复周期', _cycle, const {
            RecurringBillCycle.daily: '每天',
            RecurringBillCycle.weekly: '每周',
            RecurringBillCycle.monthly: '每月',
            RecurringBillCycle.yearly: '每年',
            RecurringBillCycle.quarterly: '每季度',
            RecurringBillCycle.halfYear: '每半年',
            RecurringBillCycle.custom: '自定义天数（沿用原规则）',
          }, (v) => _cycle = v),
          if (_cycle == RecurringBillCycle.weekly)
            _select('执行日', _weekday, {
              for (var i = 1; i <= 7; i++) i: '周${'一二三四五六日'[i - 1]}',
            }, (v) => _weekday = v),
          if (_cycle == RecurringBillCycle.yearly)
            _select('执行月份', _month, {
              for (var i = 1; i <= 12; i++) i: '$i 月',
            }, (v) => _month = v),
          if (_cycle != RecurringBillCycle.daily &&
              _cycle != RecurringBillCycle.weekly &&
              _cycle != RecurringBillCycle.custom) ...[
            _select('执行 / 扣款日期', _day, {
              for (var i = 1; i <= 31; i++) i: '$i 日',
              -1: '最后一天',
            }, (v) => _day = v),
            const Text('若当月无该日期，将在月末执行', style: TextStyle(fontSize: 13)),
          ],
          if (_cycle == RecurringBillCycle.custom)
            AppInput(
              controller: _customDays,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '每隔多少天'),
              validator: _positive,
            ),
          AppSheetOption(
            title: '生效日期',
            subtitle: _date(_start),
            chevron: true,
            onTap: () => _pick(false),
          ),
          const SizedBox(height: 12),
          _select('结束', _endType, const {
            'never': '永不结束',
            'date': '指定结束日期',
            'count': '重复 N 次（含当前已记账次数）',
          }, (v) => _endType = v),
          if (_endType == 'date')
            AppSheetOption(
              title: '结束日期',
              subtitle: _date(_end),
              chevron: true,
              onTap: () => _pick(true),
            ),
          if (_endType == 'count')
            AppInput(
              controller: _count,
              decoration: const InputDecoration(labelText: '总次数'),
              keyboardType: TextInputType.number,
              validator: _positive,
            ),
          _select('扣款提醒', _reminder, const {
            -1: '关闭',
            0: '当天',
            1: '提前 1 天',
            3: '提前 3 天',
            7: '提前 7 天',
          }, (v) => _reminder = v),
          ExpansionTile(
            title: const Text('高级选项'),
            children: [
              AppInput(
                controller: _interval,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: '每隔 N 个周期'),
                validator: _positive,
              ),
              SwitchListTile.adaptive(
                title: const Text('自动入账'),
                subtitle: const Text('关闭时，到期需确认后才影响余额'),
                value: _auto,
                onChanged: (v) => setState(() => _auto = v),
              ),
            ],
          ),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('取消'),
                ),
              ),
              Expanded(
                child: FilledButton(
                  onPressed: _submit,
                  child: const Text('确认'),
                ),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  void _submit() {
    if (!_form.currentState!.validate()) return;
    if (_endType == 'date' && _end.isBefore(_start)) {
      setState(() => _error = '结束日期不能早于生效日期');
      return;
    }
    if (!widget.scheduleOnly && (_accountId == null || _categoryId == null)) {
      setState(() => _error = '请选择账户和分类');
      return;
    }
    final old = widget.bill;
    final bill = RecurringBill(
      id: old.id,
      bookId: old.bookId,
      name: widget.scheduleOnly ? old.name : _name.text.trim(),
      type: _type,
      amount: widget.scheduleOnly ? old.amount : double.parse(_amount.text),
      cycle: _cycle,
      startDate: _start,
      endDate: _endType == 'date' ? _end : null,
      nextDate: _start,
      accountId: _accountId,
      categoryId: _categoryId,
      subcategoryId: old.subcategoryId,
      interval: int.parse(_interval.text),
      weekday: _weekday,
      dayOfMonth: _day,
      month: _month,
      repeatCount: _endType == 'count' ? int.parse(_count.text) : null,
      completedCount: old.completedCount,
      reminderDays: _reminder < 0 ? 0 : _reminder,
      customIntervalDays: _cycle == RecurringBillCycle.custom
          ? int.parse(_customDays.text)
          : old.customIntervalDays,
      reminder: _reminder >= 0,
      autoRecord: _auto,
      status: old.status,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    var next = bill.firstOccurrence();
    if (bill.completedCount > 0) {
      while (next.isBefore(old.nextDate)) {
        next = bill.nextOccurrence(next);
      }
    }
    final ended =
        (bill.endDate != null && next.isAfter(bill.endDate!)) ||
        (bill.repeatCount != null && bill.completedCount >= bill.repeatCount!);
    Navigator.pop(
      context,
      bill.copyWith(
        nextDate: next,
        status: ended ? RecurringBillStatus.ended : bill.status,
      ),
    );
  }
}
