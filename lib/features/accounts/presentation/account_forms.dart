import '../../../core/utils/entity_id.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../data/account_repository.dart';

Future<void> showAccountEditor(
  BuildContext context, {
  Account? account,
  int sortOrder = 0,
}) => showDialog<void>(
  context: context,
  builder: (_) => _AccountEditor(account: account, sortOrder: sortOrder),
);

class _AccountEditor extends ConsumerStatefulWidget {
  const _AccountEditor({this.account, required this.sortOrder});
  final Account? account;
  final int sortOrder;
  @override
  ConsumerState<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<_AccountEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.account?.name);
  final _balance = TextEditingController(text: '0.00');
  late AccountType _type = widget.account?.type ?? AccountType.debitCard;
  late AssetForm _assetForm =
      widget.account?.assetForm ?? AssetForm.unspecified;
  late String _currency = widget.account?.currency ?? 'CNY';
  bool _debt = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text(widget.account == null ? '新增账户' : '编辑账户'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _name,
              decoration: const InputDecoration(
                labelText: '账户名称',
                hintText: '如：招商银行工资卡',
              ),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? '请填写账户名称' : null,
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<AccountType>(
              initialValue: _type,
              isExpanded: true,
              decoration: const InputDecoration(labelText: '账户渠道 / 类型'),
              items: [
                for (final t in AccountType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: _saving ? null : (v) => setState(() => _type = v!),
            ),
            if (!_type.isDebt) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<AssetForm>(
                initialValue: _assetForm,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '资金形式'),
                items: [
                  for (final f in AssetForm.values)
                    DropdownMenuItem(value: f, child: Text(f.label)),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _assetForm = v!),
              ),
            ],
            if (widget.account == null) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _currency,
                isExpanded: true,
                decoration: const InputDecoration(labelText: '币种（分别统计，不折算）'),
                items: [
                  for (final c in {'CNY', 'USD', 'EUR', 'HKD', _currency})
                    DropdownMenuItem(value: c, child: Text(c)),
                ],
                onChanged: _saving
                    ? null
                    : (v) => setState(() => _currency = v!),
              ),
              if (_type.isDebt)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('这是欠款'),
                  subtitle: const Text('关闭表示溢缴或预存资金'),
                  value: _debt,
                  onChanged: _saving ? null : (v) => setState(() => _debt = v),
                ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _balance,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                  signed: true,
                ),
                decoration: InputDecoration(
                  labelText: _type.isDebt
                      ? (_debt ? '当前欠款（填正数）' : '溢缴 / 预存金额')
                      : '当前实际余额',
                  prefixText: '$_currency ',
                ),
                validator: (v) =>
                    MoneyFormatter.parseInput(v ?? '', signed: !_type.isDebt) ==
                        null
                    ? '请输入金额，最多两位小数'
                    : null,
              ),
              const SizedBox(height: 8),
              const Text(
                '初始资金不计入收支；暂不确定可以保留 0，之后校准。',
                style: TextStyle(fontSize: 12),
              ),
            ] else ...[
              const SizedBox(height: 12),
              const Text(
                '修改名称或形式不会改变余额；请使用「校准余额」更新实际资金。',
                style: TextStyle(fontSize: 12),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? '保存中…' : '保存'),
      ),
    ],
  );

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final old = widget.account;
    final now = DateTime.now();
    final entered =
        MoneyFormatter.parseInput(_balance.text, signed: !_type.isDebt) ?? 0;
    final account = Account(
      id: old?.id ?? 'account-${newEntityId()}',
      name: _name.text.trim(),
      type: _type,
      balance: old?.balance ?? (_type.isDebt && _debt ? -entered : entered),
      currency: _currency,
      assetForm: _type.isDebt ? AssetForm.unspecified : _assetForm,
      icon: old?.icon ?? 'account_balance_wallet_outlined',
      color: old?.color ?? 0xff73963b,
      sortOrder: old?.sortOrder ?? widget.sortOrder,
      isArchived: old?.isArchived ?? false,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final repository = ref.read(accountRepositoryProvider);
      if (old == null) {
        await repository.create(account);
      } else {
        await repository.update(account);
      }
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '保存失败：$error';
        });
      }
    }
  }
}

Future<void> showBalanceCalibration(BuildContext context, Account account) =>
    showDialog<void>(
      context: context,
      builder: (_) => _BalanceCalibration(account: account),
    );

class _BalanceCalibration extends ConsumerStatefulWidget {
  const _BalanceCalibration({required this.account});
  final Account account;
  @override
  ConsumerState<_BalanceCalibration> createState() =>
      _BalanceCalibrationState();
}

class _BalanceCalibrationState extends ConsumerState<_BalanceCalibration> {
  final _form = GlobalKey<FormState>();
  late final _amount = TextEditingController(
    text:
        (widget.account.type.isDebt
                ? widget.account.balance.abs()
                : widget.account.balance)
            .toStringAsFixed(2),
  );
  late bool _debt = widget.account.balance <= 0;
  bool _saving = false;
  String? _error;
  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('校准余额 · ${widget.account.name}'),
    content: SingleChildScrollView(
      child: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('填写当前实际余额。差额会记为「余额校准」，不计入收入、支出或预算。'),
            if (widget.account.type.isDebt)
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('这是欠款'),
                subtitle: const Text('关闭表示溢缴或预存资金'),
                value: _debt,
                onChanged: _saving ? null : (v) => setState(() => _debt = v),
              ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
                signed: true,
              ),
              decoration: InputDecoration(
                labelText: widget.account.type.isDebt
                    ? (_debt ? '实际欠款（填正数）' : '实际溢缴金额')
                    : '实际余额',
                prefixText: '${widget.account.currency} ',
              ),
              validator: (v) =>
                  MoneyFormatter.parseInput(
                        v ?? '',
                        signed: !widget.account.type.isDebt,
                      ) ==
                      null
                  ? '请输入金额，最多两位小数'
                  : null,
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('取消'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? '保存中…' : '确认校准'),
      ),
    ],
  );
  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    var value = MoneyFormatter.parseInput(
      _amount.text,
      signed: !widget.account.type.isDebt,
    )!;
    if (widget.account.type.isDebt && _debt) value = -value;
    try {
      await ref
          .read(accountRepositoryProvider)
          .reconcileBalance(widget.account.id, value);
      if (mounted) Navigator.pop(context);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = '校准失败：$error';
        });
      }
    }
  }
}
