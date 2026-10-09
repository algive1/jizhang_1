import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

import '../../core/widgets/app_page_background.dart';
import 'app_colors.dart';
import 'app_theme_definition.dart';

abstract final class AppTheme {
  /// Page transitions, with Android promoted to the Cupertino builder.
  ///
  /// [CupertinoPageTransitionsBuilder] is not only a visual: its
  /// `buildPageTransitions` wraps the page in the Cupertino back-gesture
  /// detector, so switching Android onto it also buys the finger-tracking
  /// left-edge swipe-back the iOS build already has — on every non-first,
  /// non-`fullscreenDialog` [PageRoute], which is exactly what the reference
  /// app ships on Android.
  ///
  /// Every other platform keeps Flutter's own default builder for that
  /// platform (iOS/macOS stay Cupertino, desktop stays Zoom).
  static final PageTransitionsTheme _pageTransitions =
      _PageBackgroundTransitionsTheme(
        builders: {
          ...const PageTransitionsTheme().builders,
          TargetPlatform.android: const CupertinoPageTransitionsBuilder(),
        },
      );

  static ThemeData light([
    AppThemeDefinition theme = BuiltInThemes.freshGreen,
  ]) => _build(theme, Brightness.light);

  static ThemeData dark([
    AppThemeDefinition theme = BuiltInThemes.freshGreen,
  ]) => _build(theme, Brightness.dark);

