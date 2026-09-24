import 'package:flutter/cupertino.dart' show CupertinoPageTransitionsBuilder;
import 'package:flutter/material.dart';

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

  static ThemeData light([AppThemeDefinition theme = BuiltInThemes.freshGreen]) {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: theme.primary,
      brightness: Brightness.light,
      surface: theme.surface,
    );
    final liquidGlass = theme.style == AppThemeStyle.liquidGlass;
    final material = AppThemeMaterial(
      style: theme.style,
      glassTint: Color.alphaBlend(
        theme.primary.withValues(alpha: .07),
        theme.surface.withValues(alpha: .76),
      ),
      glassBorder: Colors.white.withValues(alpha: .74),
      glassHighlight: Colors.white.withValues(alpha: .90),
      blurSigma: liquidGlass ? 18 : 0,
    );

    return ThemeData(
      useMaterial3: true,
      extensions: [material],
      colorScheme: colorScheme.copyWith(
        primary: theme.primary,
        onPrimary: Colors.white,
        secondary: theme.primaryDark,
        surface: theme.surface,
        surfaceContainerLowest: theme.surface,
        surfaceContainerLow: theme.surfaceSoft,
        primaryContainer: theme.primarySoft,
        onPrimaryContainer: theme.primaryDark,
        onSurface: theme.textPrimary,
        onSurfaceVariant: theme.textSecondary,
        outlineVariant: theme.divider,
        error: AppColors.warning,
      ),
      // A route needs its own opaque backing while it moves over the previous
      // route. Otherwise empty space between cards reveals the old page until
      // Navigator finishes the transition. AppScaffold explicitly opts into
      // transparency so its glass bar can still sample the mesh underneath.
      scaffoldBackgroundColor: theme.background,
      canvasColor: theme.background,
      pageTransitionsTheme: _pageTransitions,
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
        backgroundColor: liquidGlass
            ? theme.surface.withValues(alpha: .96)
            : theme.surface,
        modalBackgroundColor: liquidGlass
            ? theme.surface.withValues(alpha: .96)
            : theme.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
        ),
        clipBehavior: Clip.antiAlias,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: liquidGlass
            ? theme.surface.withValues(alpha: .97)
            : theme.surface,
        surfaceTintColor: Colors.transparent,
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: liquidGlass
            ? theme.surface.withValues(alpha: .97)
            : theme.surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: BorderSide(
            color: liquidGlass
                ? theme.divider.withValues(alpha: .76)
                : theme.divider,
          ),
        ),
      ),
      dropdownMenuTheme: DropdownMenuThemeData(
        menuStyle: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(
            liquidGlass
                ? theme.surface.withValues(alpha: .97)
                : theme.surface,
          ),
          surfaceTintColor:
              const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
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
            ? theme.surfaceSoft.withValues(alpha: .88)
            : theme.surfaceSoft,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.divider),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.divider),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: theme.primary, width: 1.5),
        ),
      ),
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
      ColoredBox(
        color: Theme.of(context).scaffoldBackgroundColor,
        child: child,
      ),
    );
  }
}
