import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

/// Shared visual material for the liquid-glass theme.
///
/// Solid themes keep the existing opaque surface behavior. Liquid glass uses
/// backdrop blur, a translucent tint, a bright inner highlight and a very
/// subtle chromatic edge so cards, popovers and navigation feel like the same
/// material rather than independent transparency effects.
class AppGlassSurface extends StatelessWidget {
  const AppGlassSurface({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.borderRadius = 24,
    this.tint,
    this.border,
    this.blurSigma,
    this.glassOpacity,
    this.shadow = true,
    this.chromaticEdge = true,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? tint;
  final Border? border;
  final double? blurSigma;

  /// Overrides the opacity of every glass gradient stop. Null preserves the
  /// surface's standard liquid-glass translucency.
  final double? glassOpacity;
  final bool shadow;
  final bool chromaticEdge;
  final Clip clipBehavior;

  @override
  Widget build(BuildContext context) {
    final glass = context.appUsesLiquidGlass;
    final material = context.appMaterial;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(borderRadius);
    final effectiveTint = tint ?? context.appSurface;

    if (!glass) {
      return Container(
        margin: margin,
        padding: padding,
        decoration: BoxDecoration(
          color: effectiveTint,
          borderRadius: radius,
          border: border ?? Border.all(color: context.appDivider),
          boxShadow: shadow
              ? const [
                  BoxShadow(
                    color: Color(0x12000000),
                    blurRadius: 16,
                    offset: Offset(0, 6),
                  ),
                ]
              : null,
        ),
        clipBehavior: clipBehavior,
        child: child,
      );
    }

    final sigma = highContrast
        ? (blurSigma ?? material.blurSigma) * .58
        : (blurSigma ?? material.blurSigma);
    final baseTint = Color.alphaBlend(
      effectiveTint.withValues(alpha: highContrast ? .82 : .62),
      material.glassTint.withValues(alpha: highContrast ? .90 : .72),
    );
    final glassFillOpacity = glassOpacity?.clamp(0.0, 1.0).toDouble();
    Color withGlassOpacity(Color color) => glassFillOpacity == null
        ? color
        : color.withValues(alpha: glassFillOpacity);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadow
            ? [
                BoxShadow(
                  color: context.appPrimary.withValues(
                    alpha: highContrast ? .12 : .10,
                  ),
                  blurRadius: highContrast ? 12 : 22,
                  spreadRadius: -4,
                  offset: const Offset(0, 8),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: clipBehavior,
        child: BackdropFilter(
          filter: ImageFilter.blur(
            sigmaX: sigma,
            sigmaY: sigma,
            tileMode: TileMode.decal,
          ),
          child: CustomPaint(
            foregroundPainter: chromaticEdge
                ? _ChromaticGlassBorderPainter(
                    radius: borderRadius,
                    highContrast: highContrast,
                    primary: context.appPrimary,
                  )
                : null,
            child: Container(
              padding: padding,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    withGlassOpacity(
                      material.glassHighlight.withValues(
                        alpha: highContrast ? .94 : .62,
                      ),
                    ),
                    withGlassOpacity(baseTint),
                    withGlassOpacity(
                      effectiveTint.withValues(
                        alpha: highContrast ? .76 : .48,
                      ),
                    ),
                  ],
                  stops: const [0, .48, 1],
                ),
                borderRadius: radius,
                border:
                    border ??
                    Border.all(
                      color: highContrast
                          ? context.appPrimary.withValues(alpha: .34)
                          : material.glassBorder.withValues(alpha: .74),
                      width: highContrast ? 1.4 : 1,
                    ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}

class _ChromaticGlassBorderPainter extends CustomPainter {
  const _ChromaticGlassBorderPainter({
    required this.radius,
    required this.highContrast,
    required this.primary,
  });

  final double radius;
  final bool highContrast;
  final Color primary;

  @override
  void paint(Canvas canvas, Size size) {
    if (highContrast || size.isEmpty) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(1.2),
      Radius.circular((radius - 1.2).clamp(0, radius).toDouble()),
    );

    final cyan = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.1
      ..shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x665BE8FF),
          Color(0x005BE8FF),
          Color(0x335BE8FF),
        ],
      ).createShader(rect);

    final magenta = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .9
      ..shader = const LinearGradient(
        begin: Alignment.bottomRight,
        end: Alignment.topLeft,
        colors: [
          Color(0x55FF74D4),
          Color(0x00FF74D4),
          Color(0x2EFF74D4),
        ],
      ).createShader(rect);

    final primaryGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .65
      ..color = primary.withValues(alpha: .10);

    canvas.save();
    canvas.translate(-.55, .35);
    canvas.drawRRect(rrect, cyan);
    canvas.restore();

    canvas.save();
    canvas.translate(.55, -.35);
    canvas.drawRRect(rrect, magenta);
    canvas.restore();

    canvas.drawRRect(rrect.deflate(.8), primaryGlow);
  }

  @override
  bool shouldRepaint(covariant _ChromaticGlassBorderPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.highContrast != highContrast ||
      oldDelegate.primary != primary;
}
