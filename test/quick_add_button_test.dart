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

    // …and it must keep the brand accent: the tint *is* the theme's primary,
    // carried semi-transparently so the shader still has a backdrop to mix
    // into. Pre-blending it opaque would leave `mix()` nothing to do and the
    // interior would be flat paint.
    final context = tester.element(find.byType(LiquidGlassFab));
    expect(
      style.appearance.color,
      context.appPrimary.withValues(alpha: QuickAddButton.glassTintAlpha),
    );
    expect(
      style.appearance.color.a,
      greaterThanOrEqualTo(.7),
      reason: 'the button must stay the brand accent, not wash out to glass',
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

  testWidgets('the tint follows the theme, so the accent is never stale', (
    tester,
  ) async {
    final tints = <int, Color>{};
    for (final theme in BuiltInThemes.all) {
      // A fresh tree per theme: an in-place theme swap keeps resolving the
      // first theme it saw.
      await tester.pumpWidget(const SizedBox.shrink());
      await pump(tester, theme: theme);
      final fab = tester.widget<LiquidGlassFab>(find.byType(LiquidGlassFab));
      tints[theme.primary.toARGB32()] = fab.style!.appearance.color;
    }
    expect(tints.length, BuiltInThemes.all.length);
    expect(
      tints.values.toSet().length,
      BuiltInThemes.all.length,
      reason: 'each theme must tint the button with its own accent',
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
