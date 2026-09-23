import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../app/theme/app_theme_tokens.dart';

/// The docked "记一笔" action button.
///
/// Built on the package's own **`LiquidGlassFab`** — the same primitive the
/// reference app pairs with its tab bar — rather than a hand-rolled circle.
///
/// ## Keeping the green *and* the glass
///
/// A flat opaque green circle sitting on a refracting glass bar reads as a
/// sticker dropped on top of it: it shares neither the material nor the
/// lighting, which is what made it look out of place.
///
/// `LiquidGlassFab` takes a whole [LiquidGlassStyle], so the button keeps its
/// accent as a **lens tint** instead of an opaque fill. The shader composes
/// that tint as
///
/// ```
/// mix(refractedBackdrop, lensColor.rgb, lensColor.a * rimFalloff * mask)
/// ```
///
/// which makes `lensColor.a` exactly the colour-versus-glass dial — so the
/// tint is passed **semi-transparent**, leaving the refracted backdrop (and
/// its variation) alive underneath. Everything that reads as *glass* is
/// composited independently of it, on top:
///
///  * the **edge refraction band** and its faint chromatic split, strongest
///    at the silhouette — so the rim visibly bends the page;
///  * the **optical rim highlight**, whose angular response follows
///    [LiquidGlassShape.lightDirection];
///  * the **contact shadow**, which lifts it clear of the bar.
///
/// So alpha buys colour and costs only *interior* refraction. At
/// [glassTintAlpha] the button is unmistakably the brand accent while the
/// rim, the bend and the shadow still land.
class QuickAddButton extends StatelessWidget {
  const QuickAddButton({
    required this.onPressed,
    required this.onLongPress,
    super.key,
    this.diameter = defaultDiameter,
  });

  static const double defaultDiameter = 62;

  /// How much of the interior is the brand colour rather than the refracted
  /// backdrop. High enough that the button stays the accent; low enough that
  /// the rim band and the bend still read.
  static const double glassTintAlpha = .76;

  /// Refraction strength, slightly softer than the navigation capsule's: the
  /// button's silhouette is a circle a third of the bar's height, so the
  /// capsule's 26 px band would swamp it.
  static const double refractionDistortion = .06;
  static const double refractionWidth = 26;

  final VoidCallback onPressed;
  final VoidCallback onLongPress;
  final double diameter;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final primary = context.appPrimary;

    // High contrast drops transparency outright rather than softening it, per
    // the project's accessibility contract, so it gets the opaque button.
    //
    // Deliberately **not** gated on `appUsesLiquidGlass`: this button sits on
    // the glass navigation bar, which every theme now runs (see
    // `app_bottom_navigation.dart`). A solid-accent button on a glass bar is
    // the mismatch this whole widget exists to avoid, and the tint comes from
    // the active theme either way, so the accent still follows the theme.
    if (highContrast) {
      return _SolidAction(
        diameter: diameter,
        color: primary,
        onPressed: onPressed,
        onLongPress: onLongPress,
      );
    }

    // The tint is handed over **semi-transparent**, not pre-blended into an
    // opaque colour. `Color.alphaBlend` against an opaque surface would
    // return alpha 1.0, and the shader's
    // `mix(refractedBackdrop, lensColor.rgb, lensColor.a * …)` would then have
    // nothing left to mix — the interior would be flat paint and the button
    // would stop being glass. Carrying the alpha through keeps the refracted
    // backdrop (and its variation) underneath the accent.
    final tint = primary.withValues(alpha: glassTintAlpha);

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
          // The glyph stays white for contrast against the accent fill; the
          // library's default would be white anyway, but pinning it keeps the
          // button independent of any adaptivity verdict.
          foregroundColor: Colors.white,
          iconSize: diameter * .58,
          padding: EdgeInsets.zero,
          style: LiquidGlassStyle(
            shape: LiquidGlassShape.roundedRectangle(
              cornerRadius: diameter / 2,
              borderWidth: 1,
              lightIntensity: 1.2,
              lightColor: const Color(0xE6FFFFFF),
              lightDirection: 80,
              borderType: const OpticalBorder(
                borderSaturation: 1.3,
                ambientIntensity: 1.0,
                borderSolidity: .45,
                lightSpread: .5,
              ),
            ),
            appearance: LiquidGlassAppearance(
              color: tint,
              blur: const LiquidGlassBlur(sigmaX: 4, sigmaY: 4),
              shadow: LiquidGlassShadow(
                color: primary.withValues(alpha: .38),
                blur: 14,
                opacity: .5,
                offset: const Offset(0, 5),
              ),
            ),
            refraction: const LiquidGlassRefraction(
              distortion: refractionDistortion,
              distortionWidth: refractionWidth,
              chromaticAberration: .002,
            ),
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
