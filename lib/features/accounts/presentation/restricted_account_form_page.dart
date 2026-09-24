import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/utils/entity_id.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../data/account_management_repository.dart';
import '../domain/account_management.dart';
import 'account_management_visuals.dart';

class RestrictedAccountFormPage extends ConsumerStatefulWidget {
  const RestrictedAccountFormPage({super.key});

  @override
  ConsumerState<RestrictedAccountFormPage> createState() =>
      _RestrictedAccountFormPageState();
}

class _RestrictedAccountFormPageState
    extends ConsumerState<RestrictedAccountFormPage> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _balance = TextEditingController();
  final _customPlatform = TextEditingController();
  final _note = TextEditingController();
  String _platform = '淘宝';
  RestrictedFundStatus _status = RestrictedFundStatus.locked;
  DateTime? _expectedReturnAt;
  bool _includeInTotal = true;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _balance.dispose();
    _customPlatform.dispose();
    _note.dispose();
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
                '新增账户',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            const SizedBox(width: 48),
          ],
        ),
        const SizedBox(height: 12),
        AppCard(
          color: context.appSurface.withValues(alpha: .92),
          borderRadius: 22,
          child: Stack(
            children: [
              const Positioned(
                right: -8,
                top: -10,
                child: AccountLeafPlaceholder(size: 88, opacity: .12),
              ),
              Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: context.appPrimarySoft.withValues(alpha: .72),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.lock_outline_rounded,
                      color: context.appPrimary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '受限资金',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          '在特定条件下才能使用的资金\n如保证金、押金等',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
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
                    hintText: '网店保证金（淘宝）',
                  ),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? '请填写账户名称' : null,
                ),
                const SizedBox(height: 14),
                const TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    labelText: '账户类型',
                    hintText: '受限资金',
                  ),
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<String>(
                  initialValue: _platform,
                  decoration: const InputDecoration(labelText: '平台 / 机构 *'),
                  items: const [
                    DropdownMenuItem(value: '淘宝', child: Text('淘宝')),
                    DropdownMenuItem(value: '抖音', child: Text('抖音')),
                    DropdownMenuItem(value: '拼多多', child: Text('拼多多')),
                    DropdownMenuItem(value: '京东', child: Text('京东')),
                    DropdownMenuItem(value: '房东', child: Text('房东')),
                    DropdownMenuItem(value: '其他', child: Text('其他')),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _platform = value ?? '其他'),
                ),
                if (_platform == '其他') ...[
                  const SizedBox(height: 14),
                  TextFormField(
                    controller: _customPlatform,
                    decoration: const InputDecoration(
                      labelText: '平台 / 机构名称 *',
                      hintText: '请输入实际平台或机构名称',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? '请填写平台或机构名称'
                        : null,
                  ),
                ],
                const SizedBox(height: 14),
                TextFormField(
                  controller: _balance,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: '当前余额 *',
                    suffixText: '元',
                  ),
                  validator: (value) {
                    final amount = MoneyFormatter.parseInput(value ?? '');
                    if (amount == null || amount < 0) return '请输入有效金额';
                    return null;
                  },
                ),
                const SizedBox(height: 14),
                DropdownButtonFormField<RestrictedFundStatus>(
                  initialValue: _status,
                  decoration: const InputDecoration(labelText: '资金状态 *'),
                  items: [
                    for (final status in RestrictedFundStatus.values)
                      DropdownMenuItem(
                        value: status,
                        child: Text(status.label),
                      ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _status = value ?? _status),
                ),
                const SizedBox(height: 14),
                InkWell(
                  onTap: _saving ? null : _pickExpectedDate,
                  borderRadius: BorderRadius.circular(12),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: '预计退回日期',
                      suffixIcon: Icon(Icons.calendar_month_outlined),
                    ),
                    child: Text(
                      _expectedReturnAt == null
                          ? '未设置'
                          : _date(_expectedReturnAt!),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                TextFormField(
                  controller: _note,
                  maxLength: 200,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    labelText: '备注',
                    hintText: '店铺关闭后预计 30 个工作日内退回。',
                  ),
                ),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Row(
                    children: [
                      const Text('是否计入总资产'),
                      const SizedBox(width: 5),
                      Tooltip(
                        message: '关闭后账户仍保留，但不计入首页和资产总览合计。',
                        child: Icon(
                          Icons.help_outline_rounded,
                          size: 16,
                          color: context.appSecondaryText,
                        ),
                      ),
                    ],
                  ),
                  subtitle: const Text('关闭后，该账户不计入资产统计'),
                  value: _includeInTotal,
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _includeInTotal = value),
                ),
              ],
            ),
          ),
        ),
        if (_error != null) ...[
          const SizedBox(height: 12),
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        ],
        const SizedBox(height: 18),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Text(_saving ? '保存中…' : '保存'),
          ),
        ),
        const SizedBox(height: 10),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.lock_outline_rounded,
              size: 14,
              color: context.appSecondaryText.withValues(alpha: .72),
            ),
            const SizedBox(width: 6),
            Text(
              '认真记录，守护每一份资金的安全',
              style: TextStyle(
                fontSize: 11,
                color: context.appSecondaryText.withValues(alpha: .82),
              ),
            ),
          ],
        ),
      ],
    ),
  );

  Future<void> _pickExpectedDate() async {
    final now = DateTime.now();
    final selected = await AppDatePicker.show(
      context,
      _expectedReturnAt ?? now,
      minimumDate: DateTime(now.year - 1),
      maximumDate: DateTime(now.year + 20),
    );
    if (selected != null) setState(() => _expectedReturnAt = selected);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    final now = DateTime.now();
    final balance = MoneyFormatter.parseInput(_balance.text) ?? 0;
    final account = Account(
      id: 'account-${newEntityId()}',
      name: _name.text.trim(),
      type: AccountType.cash,
      balance: balance,
      openingBalance: balance,
      currency: 'CNY',
      icon: 'lock_outline',
      color: 0xff5B8DEF,
      sortOrder: ref.read(managedAccountsProvider).value?.length ?? 0,
      isArchived: false,
      createdAt: now,
      updatedAt: now,
      assetForm: AssetForm.other,
      identifierSuffix: null,
    );
    try {
      final created = await ref
          .read(accountManagementRepositoryProvider)
          .create(
            account: account,
            category: AccountFundCategory.restricted,
            platform: _platform == '其他'
                ? _customPlatform.text.trim()
                : _platform,
            restrictedStatus: _status,
            expectedReturnAt: _expectedReturnAt,
            includeInTotal: _includeInTotal,
            note: _note.text,
          );
      if (mounted) {
        context.go('/profile/accounts/restricted/${created.account.id}');
      }
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = '保存失败：$error';
      });
    }
  }

  String _date(DateTime value) =>
      '${value.year.toString().padLeft(4, '0')}年'
      '${value.month.toString().padLeft(2, '0')}月'
      '${value.day.toString().padLeft(2, '0')}日';
}
