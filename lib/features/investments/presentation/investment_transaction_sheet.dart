import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../../core/widgets/app_date_picker.dart';
import '../../../core/widgets/app_form.dart';
import '../data/investment_repository.dart';
import '../domain/investment_asset.dart';
import '../domain/investment_input.dart';
import '../domain/investment_holding.dart';

/// Records a 买入 / 卖出 / 分红 / 利息 against a holding.
///
/// Returns true when a record was written, so the caller can invalidate the
/// providers that need to re-read it.
Future<bool?> showInvestmentTransactionSheet(
  BuildContext context, {
  required InvestmentHolding holding,
}) => AppBottomSheet.show<bool>(
  context: context,
  builder: (_) => _TransactionSheet(holding: holding),
);

class _TransactionSheet extends ConsumerStatefulWidget {
  const _TransactionSheet({required this.holding});

  final InvestmentHolding holding;

  @override
  ConsumerState<_TransactionSheet> createState() => _TransactionSheetState();
}

class _TransactionSheetState extends ConsumerState<_TransactionSheet> {
  final _formKey = GlobalKey<FormState>();
  final _quantity = TextEditingController();
  final _price = TextEditingController();
  final _amount = TextEditingController();
  final _note = TextEditingController();
  InvestmentTransactionType _type = InvestmentTransactionType.buy;
  DateTime _date = DateUtils.dateOnly(DateTime.now());
  bool _saving = false;

  bool get _isCashOnly =>
      _type == InvestmentTransactionType.dividend ||
      _type == InvestmentTransactionType.interest;

  @override
  void dispose() {
    _quantity.dispose();
    _price.dispose();
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final holding = widget.holding;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: Form(
        key: _formKey,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '记录交易 · ${holding.asset.name}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '当前持有 ${InvestmentTransaction.formatQuantity(holding.quantity)}'
              ' · 平均成本 '
              '¥${InvestmentInput.formatPriceLabel(holding.averageCost)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(3),
              decoration: BoxDecoration(
                color: context.appSurfaceSoft,
                borderRadius: BorderRadius.circular(22),
              ),
              child: Row(
                children: [
                  for (final type in InvestmentTransactionType.values)
                    Expanded(
                      child: Semantics(
                        selected: _type == type,
                        button: true,
                        child: InkWell(
                          key: ValueKey('investment-tx-type-${type.name}'),
                          onTap: () => setState(() => _type = type),
                          borderRadius: BorderRadius.circular(18),
                          child: AnimatedContainer(
                            duration: MediaQuery.disableAnimationsOf(context)
                                ? Duration.zero
                                : const Duration(milliseconds: 180),
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: _type == type
                                  ? AppColors.primary
                                  : Colors.transparent,
                              borderRadius: BorderRadius.circular(18),
                            ),
                            child: Text(
                              type.label,
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: _type == type
                                    ? FontWeight.w700
                                    : FontWeight.w500,
                                color: _type == type
                                    ? Colors.white
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            if (_isCashOnly)
              AppInput(
                key: const ValueKey('investment-tx-amount'),
                controller: _amount,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: const InputDecoration(labelText: '金额'),
                validator: (value) {
                  final parsed = MoneyFormatter.parseInput(value ?? '');
                  if (parsed == null || parsed <= 0) return '请输入有效金额';
                  return null;
                },
              )
            else ...[
              AppFormRow(
                children: [
                  AppInput(
                    key: const ValueKey('investment-tx-quantity'),
                    controller: _quantity,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '数量'),
                    validator: (value) {
                      final parsed = InvestmentInput.parseQuantity(value ?? '');
                      if (parsed == null || parsed <= 0) return '请输入有效数量';
                      if (_type == InvestmentTransactionType.sell &&
                          parsed > holding.quantity + 1e-9) {
                        return '超过持有数量';
                      }
                      return null;
                    },
                  ),
                  AppInput(
                    key: const ValueKey('investment-tx-price'),
                    controller: _price,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    decoration: const InputDecoration(labelText: '价格'),
                    validator: (value) {
                      final parsed = InvestmentInput.parsePrice(value ?? '');
                      if (parsed == null || parsed <= 0) return '请输入有效价格';
                      return null;
                    },
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            InkWell(
              key: const ValueKey('investment-tx-date'),
              onTap: () async {
                final picked = await AppDatePicker.show(context, _date);
                if (picked != null) setState(() => _date = picked);
              },
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: const InputDecoration(labelText: '交易日期'),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${_date.year}-${_date.month.toString().padLeft(2, '0')}-'
                        '${_date.day.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 15),
                      ),
                    ),
                    const Icon(Icons.calendar_today_outlined, size: 16),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            AppInput(
              key: const ValueKey('investment-tx-note'),
              controller: _note,
              decoration: const InputDecoration(labelText: '备注（可选）'),
            ),
            const SizedBox(height: 8),
            const Text(
              '投资收益不计入日常消费支出，买入属于现金资产转为投资资产。',
              style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            FilledButton(
              key: const ValueKey('investment-tx-submit'),
              onPressed: _saving ? null : _save,
              style: FilledButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                minimumSize: const Size.fromHeight(48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
              child: Text(_saving ? '保存中…' : '保存'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;
    setState(() => _saving = true);
    final repository = ref.read(investmentRepositoryProvider);
    try {
      if (_isCashOnly) {
        final amount = MoneyFormatter.parseInput(_amount.text)!;
        await repository.addTransaction(
          widget.holding.id,
          AddTransactionRequest(
            type: _type,
            // A cash distribution moves money without moving units; price is
            // the whole amount and quantity stays 1 so `amount == price`.
            quantity: 1,
            price: amount,
            transactionDate: _date,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
        );
      } else {
        await repository.addTransaction(
          widget.holding.id,
          AddTransactionRequest(
            type: _type,
            quantity: InvestmentInput.parseQuantity(_quantity.text)!,
            price: InvestmentInput.parsePrice(_price.text)!,
            transactionDate: _date,
            note: _note.text.trim().isEmpty ? null : _note.text.trim(),
          ),
        );
      }
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } on ArgumentError catch (error) {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message?.toString() ?? '请检查填写内容')),
      );
    } on Object {
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('保存失败，请重试')));
    }
  }
}
