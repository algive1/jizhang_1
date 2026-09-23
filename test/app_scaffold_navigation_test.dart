import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/app_bottom_navigation.dart';
import 'package:jizhang_app/core/widgets/app_bottom_sheet.dart';
import 'package:jizhang_app/core/widgets/app_page_background.dart';
import 'package:jizhang_app/core/widgets/app_scaffold.dart';
import 'package:liquid_glass_easy/liquid_glass_easy.dart';

/// The shell stack: themed backdrop, page, then the glass bar overlay.
///
/// Mirrors what `AppScaffold` builds for a primary route, without the router
/// or the database, so the geometry and the paint order can be asserted
/// directly.
Widget _shell({
  required AppThemeDefinition theme,
  String location = '/',
  bool interactive = false,
  ValueChanged<String>? onNavigate,
}) {
  return MaterialApp(
    theme: AppTheme.light(theme),
    home: Builder(
      builder: (context) => Stack(
        children: [
          const Positioned.fill(child: AppPageBackground(child: SizedBox.expand())),
          Scaffold(
            backgroundColor: Colors.transparent,
            extendBody: true,
            body: ListView.builder(
              key: const ValueKey('probe-page'),
              padding: EdgeInsets.only(
                bottom: AppScaffold.reservedBottomInset(context),
              ),
              itemCount: 12,
              itemBuilder: (context, index) => SizedBox(
                key: ValueKey('probe-row-$index'),
                height: 80,
                child: const ColoredBox(color: Color(0x33FF0000)),
              ),
            ),
          ),
          if (interactive)
            _RecordingNavBar(location: location, onNavigate: onNavigate!)
          else
            AppBottomNavigation(location: location),
          Positioned(
            left: 0,
            right: 0,
            bottom:
                AppBottomNavigation.geometry.actionCenterFromBottom(
                      MediaQuery.paddingOf(context).bottom,
                    ) -
                    AppNavGeometry.actionDiameter / 2,
            child: const Center(
              child: SizedBox(
                key: ValueKey('probe-docked-action'),
                width: AppNavGeometry.actionDiameter,
                height: AppNavGeometry.actionDiameter,
                child: SizedBox.expand(),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

/// The same overlay with the routing stripped out, so a tap can be observed
/// without a `GoRouter` ancestor.
class _RecordingNavBar extends StatelessWidget {
  const _RecordingNavBar({required this.location, required this.onNavigate});

  final String location;
  final ValueChanged<String> onNavigate;

  @override
  Widget build(BuildContext context) {
    return AppBottomNavigation(
      location: location,
      onNavigate: onNavigate,
    );
  }
}

void main() {
  test('global navigation is limited to primary workspace routes', () {
    const primaryRoutes = ['/', '/transactions', '/insights', '/profile'];
    const secondaryRoutes = [
      '/assistant',
      '/analysis',
      '/transactions/search',
      '/transactions/inbox',
      '/transactions/reimbursements',
      '/transactions/calendar',
      '/transactions/transaction-1',
      '/insights/analysis%3Acategory%3Afood',
      '/goals',
      '/goals/goal-1',
      '/profile/account',
      '/profile/account/data-binding',
      '/profile/data',
      '/profile/assets',
      '/profile/accounts',
      '/profile/accounts/account-bank',
      '/profile/categories',
      '/profile/budgets',
      '/profile/membership',
      '/profile/membership/records',
      '/profile/membership/agreement',
      '/profile/privacy',
      '/profile/legal',
      '/profile/family',
      '/profile/payment-notifications',
      '/profile/autobookkeeping',
      '/profile/autobookkeeping/logs',
      '/profile/autobookkeeping/confirm',
      '/profile/recurring-bills',
      '/profile/installments',
      '/profile/installments/plan-1',
      '/profile/investments',
      '/profile/investments/holdings/stock',
      '/profile/investments/holdings/detail/holding-1',
      '/profile/investments/add',
    ];

    for (final route in primaryRoutes) {
      expect(
        isPrimaryAppRoute(route),
        isTrue,
        reason: '$route should keep the global navigation entry points',
      );
    }
    for (final route in secondaryRoutes) {
      expect(
        isPrimaryAppRoute(route),
        isFalse,
        reason: '$route should use its own page-level actions',
      );
    }
  });

  test('primary workspace modal sheets are promoted above the app shell', () {
    const paths = [
      'lib/core/widgets/app_bottom_sheet.dart',
      'lib/core/widgets/app_scaffold.dart',
      'lib/features/books/presentation/book_selector.dart',
      'lib/features/goals/presentation/goal_creation_sheet.dart',
      'lib/features/goals/presentation/goal_planning_sheet.dart',
      'lib/features/home/presentation/home_page.dart',
      'lib/features/profile/presentation/profile_page.dart',
      'lib/features/transactions/presentation/transaction_actions.dart',
      'lib/features/transactions/presentation/transactions_page.dart',
    ];

    for (final path in paths) {
      final lines = File(path).readAsLinesSync();
      for (var index = 0; index < lines.length; index++) {
        if (!lines[index].contains('showModalBottomSheet')) continue;
        final end = index + 12 < lines.length ? index + 12 : lines.length;
        final callHead = lines.sublist(index, end).join('\n');
        expect(
          callHead,
          contains('useRootNavigator: true'),
          reason:
              '$path:${index + 1} must present above the ShellRoute navigator '
              'so primary navigation cannot remain visible.',
        );
      }
    }
  });

  testWidgets('AppBottomSheet pushes onto the root navigator', (tester) async {
    final rootObserver = _RecordingNavigatorObserver();
    final nestedObserver = _RecordingNavigatorObserver();

    await tester.pumpWidget(
      MaterialApp(
        navigatorObservers: [rootObserver],
        home: Navigator(
          observers: [nestedObserver],
          onGenerateRoute: (_) => MaterialPageRoute<void>(
            builder: (nestedContext) => Scaffold(
              body: Center(
                child: TextButton(
                  key: const ValueKey('open-root-sheet'),
                  onPressed: () => AppBottomSheet.show<void>(
                    context: nestedContext,
                    builder: (_) => const SizedBox(
                      height: 120,
                      child: Center(child: Text('root sheet')),
                    ),
                  ),
                  child: const Text('Open sheet'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.byKey(const ValueKey('open-root-sheet')));
    await tester.pumpAndSettle();

    expect(rootObserver.popupPushes, 1);
    expect(nestedObserver.popupPushes, 0);
    expect(find.text('root sheet'), findsOneWidget);
  });

  test('legacy theme payloads default to the solid material style', () {
    final theme = AppThemeDefinition.fromJson({
      'id': 'legacy',
      'name': '旧主题',
      'description': '',
      'premium': true,
      'background': '#FFFFFF',
      'surface': '#FFFFFF',
      'surfaceSoft': '#F5F5F5',
      'primary': '#527C98',
      'primaryDark': '#365D77',
      'primarySoft': '#E4EFF5',
      'textPrimary': '#1D252A',
      'textSecondary': '#707A80',
      'divider': '#E4EAEE',
    });

    expect(theme.style, AppThemeStyle.solid);
    expect(BuiltInThemes.liquidGlass.style, AppThemeStyle.liquidGlass);
  });

  test('the shell leaves room for the whole bar, action included', () {
    const geometry = AppBottomNavigation.geometry;
    const bottomPadding = 34.0; // gesture-nav inset on a typical phone

    final barTop = geometry.barTopInset(bottomPadding);
    final actionCenter = geometry.actionCenterFromBottom(bottomPadding);
    final reserved = geometry.reservedBottomInset(bottomPadding);

    // The action straddles the capsule's top edge, not its middle.
    expect(actionCenter, greaterThan(barTop));
    expect(actionCenter, lessThan(barTop + AppNavGeometry.actionDiameter));

    // Reserving room is measured from the capsule's top edge, so short
    // content (a page that does not scroll) still clears the bar. The action
    // button rises above the capsule, so clearing the capsule happens to
    // clear the button's lower half too.
    expect(reserved, greaterThan(barTop));
    expect(reserved, lessThan(barTop + 32));
    expect(
      reserved,
      greaterThan(actionCenter - AppNavGeometry.actionDiameter / 2),
      reason: 'content must not stop level with the raised button',
    );
  });

  test('the capsule is inset from the screen edge, within bounds', () {
    const geometry = AppBottomNavigation.geometry;
    for (final width in [320.0, 360.0, 393.0, 430.0, 600.0]) {
      final margin = geometry.barSideMarginFor(width);
      expect(margin, greaterThanOrEqualTo(AppNavGeometry.barSideMargin));
      expect(margin * 2, lessThan(width / 4));
      expect(geometry.barWidth(width), closeTo(width - margin * 2, .001));
    }
  });

  testWidgets(
    'every built-in theme renders the bar over the page background',
    (tester) async {
      await tester.binding.setSurfaceSize(const Size(393, 844));
      addTearDown(() => tester.binding.setSurfaceSize(null));

      for (final theme in BuiltInThemes.all) {
        await tester.pumpWidget(_shell(theme: theme));
        await tester.pump();

        // The backdrop the glass has to sample, and the page above it.
        expect(
          find.byType(AppPageBackground),
          findsOneWidget,
          reason: '${theme.id} must paint a backdrop for the glass to bend',
        );

        // The bar is the package's own navigation component, in the tree as
        // an overlay rather than as a scaffold slot.
        expect(find.byType(LiquidGlassTabBar), findsOneWidget);
        expect(find.byType(LiquidGlassLens), findsWidgets);

        // Every theme reaches the glass path; none falls back to a slab.
        final context = tester.element(find.byType(LiquidGlassTabBar));
        expect(
          MediaQuery.highContrastOf(context),
          isFalse,
          reason: 'the probe must exercise the glass branch',
        );
        final bar = tester.widget<LiquidGlassTabBar>(
          find.byType(LiquidGlassTabBar),
        );
        expect(bar.glassPill, isNot(LiquidGlassPillMode.none));
        expect(bar.centerGap, AppNavGeometry.centerGap);
        expect(bar.centerGapAfter, AppNavGeometry.centerGapAfter);
        expect(bar.height, AppNavGeometry.barHeight);

        // The four tabs plus a slot-free gap, no phantom fifth tab.
        expect(bar.items.length, 4);
        expect(tester.takeException(), isNull);
      }
    },
  );

  testWidgets('the centre gap lands on the bar centre, clear of the tabs', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shell(theme: BuiltInThemes.freshGreen));
    await tester.pump();

    final bar = tester.widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar));
    final layout = bar.navLayout;
    expect(layout.hasCenterGap, isTrue);

    // The docked action must sit on empty capsule: no tab centre may come
    // within half a cell of the bar's middle.
    final centre = layout.padding + layout.width / 2;
    for (var tab = 0; tab < bar.items.length; tab++) {
      expect(
        (layout.tabCenterOf(tab) - centre).abs(),
        greaterThanOrEqualTo(layout.cellWidth * .9),
        reason: 'tab $tab is too close to the docked action',
      );
    }
    // And the gap really is the widest span in the row: the two tabs that
    // flank it are one cell plus one gap apart, while the outer pairs are
    // one cell apart.
    final pitches = <double>[
      for (var tab = 1; tab < bar.items.length; tab++)
        layout.tabCenterOf(tab) - layout.tabCenterOf(tab - 1),
    ];
    expect(pitches[0], closeTo(layout.cellWidth, .001));
    expect(pitches[2], closeTo(layout.cellWidth, .001));
    expect(pitches[1], closeTo(layout.cellWidth * (1 + bar.centerGap), .001));
    expect(pitches[1], greaterThan(pitches[0]));

    expect(tester.takeException(), isNull);
  });

  testWidgets('the page reserves enough room to clear the capsule', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shell(theme: BuiltInThemes.freshGreen));
    await tester.pump();

    final listView = tester.widget<ListView>(
      find.byKey(const ValueKey('probe-page')),
    );
    final reserved = (listView.padding as EdgeInsets).bottom;
    final list = tester.getRect(find.byKey(const ValueKey('probe-page')));
    final action = tester.getRect(
      find.byKey(const ValueKey('probe-docked-action')),
    );

    // Where the capsule's top edge actually lands, straight from the shell's
    // own geometry, expressed in the same coordinate space as the list.
    final barTop = list.bottom -
        AppBottomNavigation.geometry.barTopInset(
          MediaQuery.paddingOf(
            tester.element(find.byKey(const ValueKey('probe-page'))),
          ).bottom,
        );

    // The last pixel of content has to stop above the capsule, otherwise it
    // sits behind the glass — which is exactly the bug this replaces.
    expect(list.bottom - reserved, lessThanOrEqualTo(barTop));
    expect(action.center.dx, closeTo(list.center.dx, .5));
  });

  testWidgets('the bar paints above the page and the action above the bar', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(_shell(theme: BuiltInThemes.freshGreen));
    await tester.pump();

    // Paint order in a `Stack` is child order, so the shell's own stack is
    // the authority: the backdrop first, then the page, then the glass, then
    // the action. Anything else and the glass has nothing to refract.
    final order = _shellStackChildren(tester);
    expect(order, hasLength(4));
    expect(order[0], AppPageBackground);
    expect(order[1], Scaffold);
    expect(order[2], AppBottomNavigation);
    expect(order[3], isNot(AppBottomNavigation));
  });

  testWidgets('a tap in the reserved gap does not select a tab', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    final visited = <String>[];
    await tester.pumpWidget(
      _shell(
        theme: BuiltInThemes.freshGreen,
        interactive: true,
        onNavigate: visited.add,
      ),
    );
    await tester.pump();

    final bar = tester.widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar));
    final layout = bar.navLayout;
    final barRect = tester.getRect(find.byType(AppBottomNavigation));
    final barLeft = barRect.center.dx - layout.width / 2;

    // Dead centre of the reserved span: the docked action's territory.
    await tester.tapAt(
      Offset(barLeft + layout.slotCenterOf(layout.gapSlot), barRect.center.dy),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(visited, isEmpty, reason: 'the gap belongs to no tab');

    // A real tab still selects.
    final tabIcon = find.byWidgetPredicate(
      (w) => w is Icon && w.icon == Icons.person_outline_rounded,
    );
    await tester.tapAt(tester.getRect(tabIcon.first).center);
    await tester.pump(const Duration(milliseconds: 400));
    expect(visited, ['/profile']);
  });

  testWidgets('the bar takes its colors from the active theme', (tester) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // The whole point of decoupling the bar from `AppThemeStyle.liquidGlass`
    // is that the *material* is shared while the *colors* stay per-theme.
    //
    // `pumpWidget` in a loop reuses the `MaterialApp` element and keeps
    // resolving the first theme it ever saw, so the tree is torn down between
    // iterations; otherwise every iteration would be compared against
    // `fresh_green`.
    final resolved = <String, Color>{};
    for (final theme in BuiltInThemes.all) {
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pumpWidget(_shell(theme: theme));
      await tester.pump();

      final bar = tester.widget<LiquidGlassTabBar>(
        find.byType(LiquidGlassTabBar),
      );
      final scheme = AppTheme.light(theme).colorScheme;
      final expectedSelected = _darken(
        scheme.secondary,
        AppBottomNavigation.selectedInkFactor,
      );

      expect(
        bar.itemStyle.selectedColor,
        expectedSelected,
        reason: '${theme.id} must select in its own darkened accent',
      );
      expect(
        bar.itemStyle.unselectedColor,
        _darken(
          scheme.onSurfaceVariant,
          AppBottomNavigation.unselectedInkFactor,
        ),
        reason: '${theme.id} must dim unselected items in its own ink',
      );
      // The capsule tint is derived from the active theme so the glass
      // keeps the current palette instead of importing a fixed cool tint.
      expect(
        bar.style!.appearance.color,
        AppBottomNavigation.plateTint(scheme),
      );
      expect(
        bar.style!.refraction.distortion,
        greaterThan(0),
        reason: '${theme.id} must keep real refraction, not a flat slab',
      );
      resolved[theme.id] = bar.itemStyle.selectedColor;
    }

    // Sanity: the four themes really do differ, so the loop above is not
    // comparing four copies of the same palette.
    expect(resolved.values.toSet().length, BuiltInThemes.all.length);
  });

  testWidgets('tab ink clears the contrast gate on the capsule and the pill', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    // Measured off the reference bar: unselected 4.73:1 on its capsule,
    // selected 8.04:1 on its pill. This is the contract that the previous
    // 86 %-dimmed ink broke at 3.3:1, making the tab row lose to whatever
    // page content sat behind the glass.
    for (final theme in BuiltInThemes.all) {
      final scheme = AppTheme.light(theme).colorScheme;
      final selected = _darken(
        scheme.secondary,
        AppBottomNavigation.selectedInkFactor,
      );
      final unselected = _darken(
        scheme.onSurfaceVariant,
        AppBottomNavigation.unselectedInkFactor,
      );

      // The capsule is a theme-derived plate tint composited over the page;
      // the settled pill is the accent tinted over that plate.
      const capsule = Color(0xFFE4E8F1);
      final pill = _blend(
        scheme.primary.withValues(alpha: AppBottomNavigation.restFillAlpha),
        capsule,
      );

      expect(
        _contrast(unselected, capsule),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.id}: unselected label must clear 4.5:1 on the capsule',
      );
      expect(
        _contrast(selected, pill),
        greaterThanOrEqualTo(4.5),
        reason: '${theme.id}: selected label must clear 4.5:1 on its pill',
      );
      // Selection has to *read* as the strong state, which the reference
      // encodes by making its selected ink darker than its grey — near black
      // on a coloured pill, not a mere hue swap. Contrast against the pill
      // alone cannot express that (a lighter pill flatters a lighter ink), so
      // the two inks are compared directly. The comparison is directional
      // rather than a fixed multiple: how much darker a theme's dark accent is
      // than its grey is the theme's own business — the green theme's
      // `primaryDark` is the lightest of the four and gates any multiple.
      expect(
        _luminance(selected),
        lessThan(_luminance(unselected)),
        reason: '${theme.id}: the selected ink must be darker than the '
            'resting ink, as the reference\'s near-black-on-amber is',
      );
      // …and the settled pill must carry the accent rather than being a
      // neutral frost, which is what makes the selection read as the theme's.
      expect(
        _luminance(pill),
        lessThan(_luminance(capsule) * .97),
        reason: '${theme.id}: the settled pill must be visibly tinted',
      );
    }
  });

  testWidgets('high contrast drops the capsule to an opaque surface', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(393, 844));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(highContrast: true),
        child: _shell(
          theme: BuiltInThemes.freshGreen,
          interactive: true,
          onNavigate: (_) {},
        ),
      ),
    );
    await tester.pump();

    final bar = tester.widget<LiquidGlassTabBar>(find.byType(LiquidGlassTabBar));
    final style = bar.style!;
    expect(style.refraction.distortion, 0);
    expect(style.refraction.distortionWidth, 0);
    expect(style.appearance.color.a, 1);
  });
}

