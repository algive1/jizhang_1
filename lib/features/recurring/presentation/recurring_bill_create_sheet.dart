import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/models/account.dart';
import '../../../core/models/category.dart';
import '../../../core/models/recurring_bill.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_glass_surface.dart';
import '../../accounts/data/account_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// Prototype-aligned form for creating a recurring bill.
///
/// It only assembles a [RecurringBill]. Persistence remains in the existing
/// page/repository flow so book, account and category validation is unchanged.
class RecurringBillCreateSheet extends ConsumerStatefulWidget {
  const RecurringBillCreateSheet({
    super.key,
    required this.bill,
    this.rulesOnly = false,
    this.onDisable,
  });

  final RecurringBill bill;
  final bool rulesOnly;
  final VoidCallback? onDisable;

  static Future<RecurringBill?> show(
    BuildContext context,
    RecurringBill bill,
  ) => showModalBottomSheet<RecurringBill>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: RecurringBillCreateSheet(bill: bill),
    ),
  );

  static Future<RecurringBill?> showRules(
    BuildContext context,
    RecurringBill bill, {
    VoidCallback? onDisable,
  }) => showModalBottomSheet<RecurringBill>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.transparent,
    builder: (sheetContext) => Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
      ),
      child: RecurringBillCreateSheet(
        bill: bill,
        rulesOnly: true,
        onDisable: onDisable,
      ),
    ),
  );

  @override
  ConsumerState<RecurringBillCreateSheet> createState() =>
      _RecurringBillCreateSheetState();
}

