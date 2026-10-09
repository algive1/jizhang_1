import 'package:flutter/material.dart';

import 'app_profile_glass_card.dart';

/// Shared floating footer; the page backdrop continues through its safe area.
class AppBottomPanel extends StatelessWidget {
  const AppBottomPanel({
    required this.child,
    super.key,
    this.padding = const EdgeInsets.fromLTRB(12, 8, 12, 8),
  });

  final Widget child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) => SafeArea(
    top: false,
    minimum: const EdgeInsets.only(bottom: 4),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      child: AppProfileGlassCard(padding: padding, child: child),
    ),
  );
}
