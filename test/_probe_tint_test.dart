// TEMPORARY probe — per-theme plate tint + ink gates. Delete after use.
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';

double _lum(Color c) {
  double ch(double v) =>
      v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * ch(c.r) + .7152 * ch(c.g) + .0722 * ch(c.b);
}

double _contrast(Color a, Color b) {
  final la = _lum(a), lb = _lum(b);
  return (math.max(la, lb) + .05) / (math.min(la, lb) + .05);
}

Color _darken(Color c, double f) =>
    Color.from(alpha: c.a, red: c.r * f, green: c.g * f, blue: c.b * f);

Color _blend(Color fg, Color bg) => Color.from(
      alpha: 1,
      red: fg.r * fg.a + bg.r * (1 - fg.a),
      green: fg.g * fg.a + bg.g * (1 - fg.a),
      blue: fg.b * fg.a + bg.b * (1 - fg.a),
    );

String _hex(Color c) {
  final v = (c.r * 255).round() << 16 | (c.g * 255).round() << 8 | (c.b * 255).round();
  return '#${v.toRadixString(16).padLeft(6, '0')}';
}

void main() {
  test('per-theme plate tint probe', () {
    const alpha = .38;
    for (final hue in <double>[.14, .20, .26]) {
      for (final dark in <double>[.86, .88, .90]) {
        // ignore: avoid_print
        print('=== hue=$hue dark=$dark ===');
        for (final theme in BuiltInThemes.all) {
          final t = AppTheme.light(theme);
          final scheme = t.colorScheme;
          final page = t.canvasColor;
          final toned = Color.alphaBlend(
            scheme.primary.withValues(alpha: hue),
            scheme.surface,
          );
          final fill = _darken(toned, dark).withValues(alpha: alpha);
          final capsule = _blend(fill, page);
          final pill = _blend(scheme.primary.withValues(alpha: .26), capsule);
          final unsel = _darken(scheme.onSurfaceVariant, .84);
          final sel = _darken(scheme.secondary, .80);
          final d = <int>[
            (capsule.r * 255).round() - (page.r * 255).round(),
            (capsule.g * 255).round() - (page.g * 255).round(),
            (capsule.b * 255).round() - (page.b * 255).round(),
          ];
          // ignore: avoid_print
          print('${theme.id.padRight(12)} page=${_hex(page)} fill=${_hex(fill)} '
              'capsule=${_hex(capsule)} step=$d  '
              'unsel(.84)=${_contrast(unsel, capsule).toStringAsFixed(2)}  '
              'sel(.80)=${_contrast(sel, pill).toStringAsFixed(2)}');
        }
      }
    }
  });
}
