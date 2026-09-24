import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_form.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../data/finance_center_repository.dart';
import '../../../app/theme/app_theme_tokens.dart';

class FinanceCenterPage extends ConsumerStatefulWidget {
  const FinanceCenterPage({super.key});

  @override
  ConsumerState<FinanceCenterPage> createState() => _FinanceCenterPageState();
}

class _FinanceCenterPageState extends ConsumerState<FinanceCenterPage> {
  int _tab = 0;
  int _revision = 0;

  FinanceCenterRepository get _repo =>
      ref.read(financeCenterRepositoryProvider);
  String get _bookId => (ref.read(
    financeCenterRepositoryProvider,
  ) as DriftFinanceCenterRepository).bookId;

  @override
  Widget build(BuildContext context) {
    final key = ValueKey('finance-center-$_revision-$_tab');
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
                        '财税与账单',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                    ),
                    FilledButton.icon(
                      onPressed: _addCurrent,
                      icon: Icon(Icons.add, size: 18),
                      label: Text('新增'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    '发票与报税仅作为台账管理，不替代税务申报或专业税务意见；银行卡账单用于核对结算与还款状态。',
                    style: TextStyle(
                      color: context.appSecondaryText,
                      height: 1.45,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                SegmentedButton<int>(
                  segments: const [
                    ButtonSegment(
                      value: 0,
                      icon: Icon(Icons.receipt_long_outlined),
                      label: Text('发票'),
                    ),
                    ButtonSegment(
                      value: 1,
                      icon: Icon(Icons.account_balance_outlined),
                      label: Text('报税'),
                    ),
                    ButtonSegment(
                      value: 2,
                      icon: Icon(Icons.credit_card_outlined),
                      label: Text('银行卡账单'),
                    ),
                  ],
                  selected: {_tab},
                  onSelectionChanged: (value) =>
                      setState(() => _tab = value.first),
                ),
                const SizedBox(height: 14),
                KeyedSubtree(
                  key: key,
                  child: switch (_tab) {
                    0 => _InvoiceList(
                      future: _repo.invoices(),
                      onEdit: _editInvoice,
                      onDelete: _deleteInvoice,
                    ),
                    1 => _TaxList(
                      future: _repo.taxFilings(),
                      onEdit: _editTax,
                      onDelete: _deleteTax,
                    ),
                    _ => _StatementList(
                      future: _repo.statements(),
                      onEdit: _editStatement,
                      onDelete: _deleteStatement,
                    ),
                  },
                ),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _addCurrent() async {
    switch (_tab) {
      case 0:
        await _editInvoice(newInvoice(_bookId));
        return;
      case 1:
        await _editTax(newTaxFiling(_bookId));
        return;
      default:
        await _editStatement(newStatement(_bookId));
        return;
    }
  }

  Future<void> _editInvoice(FinanceInvoice value) async {
    final result = await showDialog<FinanceInvoice>(
      context: context,
      builder: (_) => _InvoiceDialog(initial: value),
    );
    if (result == null) return;
    await _run(() => _repo.saveInvoice(result), '发票已保存');
  }

  Future<void> _editTax(TaxFiling value) async {
    final result = await showDialog<TaxFiling>(
      context: context,
      builder: (_) => _TaxDialog(initial: value),
    );
    if (result == null) return;
    await _run(() => _repo.saveTaxFiling(result), '报税台账已保存');
  }

  Future<void> _editStatement(CardStatement value) async {
    final result = await showDialog<CardStatement>(
      context: context,
      builder: (_) => _StatementDialog(initial: value),
    );
    if (result == null) return;
    await _run(() => _repo.saveStatement(result), '银行卡账单已保存');
  }

  Future<void> _deleteInvoice(FinanceInvoice value) =>
      _confirmDelete('删除这张发票记录？', () => _repo.deleteInvoice(value.id));
  Future<void> _deleteTax(TaxFiling value) =>
      _confirmDelete('删除这条报税台账？', () => _repo.deleteTaxFiling(value.id));
  Future<void> _deleteStatement(CardStatement value) =>
      _confirmDelete('删除这条银行卡账单？', () => _repo.deleteStatement(value.id));

  Future<void> _confirmDelete(
    String title,
    Future<void> Function() action,
  ) async {
    final yes = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: const Text('此操作只删除台账记录，不会删除已存在的记账流水。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (yes == true) await _run(action, '已删除');
  }

  Future<void> _run(Future<void> Function() action, String message) async {
    try {
      await action();
      if (!mounted) return;
      setState(() => _revision++);
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    } on Object catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }
}

class _InvoiceList extends StatelessWidget {
  const _InvoiceList({
    required this.future,
    required this.onEdit,
    required this.onDelete,
  });

  final Future<List<FinanceInvoice>> future;
  final ValueChanged<FinanceInvoice> onEdit;
  final ValueChanged<FinanceInvoice> onDelete;

  @override
  Widget build(BuildContext context) => _FutureList<FinanceInvoice>(
    future: future,
    emptyText: '暂无发票记录',
    builder: (item) => AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          child: Icon(
            item.direction == InvoiceDirection.incoming
                ? Icons.call_received
                : Icons.call_made,
          ),
        ),
        title: Text(
          item.counterparty.isEmpty
              ? (item.invoiceNo.isEmpty ? '未填写对方' : item.invoiceNo)
              : item.counterparty,
        ),
        subtitle: Text(
          '${_date(item.issueDate)} · ${_invoiceStatus(item.status)}'
          '${item.invoiceNo.isEmpty ? '' : ' · ${item.invoiceNo}'}',
        ),
        trailing: _RowMenu(
          amount: item.amount,
          onEdit: () => onEdit(item),
          onDelete: () => onDelete(item),
        ),
      ),
    ),
  );
}

class _TaxList extends StatelessWidget {
  const _TaxList({
    required this.future,
    required this.onEdit,
    required this.onDelete,
  });
  final Future<List<TaxFiling>> future;
  final ValueChanged<TaxFiling> onEdit;
  final ValueChanged<TaxFiling> onDelete;

