import 'package:flutter/material.dart';

/// Home / quick-entry visual contract; see docs/development/UI_HOME_SPEC.md.
abstract final class FinanceUi {
  static const ink = Color(0xFF14263C);
  static const muted = Color(0xFF8192A8);
  static const teal = Color(0xFF00AD9C);
  static const tealDark = Color(0xFF087E76);
  static const mint = Color(0xFFE6F8F3);
  static const line = Color(0xFFEDF2F5);
  static const coral = Color(0xFFFF7585);
  static const cardRadius = 24.0;
  static const motion = Duration(milliseconds: 280);
  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF04B5AB), Color(0xFF49CEC6), Color(0xFFB7F1DD)],
  );
  static const canvasGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE7F9F5), Color(0xFFF6FBFD), Color(0xFFFAF7EF)],
    stops: [0, .4, 1],
  );
  static const shadow = BoxShadow(
    color: Color(0x070C6070),
    blurRadius: 22,
    offset: Offset(0, 8),
  );
}
