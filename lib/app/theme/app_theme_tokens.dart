import 'package:flutter/material.dart';

/// Semantic appearance tokens. Feature UI should prefer these tokens over
/// hard-coded brand colors so every screen can participate in theme changes.
extension AppThemeTokens on BuildContext {
  ColorScheme get appColors => Theme.of(this).colorScheme;
  TextTheme get appText => Theme.of(this).textTheme;

  Color get appBackground => Theme.of(this).scaffoldBackgroundColor;
  Color get appSurface => appColors.surface;
  Color get appSurfaceSoft => appColors.surfaceContainerLow;
  Color get appSurfaceRaised => appColors.surfaceContainerLowest;
  Color get appPrimary => appColors.primary;
  Color get appPrimarySoft => appColors.primaryContainer;
  Color get appPrimaryText => appColors.onSurface;
  Color get appSecondaryText => appColors.onSurfaceVariant;
  Color get appDivider => appColors.outlineVariant;
}
