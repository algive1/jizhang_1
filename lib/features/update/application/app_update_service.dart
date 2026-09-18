import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/shared_api.dart';

enum AppUpdateKind { none, optional, required }

class AppBuildInfo {
  const AppBuildInfo({
    required this.platform,
    required this.version,
    required this.build,
  });

  final String platform;
  final String version;
  final int build;
}

class AppUpdateDecision {
  const AppUpdateDecision({
    required this.kind,
    required this.currentVersion,
    required this.latestVersion,
    required this.minimumVersion,
    required this.storeUrl,
    this.message,
  });

  final AppUpdateKind kind;
  final String currentVersion;
  final String latestVersion;
  final String minimumVersion;
  final String storeUrl;
  final String? message;
}

abstract interface class AppUpdatePlatform {
  Future<AppBuildInfo> appInfo();
  Future<bool> openStore(String url);
}

class MethodChannelAppUpdatePlatform implements AppUpdatePlatform {
  const MethodChannelAppUpdatePlatform();

  static const _channel = MethodChannel('jizhang/app_update');

  @override
  Future<AppBuildInfo> appInfo() async {
    final raw = await _channel.invokeMapMethod<String, dynamic>('appInfo');
    if (raw == null) throw StateError('无法读取应用版本');
    final platform = raw['platform'];
    final version = raw['version'];
    final build = raw['build'];
    if (platform is! String || version is! String || build is! num) {
      throw const FormatException('应用版本信息无效');
    }
    return AppBuildInfo(
      platform: platform,
      version: version,
      build: build.toInt(),
    );
  }

  @override
  Future<bool> openStore(String url) async {
    return await _channel.invokeMethod<bool>(
          'openStore',
          {'url': url},
        ) ??
        false;
  }
}

class AppUpdateService {
  AppUpdateService(
    this._api,
    this._settings,
    this._platform, {
    this.minimumCheckInterval = const Duration(hours: 12),
  });

  static const _lastCheckKey = 'app.update.last_check.v1';

  final SharedApi _api;
  final AppSettingsRepository _settings;
  final AppUpdatePlatform _platform;
  final Duration minimumCheckInterval;

  Future<AppUpdateDecision?> checkIfDue({bool force = false}) async {
    if (!force) {
      final raw = await _settings.get(_lastCheckKey);
      final last = raw == null ? null : DateTime.tryParse(raw);
      if (last != null && DateTime.now().difference(last) < minimumCheckInterval) {
        return null;
      }
    }

    final app = await _platform.appInfo();
    if (app.platform != 'android' && app.platform != 'ios') return null;

    final response = await _api.request(
      '/app/update'
      '?platform=${Uri.encodeQueryComponent(app.platform)}'
      '&version=${Uri.encodeQueryComponent(app.version)}',
    );

    final status = response['status'];
    final latest = response['latestVersion'];
    final minimum = response['minimumVersion'];
    final storeUrl = response['storeUrl'];
    final message = response['message'];

    if (status is! String || latest is! String || minimum is! String) {
      throw const FormatException('版本更新响应无效');
    }

    await _settings.set(_lastCheckKey, DateTime.now().toIso8601String());

    final kind = switch (status) {
      'required' => AppUpdateKind.required,
      'optional' => AppUpdateKind.optional,
      _ => AppUpdateKind.none,
    };
    if (kind == AppUpdateKind.none) return null;
    if (storeUrl is! String || !storeUrl.startsWith('https://')) {
      throw const FormatException('更新地址无效');
    }

    return AppUpdateDecision(
      kind: kind,
      currentVersion: app.version,
      latestVersion: latest,
      minimumVersion: minimum,
      storeUrl: storeUrl,
      message: message is String && message.trim().isNotEmpty
          ? message.trim()
          : null,
    );
  }

  Future<bool> openStore(AppUpdateDecision decision) {
    return _platform.openStore(decision.storeUrl);
  }
}

final appUpdatePlatformProvider = Provider<AppUpdatePlatform>(
  (ref) => const MethodChannelAppUpdatePlatform(),
);

final appUpdateServiceProvider = Provider<AppUpdateService>((ref) {
  return AppUpdateService(
    ref.watch(sharedApiProvider),
    ref.watch(appSettingsRepositoryProvider),
    ref.watch(appUpdatePlatformProvider),
  );
});
