import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

/// The frosted card material shared with the liquid-glass profile page.
class AppProfileGlassCard extends StatelessWidget {
  const AppProfileGlassCard({
    required this.child,
    required this.padding,
    super.key,
    this.opacity = .56,
    this.blurSigma = 5,
    this.borderHighlight = .72,
    this.shadowStrength = .12,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double opacity;
  final double blurSigma;
  final double borderHighlight;
  final double shadowStrength;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(dark ? 16 : 22);
    final opacity = highContrast
        ? .88
        : (this.opacity + (dark ? .04 : 0)).clamp(.34, .90).toDouble();
    final highlight = (borderHighlight * (highContrast ? 1.15 : 1))
        .clamp(0.0, 1.0)
        .toDouble();

    Widget surface = CustomPaint(
      foregroundPainter: dark
          ? null
          : _GlassBorderPainter(radius: 22, highlight: highlight, dark: dark),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: radius,
          color: dark
              ? (highContrast
                    ? context.appSurface
                    : Colors.white.withValues(alpha: .10))
              : null,
          border: dark
              ? Border.all(color: Colors.white.withValues(alpha: .24))
              : null,
          gradient: dark
              ? null
              : LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.white.withValues(
                      alpha: (opacity + (dark ? .02 : .16))
                          .clamp(0.0, .96)
                          .toDouble(),
                    ),
                    context.appSurface.withValues(alpha: opacity),
                    context.appSurface.withValues(
                      alpha: (opacity - .07).clamp(.28, .90).toDouble(),
                    ),
                  ],
                  stops: const [0, .44, 1],
                ),
        ),
        child: Padding(
          padding: padding,
          child: Material(
            type: MaterialType.transparency,
            textStyle: DefaultTextStyle.of(context).style,
            child: child,
          ),
        ),
      ),
    );

    if (blurSigma > .01 && !highContrast) {
      surface = BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(
          sigmaX: blurSigma,
          sigmaY: blurSigma,
          tileMode: TileMode.decal,
        ),
        child: surface,
      );
    }

    return Container(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: shadowStrength <= .001
            ? null
            : [
                BoxShadow(
                  color: Colors.black.withValues(
                    alpha: shadowStrength * (dark ? 1.25 : 1),
                  ),
                  blurRadius: 22,
                  spreadRadius: -5,
                  offset: const Offset(0, 8),
                ),
              ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: Clip.antiAlias,
        child: surface,
      ),
    );
  }
}

class _GlassBorderPainter extends CustomPainter {
  const _GlassBorderPainter({
    required this.radius,
    required this.highlight,
    required this.dark,
  });

  final double radius;
  final double highlight;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || highlight <= .001) return;
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(.65),
      Radius.circular((radius - .65).clamp(0.0, radius).toDouble()),
    );
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.05
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Colors.white.withValues(alpha: highlight * (dark ? .50 : .82)),
          const Color(0xFFFFF1DF).withValues(alpha: highlight * .48),
          Colors.white.withValues(alpha: highlight * .15),
          Colors.black.withValues(alpha: highlight * (dark ? .22 : .08)),
        ],
        stops: const [0, .28, .72, 1],
      ).createShader(rect);
    canvas.drawRRect(rrect, paint);

    final topGlow = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .55
      ..color = Colors.white.withValues(alpha: highlight * .34);
    canvas.drawRRect(rrect.deflate(1.05), topGlow);
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.highlight != highlight ||
      oldDelegate.dark != dark;
}