class _RecurringBillCreateSheetState
    extends ConsumerState<RecurringBillCreateSheet> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController();
  late final _amount = TextEditingController();
  late final _count = TextEditingController(
    text: '${widget.bill.repeatCount ?? 12}',
  );

  late bool _isIncome = widget.bill.isIncome;
  late RecurringBillCycle _cycle = widget.rulesOnly
      ? widget.bill.cycle
      : RecurringBillCycle.monthly;
  late DateTime _start = DateUtils.dateOnly(widget.bill.startDate);
  late DateTime _end =
      widget.bill.endDate ??
      DateTime(_start.year + 1, _start.month, _start.day);
  late String _endType = widget.rulesOnly ? widget.bill.endType : 'never';
  late int _interval = widget.rulesOnly ? widget.bill.interval : 1;
  late int _day = widget.rulesOnly
      ? (widget.bill.dayOfMonth ?? _start.day)
      : _start.day;
  late int _weekday = widget.rulesOnly
      ? (widget.bill.weekday ?? _start.weekday)
      : _start.weekday;
  late int _month = widget.rulesOnly
      ? (widget.bill.month ?? _start.month)
      : _start.month;
  late int _reminderDays = widget.rulesOnly ? widget.bill.reminderDays : 1;
  late bool _autoRecord = widget.rulesOnly ? widget.bill.autoRecord : false;
  late bool _reminder = widget.rulesOnly ? widget.bill.reminder : true;
  String? _accountId;
  String? _categoryId;
  String? _subcategoryId;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _amount.dispose();
    _count.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: context.appSheetSurface,
    borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
    clipBehavior: Clip.antiAlias,
    child: ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * .92,
      ),
      child: Column(
        children: [
          _dragHandle(),
          _header(context),
          Expanded(
            child: Form(
              key: _form,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 8, 18, 24),
                child: Column(
                  children: [
                    if (!widget.rulesOnly) _basicSection(),
                    const SizedBox(height: 14),
                    _scheduleSection(),
                    const SizedBox(height: 14),
                    widget.rulesOnly
                        ? _rulesOnlyBookkeepingSection()
                        : _bookkeepingSection(),
                    if (_error != null) ...[
                      const SizedBox(height: 10),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _error!,
                          style: const TextStyle(color: AppColors.expense),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
          _actions(context),
        ],
      ),
    ),
  );

  Widget _dragHandle() => Container(
    width: 42,
    height: 5,
    margin: const EdgeInsets.only(top: 10, bottom: 4),
    decoration: BoxDecoration(
      color: context.appDivider,
      borderRadius: BorderRadius.circular(999),
    ),
  );

  Widget _header(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(22, 14, 18, 10),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                widget.rulesOnly ? '配置周期规则' : '新增周期账单',
                key: ValueKey('recurring-create-title'),
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
              ),
              SizedBox(height: 6),
              Text(
                widget.rulesOnly ? '记一笔中的金额、分类和账户已自动带入' : '设置后按周期自动提醒或记账',
                style: TextStyle(fontSize: 13, color: context.appSecondaryText),
              ),
            ],
          ),
        ),
        if (widget.rulesOnly && widget.onDisable != null)
          TextButton(
            onPressed: () {
              widget.onDisable!();
              Navigator.pop(context);
            },
            child: const Text('取消定期付'),
          ),
        IconButton(
          key: const ValueKey('recurring-create-close'),
          onPressed: () => Navigator.pop(context),
          style: IconButton.styleFrom(
            backgroundColor: context.appSurfaceSoft,
            foregroundColor: context.appSecondaryText,
            fixedSize: const Size(36, 36),
          ),
          icon: const Icon(Icons.close, size: 20),
          tooltip: '关闭',
        ),
      ],
    ),
  );

  Widget _basicSection() => _SectionCard(
    title: '账单信息',
    children: [
      _fieldLabel('名称'),
      TextFormField(
        key: const ValueKey('recurring-create-name'),
        controller: _name,
        decoration: _inputDecoration('例如：房租、会员订阅'),
        validator: (value) => (value ?? '').trim().isEmpty ? '请输入名称' : null,
        textInputAction: TextInputAction.next,
      ),
      const SizedBox(height: 14),
      _fieldLabel('金额'),
      TextFormField(
        key: const ValueKey('recurring-create-amount'),
        controller: _amount,
        decoration: _moneyDecoration(),
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        validator: (value) {
          final amount = double.tryParse(value ?? '');
          return amount == null || !amount.isFinite || amount <= 0
              ? '金额必须大于 0'
              : null;
        },
        textInputAction: TextInputAction.done,
      ),
      const SizedBox(height: 14),
      _fieldLabel('类型'),
      _typeSegment(),
    ],
  );

  Widget _typeSegment() => Container(
    key: const ValueKey('recurring-create-type'),
    padding: const EdgeInsets.all(4),
    decoration: BoxDecoration(
      color: context.appSurfaceSoft,
      borderRadius: BorderRadius.circular(15),
    ),
    child: Row(
      children: [
        _SegmentButton(
          label: '支出',
          selected: !_isIncome,
          onTap: () => _changeIncome(false),
        ),
        _SegmentButton(
          label: '收入',
          selected: _isIncome,
          onTap: () => _changeIncome(true),
        ),
      ],
    ),
  );

  Widget _scheduleSection() => _SectionCard(
    title: '重复规则',
    children: [
      _cycleChoices(),
      const SizedBox(height: 8),
      _SelectionRow(
        key: const ValueKey('recurring-create-frequency'),
        title: '重复频率',
        subtitle: '设置账单重复间隔',
        value: _frequencyLabel,
        onTap: _pickInterval,
      ),
      if (_cycle != RecurringBillCycle.daily)
        _SelectionRow(
          key: const ValueKey('recurring-create-due-date'),
          title: '扣款日期',
          subtitle: _cycle == RecurringBillCycle.weekly
              ? '每周自动执行日期'
              : _cycle == RecurringBillCycle.yearly
              ? '每年自动执行日期'
              : '每月自动执行日期',
          value: _dueDateLabel,
          onTap: _pickDueDate,
        ),
      _SelectionRow(
        key: const ValueKey('recurring-create-start-date'),
        title: '生效日期',
        value: _formatDate(_start),
        onTap: () => _pickDate(false),
      ),
      _SelectionRow(
        key: const ValueKey('recurring-create-end-type'),
        title: '结束方式',
        value: _endTypeLabel,
        onTap: _pickEndType,
      ),
      if (_endType == 'date')
        _SelectionRow(
          key: const ValueKey('recurring-create-end-date'),
          title: '结束日期',
          value: _formatDate(_end),
          onTap: () => _pickDate(true),
        ),
      if (_endType == 'count') ...[
        const SizedBox(height: 8),
        TextFormField(
          key: const ValueKey('recurring-create-repeat-count'),
          controller: _count,
          decoration: _inputDecoration('重复总次数'),
          keyboardType: TextInputType.number,
          validator: _positiveInteger,
        ),
      ],
      const SizedBox(height: 14),
      _summary(),
    ],
  );

  Widget _cycleChoices() => Row(
    key: const ValueKey('recurring-create-cycle'),
    children: [
      for (final cycle in const [
        RecurringBillCycle.daily,
        RecurringBillCycle.weekly,
        RecurringBillCycle.monthly,
        RecurringBillCycle.yearly,
      ])
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _CycleButton(
              key: ValueKey('recurring-cycle-${cycle.name}'),
              label: _cycleLabel(cycle),
              selected: _cycle == cycle,
              onTap: () => _changeCycle(cycle),
            ),
          ),
        ),
    ],
  );

  Widget _summary() => Container(
    key: const ValueKey('recurring-create-summary'),
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 14),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: [context.appPrimarySoft, context.appSurfaceSoft],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: context.appDivider),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '当前规则',
          style: TextStyle(fontSize: 12, color: context.appSecondaryText),
        ),
        const SizedBox(height: 5),
        Text(
          '$_scheduleSummary · 从 ${_formatDate(_start)} 开始',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w600,
            color: context.appPrimary,
          ),
        ),
      ],
    ),
  );

  Widget _bookkeepingSection() => _SectionCard(
    title: '记账设置',
    children: [
      _SelectionRow(
        key: const ValueKey('recurring-create-account'),
        title: '扣款 / 入账账户',
        value: _selectedAccountLabel,
        placeholder: '请选择账户',
        onTap: _pickAccount,
      ),
      _SelectionRow(
        key: const ValueKey('recurring-create-category'),
        title: '分类',
        value: _selectedCategoryLabel,
        placeholder: '请选择分类',
        onTap: _pickCategory,
      ),
      _SwitchRow(
        key: const ValueKey('recurring-create-auto-record'),
        title: '自动记账',
        subtitle: '到期后自动生成流水',
        value: _autoRecord,
        onChanged: (value) => setState(() => _autoRecord = value),
      ),
      _SwitchRow(
        key: const ValueKey('recurring-create-reminder'),
        title: '扣款提醒',
        subtitle: '到期前提醒你确认',
        value: _reminder,
        onChanged: (value) => setState(() {
          _reminder = value;
          _reminderDays = value ? (_reminderDays == 0 ? 1 : _reminderDays) : 0;
        }),
      ),
      if (_reminder)
        _SelectionRow(
          key: const ValueKey('recurring-create-reminder-days'),
          title: '提醒时间',
          value: _reminderLabel,
          onTap: _pickReminderDays,
        ),
    ],
  );

  Widget _rulesOnlyBookkeepingSection() => _SectionCard(
    title: '记账设置',
    children: [
      _SwitchRow(
        key: const ValueKey('recurring-create-auto-record'),
        title: '自动记账',
        subtitle: '到期后自动生成流水',
        value: _autoRecord,
        onChanged: (value) => setState(() => _autoRecord = value),
      ),
      _SwitchRow(
        key: const ValueKey('recurring-create-reminder'),
        title: '扣款提醒',
        subtitle: '到期前提醒你确认',
        value: _reminder,
        onChanged: (value) => setState(() {
          _reminder = value;
          _reminderDays = value ? (_reminderDays == 0 ? 1 : _reminderDays) : 0;
        }),
      ),
      if (_reminder)
        _SelectionRow(
          key: const ValueKey('recurring-create-reminder-days'),
          title: '提醒时间',
          value: _reminderLabel,
          onTap: _pickReminderDays,
        ),
    ],
  );

  Widget _actions(BuildContext context) => Container(
    padding: const EdgeInsets.fromLTRB(18, 12, 18, 20),
    decoration: BoxDecoration(
      color: context.appSheetSurface,
      border: Border(top: BorderSide(color: context.appDivider)),
    ),
    child: Row(
      children: [
        Expanded(
          child: SizedBox(
            height: 54,
            child: TextButton(
              key: const ValueKey('recurring-create-cancel'),
              onPressed: () => Navigator.pop(context),
              style: TextButton.styleFrom(
                backgroundColor: context.appSurfaceSoft,
                foregroundColor: context.appSecondaryText,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
              ),
              child: Text(
                '取消',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          flex: 2,
          child: SizedBox(
            height: 54,
            child: FilledButton(
              key: const ValueKey('recurring-create-save'),
              onPressed: _submit,
              style: FilledButton.styleFrom(
                backgroundColor: context.appPrimary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(17),
                ),
                elevation: 0,
              ),
              child: Text(
                widget.rulesOnly ? '完成' : '保存周期账单',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    ),
  );

  InputDecoration _inputDecoration(String hint) => InputDecoration(
    hintText: hint,
    filled: true,
    fillColor: context.appSurfaceSoft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: context.appPrimary),
    ),
  );

  InputDecoration _moneyDecoration() => _inputDecoration('0.00').copyWith(
    prefixText: '¥  ',
    prefixStyle: TextStyle(
      fontSize: 24,
      fontWeight: FontWeight.w700,
      color: context.appPrimaryText,
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
  );

  Widget _fieldLabel(String label) => Padding(
    padding: const EdgeInsets.only(bottom: 7),
    child: Align(
      alignment: Alignment.centerLeft,
      child: Text(
        label,
        style: TextStyle(fontSize: 13, color: context.appSecondaryText),
      ),
    ),
  );

  String? _positiveInteger(String? value) =>
      (int.tryParse(value ?? '') ?? 0) < 1 ? '请输入大于 0 的整数' : null;

  void _changeIncome(bool income) {
    if (_isIncome == income) return;
    setState(() {
      _isIncome = income;
      _categoryId = null;
      _subcategoryId = null;
    });
  }

  void _changeCycle(RecurringBillCycle cycle) {
    setState(() {
      _cycle = cycle;
      _interval = 1;
      if (cycle == RecurringBillCycle.weekly) {
        _weekday = _weekday.clamp(1, 7).toInt();
      } else if (cycle == RecurringBillCycle.yearly) {
        _month = _month.clamp(1, 12).toInt();
        _day = _day.clamp(1, 31).toInt();
      }
    });
  }

  Future<void> _pickInterval() async {
    final options = switch (_cycle) {
      RecurringBillCycle.daily => [1, 2, 3, 7, 14, 30],
      RecurringBillCycle.weekly => [1, 2, 3, 4],
      RecurringBillCycle.monthly => [1, 2, 3, 6, 12],
      RecurringBillCycle.yearly => [1, 2, 3, 5],
      _ => [1, 2, 3, 6, 12],
    };
    final value = await _pickValue<int>(
      title: '重复频率',
      options: options,
      label: _frequencyText,
      selected: _interval,
    );
    if (value != null && mounted) setState(() => _interval = value);
  }

  Future<void> _pickDueDate() async {
    if (_cycle == RecurringBillCycle.weekly) {
      final value = await _pickValue<int>(
        title: '扣款日期',
        options: [for (var i = 1; i <= 7; i++) i],
        label: (item) => '每周${_weekdayName(item)}',
        selected: _weekday,
      );
      if (value != null && mounted) setState(() => _weekday = value);
      return;
    }
    final value = await _pickValue<int>(
      title: '扣款日期',
      options: [for (var i = 1; i <= 31; i++) i, -1],
      label: (item) => item == -1 ? '每月最后一天' : '每月 $item 日',
      selected: _day,
    );
    if (value != null && mounted) setState(() => _day = value);
  }

  Future<void> _pickDate(bool end) async {
    final value = await AppDatePicker.show(context, end ? _end : _start);
    if (value == null || !mounted) return;
    setState(() {
      if (end) {
        _end = value;
      } else {
        _start = value;
        if (_cycle == RecurringBillCycle.monthly ||
            _cycle == RecurringBillCycle.yearly) {
          _day = _day == -1 ? -1 : _start.day;
        }
        _weekday = _start.weekday;
        _month = _start.month;
      }
    });
  }

  Future<void> _pickEndType() async {
    final value = await _pickValue<String>(
      title: '结束方式',
      options: const ['never', 'date', 'count'],
      label: (item) => switch (item) {
        'never' => '永不结束',
        'date' => '指定结束日期',
        _ => '重复 N 次',
      },
      selected: _endType,
    );
    if (value != null && mounted) setState(() => _endType = value);
  }

  Future<void> _pickReminderDays() async {
    final value = await _pickValue<int>(
      title: '提醒时间',
      options: const [0, 1, 3, 7],
      label: (item) => item == 0 ? '当天' : '提前 $item 天',
      selected: _reminderDays,
    );
    if (value != null && mounted) {
      setState(() {
        _reminderDays = value;
        _reminder = true;
      });
    }
  }

  Future<T?> _pickValue<T>({
    required String title,
    required List<T> options,
    required String Function(T) label,
    required T selected,
  }) => AppBottomSheet.show<T>(
    context: context,
    builder: (sheet) => Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            title,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
          ),
        ),
        for (final option in options)
          AppSheetOption(
            title: label(option),
            selected: option == selected,
            onTap: () => Navigator.pop(sheet, option),
          ),
        const SizedBox(height: 12),
      ],
    ),
  );

  Future<void> _pickAccount() async {
    final accounts = ref.read(accountsProvider).value ?? const <Account>[];
    final selected = await AppBottomSheet.show<String>(
      context: context,
      builder: (sheet) => _ChoiceList<String>(
        title: '扣款 / 入账账户',
        selected: _accountId,
        options: [
          for (final account in accounts)
            _ChoiceOption(
              value: account.id,
              label: account.displayName,
              subtitle: '${account.type.label} · ${account.currency}',
            ),
        ],
        onSelected: (value) => Navigator.pop(sheet, value),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _accountId = selected;
        _error = null;
      });
    }
  }

  Future<void> _pickCategory() async {
    final categories =
        (ref.read(categoriesProvider).value ?? const <Category>[])
            .where(
              (category) =>
                  category.type ==
                  (_isIncome ? CategoryType.income : CategoryType.expense),
            )
            .toList();
    final selected = await AppBottomSheet.show<_CategorySelection>(
      context: context,
      builder: (sheet) => _ChoiceList<_CategorySelection>(
        title: '分类',
        selected: _categoryId == null
            ? null
            : _CategorySelection(rootId: _categoryId!, childId: _subcategoryId),
        options: [
          for (final category in categories)
            _ChoiceOption(
              value: _CategorySelection(
                rootId: category.parentId ?? category.id,
                childId: category.parentId == null ? null : category.id,
              ),
              label: category.parentId == null
                  ? category.name
                  : '  ${category.name}',
              subtitle: category.parentId == null ? '一级分类' : '二级分类',
            ),
        ],
        onSelected: (value) => Navigator.pop(sheet, value),
      ),
    );
    if (selected != null && mounted) {
      setState(() {
        _categoryId = selected.rootId;
        _subcategoryId = selected.childId;
        _error = null;
      });
    }
  }

  void _submit() {
    if (!widget.rulesOnly && !_form.currentState!.validate()) return;
    final old = widget.bill;
    final amount = widget.rulesOnly
        ? old.amount
        : (double.tryParse(_amount.text.trim()) ?? 0);
    if (!widget.rulesOnly && (!amount.isFinite || amount <= 0)) {
      return;
    }
    final accountId = widget.rulesOnly ? old.accountId : _accountId;
    final categoryId = widget.rulesOnly ? old.categoryId : _categoryId;
    if (!widget.rulesOnly && (accountId == null || categoryId == null)) {
      setState(() => _error = '请选择扣款 / 入账账户和分类');
      return;
    }
    if (_endType == 'date' && _end.isBefore(_start)) {
      setState(() => _error = '结束日期不能早于生效日期');
      return;
    }

    final bill = RecurringBill(
      id: old.id,
      bookId: old.bookId,
      name: widget.rulesOnly ? old.name : _name.text.trim(),
      type: widget.rulesOnly
          ? old.type
          : (_isIncome ? RecurringBillType.income : RecurringBillType.other),
      amount: amount,
      cycle: _cycle,
      startDate: _start,
      endDate: _endType == 'date' ? DateUtils.dateOnly(_end) : null,
      nextDate: _start,
      accountId: accountId,
      categoryId: categoryId,
      subcategoryId: widget.rulesOnly ? old.subcategoryId : _subcategoryId,
      interval: _interval,
      weekday: _weekday,
      dayOfMonth: _day,
      month: _month,
      repeatCount: _endType == 'count' ? int.parse(_count.text) : null,
      completedCount: widget.rulesOnly ? old.completedCount : 0,
      reminderDays: _reminder ? _reminderDays : 0,
      customIntervalDays: old.customIntervalDays,
      autoRecord: _autoRecord,
      reminder: _reminder,
      status: old.status,
      createdAt: old.createdAt,
      updatedAt: DateTime.now(),
    );
    var next = bill.firstOccurrence();
    if (widget.rulesOnly && old.completedCount > 0) {
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
        status: widget.rulesOnly
            ? (ended ? RecurringBillStatus.ended : old.status)
            : (ended ? RecurringBillStatus.ended : RecurringBillStatus.active),
      ),
    );
  }

  String get _frequencyLabel => _frequencyText(_interval);

  String _frequencyText(int value) => switch (_cycle) {
    RecurringBillCycle.daily => '每 $value 天',
    RecurringBillCycle.weekly => '每 $value 周',
    RecurringBillCycle.yearly => '每 $value 年',
    _ => '每 $value 个月',
  };

  String get _dueDateLabel => switch (_cycle) {
    RecurringBillCycle.weekly => '每周${_weekdayName(_weekday)}',
    RecurringBillCycle.yearly =>
      '每年 $_month 月 ${_day == -1 ? '最后一天' : '$_day 日'}',
    _ => _day == -1 ? '每月最后一天' : '每月 $_day 日',
  };

  String get _scheduleSummary {
    final frequency = switch (_cycle) {
      RecurringBillCycle.daily => _frequencyText(_interval),
      RecurringBillCycle.weekly =>
        '${_frequencyText(_interval)} · 周${_weekdayName(_weekday)}',
      RecurringBillCycle.yearly =>
        '${_frequencyText(_interval)} · $_month月${_day == -1 ? '最后一天' : '$_day日'}',
      _ => '${_frequencyText(_interval)} · ${_day == -1 ? '最后一天' : '$_day日'}',
    };
    return frequency;
  }

  String get _endTypeLabel => switch (_endType) {
    'date' => '截至 ${_formatDate(_end)}',
    'count' => '重复 ${_count.text.isEmpty ? 'N' : _count.text} 次',
    _ => '永不结束',
  };

  String get _reminderLabel =>
      _reminderDays == 0 ? '当天' : '提前 $_reminderDays 天';

  String get _selectedAccountLabel {
    final accounts = ref.watch(accountsProvider).value ?? const <Account>[];
    return accounts
            .where((account) => account.id == _accountId)
            .firstOrNull
            ?.displayName ??
        '';
  }

  String get _selectedCategoryLabel {
    final categories =
        ref.watch(categoriesProvider).value ?? const <Category>[];
    final selected = categories
        .where((category) => category.id == (_subcategoryId ?? _categoryId))
        .firstOrNull;
    if (selected == null) return '';
    if (selected.parentId == null) return selected.name;
    final parent = categories
        .where((category) => category.id == selected.parentId)
        .firstOrNull;
    return parent == null ? selected.name : '${parent.name} · ${selected.name}';
  }

  String _formatDate(DateTime value) =>
      '${value.year}/${value.month.toString().padLeft(2, '0')}/${value.day.toString().padLeft(2, '0')}';

  String _cycleLabel(RecurringBillCycle cycle) => switch (cycle) {
    RecurringBillCycle.daily => '每天',
    RecurringBillCycle.weekly => '每周',
    RecurringBillCycle.monthly => '每月',
    RecurringBillCycle.yearly => '每年',
    _ => '其他',
  };

  String _weekdayName(int weekday) => '一二三四五六日'[weekday.clamp(1, 7) - 1];
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => AppGlassSurface(
    borderRadius: 22,
    padding: const EdgeInsets.all(18),
    tint: context.appSurface,
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 15),
        ...children,
      ],
    ),
  );
}