/// WCAG relative luminance.
double _luminance(Color color) {
  double channel(double v) =>
      v <= .03928 ? v / 12.92 : math.pow((v + .055) / 1.055, 2.4).toDouble();
  return .2126 * channel(color.r) +
      .7152 * channel(color.g) +
      .0722 * channel(color.b);
}

/// WCAG contrast ratio between two opaque colours.
double _contrast(Color a, Color b) {
  final la = _luminance(a);
  final lb = _luminance(b);
  final hi = math.max(la, lb);
  final lo = math.min(la, lb);
  return (hi + .05) / (lo + .05);
}

/// The same darkening the bar applies to its ink.
Color _darken(Color color, double factor) => Color.from(
      alpha: color.a,
      red: color.r * factor,
      green: color.g * factor,
      blue: color.b * factor,
    );

/// Source-over composite of a translucent colour onto an opaque one.
Color _blend(Color fg, Color bg) => Color.from(
      alpha: 1,
      red: fg.r * fg.a + bg.r * (1 - fg.a),
      green: fg.g * fg.a + bg.g * (1 - fg.a),
      blue: fg.b * fg.a + bg.b * (1 - fg.a),
    );

/// Runtime types of the shell `Stack`'s direct children, in paint order.
List<Type> _shellStackChildren(WidgetTester tester) {
  final stack = tester.widget<Stack>(
    find
        .ancestor(
          of: find.byType(AppPageBackground),
          matching: find.byType(Stack),
        )
        .first,
  );
  return [
    for (final child in stack.children)
      if (child is Positioned) child.child.runtimeType else child.runtimeType,
  ];
}

class _RecordingNavigatorObserver extends NavigatorObserver {
  int popupPushes = 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);
    if (route is PopupRoute<dynamic>) popupPushes++;
  }
}
