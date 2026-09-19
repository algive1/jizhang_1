import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_theme_definition.dart';

abstract final class AppTheme {
  static ThemeData light([AppThemeDefinition theme = BuiltInThemes.freshGreen]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: theme.primary,
      brightness: Brightness.light,
      surface: theme.surface,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme.copyWith(
        primary: theme.primary,
        onPrimary: Colors.white,
        secondary: theme.primaryDark,
        surface: theme.surface,
        onSurface: theme.textPrimary,
        error: AppColors.warning,
      ),
      scaffoldBackgroundColor: theme.background,
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: theme.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          color: theme.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          color: theme.textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          color: theme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        bodyLarge: TextStyle(
          color: theme.textPrimary,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: theme.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: theme.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: theme.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: theme.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: theme.surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      listTileTheme: const ListTileThemeData(minTileHeight: 56),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        constraints: const BoxConstraints(minHeight: 52),
        labelStyle: const TextStyle(fontSize: 14),
        errorMaxLines: 3,
        fillColor: theme.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: theme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: theme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: const BorderSide(color: theme.primary, width: 1.5),
        ),
      ),
    );
  }
}
