import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';
import 'app_glass_surface.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderRadius = 24,
    this.border,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double borderRadius;
  final Border? border;

  @override
  Widget build(BuildContext context) {
    return AppGlassSurface(
      padding: padding,
      borderRadius: borderRadius,
      tint: color ?? context.appSurface,
      border: border,
      blurSigma: 12,
      chromaticEdge: false,
      child: child,
    );
  }
}