  @override
  Widget build(BuildContext context) => _FutureList<TaxFiling>(
    future: future,
    emptyText: '暂无报税台账',
    builder: (item) => AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: const CircleAvatar(
          child: Icon(Icons.account_balance_outlined),
        ),
        title: Text('${item.period} · ${item.taxType}'),
        subtitle: Text(
          '截止 ${_date(item.dueDate)} · ${_taxStatus(item.status)}'
          ' · 应税额 ¥${item.taxableAmount.toStringAsFixed(2)}',
        ),
        trailing: _RowMenu(
          amount: item.taxDue,
          onEdit: () => onEdit(item),
          onDelete: () => onDelete(item),
        ),
      ),
    ),
  );
}

class _StatementList extends StatelessWidget {
  const _StatementList({
    required this.future,
    required this.onEdit,
    required this.onDelete,
  });
  final Future<List<CardStatement>> future;
  final ValueChanged<CardStatement> onEdit;
  final ValueChanged<CardStatement> onDelete;

  @override
  Widget build(BuildContext context) => _FutureList<CardStatement>(
    future: future,
    emptyText: '暂无银行卡账单',
    builder: (item) => AppCard(
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: CircleAvatar(
          child: Icon(
            item.type == CardStatementType.credit
                ? Icons.credit_card
                : Icons.account_balance_wallet_outlined,
          ),
        ),
        title: Text('${item.accountName} · ${item.statementMonth}'),
        subtitle: Text(
          '${item.type == CardStatementType.credit ? '贷记/信用卡' : '借记卡'}'
          ' · ${_statementStatus(item.status)}'
          '${item.dueDate == null ? '' : ' · 到期 ${_date(item.dueDate!)}'}',
        ),
        trailing: _RowMenu(
          amount: item.remaining,
          amountLabel: item.type == CardStatementType.credit ? '待还' : '账单',
          onEdit: () => onEdit(item),
          onDelete: () => onDelete(item),
        ),
      ),
    ),
  );
}

class _FutureList<T> extends StatelessWidget {
  const _FutureList({
    required this.future,
    required this.emptyText,
    required this.builder,
  });

  final Future<List<T>> future;
  final String emptyText;
  final Widget Function(T item) builder;

