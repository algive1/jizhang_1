import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/app/theme/app_theme_tokens.dart';
import 'package:jizhang_app/core/widgets/quick_add_button.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// The docked "记一笔" button is the one element sitting **on** the glass bar,
/// so it has to belong to the same material family without losing the brand
/// accent.
void main() {
  Future<void> pump(
    WidgetTester tester, {
    required AppThemeDefinition theme,
    bool highContrast = false,
  }) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(theme),
        home: Builder(
          builder: (context) {
            // `copyWith` rather than a bare `MediaQueryData()`: a fresh one
            // drops padding/viewInsets and the theme tokens read through it.
            final media = MediaQuery.of(context).copyWith(
              highContrast: highContrast,
            );
            return MediaQuery(
              data: media,
              child: Scaffold(
                body: Center(
                  child: QuickAddButton(
                    onPressed: () {},
                    onLongPress: () {},
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('the glass button is a tinted liquid-glass lens', (tester) async {
    await pump(tester, theme: BuiltInThemes.freshGreen);

    final fab = tester.widget<LiquidGlassFab>(find.byType(LiquidGlassFab));
    final style = fab.style!;

    // It must actually refine the backdrop, not just draw a tinted circle.
    expect(style.refraction.distortion, greaterThan(0));
    expect(style.refraction.distortionWidth, greaterThan(0));
    expect(style.appearance.blur.sigmaX, greaterThan(0));
    expect(fab.size, QuickAddButton.defaultDiameter);
    final shadow = style.appearance.shadow;
    expect(shadow, isNotNull);
    expect(shadow!.blur, greaterThan(0));
    expect(shadow.opacity, greaterThan(0));
    expect(shadow.color, Colors.black.withValues(alpha: .22));
    expect(shadow.offset, const Offset(0, 5));

    // The fill and plus glyph share the capsule tint and selected ink used by
    // navigation; both stay semitransparent/colored over the live backdrop.
    final context = tester.element(find.byType(LiquidGlassFab));
    final scheme = context.appColors;
    expect(
      style.appearance.color,
      Colors.white.withValues(alpha: .24),
    );
    expect(
      fab.foregroundColor,
      _darken(scheme.secondary, .90),
      reason: 'the plus glyph should match the navigation selected accent',
    );
    expect(
      style.appearance.color.a,
      lessThan(1),
      reason: 'a fully opaque fill would stop being glass',
    );

    // An optical rim is what makes it read as glass rather than flat paint.
    expect(style.shape, isNotNull);
    expect(style.shape!.borderType, isNot(isNull));
  });

  testWidgets('the FAB shares navigation colors across all themes', (
    tester,
  ) async {
    final fills = <int, Color>{};
    final foregrounds = <int, Color>{};
    for (final theme in BuiltInThemes.all) {
      // A fresh tree per theme: an in-place theme swap keeps resolving the
      // first theme it saw.
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, theme: theme);
      final fab = tester.widget<LiquidGlassFab>(find.byType(LiquidGlassFab));
      final scheme = AppTheme.light(theme).colorScheme;
      final expectedFill = Colors.white.withValues(alpha: .24);
      final expectedForeground = theme.style == AppThemeStyle.liquidGlass
          ? Color.lerp(scheme.secondary, scheme.primary, .4)!
          : _darken(scheme.secondary, .90);
      final actualFill = fab.style!.appearance.color;
      final actualForeground = fab.foregroundColor!;
      final composedFill = _blend(expectedFill, theme.background);

      expect(actualFill, expectedFill, reason: '${theme.id} fill matches nav');
      expect(
        actualForeground,
        expectedForeground,
        reason: '${theme.id} glyph matches nav selected ink',
      );
      expect(
        _contrast(actualForeground, composedFill),
        greaterThanOrEqualTo(3),
        reason: '${theme.id} plus glyph must clear 3:1 on the glass fill',
      );
      fills[actualFill.toARGB32()] = actualFill;
      foregrounds[actualForeground.toARGB32()] = actualForeground;
    }
    expect(
      fills.length,
      1,
      reason: 'all themes must use the same white glass fill',
    );
    expect(
      foregrounds.length,
      BuiltInThemes.all.length,
      reason: 'each theme must give the plus glyph its own accent',
    );
  });

  testWidgets('high contrast falls back to an opaque accent button', (
    tester,
  ) async {
    await pump(tester, theme: BuiltInThemes.freshGreen, highContrast: true);

    // No glass at all in high contrast: the contract is to drop transparency
    // rather than merely soften it.
    expect(find.byType(LiquidGlassFab), findsNothing);
    expect(find.byType(LiquidGlassLens), findsNothing);

    final material = tester.widget<Material>(
      find.descendant(
        of: find.byType(QuickAddButton),
        matching: find.byType(Material),
      ),
    );
    expect(material.color, BuiltInThemes.freshGreen.primary);
    expect(
      tester.widget<Icon>(find.byIcon(Icons.add)).color,
      Colors.white,
    );
  });

  testWidgets('tapping and long-pressing reach their callbacks', (
    tester,
  ) async {
    var taps = 0;
    var longPresses = 0;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(BuiltInThemes.freshGreen),
        home: Scaffold(
          body: Center(
            child: QuickAddButton(
              onPressed: () => taps++,
              onLongPress: () => longPresses++,
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.byType(QuickAddButton));
    await tester.pump();
    expect(taps, 1);

    await tester.longPress(find.byType(QuickAddButton));
    await tester.pump();
    expect(longPresses, 1);
  });
}

Color _darken(Color color, double factor) => Color.from(
      alpha: color.a,
      red: color.r * factor,
      green: color.g * factor,
      blue: color.b * factor,
    );

Color _blend(Color foreground, Color background) => Color.from(
      alpha: 1,
      red: foreground.r * foreground.a + background.r * (1 - foreground.a),
      green: foreground.g * foreground.a + background.g * (1 - foreground.a),
      blue: foreground.b * foreground.a + background.b * (1 - foreground.a),
    );

double _contrast(Color foreground, Color background) {
  final foregroundLuminance = foreground.computeLuminance();
  final backgroundLuminance = background.computeLuminance();
  final lighter = math.max(foregroundLuminance, backgroundLuminance);
  final darker = math.min(foregroundLuminance, backgroundLuminance);
  return (lighter + .05) / (darker + .05);
}
