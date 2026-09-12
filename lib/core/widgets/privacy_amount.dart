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
      final amount = span == null
          ? Text(
              text!,
              maxLines: fit ? 1 : null,
              softWrap: fit ? false : true,
              style: style,
            )
          : Text.rich(
              span!,
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
      text: span ?? TextSpan(text: text, style: resolvedStyle),
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
}
