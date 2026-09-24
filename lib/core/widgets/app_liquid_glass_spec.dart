import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../app/theme/app_theme_tokens.dart';

/// One source of truth for the optical material used by the app's floating
/// navigation, docked action, and reusable liquid-glass components.
///
/// Geometry is intentionally supplied by each component. Tint, blur,
/// refraction, chromatic aberration, rim lighting, shadows, and accessibility
/// fallback stay shared so a card/tab/button cannot slowly drift into a
/// different "glass-like" material.
abstract final class AppLiquidGlassSpec {
  static const double capsuleBlurSigma = 5;
  static const double capsuleDistortion = .06;
  static const double capsuleDistortionWidth = 26;
  static const double capsuleChromaticAberration = .003;

  static const double actionBlurSigma = 4;
  static const double actionDistortion = .06;
  static const double actionDistortionWidth = 26;
  static const double actionChromaticAberration = .002;

  static const double selectedInkFactor = .90;
  static const double unselectedInkFactor = .84;

  static const double tabGrowHeight = 9;
  static const double tabTravelStiffness = 280;
  static const double tabTravelDamping = 31.4;

  /// Shared pale white tint used by both the navigation capsule and FAB.
  static Color capsuleTint() => Colors.white.withValues(alpha: .24);

  static Color selectedEmphasisFor(
    ColorScheme scheme, {
    required bool liquidGlass,
  }) =>
      liquidGlass
          ? Color.lerp(scheme.secondary, scheme.primary, .4)!
          : darken(scheme.secondary, selectedInkFactor);

  static Color darken(Color color, double factor) => Color.from(
        alpha: color.a,
        red: color.r * factor,
        green: color.g * factor,
        blue: color.b * factor,
      );

  /// Navigation-grade glass. Cards and tab capsules use this exact optical
  /// recipe; only their corner radius changes with geometry.
  static LiquidGlassStyle capsuleStyle(
    BuildContext context, {
    required double cornerRadius,
  }) {
    final highContrast = MediaQuery.highContrastOf(context);
    return LiquidGlassTabBar.defaultStyle.copyWith(
      shape: LiquidGlassShape.roundedRectangle(
        cornerRadius: cornerRadius,
        borderWidth: highContrast ? 1.4 : .9,
        borderColor: highContrast
            ? context.appPrimary.withValues(alpha: .34)
            : Colors.white.withValues(alpha: .42),
        lightIntensity: 1.1,
        lightColor: const Color(0xCCFFFFFF),
        lightDirection: 62,
        borderType: const OpticalBorder(
          borderSaturation: 1.2,
          ambientIntensity: 1.0,
          borderSolidity: .55,
          lightSpread: .5,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: highContrast ? const Color(0xFFF7FAFF) : capsuleTint(),
        blur: LiquidGlassBlur(
          sigmaX: highContrast ? 8 : capsuleBlurSigma,
          sigmaY: highContrast ? 8 : capsuleBlurSigma,
        ),
        shadow: const LiquidGlassShadow(blur: 14, opacity: .18, inset: 0),
      ),
      refraction: highContrast
          ? const LiquidGlassRefraction(
              distortion: 0,
              distortionWidth: 0,
              chromaticAberration: 0,
            )
          : const LiquidGlassRefraction(
              distortion: capsuleDistortion,
              distortionWidth: capsuleDistortionWidth,
              chromaticAberration: capsuleChromaticAberration,
            ),
    );
  }

  /// FAB-grade glass. Generic single buttons use this exact material while
  /// deriving their own pill/circle radius from their geometry.
  static LiquidGlassStyle actionStyle(
    BuildContext context, {
    required double cornerRadius,
  }) {
    return LiquidGlassStyle(
      shape: LiquidGlassShape.roundedRectangle(
        cornerRadius: cornerRadius,
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
        color: capsuleTint(),
        blur: const LiquidGlassBlur(
          sigmaX: actionBlurSigma,
          sigmaY: actionBlurSigma,
        ),
        shadow: LiquidGlassShadow(
          color: Colors.black.withValues(alpha: .22),
          blur: 14,
          opacity: .3,
          offset: const Offset(0, 5),
        ),
      ),
      refraction: const LiquidGlassRefraction(
        distortion: actionDistortion,
        distortionWidth: actionDistortionWidth,
        chromaticAberration: actionChromaticAberration,
      ),
    );
  }

  /// The exact settled selection layer used by the navigation bar.
  static LiquidGlassStyle tabRestStyle(
    BuildContext context, {
    required double cornerRadius,
  }) {
    final highContrast = MediaQuery.highContrastOf(context);
    final restFill = highContrast
        ? const Color(0xFFDCE8FF)
        : const Color(0xFF333333).withValues(alpha: .03);

    return LiquidGlassStyle(
      shape: LiquidGlassShape.roundedRectangle(
        cornerRadius: cornerRadius,
        borderWidth: .7,
        borderColor: Colors.white.withValues(alpha: .55),
      ),
      appearance: LiquidGlassAppearance(color: restFill),
    );
  }

  /// The package's own moving selection glass. The app navigation deliberately
  /// leaves [LiquidGlassTabPillStyle.glassStyle] null, so this resolved style
  /// is the exact material it uses while the pill is travelling.
  static LiquidGlassStyle movingTabStyle() =>
      const LiquidGlassTabPillStyle().effectiveGlass;

  static LiquidGlassTabPillStyle tabPillStyle(
    BuildContext context, {
    required double cornerRadius,
  }) {
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    return LiquidGlassTabPillStyle(
      mode: LiquidGlassPillMode.impellerOnly,
      growHeight: tabGrowHeight,
      distortion: .04,
      distortionWidth: 12,
      magnification: 1,
      travelStiffness: tabTravelStiffness,
      travelDamping: tabTravelDamping,
      animated: !animationsDisabled,
      rest: tabRestStyle(context, cornerRadius: cornerRadius),
      magnifierPill: const LiquidGlassTabMagnifierPillStyle(
        enabled: true,
        magnification: .87,
      ),
      motion: const LiquidGlassLensMotionSpec(
        sampleWindow: .3,
        sensitivity: .00007,
        maxDeformation: .12,
        responseTime: .18,
      ),
    );
  }
}
