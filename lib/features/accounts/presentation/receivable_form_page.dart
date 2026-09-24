import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/app_card.dart';
import '../../books/data/book_repository.dart';
import '../data/receivable_repository.dart';
import '../domain/account_management.dart';

class ReceivableFormPage extends ConsumerStatefulWidget {
  const ReceivableFormPage({super.key});

  @override
  ConsumerState<ReceivableFormPage> createState() => _ReceivableFormPageState();
}

class _ReceivableFormPageState extends ConsumerState<ReceivableFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _counterparty = TextEditingController();
  final _amount = TextEditingController();
  final _remark = TextEditingController();
  ReceivableType _type = ReceivableType.reimbursement;
  DateTime _occurredAt = DateTime.now();
  DateTime? _expectedAt;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _counterparty.dispose();
    _amount.dispose();
    _remark.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        Row(
          children: [
            IconButton(
              onPressed: () => context.pop(),
              icon: const Icon(Icons.arrow_back),
            ),
            Expanded(
              child: Text(
                '新增应收',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                DropdownButtonFormField<ReceivableType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: '应收类型 *'),
                  items: [
                    for (final type in ReceivableType.values)
                      DropdownMenuItem(value: type, child: Text(type.label)),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _type = value ?? _type),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: '应收名称 *',
                    hintText: '如：差旅待报销',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请填写应收名称' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _counterparty,
                  decoration: const InputDecoration(
                    labelText: '往来对象 *',
                    hintText: '如：公司报销',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请填写往来对象' : null,
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _amount,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '应收总额 *',
                    prefixText: '¥ ',
                  ),
                  validator: (value) =>
                      MoneyFormatter.parseInput(value ?? '') == null
                      ? '请输入有效金额'
                      : null,
                ),
                const SizedBox(height: 14),
                _DateField(
                  label: '发生日期',
                  value: _occurredAt,
                  onTap: () => _pickDate(
                    initial: _occurredAt,
                    onPicked: (value) => setState(() => _occurredAt = value),
                  ),
                ),
                const SizedBox(height: 14),
                _DateField(
                  label: '预计到账',
                  value: _expectedAt,
                  onTap: () => _pickDate(
                    initial: _expectedAt ?? DateTime.now(),
                    onPicked: (value) => setState(() => _expectedAt = value),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _remark,
                  maxLines: 3,
                  maxLength: 200,
                  decoration: const InputDecoration(labelText: '备注'),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 20),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ),
      ],
    ),
  );

  Future<void> _pickDate({
    required DateTime initial,
    required ValueChanged<DateTime> onPicked,
  }) async {
    final result = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(DateTime.now().year - 5),
      lastDate: DateTime(DateTime.now().year + 20),
    );
    if (result != null) onPicked(result);
  }

  String _defaultBusinessStatus() => switch (_type) {
    ReceivableType.reimbursement => '待提交',
    ReceivableType.refund => '处理中',
    ReceivableType.lend => '待归还',
    ReceivableType.customer => '待付款',
    ReceivableType.other => '待回收',
  };

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final String? assetBookCandidate =
        ref.read(activeBookProvider)?.assetBookId ??
        ref.read(activeBookIdProvider);
    if (assetBookCandidate == null) {
      setState(() {
        _saving = false;
        _error = '当前资产账本不可用';
      });
      return;
    }
    final assetBookId = assetBookCandidate;
    final now = DateTime.now();
    final item = Receivable(
      id: 'receivable-${newEntityId()}',
      bookId: assetBookId,
      name: _name.text.trim(),
      type: _type,
      counterparty: _counterparty.text.trim(),
      totalAmount: MoneyFormatter.parseInput(_amount.text) ?? 0,
      receivedAmount: 0,
      occurredAt: _occurredAt,
      expectedAt: _expectedAt,
      status: ReceivableStatus.pending,
      businessStatus: _defaultBusinessStatus(),
      remark: _remark.text.trim(),
      createdAt: now,
      updatedAt: now,
    );
    try {
      final created = await ref.read(receivableRepositoryProvider).create(item);
      ref.invalidate(receivablesProvider);
      if (mounted) {
        context.go('/profile/accounts/receivables/${created.id}');
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$error';
      });
    }
  }
}

class _DateField extends StatelessWidget {
  const _DateField({
    required this.label,
    required this.value,
    required this.onTap,
  });

  final String label;
  final DateTime? value;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(12),
    child: InputDecorator(
      decoration: InputDecoration(
        labelText: label,
        suffixIcon: const Icon(Icons.calendar_month_outlined),
      ),
      child: Text(
        value == null
            ? '未设置'
            : '${value!.year.toString().padLeft(4, '0')}-'
                  '${value!.month.toString().padLeft(2, '0')}-'
                  '${value!.day.toString().padLeft(2, '0')}',
      ),
    ),
  );
}
