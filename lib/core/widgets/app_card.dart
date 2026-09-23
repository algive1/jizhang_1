import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';
import 'app_glass_surface.dart';

enum AppCardMaterial { content, frosted }

class AppCard extends StatelessWidget {
  const AppCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.color,
    this.borderRadius = 24,
    this.border,
    this.material = AppCardMaterial.content,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final double borderRadius;
  final Border? border;
  final AppCardMaterial material;

  @override
  Widget build(BuildContext context) {
    if (material == AppCardMaterial.content) {
      final tint = color ?? context.appSurface;
      return Container(
        padding: padding,
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: context.appUsesLiquidGlass
              ? tint.withValues(alpha: .96)
              : tint,
          borderRadius: BorderRadius.circular(borderRadius),
          border: border ?? Border.all(color: context.appDivider),
          boxShadow: const [
            BoxShadow(
              color: Color(0x12000000),
              blurRadius: 16,
              offset: Offset(0, 6),
            ),
          ],
        ),
        child: child,
      );
    }

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
