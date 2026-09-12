import 'package:flutter/material.dart';

const privacyAmountMask = '••••';

const privacyAmountMaskStyle = TextStyle(
  fontSize: 13,
  fontWeight: FontWeight.w600,
  letterSpacing: 3,
  height: 1,
);

/// Renders an amount with a small, fixed privacy mask without changing the
/// amount area's normal line height.
class PrivacyAmount extends StatelessWidget {
  const PrivacyAmount({
    this.text,
    this.span,
    required this.style,
    required this.hidden,
    this.fit = false,
    this.alignment = Alignment.centerLeft,
    super.key,
  }) : assert(text != null || span != null);

  final String? text;
  final InlineSpan? span;
  final TextStyle style;
  final bool hidden;
  final bool fit;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    if (!hidden) {
      final visibleSpan = span ?? _decimalSpan(text!, style);
      final amount = visibleSpan == null
          ? Text(
              text!,
              maxLines: fit ? 1 : null,
              softWrap: fit ? false : true,
              style: style,
            )
          : Text.rich(
              visibleSpan,
              maxLines: fit ? 1 : null,
              softWrap: fit ? false : true,
            );
      return fit
          ? FittedBox(
              fit: BoxFit.scaleDown,
              alignment: alignment,
              child: amount,
            )
          : amount;
    }

    final resolvedStyle = DefaultTextStyle.of(context).style.merge(style);
    final metrics = TextPainter(
      text: span ?? _decimalSpan(text!, resolvedStyle) ?? TextSpan(text: text),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final maskStyle = privacyAmountMaskStyle.copyWith(
      color: resolvedStyle.color,
      fontFamily: resolvedStyle.fontFamily,
    );

    return SizedBox(
      height: metrics.height,
      child: Align(
        alignment: alignment,
        child: Text(
          privacyAmountMask,
          maxLines: 1,
          softWrap: false,
          style: maskStyle,
          textScaler: TextScaler.noScaling,
        ),
      ),
    );
  }

  InlineSpan? _decimalSpan(String value, TextStyle baseStyle) {
    final separator = value.lastIndexOf('.');
    if (separator < 0 || separator == value.length - 1) return null;
    final fractionStyle = baseStyle.copyWith(
      fontSize: (baseStyle.fontSize ?? 14) * .5,
      height: baseStyle.height,
    );
    return TextSpan(
      style: baseStyle,
      children: [
        TextSpan(text: value.substring(0, separator + 1)),
        TextSpan(text: value.substring(separator + 1), style: fractionStyle),
      ],
    );
  }
}
