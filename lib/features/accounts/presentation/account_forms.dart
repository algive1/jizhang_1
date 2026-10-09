import '../../../core/widgets/app_form.dart';
import '../../../core/utils/entity_id.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../data/account_management_repository.dart';
import '../domain/account_management.dart';
import '../data/account_repository.dart';

Future<void> showAccountEditor(
  BuildContext context, {
  Account? account,
  ManagedAccount? managed,
  AccountType initialType = AccountType.debitCard,
  String initialCurrency = 'CNY',
  int sortOrder = 0,
}) => showDialog<void>(
  context: context,
  builder: (_) => _AccountEditor(
    account: account,
    managed: managed,
    initialType: initialType,
    initialCurrency: initialCurrency,
    sortOrder: sortOrder,
  ),
);

class _AccountEditor extends ConsumerStatefulWidget {
  const _AccountEditor({
    this.account,
    this.managed,
    required this.initialType,
    required this.initialCurrency,
    required this.sortOrder,
  });
  final Account? account;
  final ManagedAccount? managed;
  final AccountType initialType;
  final String initialCurrency;
  final int sortOrder;
  @override
  ConsumerState<_AccountEditor> createState() => _AccountEditorState();
}

class _AccountEditorState extends ConsumerState<_AccountEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.account?.name);
  late final _identifierSuffix = TextEditingController(
    text: widget.account?.identifierSuffix ?? '',
  );
  final _balance = TextEditingController(text: '0.00');
  late AccountType _type = widget.account?.type ?? widget.initialType;
  late final _platform = TextEditingController(text: widget.managed?.platform);
  late final _note = TextEditingController(text: widget.managed?.note);
  late bool _include = widget.managed?.includeInTotal ?? true;
  late RestrictedFundStatus _status =
      widget.managed?.restrictedStatus ?? RestrictedFundStatus.locked;
  late DateTime? _expected = widget.managed?.expectedReturnAt;
  bool get _restricted =>
      widget.managed?.category == AccountFundCategory.restricted;
  bool get _hasPlatform =>
      _restricted ||
      widget.managed?.category == AccountFundCategory.storedValue;
  late AssetForm _assetForm =
      widget.account?.assetForm ?? AssetForm.unspecified;
  late String _currency = widget.account?.currency ?? widget.initialCurrency;
  bool _debt = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _identifierSuffix.dispose();
    _balance.dispose();
    _platform.dispose();
    _note.dispose();
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
            AppSelect<AccountType>(
              initialValue: _type,
              isExpanded: true,
              decoration: appFieldDecoration('账户渠道 / 类型'),
              items: [
                for (final t in AccountType.values)
                  DropdownMenuItem(value: t, child: Text(t.label)),
              ],
              onChanged: _saving || _hasPlatform
                  ? null
                  : (v) => setState(() {
                      _type = v!;
                      if (!_type.requiresIdentifierSuffix) {
                        _identifierSuffix.clear();
                      }
                    }),
            ),
            if (_type.requiresIdentifierSuffix) ...[
              const SizedBox(height: 12),
              TextFormField(
                controller: _identifierSuffix,
                keyboardType: TextInputType.number,
                maxLength: 4,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: _type.identifierInputLabel,
                  hintText: '请输入 4 位数字',
                  counterText: '',
                ),
                validator: (value) {
                  final suffix = value?.trim() ?? '';
                  return RegExp(r'^\d{4}$').hasMatch(suffix)
                      ? null
                      : '${_type.identifierInputLabel}必须是 4 位数字';
                },
              ),
            ],
            if (!_type.isDebt) ...[
              const SizedBox(height: 12),
              AppSelect<AssetForm>(
                initialValue: _assetForm,
                isExpanded: true,
                decoration: appFieldDecoration('资金形式'),
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
              AppSelect<String>(
                initialValue: _currency,
                isExpanded: true,
                decoration: appFieldDecoration('币种（分别统计，不折算）'),
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
            if (widget.managed != null) ...[
              if (_hasPlatform) ...[
                const SizedBox(height: 12),
                TextFormField(
                  controller: _platform,
                  decoration: InputDecoration(
                    labelText: _restricted ? '平台 / 机构' : '平台 / 用途',
                  ),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? '请填写平台或机构名称' : null,
                ),
              ],
              if (_restricted) ...[
                const SizedBox(height: 12),
                AppSelect<RestrictedFundStatus>(
                  initialValue: _status,
                  decoration: appFieldDecoration('资金状态'),
                  items: [
                    for (final status in RestrictedFundStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (v) => setState(() => _status = v!),
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('预计退回日期'),
                  subtitle: Text(
                    _expected == null
                        ? '未设置'
                        : _expected!.toIso8601String().substring(0, 10),
                  ),
                  trailing: const Icon(Icons.calendar_month_outlined),
                  onTap: _saving
                      ? null
                      : () async {
                          final date = await AppDatePicker.show(
                            context,
                            _expected ?? DateTime.now(),
                          );
                          if (date != null && mounted)
                            setState(() => _expected = date);
                        },
                ),
              ],
              const SizedBox(height: 12),
              TextFormField(
                controller: _note,
                maxLines: 3,
                decoration: const InputDecoration(labelText: '备注'),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('计入总资产'),
                value: _include,
                onChanged: _saving ? null : (v) => setState(() => _include = v),
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
      bookId: old?.bookId ?? 'book-personal',
      id: old?.id ?? 'account-${newEntityId()}',
      name: _name.text.trim(),
      type: _type,
      balance: old?.balance ?? (_type.isDebt && _debt ? -entered : entered),
      openingBalance: old?.openingBalance,
      currency: _currency,
      assetForm: _type.isDebt ? AssetForm.unspecified : _assetForm,
      identifierSuffix: _type.requiresIdentifierSuffix
          ? _identifierSuffix.text.trim()
          : null,
      icon: old?.icon ?? 'account_balance_wallet_outlined',
      color: old?.color ?? 0xff73963b,
      sortOrder: old?.sortOrder ?? widget.sortOrder,
      isArchived: old?.isArchived ?? false,
      createdAt: old?.createdAt ?? now,
      updatedAt: now,
    );
    try {
      final database = ref.read(databaseProvider);
      final repository = old == null
          ? ref.read(accountRepositoryProvider)
          : DriftAccountRepository(database, bookId: old.bookId);
      await database.transaction(() async {
        if (old == null) {
          await repository.create(account);
        } else {
          await repository.update(account);
        }
        final managed = widget.managed;
        if (managed != null) {
          await DriftAccountManagementRepository(
            database,
            repository,
            bookId: managed.account.bookId,
          ).updateMeta(
            accountId: account.id,
            category: managed.category,
            platform: _platform.text,
            restrictedStatus: _restricted ? _status : managed.restrictedStatus,
            expectedReturnAt: _restricted
                ? _expected
                : managed.expectedReturnAt,
            includeInTotal: _include,
            note: _note.text,
          );
        }
      });
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
    title: Text(
      '${widget.account.type.isDebt ? '校准欠款' : '校准余额'} · ${widget.account.displayName}',
    ),
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
      await DriftAccountRepository(
        ref.read(databaseProvider),
        bookId: widget.account.bookId,
      ).reconcileBalance(widget.account.id, value);
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
