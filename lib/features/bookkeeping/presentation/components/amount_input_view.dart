import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../application/amount_input.dart';
import 'bookkeeping_card_style.dart';

class AmountInputView extends StatelessWidget {
  const AmountInputView({
    super.key,
    required this.input,
    required this.currency,
  });
  final AmountInput input;
  final String currency;

  @override
  Widget build(BuildContext context) => Container(
    key: const ValueKey('quick-amount-input'),
    height: BookkeepingCardStyle.amountHeight,
    padding: const EdgeInsets.symmetric(
      horizontal: BookkeepingCardStyle.amountHorizontalPadding,
    ),
    decoration: BoxDecoration(
      color: BookkeepingCardStyle.amountBackground,
      borderRadius: BorderRadius.circular(BookkeepingCardStyle.amountRadius),
    ),
    child: Row(
      children: [
        Expanded(
          flex: 2,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              input.value.isEmpty ? '0' : input.value,
              key: const ValueKey('quick-amount-expression'),
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 30,
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          flex: 3,
          child: FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerRight,
            child: Text(
              '= $currency${input.amount == null ? '0.00' : input.displayValue}',
              key: const ValueKey('quick-amount-display'),
              style: const TextStyle(
                color: AppColors.primaryDark,
                fontSize: 20,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ],
    ),
  );
}