  @override
  Widget build(BuildContext context) => FutureBuilder<List<T>>(
    future: future,
    builder: (context, snapshot) {
      if (snapshot.connectionState != ConnectionState.done) {
        return Padding(
          padding: EdgeInsets.all(30),
          child: Center(child: CircularProgressIndicator()),
        );
      }
      if (snapshot.hasError) {
        return AppCard(child: Text('读取失败：${snapshot.error}'));
      }
      final values = snapshot.data ?? <T>[];
      if (values.isEmpty) {
        return AppCard(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 30),
            child: Center(
              child: Text(
                emptyText,
                style: TextStyle(color: context.appSecondaryText),
              ),
            ),
          ),
        );
      }
      return Column(
        children: [
          for (final item in values)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: builder(item),
            ),
        ],
      );
    },
  );
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.amount,
    required this.onEdit,
    required this.onDelete,
    this.amountLabel,
  });

  final double amount;
  final String? amountLabel;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (amountLabel != null)
            Text(
              amountLabel!,
              style: TextStyle(fontSize: 11, color: context.appSecondaryText),
            ),
          Text(
            '¥${amount.toStringAsFixed(2)}',
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
      PopupMenuButton<String>(
        onSelected: (value) => value == 'edit' ? onEdit() : onDelete(),
        itemBuilder: (_) => const [
          PopupMenuItem(value: 'edit', child: Text('编辑')),
          PopupMenuItem(value: 'delete', child: Text('删除')),
        ],
      ),
    ],
  );
}

class _InvoiceDialog extends StatefulWidget {
  const _InvoiceDialog({required this.initial});
  final FinanceInvoice initial;

  @override
  State<_InvoiceDialog> createState() => _InvoiceDialogState();
}

