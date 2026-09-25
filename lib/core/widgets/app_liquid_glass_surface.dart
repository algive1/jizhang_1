import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../app/theme/app_theme_tokens.dart';

/// Shared refracting surface for the liquid-glass theme.
///
/// Unlike a plain [BackdropFilter], this uses the same live
/// [LiquidGlassLens] engine as the bottom navigation. On Impeller the shader
/// samples the current backdrop at compositing time, so a card that moves in
/// a scroll view keeps its refraction aligned with the content behind it
/// instead of sampling the previous frame.
///
/// Put many sibling surfaces under a [LiquidGlassBatch] so they share a
/// single backdrop read. Nested glass (for example small action tiles inside
/// a glass card) should use its own nested batch so the inner glass can still
/// see the outer surface that has already been painted.
class AppLiquidGlassSurface extends StatelessWidget {
  const AppLiquidGlassSurface({
    required this.child,
    super.key,
    this.padding,
    this.margin,
    this.borderRadius = 30,
    this.tint,
    this.blurSigma,
    this.glassOpacity,
    this.themeColorAccents = true,
    this.shadow = true,
    this.clipBehavior = Clip.antiAlias,
    this.interactive = false,
    this.distortion = .045,
    this.distortionWidth = 22,
    this.chromaticAberration = .0025,
    this.magnification = 1.008,
  })  : assert(glassOpacity == null || (glassOpacity >= 0 && glassOpacity <= 1)),
        assert(distortion >= 0),
        assert(distortionWidth >= 0),
        assert(chromaticAberration >= 0),
        assert(magnification > 0);

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final Color? tint;

  /// Gaussian blur inside the glass. Defaults to the same deliberately light
  /// blur range as the navigation so background structure remains visible.
  final double? blurSigma;

  /// Alpha of the material tint. Refraction is independent of this value.
  final double? glassOpacity;

  /// Adds a small theme-coloured contact shadow. The optical rim itself stays
  /// neutral so every glass surface reads as the same material.
  final bool themeColorAccents;

  final bool shadow;

  /// Retained for the solid-theme fallback. The liquid lens owns its own clip.
  final Clip clipBehavior;

  /// Adds the subtle press/flex response used by small glass controls.
  final bool interactive;

  /// Optical controls. Large cards use the restrained defaults; compact
  /// controls can raise these slightly without forking the render path.
  final double distortion;
  final double distortionWidth;
  final double chromaticAberration;
  final double magnification;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final effectiveTint = tint ?? context.appSurface;
    final radius = BorderRadius.circular(borderRadius);

    if (!context.appUsesLiquidGlass) {
      return Container(
        margin: margin,
        padding: padding,
        clipBehavior: clipBehavior,
        decoration: BoxDecoration(
          color: effectiveTint,
          borderRadius: radius,
          border: Border.all(color: context.appDivider),
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
        child: child,
      );
    }

    final sigma = highContrast ? (blurSigma ?? 5) * 1.6 : (blurSigma ?? 5);
    final tintAlpha = (glassOpacity ?? (highContrast ? .74 : .26))
        .clamp(0.0, 1.0)
        .toDouble();

    final style = LiquidGlassStyle(
      shape: LiquidGlassShape.roundedRectangle(
        cornerRadius: borderRadius,
        borderWidth: highContrast ? 1.4 : .9,
        borderColor: highContrast
            ? context.appPrimary.withValues(alpha: .38)
            : Colors.white.withValues(alpha: .46),
        lightIntensity: highContrast ? 1 : 1.08,
        lightColor: const Color(0xE6FFFFFF),
        lightDirection: 62,
        borderType: const OpticalBorder(
          borderSaturation: 1.16,
          ambientIntensity: .96,
          borderSolidity: .54,
          lightSpread: .48,
        ),
      ),
      appearance: LiquidGlassAppearance(
        color: effectiveTint.withValues(alpha: tintAlpha),
        blur: LiquidGlassBlur(sigmaX: sigma, sigmaY: sigma),
        saturation: highContrast ? 1 : 1.03,
        shadow: shadow
            ? LiquidGlassShadow(
                blur: highContrast ? 3 : 4.5,
                opacity: highContrast ? .16 : .12,
                color: themeColorAccents ? context.appPrimary : Colors.black,
                offset: const Offset(0, 5),
                inset: 1,
              )
            : null,
      ),
      refraction: highContrast
          ? const LiquidGlassRefraction(
              distortion: 0,
              distortionWidth: 0,
              chromaticAberration: 0,
            )
          : LiquidGlassRefraction(
              distortion: distortion,
              distortionWidth: distortionWidth,
              magnification: magnification,
              chromaticAberration: chromaticAberration,
            ),
    );

    final lens = LiquidGlassLens(
      style: style,
      touch: interactive && !MediaQuery.disableAnimationsOf(context)
          ? const LiquidGlassTouch.flexing(LiquidGlassFlex.subtle())
          : null,
      child: Padding(
        padding: padding ?? EdgeInsets.zero,
        child: child,
      ),
    );

    if (margin == null) return lens;
    return Padding(padding: margin!, child: lens);
  }
}
