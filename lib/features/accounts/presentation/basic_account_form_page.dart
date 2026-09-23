import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/app_card.dart';
import '../data/account_management_repository.dart';
import '../domain/account_management.dart';

class BasicAccountFormPage extends ConsumerStatefulWidget {
  const BasicAccountFormPage({required this.category, super.key});

  final AccountFundCategory category;

  @override
  ConsumerState<BasicAccountFormPage> createState() =>
      _BasicAccountFormPageState();
}

class _BasicAccountFormPageState extends ConsumerState<BasicAccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _suffix = TextEditingController();
  final _balance = TextEditingController(text: '0.00');
  AccountType _type = AccountType.debitCard;
  String _currency = 'CNY';
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _suffix.dispose();
    _balance.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => SafeArea(
    child: ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
      children: [
        _Header(
          title: widget.category == AccountFundCategory.storedValue
              ? '新增储值资金'
              : widget.category == AccountFundCategory.custom
              ? '新增自定义账户'
              : '新增日常资金',
          onBack: () => context.pop(),
        ),
        const SizedBox(height: 14),
        AppCard(
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(
                    labelText: '账户名称 *',
                    hintText: '如：招商银行工资卡',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请填写账户名称' : null,
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<AccountType>(
                  initialValue: _type,
                  decoration: const InputDecoration(labelText: '账户渠道 / 类型'),
                  items: const [
                    DropdownMenuItem(
                      value: AccountType.cash,
                      child: Text('现金'),
                    ),
                    DropdownMenuItem(
                      value: AccountType.wechat,
                      child: Text('微信'),
                    ),
                    DropdownMenuItem(
                      value: AccountType.alipay,
                      child: Text('支付宝'),
                    ),
                    DropdownMenuItem(
                      value: AccountType.debitCard,
                      child: Text('银行卡'),
                    ),
                    DropdownMenuItem(
                      value: AccountType.other,
                      child: Text('其他'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() {
                          _type = value ?? AccountType.other;
                          if (!_type.requiresIdentifierSuffix) _suffix.clear();
                        }),
                ),
                if (_type.requiresIdentifierSuffix) ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _suffix,
                    maxLength: 4,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: InputDecoration(
                      labelText: _type.identifierInputLabel,
                      counterText: '',
                    ),
                    validator: (value) => RegExp(r'^\d{4}$')
                            .hasMatch(value?.trim() ?? '')
                        ? null
                        : '请输入 4 位数字',
                  ),
                ],
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _currency,
                  decoration: const InputDecoration(labelText: '币种'),
                  items: const [
                    DropdownMenuItem(value: 'CNY', child: Text('人民币（CNY）')),
                    DropdownMenuItem(value: 'USD', child: Text('美元（USD）')),
                    DropdownMenuItem(value: 'HKD', child: Text('港币（HKD）')),
                    DropdownMenuItem(value: 'EUR', child: Text('欧元（EUR）')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _currency = value ?? 'CNY'),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _balance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: '当前余额 *',
                    prefixText: '$_currency ',
                  ),
                  validator: (value) =>
                      MoneyFormatter.parseInput(value ?? '') == null
                      ? '请输入有效金额'
                      : null,
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
        ],
        const SizedBox(height: 22),
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

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final balance = MoneyFormatter.parseInput(_balance.text) ?? 0;
    final assetForm = widget.category == AccountFundCategory.storedValue
        ? AssetForm.walletBalance
        : switch (_type) {
            AccountType.cash => AssetForm.cash,
            AccountType.wechat || AccountType.alipay => AssetForm.walletBalance,
            AccountType.debitCard => AssetForm.demandDeposit,
            _ => AssetForm.other,
          };
    final account = Account(
      id: 'account-${newEntityId()}',
      name: _name.text.trim(),
      type: _type,
      balance: balance,
      openingBalance: balance,
      currency: _currency,
      icon: 'account_balance_wallet_outlined',
      color: 0xff73963b,
      sortOrder: ref.read(managedAccountsProvider).value?.length ?? 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      assetForm: assetForm,
      identifierSuffix:
          _type.requiresIdentifierSuffix ? _suffix.text.trim() : null,
    );
    try {
      await ref.read(accountManagementRepositoryProvider).create(
        account: account,
        category: widget.category,
        includeInTotal: true,
      );
      if (mounted) context.go('/profile/accounts');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$error';
      });
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.title, required this.onBack});
  final String title;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      IconButton(onPressed: onBack, icon: const Icon(Icons.arrow_back)),
      Expanded(
        child: Text(
          title,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      const SizedBox(width: 48),
    ],
  );
}
