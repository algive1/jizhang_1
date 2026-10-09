import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme_definition.dart';

/// Change the backdrop without replacing the Navigator or its page state.
class AppAppearanceBackground extends StatelessWidget {
  const AppAppearanceBackground({required this.child, super.key});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final dark = theme.brightness == Brightness.dark;
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: RepaintBoundary(
            child: dark
                ? const AppPageBackground(child: SizedBox.expand())
                : DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          theme.scaffoldBackgroundColor,
                          Color.alphaBlend(
                            scheme.primary.withValues(alpha: .08),
                            scheme.surface,
                          ),
                          scheme.surface,
                        ],
                        stops: const [0, .52, 1],
                      ),
                    ),
                  ),
          ),
        ),
        Theme(
          data: dark
              ? theme.copyWith(scaffoldBackgroundColor: Colors.transparent)
              : theme,
          child: child,
        ),
      ],
    );
  }
}

/// Shared backdrop behind page content and the floating navigation.
/// Night uses the reference's black base and three HSL glows at intensity 50.
/// [AppThemeMaterial.pageTint] preserves the original theme hue independently
/// of the brighter foreground accent. Day keeps its existing composition.
class AppPageBackground extends StatelessWidget {
  const AppPageBackground({
    required this.child,
    this.solidDay = false,
    super.key,
  });

  final Widget child;
  final bool solidDay;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = isDark ? Colors.black : theme.scaffoldBackgroundColor;
    final tint =
        theme.extension<AppThemeMaterial>()?.pageTint ?? colors.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        gradient: isDark || solidDay
            ? null
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  base,
                  Color.alphaBlend(
                    colors.primary.withValues(alpha: .055),
                    colors.surface,
                  ),
                  base,
                ],
                stops: const [0, .52, 1],
              ),
      ),
      child: CustomPaint(
        painter: !isDark && solidDay
            ? null
            : _MeshGlowPainter(colors: colors, isDark: isDark, tint: tint),
        child: child,
      ),
    );
  }
}

/// The three-glow mesh on top of [AppPageBackground]'s base gradient.
class _MeshGlowPainter extends CustomPainter {
  const _MeshGlowPainter({
    required this.colors,
    required this.isDark,
    required this.tint,
  });

  final ColorScheme colors;
  final bool isDark;
  final Color tint;

  /// Glow centres and radius factors, ported from the reference app's
  /// recovered decoration: lower-left, upper-right, upper-left. Alignment
  /// units (`-1..1`) so they scale with any surface, and radius factors
  /// relative to the shorter side.
  static const List<(Alignment, double)> _glows = [
    (Alignment(-.3, 1.15), 1.05),
    (Alignment(1.05, -.05), 1.10),
    (Alignment(-.85, -.85), 1.18),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final glowColors = _glowColors();
    final shortest = math.min(size.width, size.height);

    for (var index = 0; index < _glows.length; index++) {
      final (alignment, radiusFactor) = _glows[index];
      // Flutter Alignment and canvas both count y downwards. Preserve the
      // existing daytime composition; night follows the reference positions.
      final focal = isDark
          ? alignment.alongSize(size)
          : Offset(
              (alignment.x + 1) / 2 * size.width,
              (1 - alignment.y) / 2 * size.height,
            );
      final radius = shortest * radiusFactor;
      final color = glowColors[index];
      canvas.drawCircle(
        focal,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [color, color.withValues(alpha: 0)],
            stops: const [0, 1],
          ).createShader(Rect.fromCircle(center: focal, radius: radius)),
      );
    }
  }

  /// One glow colour per centre, each pulled from the scheme's own palette
  /// and pushed away from the base so it reads as a soft wash.
  List<Color> _glowColors() {
    if (isDark) {
      final hsl = HSLColor.fromColor(tint);
      if (hsl.saturation < .08) {
        final strength = tint.computeLuminance() > .5 ? .18 : .08;
        return [
          tint.withValues(alpha: strength * .55 * .48),
          tint.withValues(alpha: strength * .55 * .72),
          tint.withValues(alpha: strength * .92),
        ];
      }
      Color glow(
        double hue,
        double minS,
        double maxS,
        double minL,
        double maxL,
        double alpha,
      ) => hsl
          .withHue((hsl.hue + hue) % 360)
          .withSaturation(hsl.saturation.clamp(minS, maxS))
          .withLightness(hsl.lightness.clamp(minL, maxL))
          .toColor()
          .withValues(alpha: alpha);
      // Default saved intensity 50: bottom, right, then upper-left.
      return [
        glow(-22, .50, .82, .30, .44, .1152),
        glow(28, .58, .88, .34, .48, .1728),
        glow(0, .68, .95, .38, .52, .2944),
      ];
    }
    return [
      // Lower-left: the soft container tone, almost achromatic. Sits lowest
      // on the surface, right where the glass bar floats — this is the wash
      // the bar actually bends.
      _wash(colors.primaryContainer, lightness: .88, saturation: .34),
      // Upper-right: the primary hue, the strongest of the three.
      _wash(colors.primary, lightness: .84, saturation: .46),
      // Upper-left: surface lift.
      _wash(colors.surface, lightness: .96, saturation: .14),
    ];
  }

  Color _wash(
    Color color, {
    required double lightness,
    required double saturation,
  }) {
    final hsl = HSLColor.fromColor(color);
    return hsl
        .withLightness(lightness.clamp(0, 1))
        .withSaturation(saturation.clamp(0, 1))
        .toColor()
        .withValues(alpha: isDark ? .70 : .85);
  }

  @override
  bool shouldRepaint(covariant _MeshGlowPainter oldDelegate) =>
      oldDelegate.isDark != isDark ||
      oldDelegate.tint != tint ||
      oldDelegate.colors.primary != colors.primary ||
      oldDelegate.colors.primaryContainer != colors.primaryContainer ||
      oldDelegate.colors.surface != colors.surface ||
      oldDelegate.colors.surfaceContainerHighest !=
          colors.surfaceContainerHighest;
}
