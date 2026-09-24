import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../app/theme/app_theme_tokens.dart';
import 'app_bottom_navigation.dart';
import 'app_liquid_glass_spec.dart';

/// The docked "记一笔" action button.
///
/// Built on the package's own **`LiquidGlassFab`** — the same primitive the
/// reference app pairs with its tab bar — rather than a hand-rolled circle.
///
/// Its translucent fill matches the active navigation capsule, and the plus
/// glyph uses the same selected accent as the navigation items. Shape,
/// refraction and rim lighting keep it visibly made of glass.
class QuickAddButton extends StatelessWidget {
  const QuickAddButton({
    required this.onPressed,
    required this.onLongPress,
    super.key,
    this.diameter = defaultDiameter,
  });

  static const double defaultDiameter = 62;

  /// Refraction strength, slightly softer than the navigation capsule's: its
  /// circular silhouette is close to the bar's height, so the capsule's 26 px
  /// band would dominate it.
  static const double refractionDistortion = AppLiquidGlassSpec.actionDistortion;
  static const double refractionWidth = AppLiquidGlassSpec.actionDistortionWidth;

  final VoidCallback onPressed;
  final VoidCallback onLongPress;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final primary = context.appPrimary;
    final scheme = context.appColors;
    final liquidGlass = context.appUsesLiquidGlass;

    // High contrast drops transparency outright rather than softening it, per
    // the project's accessibility contract, so it gets the opaque button.
    //
    if (highContrast) {
      return _SolidAction(
        diameter: diameter,
        color: primary,
        onPressed: onPressed,
        onLongPress: onLongPress,
      );
    }

    final foreground = AppBottomNavigation.selectedEmphasisFor(
      scheme,
      liquidGlass: liquidGlass,
    );

    return GestureDetector(
      // `LiquidGlassFab` owns tap; the long press (voice bookkeeping) is ours.
      onLongPress: onLongPress,
      child: Semantics(
        button: true,
        label: '记一笔',
        child: LiquidGlassFab(
          icon: Icons.add,
          onPressed: onPressed,
          size: diameter,
          foregroundColor: foreground,
          iconSize: diameter * .58,
          padding: EdgeInsets.zero,
          style: AppLiquidGlassSpec.actionStyle(
            context,
            cornerRadius: diameter / 2,
          ),
        ),
      ),
    );
  }
}

/// The opaque fallback: solid accent fill, white glyph, hairline rim.
class _SolidAction extends StatelessWidget {
  const _SolidAction({
    required this.diameter,
    required this.color,
    required this.onPressed,
    required this.onLongPress,
  });

  final double diameter;
  final Color color;
  final VoidCallback onPressed;
  final VoidCallback onLongPress;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onLongPress: onLongPress,
      child: Semantics(
        button: true,
        label: '记一笔',
        onTap: onPressed,
        child: DecoratedBox(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: color.withValues(alpha: .28),
                blurRadius: 13,
                offset: const Offset(0, 5),
              ),
            ],
          ),
          child: Material(
            color: color,
            shape: const CircleBorder(
              side: BorderSide(color: Color(0xA6FFFFFF)),
            ),
            child: InkWell(
              customBorder: const CircleBorder(),
              onTap: onPressed,
              child: SizedBox(
                width: diameter,
                height: diameter,
                child: Icon(
                  Icons.add,
                  size: diameter * .6,
                  color: Colors.white,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
