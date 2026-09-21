import 'package:flutter/material.dart';

import 'app_theme_definition.dart';

/// Semantic appearance tokens. Feature UI should prefer these tokens over
/// hard-coded brand colors so every screen can participate in theme changes.
extension AppThemeTokens on BuildContext {
  ColorScheme get appColors => Theme.of(this).colorScheme;
  TextTheme get appText => Theme.of(this).textTheme;

  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;
  Color get appSurface => appColors.surface;
  Color get appSurfaceSoft => appColors.surfaceContainerLow;
  Color get appSurfaceRaised => appColors.surfaceContainerLowest;
  Color get appSheetSurface => appUsesLiquidGlass
      ? appColors.surface.withValues(alpha: .96)
      : appColors.surface;
  Color get appDialogSurface => appUsesLiquidGlass
      ? appColors.surface.withValues(alpha: .97)
      : appColors.surface;
  Color get appPopoverSurface => appUsesLiquidGlass
      ? Color.alphaBlend(
          appColors.primary.withValues(alpha: .055),
          appColors.surface.withValues(alpha: .95),
        )
      : appColors.surface;
  Color get appPrimary => appColors.primary;
  Color get appPrimarySoft => appColors.primaryContainer;
  Color get appPrimaryText => appColors.onSurface;
  Color get appSecondaryText => appColors.onSurfaceVariant;
  Color get appDivider => appColors.outlineVariant;

  AppThemeMaterial get appMaterial =>
      Theme.of(this).extension<AppThemeMaterial>() ??
      const AppThemeMaterial(
        style: AppThemeStyle.solid,
        glassTint: Colors.white,
        glassBorder: Colors.transparent,
        glassHighlight: Colors.white,
        blurSigma: 0,
      );

  bool get appUsesLiquidGlass => appMaterial.usesLiquidGlass;
}