class _SegmentButton extends StatelessWidget {
  const _SegmentButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? context.appSurfaceRaised : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
          boxShadow: selected
              ? const [
                  BoxShadow(
                    color: Color(0x0F141E0A),
                    blurRadius: 10,
                    offset: Offset(0, 3),
                  ),
                ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            color: selected ? context.appPrimary : context.appSecondaryText,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
          ),
        ),
      ),
    ),
  );
}

class _CycleButton extends StatelessWidget {
  const _CycleButton({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(14),
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      height: 44,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: selected ? context.appPrimarySoft : context.appSurfaceSoft,
        border: Border.all(
          color: selected ? context.appPrimary : context.appDivider,
        ),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 14,
          color: selected ? context.appPrimary : context.appSecondaryText,
          fontWeight: selected ? FontWeight.w700 : FontWeight.w400,
        ),
      ),
    ),
  );
}

class _SelectionRow extends StatelessWidget {
  const _SelectionRow({
    super.key,
    required this.title,
    required this.value,
    required this.onTap,
    this.subtitle,
    this.placeholder,
  });

  final String title;
  final String value;
  final String? subtitle;
  final String? placeholder;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    child: Container(
      constraints: const BoxConstraints(minHeight: 56),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: context.appDivider)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TextStyle(fontSize: 15)),
                if (subtitle != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 12,
                      color: context.appSecondaryText,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: Text(
                    value.isEmpty ? (placeholder ?? '未设置') : value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.end,
                    style: TextStyle(
                      fontSize: 14,
                      color: value.isEmpty
                          ? context.appSecondaryText
                          : context.appPrimaryText,
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Icon(
                  Icons.chevron_right,
                  size: 20,
                  color: context.appSecondaryText,
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    super.key,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
  });

  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minHeight: 58),
    decoration: BoxDecoration(
      border: Border(bottom: BorderSide(color: context.appDivider)),
    ),
    child: Row(
      children: [
        Expanded(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: TextStyle(fontSize: 15)),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: TextStyle(
                  fontSize: 12,
                  color: context.appSecondaryText,
                ),
              ),
            ],
          ),
        ),
        Switch.adaptive(value: value, onChanged: onChanged),
      ],
    ),
  );
}

