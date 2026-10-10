import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/membership.dart';
import '../app_runtime/data/app_runtime_repository.dart';
import '../membership/application/membership_feature_guard.dart';
import '../membership/data/membership_repository.dart';

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
    required this.notificationListenerConnected,
    required this.screenshotSupported,
    required this.screenshotEnabled,
    required this.ruleSchemaVersion,
    required this.ruleVersions,
    required this.ruleSource,
    this.miuiFamily = false,
    this.batteryOptimizationIgnored = false,
    this.backgroundRestricted = false,
    this.available = true,
  });

  final bool enabled;
  final bool accessibilityGranted;
  final bool accessibilityConnected;
  final bool overlayGranted;
  final bool notificationGranted;
  final bool foregroundRunning;
  final bool notificationListenerGranted;
  final bool notificationListenerEnabled;
  final bool notificationListenerConnected;
  final bool screenshotSupported;
  final bool screenshotEnabled;
  final int ruleSchemaVersion;
  final String ruleVersions;
  final String ruleSource;
  final bool miuiFamily;
  final bool batteryOptimizationIgnored;
  final bool backgroundRestricted;
  final bool available;

  bool get healthy => available && enabled && diagnosisIssues.isEmpty;
  String get summary => !available
      ? '无法读取服务状态，请重新检测'
      : !enabled
      ? '自动记账未开启'
      : healthy
      ? '自动记账运行正常'
      : diagnosisIssues.first;
  List<String> get diagnosisIssues => [
    if (!available) '无法读取权限状态，请重试',
    if (!accessibilityGranted)
      '无障碍权限未开启'
    else if (enabled && !accessibilityConnected)
      '无障碍已授权但服务未连接',
    if (!overlayGranted) '悬浮窗权限未开启',
    if (!notificationGranted) '通知权限或自动记账通知渠道未开启',
    if (!notificationListenerGranted)
      '支付通知读取权限未开启'
    else if (notificationListenerEnabled && !notificationListenerConnected)
      '支付通知监听已开启但未连接',
    if (enabled && !foregroundRunning) '自动记账服务未运行',
    if (backgroundRestricted) '系统限制后台运行',
  ];

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
      notificationListenerConnected: flag('notificationListenerConnected'),
      screenshotSupported: flag('screenshotSupported'),
      screenshotEnabled: flag('screenshotEnabled'),
      ruleSchemaVersion: (map['ruleSchemaVersion'] as num?)?.toInt() ?? 0,
      ruleVersions: map['ruleVersions']?.toString() ?? '',
      ruleSource: map['ruleSource']?.toString() ?? 'unknown',
      miuiFamily: flag('miuiFamily'),
      batteryOptimizationIgnored: flag('batteryOptimizationIgnored'),
      backgroundRestricted: flag('backgroundRestricted'),
    );
  }
}

abstract interface class AutoBookkeepingSettingsBridge {
  Future<bool> isAccessibilityGranted();
  Future<void> openAccessibilitySettings();
  Future<bool> isOverlayGranted();
  Future<void> openOverlaySettings();
  Future<void> openBackgroundSettings();
  Future<void> openAutoStartSettings();
  Future<void> reconnectNotificationListener();
  Future<bool> isEnabled();
  Future<bool> isNotificationGranted();
  Future<AutoBookkeepingRuntimeStatus> runtimeStatus();
  Future<bool> requestNotificationPermission();
  Future<bool> setScreenshotEnabled(bool enabled);
  Future<void> setEnabled(bool enabled);
}

class MethodChannelAutoBookkeepingSettings
    implements AutoBookkeepingSettingsBridge {
  const MethodChannelAutoBookkeepingSettings({this.beforeEnable});
  final Future<void> Function()? beforeEnable;

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
  Future<void> openBackgroundSettings() =>
      _invokeSettings('openBackgroundSettings');

  @override
  Future<void> openAutoStartSettings() =>
      _invokeSettings('openAutoStartSettings');

  @override
  Future<void> reconnectNotificationListener() =>
      _invokeSettings('reconnectNotificationListener');

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
          available: false,
          enabled: false,
          accessibilityGranted: false,
          accessibilityConnected: false,
          overlayGranted: false,
          notificationGranted: false,
          foregroundRunning: false,
          notificationListenerGranted: false,
          notificationListenerEnabled: false,
          notificationListenerConnected: false,
          screenshotSupported: false,
          screenshotEnabled: false,
          ruleSchemaVersion: 0,
          ruleVersions: '',
          ruleSource: 'unknown',
        );
      }
      return AutoBookkeepingRuntimeStatus.fromMap(raw);
    } on MissingPluginException {
      return const AutoBookkeepingRuntimeStatus(
        available: false,
        enabled: false,
        accessibilityGranted: false,
        accessibilityConnected: false,
        overlayGranted: false,
        notificationGranted: false,
        foregroundRunning: false,
        notificationListenerGranted: false,
        notificationListenerEnabled: false,
        notificationListenerConnected: false,
        screenshotSupported: false,
        screenshotEnabled: false,
        ruleSchemaVersion: 0,
        ruleVersions: '',
        ruleSource: 'unknown',
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
      return await _channel.invokeMethod<bool>(
            'requestNotificationPermission',
          ) ??
          false;
    } on MissingPluginException {
      throw StateError('自动记账仅支持 Android');
    }
  }

  @override
  Future<bool> setScreenshotEnabled(bool enabled) async {
    try {
      return await _channel.invokeMethod<bool>(
            'setScreenshotEnabled',
            enabled,
          ) ??
          false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  Future<void> setEnabled(bool enabled) async {
    if (enabled) await beforeEnable?.call();
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
  (ref) => MethodChannelAutoBookkeepingSettings(
    beforeEnable: () async {
      await ref
          .read(appRuntimeRepositoryProvider)
          .require(AppCapability.automaticBookkeeping);
      await requireMembershipFeature(
        ref.read(membershipFeatureAccessServiceProvider),
        MembershipFeature.automaticBookkeeping,
      );
    },
  ),
);

final autoBookkeepingRuntimeProvider =
    NotifierProvider<
      AutoBookkeepingRuntimeController,
      AsyncValue<AutoBookkeepingRuntimeStatus>
    >(AutoBookkeepingRuntimeController.new);

class AutoBookkeepingRuntimeController
    extends Notifier<AsyncValue<AutoBookkeepingRuntimeStatus>> {
  int _revision = 0;
  @override
  AsyncValue<AutoBookkeepingRuntimeStatus> build() => const AsyncLoading();

  Future<AutoBookkeepingRuntimeStatus?> refresh() async {
    final revision = ++_revision;
    try {
      final status = await ref
          .read(autoBookkeepingSettingsProvider)
          .runtimeStatus()
          .timeout(const Duration(seconds: 5));
      if (ref.mounted && revision == _revision) state = AsyncData(status);
    } on Object catch (error, stack) {
      if (ref.mounted && revision == _revision)
        state = AsyncError(error, stack);
    }
    return ref.mounted ? state.value : null;
  }
}
