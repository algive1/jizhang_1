import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

abstract final class AppNoticeTheme {
  static (int, int)? _lastColors;

  static void sync(ThemeData theme) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    final colors = (
      theme.colorScheme.surface.toARGB32(),
      theme.colorScheme.onSurface.toARGB32(),
    );
    if (_lastColors == colors) return;
    _lastColors = colors;
    const MethodChannel('jizhang/notice_theme')
        .invokeMethod<void>('setColors', {
          'background': colors.$1,
          'foreground': colors.$2,
        })
        .catchError((Object _) {});
  }
}
