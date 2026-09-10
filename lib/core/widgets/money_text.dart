import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.positive,
    this.showSign = false,
    this.currency = 'CNY',
  });

  final double amount;
  final TextStyle? style;
  final bool? positive;
  final bool showSign;
  final String currency;

  @override
  Widget build(BuildContext context) {
    final isPositive = positive ?? amount >= 0;
    final sign = showSign
        ? (isPositive ? '+ ' : '- ')
        : (amount < 0 && positive == null ? '- ' : '');
    final value = NumberFormat.currency(
      locale: 'zh_CN',
      symbol: currency == 'CNY' ? '¥' : '$currency ',
      decimalDigits: amount % 1 == 0 ? 0 : 2,
    ).format(amount.abs());
    final resolvedStyle = style ?? Theme.of(context).textTheme.bodyLarge!;
    return Text(
      '$sign$value',
      style: resolvedStyle.copyWith(
        color: positive == null
            ? resolvedStyle.color
            : (isPositive ? AppColors.income : AppColors.textPrimary),
      ),
    );
  }
}
