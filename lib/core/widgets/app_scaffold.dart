import 'package:flutter/material.dart';

import '../../features/bookkeeping/presentation/quick_add_sheet.dart';
import '../../features/voice/presentation/voice_bookkeeping_sheet.dart';
import 'app_bottom_navigation.dart';
import 'quick_add_button.dart';

const _primaryAppRoutes = {'/', '/transactions', '/goals', '/profile'};

bool isPrimaryAppRoute(String location) => _primaryAppRoutes.contains(location);

class AppScaffold extends StatelessWidget {
  const AppScaffold({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final showGlobalEntryActions = isPrimaryAppRoute(location);
    return Scaffold(
      extendBody: true,
      body: child,
      floatingActionButton: showGlobalEntryActions
          ? QuickAddButton(
              onPressed: () => showQuickAddSheet(context),
              onLongPress: () => showModalBottomSheet<void>(
                context: context,
                isScrollControlled: true,
                backgroundColor: Colors.transparent,
                builder: (_) => const VoiceBookkeepingSheet(),
              ),
            )
          : null,
      floatingActionButtonLocation: showGlobalEntryActions
          ? const _CenteredDockedFabLocation(offsetY: 10)
          : null,
      bottomNavigationBar: showGlobalEntryActions
          ? AppBottomNavigation(location: location)
          : null,
    );
  }
}

/// Keeps the FAB and BottomAppBar notch in the same coordinate system.
///
/// A widget-level [Transform] would move only the button after Scaffold has
/// calculated the notch, leaving a visible background seam around the button.
class _CenteredDockedFabLocation extends FloatingActionButtonLocation {
  const _CenteredDockedFabLocation({required this.offsetY});

  final double offsetY;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    return FloatingActionButtonLocation.centerDocked
        .getOffset(scaffoldGeometry)
        .translate(0, offsetY);
  }
}
