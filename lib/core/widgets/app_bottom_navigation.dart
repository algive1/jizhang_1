import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

import '../../app/theme/app_theme_tokens.dart';

/// Floating bottom navigation bar, built on the package's own
/// **navigation** component.
///
/// This is `LiquidGlassTabBar` — the same widget the reference app ships
/// (`LiquidGlassTabBar` + `LiquidGlassNavBarMotionPill`, driven by a
/// dedicated `LiquidGlassTabPillStyle`) — rather than a hand-rolled
/// `LiquidGlassLens` capsule with a generic `LiquidGlassMotionPill` on
/// top. That distinction matters, because the bar's look is three
/// separately-tuned materials, and only the tab bar exposes all three:
///
///  1. **the capsule** ([LiquidGlassStyle]): tint, blur, refraction, shadow;
///  2. **the moving glass pill** ([LiquidGlassTabPillStyle.glassStyle]):
///     the raised, refracting, squash-and-stretch highlight;
///  3. **the settled rest pill** ([LiquidGlassTabPillStyle.rest]): a
///     **zero-refraction** fill — the pill's own `distortion`/
///     `distortionWidth` must never be reused here, or the resting bar
///     looks blurrier and more bent than the reference.
///
/// ## Why `withImpeller` and a full-screen `Stack`
///
/// The glass only refracts what is painted **behind** it, so the page has
/// to be painted underneath this widget rather than beside it. The library
/// offers two ways to get the real dual-pipeline morph pill:
///
///  * `LiquidGlassScaffold(bottomNavigationBar: LiquidGlassTabBar(...))`,
///    which captures the body into an offscreen image; and
///  * [LiquidGlassTabBar.withImpeller], a full-screen, bodyless overlay
///    meant to be the **last child of a `Stack`** over the page.
///
/// We use the second. `LiquidGlassScaffold` owns the page (so the themed
/// page background would have to be handed to it as a flat
/// `backgroundColor`), it has no content-inset slot for the docked action,
/// and on Skia its bar path resolves to the plain tier with no backdrop
/// filter at all. The overlay leaves the page, the themed background and
/// the action button in one subtree, which is exactly what the live
/// backdrop needs.
///
/// Because it is an overlay it must be the last child of a full-screen
/// `Stack`, and the content it covers must reserve room for it — see
/// [AppNavGeometry.reservedBottomInset].
class AppBottomNavigation extends StatelessWidget {
  const AppBottomNavigation({
    required this.location,
    super.key,
    this.onNavigate,
  });

  /// Screen-space geometry of the bar, the docked action and the room the
  /// page has to leave free.
  static const AppNavGeometry geometry = AppNavGeometry();

  /// The ordinary-contrast white tint shared by the navigation capsule and FAB.
  static Color capsuleTint() => Colors.white.withValues(alpha: .24);

  /// The ordinary-contrast selected ink shared by navigation and the FAB glyph.
  static Color selectedEmphasisFor(
    ColorScheme scheme, {
    required bool liquidGlass,
  }) =>
      liquidGlass
          ? Color.lerp(scheme.secondary, scheme.primary, .4)!
          : _darken(scheme.secondary, selectedInkFactor);

  /// Capsule backdrop blur, in logical pixels.
  ///
  /// Deliberately low. Blur is what decides how much *detail* survives behind
  /// the plate — it does **not** decide how much background shows through; that
  /// is the tint's alpha alone. A big radius therefore does not
  /// buy "more glass", it buys "less background": at 16 the backdrop was
  /// smeared into flat wash and the bar read as an opaque slab. At 5 the
  /// backdrop stays legible as shapes moving under the plate, which is what
  /// makes it read as glass at all — and it is much closer to the reference
  /// implementation's own 2.5. Every theme uses the same faint white tint.
  ///
  /// Contrast for the tab row comes from its theme-specific ink, not from
  /// destroying the backdrop. Content that *rests* near the bar is kept
  /// out from under the glass by `AppNavGeometry.reservedBottomInset` and the
  /// shell's viewport inset, so this radius only ever softens content
  /// mid-scroll.
  static const double capsuleBlurSigma = 5;

  /// Height the host has to leave free for the bar overlay to be usable.
  static double reservedBottomInset(BuildContext context) =>
      geometry.reservedBottomInset(MediaQuery.paddingOf(context).bottom);

  final String location;

  /// Where a selected tab goes. Defaults to `context.go`; tests inject their
  /// own so a tap can be observed without a `GoRouter` ancestor.
  final ValueChanged<String>? onNavigate;

