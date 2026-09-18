import 'package:flutter/material.dart';

/// Shared visual metrics for bookkeeping entry cards.
///
/// The full manual-entry page and the automatic-bookkeeping confirmation card
/// intentionally share these values so later visual tuning stays in sync.
abstract final class BookkeepingCardStyle {
  static const double outerRadius = 20;
  static const EdgeInsets outerPadding = EdgeInsets.fromLTRB(12, 10, 12, 12);

  static const double noteHeight = 40;
  static const double compactActionHeight = 36;
  static const double amountHeight = 58;
  static const double chipHeight = 40;

  static const double sectionGap = 10;
  static const double rowGap = 8;
  static const double inlineGap = 6;
  static const double compactInlineGap = 4;

  static const double amountHorizontalPadding = 14;
  static const double amountRadius = 20;

  static const Color amountBackground = Color(0xFFF3F3F3);
}
