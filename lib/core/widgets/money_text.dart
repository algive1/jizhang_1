import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../app/theme/app_colors.dart';
import 'privacy_amount.dart';

class MoneyText extends StatelessWidget {
  const MoneyText(
    this.amount, {
    super.key,
    this.style,
    this.positive,
    this.showSign = false,
    this.currency = 'CNY',
    this.hidden = false,
  });

  final double amount;
  final TextStyle? style;
  final bool? positive;
  final bool showSign;
  final String currency;
  final bool hidden;

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
    final amountStyle = resolvedStyle.copyWith(
      color: positive == null
          ? resolvedStyle.color
          : (isPositive ? AppColors.income : AppColors.expense),
    );
    return PrivacyAmount(
      text: '$sign$value',
      span: _amountSpan(sign, value, amountStyle),
      style: amountStyle,
      hidden: hidden,
    );
  }

  InlineSpan _amountSpan(String sign, String value, TextStyle style) {
    final separator = value.lastIndexOf('.');
    if (separator < 0 || separator == value.length - 1) {
      return TextSpan(text: '$sign$value', style: style);
    }
    final fractionStyle = style.copyWith(
      fontSize: (style.fontSize ?? 14) * .5,
      height: style.height,
    );
    return TextSpan(
      style: style,
      children: [
        TextSpan(text: '$sign${value.substring(0, separator)}'),
        TextSpan(text: value.substring(separator, separator + 1)),
        TextSpan(text: value.substring(separator + 1), style: fractionStyle),
      ],
    );
  }
}