  @override
  Widget build(BuildContext context) {
    final selected = _selectedIndex;
    final navigate = onNavigate ?? (route) => context.go(route);

    return LiquidGlassTabBar.withImpeller(
      key: const ValueKey('app-bottom-navigation-bar'),
      items: _items,
      selectedIndex: selected,
      onChanged: (index) => navigate(_routes[index]),
      width: geometry.barWidth(MediaQuery.sizeOf(context).width),
      height: AppNavGeometry.barHeight,
      itemPadding: AppNavGeometry.itemPadding,
      margin: const EdgeInsets.only(bottom: AppNavGeometry.barBottomMargin),
      centerGap: AppNavGeometry.centerGap,
      centerGapAfter: AppNavGeometry.centerGapAfter,
      style: _capsuleStyle(context),
      itemStyle: _itemStyle(context),
      pillStyle: _pillStyle(context),
    );
  }

  static const List<String> _routes = <String>[
    '/',
    '/transactions',
    '/insights',
    '/profile',
  ];

  int get _selectedIndex {
    if (location.startsWith('/transactions') || location == '/analysis') {
      return 1;
    }
    if (location.startsWith('/insights')) return 2;
    if (location.startsWith('/profile')) return 3;
    return 0;
  }

  static const List<LiquidGlassTabBarItem> _items = <LiquidGlassTabBarItem>[
    LiquidGlassTabBarItem(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: '首页',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.receipt_long_outlined,
      selectedIcon: Icons.receipt_long_rounded,
      label: '流水',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.auto_graph_outlined,
      selectedIcon: Icons.auto_graph_rounded,
      label: '洞察',
    ),
    LiquidGlassTabBarItem(
      icon: Icons.person_outline_rounded,
      selectedIcon: Icons.person_rounded,
      label: '我的',
    ),
  ];

  /// The **bar capsule** — layer 1.
  ///
  /// Params follow the reference implementation: `distortion 0.07` over a
  /// `28` px band with `0.002` chromatic aberration, a `0.7` px rim, and the
  /// optical border that supplies the edge highlight. Contrast comes from
  /// refraction plus that rim, so high-contrast mode swaps the transparent
  /// tinge for an opaque surface and drops refraction entirely instead of
  /// only softening the blur — the project's accessibility contract.
  static LiquidGlassStyle _capsuleStyle(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    return LiquidGlassTabBar.defaultStyle.copyWith(
      shape: LiquidGlassShape.roundedRectangle(
        cornerRadius: AppNavGeometry.barHeight / 2,
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
        color: highContrast
            ? const Color(0xFFF7FAFF)
            : capsuleTint(),
        // Blur and tint work together; icons and labels render above both.
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
              distortion: .06,
              distortionWidth: 26,
              chromaticAberration: .003,
            ),
    );
  }

  /// **Icon and label** styling. The selected ink uses a brighter theme
  /// accent per the reference palette; unselected ink remains muted. Both
  /// states are checked against their rendered capsule/pill composites in
  /// `test/app_scaffold_navigation_test.dart` for at least 4.5:1 contrast.
  static LiquidGlassTabItemStyle _itemStyle(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final liquidGlass = context.appUsesLiquidGlass;
    final selectedColor = highContrast
        ? context.appPrimaryText
        : selectedEmphasisFor(
            context.appColors,
            liquidGlass: liquidGlass,
          );
    return LiquidGlassTabItemStyle(
      selectedColor: selectedColor,
      unselectedColor: highContrast
          ? context.appPrimaryText
          : _darken(context.appSecondaryText, unselectedInkFactor),
      iconSize: 23,
      labelFontSize: 11.5,
      iconLabelGap: 1,
      selectedFontWeight: FontWeight.w600,
      unselectedFontWeight: FontWeight.w400,
    );
  }

  /// How much the selected ink is darkened from secondary in the three solid
  /// themes. Liquid Glass uses a 40% blend toward primary instead.
  static const double selectedInkFactor = .90;

  /// How much the unselected ink is darkened from the theme's secondary text.
  ///
  /// At `.84` every theme clears 4.5 : 1 on the capsule (worst 4.77 : 1),
  /// close to the reference's ~4.7 : 1 grey. The capsule's tint reduces
  /// contrast for dark ink, so the unselected ink stays dark enough to keep
  /// the ratio above the accessibility threshold.
  static const double unselectedInkFactor = .84;

  static Color _darken(Color color, double factor) => Color.from(
        alpha: color.a,
        red: color.r * factor,
        green: color.g * factor,
        blue: color.b * factor,
      );

