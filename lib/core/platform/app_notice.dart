import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../widgets/app_snack_bar.dart';

abstract final class AppNotice {
  static Future<void> show(BuildContext context, String message) async {
    try {
      final shown = await const MethodChannel('jizhang/notice_theme')
          .invokeMethod<bool>('show', {'message': message});
      if (shown == true) return;
    } on Object {
      // The in-app fallback also works when overlay permission is missing.
    }
    if (context.mounted) AppSnackBar.show(context, message);
  }
}
