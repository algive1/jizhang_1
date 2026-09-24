import 'package:flutter/material.dart';

import '../../app/theme/app_theme_tokens.dart';
import 'app_bottom_navigation.dart';

abstract final class AppSnackBar {
  static SnackBar build(BuildContext context, String message) {
    final bottomPadding = MediaQuery.paddingOf(context).bottom;
    final fabClearance =
        AppBottomNavigation.geometry.actionCenterFromBottom(bottomPadding) +
        AppNavGeometry.actionDiameter / 2 +
        8;
    return SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: EdgeInsets.fromLTRB(16, 0, 16, fabClearance),
      backgroundColor: context.appSurface,
      content: Text(
        message,
        style: TextStyle(
          color: context.appPrimaryText,
          fontWeight: FontWeight.w600,
        ),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      elevation: 4,
    );
  }

  static void show(BuildContext context, String message) {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (messenger == null) return;
    messenger.clearSnackBars();
    messenger.showSnackBar(build(context, message));
  }
}