  /// The **selection pill** — layers 2 and 3.
  ///
  /// [LiquidGlassTabPillStyle.rest] is the settled highlight: a
  /// **zero-refraction** fill that the moving glass lerps into as it lands.
  /// Every theme uses the same 3% dark-gray fill. Theme-specific icon and
  /// label colors are checked against it for accessible contrast.
  ///
  /// [glassStyle] is left at the tuned default so the moving pill stays pure
  /// refraction; only the motion and shape knobs below are set, matching the
  /// reference (`growHeight 9`, distortion `0.04` over `12` px, travel
  /// spring `280 / 31.4`, deformation capped at ±12 %).
  static LiquidGlassTabPillStyle _pillStyle(BuildContext context) {
    final highContrast = MediaQuery.highContrastOf(context);
    final animationsDisabled = MediaQuery.disableAnimationsOf(context);
    final restFill = highContrast
        ? const Color(0xFFDCE8FF)
        : const Color(0xFF333333).withValues(alpha: .03);

    return LiquidGlassTabPillStyle(
      // `impellerOnly`, not `both`: on Skia `both` would make the pill
      // capture the page a second time on top of the bar's own capture.
      mode: LiquidGlassPillMode.impellerOnly,
      growHeight: 9,
      distortion: .04,
      distortionWidth: 12,
      magnification: 1,
      travelStiffness: 280,
      travelDamping: 31.4,
      animated: !animationsDisabled,
      rest: LiquidGlassStyle(
        shape: LiquidGlassShape.roundedRectangle(
          cornerRadius: AppNavGeometry.barHeight / 2,
          borderWidth: .7,
          borderColor: Colors.white.withValues(alpha: .55),
        ),
        appearance: LiquidGlassAppearance(color: restFill),
      ),
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

/// Screen-space geometry shared by the bar overlay, the docked centre
/// action and the page's bottom inset.
///
/// One source of truth on purpose: the bar floats over the page, and the
/// action button and the content inset both have to agree with where it
/// actually lands. The previous implementation spread that across a host
/// height, a separate FAB offset constant and a per-page magic number,
/// which is how the two drift apart.
@immutable
class AppNavGeometry {
  const AppNavGeometry();

  /// Capsule height, matching the reference bar.
  static const double barHeight = 60;

  /// Inner padding between the capsule rim and the icon row.
  static const double itemPadding = 3;

  /// Gap above the bottom safe-area inset.
  static const double barBottomMargin = 8;

  /// Inset from the screen edge on each side. A proportional floor keeps
  /// the capsule's corner radius from looking pinched on small screens.
  static const double barSideMargin = 16;
  static const double barSideMarginRatio = .045;

  /// A slot-free span in the middle of the bar, in tab units, so the
  /// docked action button sits on empty capsule rather than on a tab.
  static const double centerGap = 1;

  /// The gap goes after the second of four tabs.
  static const int centerGapAfter = 1;

  /// Diameter of the docked centre action button.
  static const double actionDiameter = 62;

  /// How far the button's centre sits above the capsule's top edge. A
  /// positive value lifts it clear of the glass so it reads as a raised
  /// primary action.
  static const double actionLift = 2;

  double barSideMarginFor(double screenWidth) =>
      (screenWidth * barSideMarginRatio).clamp(barSideMargin, 24).toDouble();

  double barWidth(double screenWidth) {
    final margin = barSideMarginFor(screenWidth);
    return (screenWidth - margin * 2).clamp(0, screenWidth).toDouble();
  }

  /// Distance from the bottom edge to the capsule's bottom, safe area
  /// included.
  double barBottomInset(double bottomPadding) =>
      bottomPadding + barBottomMargin;

  /// Distance from the bottom edge to the capsule's top edge.
  double barTopInset(double bottomPadding) =>
      barBottomInset(bottomPadding) + barHeight;

  /// Centre of the docked action, measured from the bottom edge.
  double actionCenterFromBottom(double bottomPadding) =>
      barTopInset(bottomPadding) + actionLift;

  /// Room the page must leave free below its last pixel of content.
  ///
  /// The bar is an overlay, so this is the only thing keeping content from
  /// hiding behind the glass. It is measured from the **capsule's top edge**,
  /// not from the action button: the button rises above the capsule, but the
  /// capsule is the wider, more opaque of the two, and reserving only the
  /// button's height leaves the bottom of the content — the last list row, or
  /// a short page's empty state — sitting behind the bar with the action
  /// button clear above it. Clearing the capsule clears both.
  double reservedBottomInset(double bottomPadding) =>
      barTopInset(bottomPadding) + _contentBreath;

  static const double _contentBreath = 18;
}