class _ChoiceOption<T> {
  const _ChoiceOption({
    required this.value,
    required this.label,
    this.subtitle,
  });

  final T value;
  final String label;
  final String? subtitle;
}

class _ChoiceList<T> extends StatelessWidget {
  const _ChoiceList({
    required this.title,
    required this.options,
    required this.selected,
    required this.onSelected,
  });

  final String title;
  final List<_ChoiceOption<T>> options;
  final T? selected;
  final ValueChanged<T> onSelected;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          title,
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
      ),
      if (options.isEmpty)
        Padding(
          padding: EdgeInsets.fromLTRB(20, 0, 20, 24),
          child: Text(
            '暂无可选项，请先在当前账本添加。',
            style: TextStyle(color: context.appSecondaryText),
          ),
        )
      else
        for (final option in options)
          AppSheetOption(
            title: option.label,
            subtitle: option.subtitle,
            selected: option.value == selected,
            onTap: () => onSelected(option.value),
          ),
      const SizedBox(height: 12),
    ],
  );
}

class _CategorySelection {
  const _CategorySelection({required this.rootId, required this.childId});

  final String rootId;
  final String? childId;

  @override
  bool operator ==(Object other) =>
      other is _CategorySelection &&
      other.rootId == rootId &&
      other.childId == childId;

  @override
  int get hashCode => Object.hash(rootId, childId);
}
