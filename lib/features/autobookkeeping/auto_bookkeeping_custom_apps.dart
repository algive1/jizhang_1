import 'package:flutter/services.dart';

/// One app the user could hand to auto bookkeeping.
class LearnableApp {
  const LearnableApp({
    required this.packageName,
    required this.label,
    required this.added,
  });

  final String packageName;
  final String label;
  final bool added;

  factory LearnableApp.fromMap(Map<dynamic, dynamic> map) => LearnableApp(
        packageName: map['packageName'] as String? ?? '',
        label: map['label'] as String? ?? '',
        added: map['added'] == true,
      );
}

/// Apps the user added themselves.
///
/// Adding a package does two things on the native side: it makes the rule
/// registry resolve that package through the generic template, and it merges the
/// package into the accessibility service's runtime whitelist (the framework
/// only delivers events for packages named in `serviceInfo.packageNames`). Both
/// are why an app nobody shipped a rule for can still be recognised.
class AutoBookkeepingCustomApps {
  const AutoBookkeepingCustomApps._();

  static const _channel = MethodChannel('jizhang/autobookkeeping');

  /// Package names the user has added.
  static Future<List<String>> list() async {
    try {
      final raw = await _channel.invokeMethod<List<dynamic>>('listCustomApps');
      return raw?.whereType<String>().toList(growable: false) ?? const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Launchable apps matching [query]; empty query returns everything.
  static Future<List<LearnableApp>> searchInstalled([String query = '']) async {
    try {
      final raw = await _channel
          .invokeMethod<List<dynamic>>('searchInstalledApps', query);
      return raw
              ?.whereType<Map<dynamic, dynamic>>()
              .map(LearnableApp.fromMap)
              .where((app) => app.packageName.isNotEmpty)
              .toList(growable: false) ??
          const [];
    } on MissingPluginException {
      return const [];
    }
  }

  /// Returns false when the native side rejects the package id.
  static Future<bool> add(String packageName) async {
    try {
      return await _channel.invokeMethod<bool>('addCustomApp', packageName) ??
          false;
    } on MissingPluginException {
      return false;
    } on PlatformException {
      return false;
    }
  }

  static Future<void> remove(String packageName) async {
    try {
      await _channel.invokeMethod<void>('removeCustomApp', packageName);
    } on MissingPluginException {
      // Non-Android platform: nothing to remove.
    }
  }
}
