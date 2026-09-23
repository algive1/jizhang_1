import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../analytics/product_analytics.dart';

import '../../features/bookkeeping/presentation/quick_add_sheet.dart';
import '../../features/voice/presentation/voice_bookkeeping_sheet.dart';
import 'app_bottom_navigation.dart';
import 'app_page_background.dart';
import 'quick_add_button.dart';

const _primaryAppRoutes = {'/', '/transactions', '/insights', '/profile'};

bool isPrimaryAppRoute(String location) => _primaryAppRoutes.contains(location);

/// The application shell: themed backdrop, page, and the floating glass
/// navigation bar over both.
///
/// ## Why the bar is an overlay instead of a scaffold slot
///
/// The liquid-glass bar refracts a **live backdrop** — on Impeller it
/// samples whatever has already been painted behind it. That only works if
/// the page is painted in the same subtree, so the stack here is deliberate
/// and ordered:
///
/// ```
/// Stack
///  ├─ AppPageBackground   ← themed mesh gradient (the colour the glass bends)
///  ├─ Scaffold(transparent, extendBody)  ← the page, edge to edge
///  └─ AppBottomNavigation ← the glass bar overlay (must be last)
/// ```
///
/// The old arrangement put the bar in `Scaffold.bottomNavigationBar`, which
/// is a *sibling slot*, not an overlay: `Scaffold` sizes it, the page stops
/// above it, and only the bar's own 96 dp slot is painted behind the
/// capsule. Reserving room is therefore the shell's job rather than the
/// platform's — the body receives
/// [AppNavGeometry.reservedBottomInset] as bottom padding, and the docked
/// action button is positioned from the same geometry.
class AppScaffold extends ConsumerStatefulWidget {
  const AppScaffold({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  /// Bottom padding a page body must leave free for the bar and its action.
  ///
  /// Exposed so pages can add it to a `SliverPadding`/`ListView` instead of
  /// carrying their own magic number.
  static double reservedBottomInset(BuildContext context) =>
      AppBottomNavigation.reservedBottomInset(context);

  @override
  ConsumerState<AppScaffold> createState() => _AppScaffoldState();
}

class _AppScaffoldState extends ConsumerState<AppScaffold> {
  @override
  void initState() {
    super.initState();
    _trackScreen();
  }

  @override
  void didUpdateWidget(covariant AppScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.location != widget.location) _trackScreen();
  }

  void _trackScreen() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(
        ref.read(productAnalyticsProvider).track(
          'screen_view',
          screen: widget.location,
        ),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    final showGlobalEntryActions = isPrimaryAppRoute(widget.location);
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    const actionDiameter = AppNavGeometry.actionDiameter;

    return Stack(
      children: [
        Positioned.fill(child: AppPageBackground(child: const SizedBox.expand())),
        Scaffold(
          // The page paints edge to edge and `AppPageBackground` supplies the
          // colour, so the scaffold itself must stay clear — otherwise the
          // glass would sample the scaffold rather than the backdrop.
          backgroundColor: Colors.transparent,
          extendBody: true,
          // The page's viewport stops at the **capsule's bottom edge**, not at
          // the screen's. Everything above that line can scroll under the
          // glass and is blurred by it; the strip between the capsule's bottom
          // edge and the screen's (the bottom safe area plus the bar's own
          // bottom margin) has **no glass over it at all**, so page content
          // parked there renders razor sharp right under the bar and reads as
          // "the plate is not blurring anything". Ending the viewport at the
          // capsule leaves that strip to the themed backdrop, which has no
          // detail to give away.
          body: Padding(
            padding: EdgeInsets.only(
              bottom: AppBottomNavigation.geometry.barBottomInset(
                bottomPadding,
              ),
            ),
            child: widget.child,
          ),
        ),
        if (showGlobalEntryActions) ...<Widget>[
          AppBottomNavigation(location: widget.location),
          Positioned(
            left: 0,
            right: 0,
            bottom: AppBottomNavigation.geometry
                    .actionCenterFromBottom(bottomPadding) -
                actionDiameter / 2,
            child: Center(
              child: SizedBox(
                width: actionDiameter,
                height: actionDiameter,
                // The geometry owns the size, the button renders it.
                child: QuickAddButton(
                  diameter: actionDiameter,
                  onPressed: () => showQuickAddSheet(context),
                  onLongPress: () => showModalBottomSheet<void>(
                    context: context,
                    useRootNavigator: true,
                    isScrollControlled: true,
                    backgroundColor: Colors.transparent,
                    builder: (_) => const VoiceBookkeepingSheet(),
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}