  static ThemeData _build(AppThemeDefinition theme, Brightness brightness) {
    final dark = brightness == Brightness.dark;
    final palette = dark ? _darkDefinition(theme) : theme;
    final colorScheme = ColorScheme.fromSeed(
      seedColor: palette.primary,
      brightness: brightness,
      surface: palette.surface,
    );
    final liquidGlass = palette.style == AppThemeStyle.liquidGlass;
    final material = AppThemeMaterial(
      style: palette.style,
      pageTint: theme.primary,
      glassTint: dark
          ? Colors.white.withValues(alpha: .10)
          : Color.alphaBlend(
              palette.primary.withValues(alpha: .07),
              palette.surface.withValues(alpha: .76),
            ),
      glassBorder: Colors.white.withValues(alpha: dark ? .24 : .74),
      glassHighlight: Colors.white.withValues(alpha: dark ? .10 : .90),
      blurSigma: dark ? 5 : (liquidGlass ? 18 : 0),
    );
    final onPrimary = dark
        ? (palette.primary.computeLuminance() > .179
              ? Colors.black
              : Colors.white)
        : Colors.white;
    final buttonStyle = dark
        ? FilledButton.styleFrom(
            backgroundColor: palette.primary,
            foregroundColor: onPrimary,
            disabledBackgroundColor: palette.surfaceSoft,
            disabledForegroundColor: palette.textPrimary.withValues(alpha: .38),
            minimumSize: const Size(0, 48),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            elevation: 0,
          )
        : null;

    return ThemeData(
      useMaterial3: true,
      extensions: [material],
      colorScheme: colorScheme.copyWith(
        primary: palette.primary,
        onPrimary: onPrimary,
        secondary: palette.primaryDark,
        surface: palette.surface,
        surfaceContainerLowest: palette.surface,
        surfaceContainerLow: palette.surfaceSoft,
        primaryContainer: palette.primarySoft,
        onPrimaryContainer: palette.primaryDark,
        onSurface: palette.textPrimary,
        onSurfaceVariant: palette.textSecondary,
        outlineVariant: palette.divider,
        error: AppColors.warning,
      ),
      // A route needs its own opaque backing while it moves over the previous
      // route. Otherwise empty space between cards reveals the old page until
      // Navigator finishes the transition. AppScaffold explicitly opts into
      // transparency so its glass bar can still sample the mesh underneath.
      scaffoldBackgroundColor: palette.background,
      canvasColor: palette.background,
      cardColor: dark ? palette.surface : null,
      cardTheme: dark
          ? CardThemeData(
              color: palette.surface,
              surfaceTintColor: Colors.transparent,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            )
          : const CardThemeData(),
      filledButtonTheme: FilledButtonThemeData(style: buttonStyle),
      elevatedButtonTheme: ElevatedButtonThemeData(style: buttonStyle),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: dark
            ? OutlinedButton.styleFrom(
                foregroundColor: palette.primaryDark,
                side: BorderSide(color: palette.divider),
                minimumSize: const Size(0, 48),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              )
            : null,
      ),
      textButtonTheme: TextButtonThemeData(
        style: dark
            ? TextButton.styleFrom(foregroundColor: palette.primaryDark)
            : null,
      ),
      pageTransitionsTheme: _pageTransitions,
      snackBarTheme: SnackBarThemeData(
        backgroundColor: palette.surface,
        contentTextStyle: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        actionTextColor: palette.primaryDark,
        closeIconColor: palette.textPrimary,
        behavior: SnackBarBehavior.floating,
        insetPadding: const EdgeInsets.fromLTRB(16, 0, 16, 112),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 4,
      ),
      textTheme: TextTheme(
        headlineLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 30,
          fontWeight: FontWeight.w700,
          height: 1.2,
        ),
        headlineMedium: TextStyle(
          color: palette.textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w700,
          height: 1.25,
        ),
        titleLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 21,
          fontWeight: FontWeight.w600,
          height: 1.3,
        ),
        titleMedium: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
          height: 1.35,
        ),
        bodyLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 16,
          height: 1.45,
        ),
        bodyMedium: TextStyle(
          color: palette.textSecondary,
          fontSize: 14,
          height: 1.4,
        ),
        labelLarge: TextStyle(
          color: palette.textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: palette.textPrimary,
        elevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
      ),
      dividerTheme: DividerThemeData(
        color: palette.divider,
        thickness: 1,
        space: 1,
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: liquidGlass && !dark
            ? palette.surface.withValues(alpha: .96)
            : palette.surface,
        modalBackgroundColor: liquidGlass && !dark
            ? palette.surface.withValues(alpha: .96)
            : palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: liquidGlass && !dark
            ? palette.surface.withValues(alpha: .97)
            : palette.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: liquidGlass && !dark
            ? palette.surface.withValues(alpha: .97)
            : palette.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: liquidGlass
                ? palette.divider.withValues(alpha: .76)
                : palette.divider,
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            liquidGlass && !dark
                ? palette.surface.withValues(alpha: .97)
                : palette.surface,
          ),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
        ),
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
        fillColor: liquidGlass
            ? palette.surfaceSoft.withValues(alpha: .88)
            : palette.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: palette.primary, width: 1.5),
        ),
      ),
    );
  }

  static AppThemeDefinition _darkDefinition(AppThemeDefinition theme) {
    var primary = Color.lerp(theme.primary, Colors.white, .22)!;
    // Foreground accents must clear the white 10% glass/pill. The backdrop
    // continues to use the original theme tint, independently of this lift.
    for (var step = 0; step < 8 && primary.computeLuminance() < .35; step++) {
      primary = Color.lerp(primary, Colors.white, .12)!;
    }
    const surface = Color(0xFF111111);
    return AppThemeDefinition(
      id: theme.id,
      name: theme.name,
      description: theme.description,
      premium: theme.premium,
      style: theme.style,
      background: Colors.black,
      surface: surface,
      surfaceSoft: const Color(0xFF1F1F1F),
      primary: primary,
      primaryDark: primary,
      primarySoft: Color.alphaBlend(primary.withValues(alpha: .18), surface),
      textPrimary: Colors.white,
      textSecondary: const Color(0xFFB3B3B3),
      divider: Colors.white.withValues(alpha: .12),
    );
  }
}

/// Paints a route-local backing before Flutter applies its platform transition.
/// This also covers pages that return a bare SafeArea/ListView instead of a
/// Scaffold. The backing moves with the new page, so the exposed strip during
/// an interactive back swipe still shows the previous route as intended.
class _PageBackgroundTransitionsTheme extends PageTransitionsTheme {
  const _PageBackgroundTransitionsTheme({required super.builders});

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return super.buildTransitions<T>(
      route,
      context,
      animation,
      secondaryAnimation,
      AppPageBackground(solidDay: true, child: child),
    );
  }
}