class _InvoiceDialogState extends State<_InvoiceDialog> {
  late final TextEditingController no;
  late final TextEditingController counterparty;
  late final TextEditingController amount;
  late final TextEditingController tax;
  late final TextEditingController note;
  late InvoiceDirection direction;
  late InvoiceStatus status;
  late DateTime date;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    no = TextEditingController(text: v.invoiceNo);
    counterparty = TextEditingController(text: v.counterparty);
    amount = TextEditingController(text: v.amount == 0 ? '' : '${v.amount}');
    tax = TextEditingController(text: v.taxAmount == 0 ? '' : '${v.taxAmount}');
    note = TextEditingController(text: v.note);
    direction = v.direction;
    status = v.status;
    date = v.issueDate;
  }

  @override
  void dispose() {
    for (final c in [no, counterparty, amount, tax, note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('发票记录'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<InvoiceDirection>(
              initialValue: direction,
              decoration: appFieldDecoration('方向'),
              items: const [
                DropdownMenuItem(
                  value: InvoiceDirection.incoming,
                  child: Text('收到发票'),
                ),
                DropdownMenuItem(
                  value: InvoiceDirection.outgoing,
                  child: Text('开出发票'),
                ),
              ],
              onChanged: (v) => direction = v ?? direction,
            ),
            _field(counterparty, '对方单位/个人'),
            _field(no, '发票号码（可选）'),
            _field(amount, '含税金额', number: true),
            _field(tax, '税额', number: true),
            _DateField(
              label: '开票日期',
              value: date,
              onChanged: (v) => setState(() => date = v),
            ),
            DropdownButtonFormField<InvoiceStatus>(
              initialValue: status,
              decoration: appFieldDecoration('状态'),
              items: InvoiceStatus.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(_invoiceStatus(v)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => status = v ?? status,
            ),
            _field(note, '备注'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final a = double.tryParse(amount.text.trim());
          final t = double.tryParse(tax.text.trim()) ?? 0;
          if (a == null || a < 0 || t < 0) {
            _invalid(context, '请输入有效金额');
            return;
          }
          Navigator.pop(
            context,
            FinanceInvoice(
              id: widget.initial.id,
              bookId: widget.initial.bookId,
              direction: direction,
              invoiceNo: no.text.trim(),
              counterparty: counterparty.text.trim(),
              amount: a,
              taxAmount: t,
              issueDate: date,
              status: status,
              note: note.text.trim(),
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _TaxDialog extends StatefulWidget {
  const _TaxDialog({required this.initial});
  final TaxFiling initial;
  @override
  State<_TaxDialog> createState() => _TaxDialogState();
}

class _TaxDialogState extends State<_TaxDialog> {
  late final TextEditingController period;
  late final TextEditingController type;
  late final TextEditingController taxable;
  late final TextEditingController due;
  late final TextEditingController note;
  late TaxFilingStatus status;
  late DateTime dueDate;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    period = TextEditingController(text: v.period);
    type = TextEditingController(text: v.taxType);
    taxable = TextEditingController(
      text: v.taxableAmount == 0 ? '' : '${v.taxableAmount}',
    );
    due = TextEditingController(text: v.taxDue == 0 ? '' : '${v.taxDue}');
    note = TextEditingController(text: v.note);
    status = v.status;
    dueDate = v.dueDate;
  }

  @override
  void dispose() {
    for (final c in [period, type, taxable, due, note]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('报税台账'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _field(period, '税期（如 2026-09）'),
            _field(type, '税种'),
            _field(taxable, '应税金额', number: true),
            _field(due, '应缴税额', number: true),
            _DateField(
              label: '申报/缴款截止日',
              value: dueDate,
              onChanged: (v) => setState(() => dueDate = v),
            ),
            DropdownButtonFormField<TaxFilingStatus>(
              initialValue: status,
              decoration: appFieldDecoration('状态'),
              items: TaxFilingStatus.values
                  .map(
                    (v) =>
                        DropdownMenuItem(value: v, child: Text(_taxStatus(v))),
                  )
                  .toList(),
              onChanged: (v) => status = v ?? status,
            ),
            _field(note, '备注'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          if (!RegExp(r'^\d{4}-(0[1-9]|1[0-2])$')
              .hasMatch(period.text.trim())) {
            _invalid(context, '税期格式应为 YYYY-MM');
            return;
          }
          final taxableValue = double.tryParse(taxable.text.trim()) ?? 0;
          final dueValue = double.tryParse(due.text.trim()) ?? 0;
          if (type.text.trim().isEmpty || taxableValue < 0 || dueValue < 0) {
            _invalid(context, '请检查税种和金额');
            return;
          }
          Navigator.pop(
            context,
            TaxFiling(
              id: widget.initial.id,
              bookId: widget.initial.bookId,
              period: period.text.trim(),
              taxType: type.text.trim(),
              taxableAmount: taxableValue,
              taxDue: dueValue,
              dueDate: dueDate,
              status: status,
              note: note.text.trim(),
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

class _StatementDialog extends StatefulWidget {
  const _StatementDialog({required this.initial});
  final CardStatement initial;

  @override
  State<_StatementDialog> createState() => _StatementDialogState();
}

class _StatementDialogState extends State<_StatementDialog> {
  late final TextEditingController account;
  late final TextEditingController month;
  late final TextEditingController opening;
  late final TextEditingController closing;
  late final TextEditingController amount;
  late final TextEditingController minimum;
  late final TextEditingController paid;
  late final TextEditingController note;
  late CardStatementType type;
  late CardStatementStatus status;
  late DateTime? dueDate;

  @override
  void initState() {
    super.initState();
    final v = widget.initial;
    account = TextEditingController(text: v.accountName);
    month = TextEditingController(text: v.statementMonth);
    opening = TextEditingController(text: '${v.openingBalance}');
    closing = TextEditingController(text: '${v.closingBalance}');
    amount = TextEditingController(
      text: v.statementAmount == 0 ? '' : '${v.statementAmount}',
    );
    minimum = TextEditingController(
      text: v.minimumDue == 0 ? '' : '${v.minimumDue}',
    );
    paid = TextEditingController(
      text: v.paidAmount == 0 ? '' : '${v.paidAmount}',
    );
    note = TextEditingController(text: v.note);
    type = v.type;
    status = v.status;
    dueDate = v.dueDate;
  }

  @override
  void dispose() {
    for (final c in [
      account,
      month,
      opening,
      closing,
      amount,
      minimum,
      paid,
      note,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('银行卡账单'),
    content: SizedBox(
      width: 420,
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            DropdownButtonFormField<CardStatementType>(
              initialValue: type,
              decoration: appFieldDecoration('账单类型'),
              items: const [
                DropdownMenuItem(
                  value: CardStatementType.credit,
                  child: Text('贷记/信用卡'),
                ),
                DropdownMenuItem(
                  value: CardStatementType.debit,
                  child: Text('借记卡'),
                ),
              ],
              onChanged: (v) => setState(() => type = v ?? type),
            ),
            _field(account, '账户/银行卡名称'),
            _field(month, '账单月份（YYYY-MM）'),
            _field(opening, '期初余额', number: true),
            _field(closing, '期末余额', number: true),
            _field(amount, '本期账单金额', number: true),
            _field(minimum, '最低还款额', number: true),
            _field(paid, '已还金额', number: true),
            if (type == CardStatementType.credit && dueDate != null)
              _DateField(
                label: '到期还款日',
                value: dueDate!,
                onChanged: (v) => setState(() => dueDate = v),
              ),
            DropdownButtonFormField<CardStatementStatus>(
              initialValue: status,
              decoration: appFieldDecoration('状态'),
              items: CardStatementStatus.values
                  .map(
                    (v) => DropdownMenuItem(
                      value: v,
                      child: Text(_statementStatus(v)),
                    ),
                  )
                  .toList(),
              onChanged: (v) => status = v ?? status,
            ),
            _field(note, '备注'),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: () {
          final values = [
            double.tryParse(opening.text.trim()) ?? 0,
            double.tryParse(closing.text.trim()) ?? 0,
            double.tryParse(amount.text.trim()) ?? 0,
            double.tryParse(minimum.text.trim()) ?? 0,
            double.tryParse(paid.text.trim()) ?? 0,
          ];
          if (account.text.trim().isEmpty ||
              !RegExp(r'^\d{4}-(0[1-9]|1[0-2])$').hasMatch(month.text.trim()) ||
              values.skip(2).any((v) => v < 0)) {
            _invalid(context, '请检查账户、月份与金额');
            return;
          }
          Navigator.pop(
            context,
            CardStatement(
              id: widget.initial.id,
              bookId: widget.initial.bookId,
              accountName: account.text.trim(),
              type: type,
              statementMonth: month.text.trim(),
              openingBalance: values[0],
              closingBalance: values[1],
              statementAmount: values[2],
              minimumDue: values[3],
              paidAmount: values[4],
              dueDate: type == CardStatementType.credit ? dueDate : null,
              status: status,
              note: note.text.trim(),
            ),
          );
        },
        child: const Text('保存'),
      ),
    ],
  );
}

const _financeFieldHeight = 52.0;

InputDecoration _financeDecoration({String? hintText, Widget? suffixIcon}) =>
    InputDecoration(
      hintText: hintText,
      floatingLabelBehavior: FloatingLabelBehavior.never,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      constraints: const BoxConstraints(minHeight: _financeFieldHeight),
      suffixIcon: suffixIcon,
    );

Widget _field(
  TextEditingController controller,
  String label, {
  bool number = false,
}) => Padding(
  padding: const EdgeInsets.only(top: 10),
  child: SizedBox(
    height: _financeFieldHeight,
    child: TextField(
      controller: controller,
      textAlignVertical: TextAlignVertical.center,
      keyboardType: number
          ? const TextInputType.numberWithOptions(decimal: true, signed: true)
          : TextInputType.text,
      decoration: _financeDecoration(hintText: label),
    ),
  ),
);

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final DateTime value;
  final ValueChanged<DateTime> onChanged;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 10),
    child: Semantics(
      button: true,
      label: "$label，${_date(value)}，点击选择日期",
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () async {
          final picked = await AppDatePicker.show(
            context,
            value,
            minimumDate: DateTime(2000),
            maximumDate: DateTime(2100),
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: _financeDecoration(
            suffixIcon: const Icon(Icons.calendar_month_outlined),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(fontSize: 12, color: context.appSecondaryText),
              ),
              const SizedBox(height: 2),
              Text(_date(value)),
            ],
          ),
        ),
      ),
    ),
  );
}

void _invalid(BuildContext context, String message) =>
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));

String _date(DateTime value) =>
    '${value.year}-${value.month.toString().padLeft(2, '0')}-'
    '${value.day.toString().padLeft(2, '0')}';

String _invoiceStatus(InvoiceStatus value) => switch (value) {
  InvoiceStatus.draft => '草稿',
  InvoiceStatus.issued => '已开出',
  InvoiceStatus.received => '已收到',
  InvoiceStatus.reimbursed => '已报销/入账',
  InvoiceStatus.voided => '已作废',
};

String _taxStatus(TaxFilingStatus value) => switch (value) {
  TaxFilingStatus.pending => '待申报',
  TaxFilingStatus.filed => '已申报',
  TaxFilingStatus.paid => '已缴税',
};

String _statementStatus(CardStatementStatus value) => switch (value) {
  CardStatementStatus.open => '待处理',
  CardStatementStatus.paid => '已还款/结清',
  CardStatementStatus.reconciled => '已核对',
};
