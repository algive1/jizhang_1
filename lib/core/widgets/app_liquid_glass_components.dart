import 'package:flutter/material.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';
// The vendored package keeps the segmented control out of its public barrel
// while its motion API is experimental. This wrapper contains that dependency
// so feature code never imports package internals directly.
// ignore: implementation_imports
import 'package:liquid_glass_easy/src/widgets/components/liquid_glass_segmented.dart';

import '../../app/theme/app_theme_tokens.dart';
import 'app_liquid_glass_spec.dart';

typedef AppLiquidGlassTabBuilder = Widget Function(
  BuildContext context,
  int index,
  bool selected,
  Color color,
);

/// Reusable card made from the exact optical material used by the app's
/// floating bottom navigation capsule.
class AppLiquidGlassCard extends StatelessWidget {
  const AppLiquidGlassCard({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.all(20),
    this.margin,
    this.borderRadius = 24,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final content = Padding(padding: padding, child: child);
    final inner = onTap == null
        ? content
        : Material(
            type: MaterialType.transparency,
            child: InkWell(
              borderRadius: BorderRadius.circular(borderRadius),
              onTap: onTap,
              child: content,
            ),
          );

    final glass = LiquidGlassLens(
      style: AppLiquidGlassSpec.capsuleStyle(
        context,
        cornerRadius: borderRadius,
      ),
      child: inner,
    );

    final outerMargin = margin;
    return outerMargin == null
        ? glass
        : Padding(padding: outerMargin, child: glass);
  }
}

/// Inline tab/segmented control using the same capsule, ink, settled pill,
/// and moving glass material as [AppBottomNavigation].
///
/// The package's inline segmented host owns the local layout; all visible
/// optical parameters come from [AppLiquidGlassSpec], so it does not invent a
/// second glass recipe.
class AppLiquidGlassTabs extends StatelessWidget {
  const AppLiquidGlassTabs({
    required this.tabs,
    required this.selectedIndex,
    required this.onChanged,
    super.key,
    this.width = 280,
    this.height = 44,
    this.padding = 4,
    this.fontSize = 13,
    this.tabBuilder,
  })  : assert(tabs.length > 0),
        assert(selectedIndex >= 0 && selectedIndex < tabs.length);

  final List<String> tabs;
  final int selectedIndex;
  final ValueChanged<int> onChanged;
  final double width;
  final double height;
  final double padding;
  final double fontSize;
  final AppLiquidGlassTabBuilder? tabBuilder;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final selectedColor = highContrast
        ? context.appPrimaryText
        : AppLiquidGlassSpec.selectedEmphasisFor(
            context.appColors,
            liquidGlass: context.appUsesLiquidGlass,
          );
    final unselectedColor = highContrast
        ? context.appPrimaryText
        : AppLiquidGlassSpec.darken(
            context.appSecondaryText,
            AppLiquidGlassSpec.unselectedInkFactor,
          );

    return LiquidGlassSegmented(
      segments: tabs,
      selectedIndex: selectedIndex,
      onChanged: onChanged,
      width: width,
      height: height,
      padding: padding,
      style: AppLiquidGlassSpec.capsuleStyle(
        context,
        cornerRadius: height / 2,
      ),
      pillStyle: LiquidGlassSegmentedPillStyle(
        glass: !highContrast,
        animated: !animationsDisabled,
        duration: const Duration(milliseconds: 320),
        curve: Curves.easeOutCubic,
        growHeight: AppLiquidGlassSpec.tabGrowHeight,
        glassStyle: highContrast ? null : AppLiquidGlassSpec.movingTabStyle(),
        restStyle: AppLiquidGlassSpec.tabRestStyle(
          context,
          cornerRadius: height / 2,
        ),
      ),
      labelStyle: LiquidGlassSegmentedLabelStyle(
        selectedColor: selectedColor,
        unselectedColor: unselectedColor,
        fontSize: fontSize,
        selectedFontWeight: FontWeight.w600,
        unselectedFontWeight: FontWeight.w400,
      ),
      segmentBuilder: tabBuilder,
    );
  }
}

/// A reusable single action button made from the exact FAB glass material.
///
/// Its geometry may be a pill instead of a circle, but tint, blur, shadow,
/// refraction, chromatic aberration and optical rim are shared with
/// [QuickAddButton].
class AppLiquidGlassButton extends StatelessWidget {
  const AppLiquidGlassButton({
    super.key,
    this.label,
    this.icon,
    this.child,
    this.onPressed,
    this.width,
    this.height = 48,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
    this.foregroundColor,
    this.fontSize = 15,
    this.fontWeight = FontWeight.w600,
    this.iconSize = 20,
  }) : assert(
          label != null || icon != null || child != null,
          'Give the button a label, icon, or child.',
        );

  final String? label;
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color? foregroundColor;
  final double fontSize;
  final FontWeight fontWeight;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final foreground = foregroundColor ??
        (highContrast
            ? Colors.white
            : AppLiquidGlassSpec.selectedEmphasisFor(
                context.appColors,
                liquidGlass: context.appUsesLiquidGlass,
              ));

    if (highContrast) {
      return _HighContrastActionButton(
        label: label,
        icon: icon,
        child: child,
        onPressed: onPressed,
        width: width,
        height: height,
        padding: padding,
        foreground: foreground,
        fontSize: fontSize,
        fontWeight: fontWeight,
        iconSize: iconSize,
      );
    }

    return LiquidGlassButton(
      label: label,
      icon: icon,
      child: child,
      onPressed: onPressed,
      width: width,
      height: height,
      padding: padding,
      foregroundColor: foreground,
      fontSize: fontSize,
      fontWeight: fontWeight,
      iconSize: iconSize,
      style: AppLiquidGlassSpec.actionStyle(
        context,
        cornerRadius: height / 2,
      ),
    );
  }
}

class _HighContrastActionButton extends StatelessWidget {
  const _HighContrastActionButton({
    required this.label,
    required this.icon,
    required this.child,
    required this.onPressed,
    required this.width,
    required this.height,
    required this.padding,
    required this.foreground,
    required this.fontSize,
    required this.fontWeight,
    required this.iconSize,
  });

  final String? label;
  final IconData? icon;
  final Widget? child;
  final VoidCallback? onPressed;
  final double? width;
  final double height;
  final EdgeInsetsGeometry padding;
  final Color foreground;
  final double fontSize;
  final FontWeight fontWeight;
  final double iconSize;

  Widget _content() {
    final custom = child;
    if (custom != null) {
      return IconTheme.merge(
        data: IconThemeData(color: foreground, size: iconSize),
        child: DefaultTextStyle.merge(
          style: TextStyle(
            color: foreground,
            fontSize: fontSize,
            fontWeight: fontWeight,
          ),
          child: custom,
        ),
      );
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[
          Icon(icon, size: iconSize, color: foreground),
          if (label != null) const SizedBox(width: 8),
        ],
        if (label != null)
          Text(
            label!,
            style: TextStyle(
              color: foreground,
              fontSize: fontSize,
              fontWeight: fontWeight,
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final primary = context.appPrimary;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(height / 2),
        boxShadow: [
          BoxShadow(
            color: primary.withValues(alpha: .28),
            blurRadius: 13,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Material(
        color: primary,
        shape: StadiumBorder(
          side: BorderSide(color: Colors.white.withValues(alpha: .65)),
        ),
        child: InkWell(
          customBorder: const StadiumBorder(),
          onTap: onPressed,
          child: SizedBox(
            width: width,
            height: height,
            child: Padding(
              padding: padding,
              child: Center(child: _content()),
            ),
          ),
        ),
      ),
    );
  }
}
