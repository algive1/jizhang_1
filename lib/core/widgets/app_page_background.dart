import 'dart:math' as math;

import 'package:flutter/material.dart';

/// The page backdrop every theme paints **behind** its content.
///
/// Glass only ever shows what is painted under it, so a bar sitting on a
/// flat `scaffoldBackgroundColor` refracts a flat colour and reads as a
/// tinted slab no matter how strong the distortion is. The reference app
/// solves this the same way: its `MMGlassPageBackground` returns a
/// decorated box whose decoration is a mesh gradient — one theme base
/// colour plus **three radial glows** — and the navigation bar is just the
/// layer that blurs and bends that already-painted backdrop.
///
/// Colours are derived from the **active `ColorScheme`** rather than from a
/// theme record, so the backdrop follows any theme that reaches the widget
/// tree — the four built-ins, a catalogue theme pushed from the server, or
/// a platform-brightness override — with no per-theme table to keep in
/// sync:
///
///  * the base is the theme's own `scaffoldBackgroundColor`;
///  * the glows tint with `primaryContainer`, `primary` and `surface`.
///
/// The three glows are spread across the whole surface rather than
/// concentrated near the bottom edge, because their job is to give the
/// glass something with **variation** to refract — a gradient that is flat
/// where the bar sits would defeat the point.
class AppPageBackground extends StatelessWidget {
  const AppPageBackground({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final base = Theme.of(context).scaffoldBackgroundColor;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: base,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            base,
            Color.alphaBlend(
              colors.primary.withValues(alpha: isDark ? .12 : .055),
              colors.surface,
            ),
            base,
          ],
          stops: const [0, .52, 1],
        ),
      ),
      child: CustomPaint(
        painter: _MeshGlowPainter(colors: colors, isDark: isDark),
        child: child,
      ),
    );
  }
}

/// The three-glow mesh on top of [AppPageBackground]'s base gradient.
class _MeshGlowPainter extends CustomPainter {
  const _MeshGlowPainter({required this.colors, required this.isDark});

  final ColorScheme colors;
  final bool isDark;

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
      // `Alignment` counts y upwards from the centre, canvas pixels count
      // it downwards, hence the flip.
      final focal = Offset(
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
      // On a dark base the wash has to *lift*, so the glows take the
      // container tones and stay low-alpha.
      return [
        _wash(colors.primaryContainer, lightness: .26, saturation: .34),
        _wash(colors.primary, lightness: .30, saturation: .40),
        _wash(colors.surfaceContainerHighest, lightness: .24, saturation: .16),
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
      oldDelegate.colors.primary != colors.primary ||
      oldDelegate.colors.primaryContainer != colors.primaryContainer ||
      oldDelegate.colors.surface != colors.surface ||
      oldDelegate.colors.surfaceContainerHighest !=
          colors.surfaceContainerHighest;
}
