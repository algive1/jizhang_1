import 'package:flutter/material.dart';

import '../../features/bookkeeping/presentation/quick_add_sheet.dart';
import '../../features/voice/presentation/voice_bookkeeping_sheet.dart';
import 'app_bottom_navigation.dart';
import 'quick_add_button.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({required this.location, required this.child, super.key});

  final String location;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBody: true,
      body: child,
      floatingActionButton: QuickAddButton(
        onPressed: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const QuickAddSheet(),
        ),
        onLongPress: () => showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.transparent,
          builder: (_) => const VoiceBookkeepingSheet(),
        ),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      bottomNavigationBar: AppBottomNavigation(location: location),
    );
  }
}
