import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';

/// Navigation-layer liquid glass.
///
/// The shader path adds a small lens bend and a five-tap softening pass to the
/// backdrop. Skia and platforms without shader image-filter support use the
/// same geometry and tint with a normal BackdropFilter blur.
class AppLiquidGlassSurface extends StatefulWidget {
  const AppLiquidGlassSurface({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.borderRadius = 30,
    this.tint,
    this.shadow = true,
    this.clipBehavior = Clip.antiAlias,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? tint;
  final bool shadow;
  final Clip clipBehavior;

  @override
  State<AppLiquidGlassSurface> createState() => _AppLiquidGlassSurfaceState();
}

class _AppLiquidGlassSurfaceState extends State<AppLiquidGlassSurface> {
  late final Future<ui.FragmentProgram?> _program = _loadProgram();

  Future<ui.FragmentProgram?> _loadProgram() async {
    if (!ui.ImageFilter.isShaderFilterSupported) return null;
    try {
      return await ui.FragmentProgram.fromAsset('shaders/liquid_glass.frag');
    } catch (_) {
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<ui.FragmentProgram?>(
      future: _program,
      builder: (context, snapshot) {
        return _buildSurface(context, snapshot.data);
      },
    );
  }

  Widget _buildSurface(BuildContext context, ui.FragmentProgram? program) {
    final material = context.appMaterial;
    final highContrast = MediaQuery.highContrastOf(context);
    final radius = BorderRadius.circular(widget.borderRadius);
    final tint = widget.tint ?? context.appSurface;
    final blurSigma = highContrast
        ? material.blurSigma * .62
        : material.blurSigma;
    final filter = program != null && ui.ImageFilter.isShaderFilterSupported
        ? ui.ImageFilter.shader(program.fragmentShader())
        : ui.ImageFilter.blur(
            sigmaX: blurSigma,
            sigmaY: blurSigma,
            tileMode: TileMode.decal,
          );

    return Container(
      margin: widget.margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: widget.shadow
            ? [
                BoxShadow(
                  color: context.appPrimary.withValues(alpha: .16),
                  blurRadius: highContrast ? 12 : 20,
                  spreadRadius: -5,
                  offset: const Offset(0, 8),
                ),
                BoxShadow(
                  color: Colors.white.withValues(alpha: .32),
                  blurRadius: 2,
                  spreadRadius: -1,
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: radius,
        clipBehavior: widget.clipBehavior,
        child: Stack(
          fit: StackFit.passthrough,
          children: [
            Positioned.fill(
              child: BackdropFilter(
                filter: filter,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Colors.white.withValues(
                          alpha: highContrast ? .46 : .30,
                        ),
                        Color.alphaBlend(
                          context.appPrimary.withValues(alpha: .035),
                          tint,
                        ).withValues(alpha: highContrast ? .34 : .20),
                        tint.withValues(alpha: highContrast ? .28 : .13),
                      ],
                      stops: const [0, .48, 1],
                    ),
                  ),
                ),
              ),
            ),
            CustomPaint(
              foregroundPainter: _LiquidGlassChromePainter(
                radius: widget.borderRadius,
                primary: context.appPrimary,
                highContrast: highContrast,
              ),
              child: Padding(
                padding: widget.padding ?? EdgeInsets.zero,
                child: widget.child,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LiquidGlassChromePainter extends CustomPainter {
  const _LiquidGlassChromePainter({
    required this.radius,
    required this.primary,
    required this.highContrast,
  });

  final double radius;
  final Color primary;
  final bool highContrast;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;

    final rect = Offset.zero & size;
    final outer = RRect.fromRectAndRadius(
      rect.deflate(1),
      Radius.circular((radius - 1).clamp(0, radius).toDouble()),
    );
    final border = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = highContrast ? 1.4 : 1
      ..color = Colors.white.withValues(alpha: highContrast ? .94 : .78);
    canvas.drawRRect(outer, border);

    final topHighlight = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = highContrast ? 1.5 : 1.15
      ..color = Colors.white.withValues(alpha: highContrast ? .82 : .52);
    final highlightPath = Path()
      ..moveTo(radius * .78, 2.2)
      ..cubicTo(
        size.width * .34,
        1.2,
        size.width * .56,
        1.2,
        size.width - radius * .78,
        2.2,
      );
    canvas.drawPath(highlightPath, topHighlight);

    final lowerRim = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = .85
      ..color = primary.withValues(alpha: highContrast ? .26 : .14);
    canvas.drawRRect(outer.deflate(.8), lowerRim);
  }

  @override
  bool shouldRepaint(covariant _LiquidGlassChromePainter oldDelegate) =>
      oldDelegate.radius != radius ||
      oldDelegate.primary != primary ||
      oldDelegate.highContrast != highContrast;
}
