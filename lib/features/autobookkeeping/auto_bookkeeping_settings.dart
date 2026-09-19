import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AutoBookkeepingRuntimeStatus {
  const AutoBookkeepingRuntimeStatus({
    required this.enabled,
    required this.accessibilityGranted,
    required this.accessibilityConnected,
    required this.overlayGranted,
    required this.notificationGranted,
    required this.foregroundRunning,
    required this.notificationListenerGranted,
    required this.notificationListenerEnabled,
  });

  final bool enabled;
  final bool accessibilityGranted;
  final bool accessibilityConnected;
  final bool overlayGranted;
  final bool notificationGranted;
  final bool foregroundRunning;
  final bool notificationListenerGranted;
  final bool notificationListenerEnabled;

  factory AutoBookkeepingRuntimeStatus.fromMap(Map<Object?, Object?> map) {
    bool flag(String key) => map[key] == true;
    return AutoBookkeepingRuntimeStatus(
      enabled: flag('enabled'),
      accessibilityGranted: flag('accessibilityGranted'),
      accessibilityConnected: flag('accessibilityConnected'),
      overlayGranted: flag('overlayGranted'),
      notificationGranted: flag('notificationGranted'),
      foregroundRunning: flag('foregroundRunning'),
      notificationListenerGranted: flag('notificationListenerGranted'),
      notificationListenerEnabled: flag('notificationListenerEnabled'),
    );
  }
}

abstract interface class AutoBookkeepingSettingsBridge {
  Future<bool> isAccessibilityGranted();
  Future<void> openAccessibilitySettings();
  Future<bool> isOverlayGranted();
  Future<void> openOverlaySettings();
  Future<bool> isEnabled();
  Future<bool> isNotificationGranted();
  Future<AutoBookkeepingRuntimeStatus> runtimeStatus();
  Future<bool> requestNotificationPermission();
  Future<void> setEnabled(bool enabled);
}

class MethodChannelAutoBookkeepingSettings
    implements AutoBookkeepingSettingsBridge {
  const MethodChannelAutoBookkeepingSettings();

  static const _channel = MethodChannel('jizhang/autobookkeeping');

  @override
  Future<bool> isAccessibilityGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isAccessibilityGranted') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openAccessibilitySettings() =>
      _invokeSettings('openAccessibilitySettings');

  @override
  Future<bool> isOverlayGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isOverlayGranted') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> openOverlaySettings() => _invokeSettings('openOverlaySettings');

  @override
  Future<bool> isEnabled() async {
    try {
      return await _channel.invokeMethod<bool>('isEnabled') ?? false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<AutoBookkeepingRuntimeStatus> runtimeStatus() async {
    try {
      final raw = await _channel.invokeMethod<Map<Object?, Object?>>(
        'runtimeStatus',
      );
      if (raw == null) {
        return const AutoBookkeepingRuntimeStatus(
          enabled: false,
          accessibilityGranted: false,
          accessibilityConnected: false,
          overlayGranted: false,
          notificationGranted: false,
          foregroundRunning: false,
          notificationListenerGranted: false,
          notificationListenerEnabled: false,
        );
      }
      return AutoBookkeepingRuntimeStatus.fromMap(raw);
    } on MissingPluginException {
      return const AutoBookkeepingRuntimeStatus(
        enabled: false,
        accessibilityGranted: false,
        accessibilityConnected: false,
        overlayGranted: false,
        notificationGranted: false,
        foregroundRunning: false,
        notificationListenerGranted: false,
        notificationListenerEnabled: false,
      );
    }
  }

  @override
  Future<bool> isNotificationGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationGranted') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<bool> requestNotificationPermission() async {
    try {
      return await _channel.invokeMethod<bool>('requestNotificationPermission') ??
          false;
    } on MissingPluginException {
      throw StateError('自动记账仅支持 Android');
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    try {
      await _channel.invokeMethod<void>('setEnabled', enabled);
    } on MissingPluginException {
      throw StateError('自动记账仅支持 Android');
    }
  }

  Future<void> _invokeSettings(String method) async {
    try {
      await _channel.invokeMethod<void>(method);
    } on MissingPluginException {
      throw StateError('自动记账仅支持 Android');
    }
  }
}

final autoBookkeepingSettingsProvider = Provider<AutoBookkeepingSettingsBridge>(
  (ref) => const MethodChannelAutoBookkeepingSettings(),
);
