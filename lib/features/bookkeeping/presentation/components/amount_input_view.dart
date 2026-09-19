import 'package:flutter/material.dart';

import '../../application/amount_input.dart';
import '../../../app/theme/app_theme_tokens.dart';

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
    height: 58,
    padding: const EdgeInsets.symmetric(horizontal: 14),
    decoration: BoxDecoration(
      color: const Color(0xFFF3F3F3),
      borderRadius: BorderRadius.circular(20),
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
              style: TextStyle(
                color: context.appPrimaryText,
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
              style: TextStyle(
                color: context.appPrimary,
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
