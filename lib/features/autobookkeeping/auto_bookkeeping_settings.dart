import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

abstract interface class AutoBookkeepingSettingsBridge {
  Future<bool> isAccessibilityGranted();
  Future<void> openAccessibilitySettings();
  Future<bool> isOverlayGranted();
  Future<void> openOverlaySettings();
  Future<bool> isEnabled();
  Future<bool> isNotificationGranted();
  Future<void> requestNotificationPermission();
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
  Future<bool> isNotificationGranted() async {
    try {
      return await _channel.invokeMethod<bool>('isNotificationGranted') ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> requestNotificationPermission() =>
      _invokeSettings('requestNotificationPermission');

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
