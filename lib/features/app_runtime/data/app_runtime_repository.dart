import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/installation/installation_identity.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';

enum AppCapability {
  ai('aiEnabled', 'AI 服务'),
  ocr('ocrEnabled', '账单识别'),
  voice('voiceEnabled', '语音记账'),
  automaticBookkeeping('autoAccountingEnabled', '自动记账'),
  cloudBackup('cloudBackupEnabled', '云备份');

  const AppCapability(this.key, this.label);
  final String key;
  final String label;
}

class AppCapabilityUnavailable implements Exception {
  const AppCapabilityUnavailable(this.capability);
  final AppCapability capability;
  @override
  String toString() => '${capability.label}暂时关闭，请稍后重试';
}

class AppConfiguration {
  const AppConfiguration(this.flags, this.versions);
  const AppConfiguration.defaults() : flags = const {}, versions = const {};
  final Map<String, bool> flags;
  final Map<String, int> versions;
  bool allows(AppCapability capability) => flags[capability.key] ?? true;

  factory AppConfiguration.fromJson(Map<String, dynamic> response) {
    final documents = response['documents'];
    if (documents is! List || documents.length > 200) {
      throw const FormatException('应用配置响应无效');
    }
    final flags = <String, bool>{}, versions = <String, int>{};
    final sorted = <Map<String, dynamic>>[];
    for (final document in documents) {
      if (document is! Map) throw const FormatException('应用配置文档无效');
      final value = Map<String, dynamic>.from(document);
      final key = value['key'], version = value['version'];
      if (key is! String ||
          !RegExp(r'^[a-zA-Z0-9._-]{1,100}$').hasMatch(key) ||
          version is! int ||
          version < 1 ||
          versions.containsKey(key) ||
          value['payload'] is! Map) {
        throw const FormatException('应用配置版本无效');
      }
      versions[key] = version;
      sorted.add(value);
    }
    sorted.sort((a, b) => (a['key'] as String).compareTo(b['key'] as String));
    for (final document in sorted) {
      final payload = document['payload'] as Map;
      for (final capability in AppCapability.values) {
        if (!payload.containsKey(capability.key)) continue;
        final value = payload[capability.key];
        if (value is! bool) throw const FormatException('应用配置开关无效');
        flags[capability.key] = value;
      }
    }
    return AppConfiguration(
      Map.unmodifiable(flags),
      Map.unmodifiable(versions),
    );
  }
}

class AppOperation {
  const AppOperation({
    required this.id,
    required this.title,
    required this.body,
  });
  final String id;
  final String title;
  final String body;
  factory AppOperation.fromJson(Object? raw) {
    if (raw is! Map ||
        raw['id'] is! String ||
        raw['title'] is! String ||
        raw['body'] is! String ||
        (raw['id'] as String).isEmpty ||
        (raw['id'] as String).length > 100 ||
        (raw['title'] as String).trim().isEmpty ||
        (raw['body'] as String).trim().isEmpty ||
        (raw['title'] as String).length > 100 ||
        (raw['body'] as String).length > 4000) {
      throw const FormatException('帮助内容响应无效');
    }
    return AppOperation(id: raw['id'], title: raw['title'], body: raw['body']);
  }
}

class AppOperationsResult {
  const AppOperationsResult(
    this.items, {
    this.cached = false,
    this.unavailable = false,
  });
  final List<AppOperation> items;
  final bool cached;
  final bool unavailable;
}

/// Cache belongs to the backend origin. A successful empty publication replaces
/// the previous cache, so taking content offline and rolling versions back work.
class AppRuntimeRepository {
  AppRuntimeRepository(
    this.api,
    this.settings, {
    this.enabled = true,
    DateTime Function()? clock,
    this.refreshInterval = const Duration(minutes: 30),
    this.cacheLifetime = const Duration(days: 7),
  }) : _clock = clock ?? DateTime.now;

  final SharedApi api;
  final AppSettingsRepository settings;
  final bool enabled;
  final DateTime Function() _clock;
  final Duration refreshInterval;
  final Duration cacheLifetime;
  final _changes = StreamController<AppConfiguration>.broadcast();
  Future<AppConfiguration>? _refreshing;
  DateTime? _lastAttempt;
  DateTime? _configurationAt;
  AppConfiguration? _configuration;
  final Map<String, Future<AppOperationsResult>> _operationFlights = {};

  String _key(String name) =>
      'app.runtime.v1.${Uri.encodeComponent(api.baseUrl)}.$name';

  Future<({Map<String, dynamic> response, DateTime at})?> _cache(
    String name,
  ) async {
    try {
      final raw = await settings.get(_key(name));
      if (raw == null) return null;
      final json = jsonDecode(raw);
      if (json is! Map<String, dynamic>) return null;
      final date = DateTime.tryParse(json['at']?.toString() ?? '');
      if (date == null ||
          date.isAfter(_clock()) ||
          _clock().difference(date) > cacheLifetime)
        return null;
      return json['response'] is Map<String, dynamic>
          ? (response: json['response'] as Map<String, dynamic>, at: date)
          : null;
    } on Object {
      return null;
    }
  }

  Future<void> _save(String name, Map<String, dynamic> response) =>
      settings.set(
        _key(name),
        jsonEncode({
          'at': _clock().toUtc().toIso8601String(),
          'response': response,
        }),
      );

  Future<AppConfiguration> currentConfiguration() async {
    if (!enabled) return const AppConfiguration.defaults();
    if (_configuration != null &&
        _configurationAt != null &&
        !_configurationAt!.isAfter(_clock()) &&
        _clock().difference(_configurationAt!) <= cacheLifetime)
      return _configuration!;
    final cached = await _cache('config');
    try {
      _configurationAt = cached?.at ?? _clock();
      return _configuration = cached == null
          ? const AppConfiguration.defaults()
          : AppConfiguration.fromJson(cached.response);
    } on Object {
      return _configuration = const AppConfiguration.defaults();
    }
  }

  Stream<AppConfiguration> watchConfiguration() async* {
    yield await currentConfiguration();
    yield* _changes.stream;
  }

  Future<AppConfiguration> refreshConfiguration({bool force = false}) {
    if (_refreshing != null) return _refreshing!;
    final future = _refreshConfiguration(force: force);
    _refreshing = future;
    return future.whenComplete(() => _refreshing = null);
  }

  Future<AppConfiguration> _refreshConfiguration({required bool force}) async {
    final current = await currentConfiguration();
    if (!enabled ||
        (!force &&
            _lastAttempt != null &&
            !_lastAttempt!.isAfter(_clock()) &&
            _clock().difference(_lastAttempt!) < refreshInterval))
      return current;
    _lastAttempt = _clock();
    try {
      final id = await installationIdentity(settings);
      api.installationId = id;
      final response = await api.request('/app/config?installationId=$id');
      final parsed = AppConfiguration.fromJson(response);
      await _save('config', response);
      _configuration = parsed;
      _configurationAt = _clock();
      if (!_changes.isClosed) _changes.add(parsed);
      return parsed;
    } on Object {
      // Retry after a minute; preserve the last validated configuration offline.
      _lastAttempt = _clock().subtract(
        refreshInterval - const Duration(minutes: 1),
      );
      return current;
    }
  }

  Future<void> require(AppCapability capability) async {
    final config = await refreshConfiguration();
    if (!config.allows(capability)) throw AppCapabilityUnavailable(capability);
  }

  Future<AppOperationsResult> operations(String kind, {bool force = false}) {
    if (!{'faq', 'banner', 'activity'}.contains(kind))
      throw ArgumentError.value(kind);
    if (_operationFlights[kind] case final future?) return future;
    final future = _operations(kind, force: force);
    _operationFlights[kind] = future;
    return future.whenComplete(() => _operationFlights.remove(kind));
  }

  List<AppOperation> _parseOperations(Map<String, dynamic> response) {
    final items = response['items'];
    if (items is! List || items.length > 50)
      throw const FormatException('帮助内容响应无效');
    final parsed = items.map(AppOperation.fromJson).toList(growable: false);
    if (parsed.map((item) => item.id).toSet().length != parsed.length) {
      throw const FormatException('帮助内容重复');
    }
    return parsed;
  }

  Future<AppOperationsResult> _operations(
    String kind, {
    required bool force,
  }) async {
    if (!enabled) return const AppOperationsResult([]);
    final cache = await _cache(kind);
    try {
      if (!force &&
          cache != null &&
          _clock().difference(cache.at) < refreshInterval) {
        try {
          return AppOperationsResult(
            _parseOperations(cache.response),
            cached: true,
          );
        } on Object {
          /* Invalid cache is replaced from the server. */
        }
      }
      final response = await api.request('/app/operations?kind=$kind');
      final items = _parseOperations(response);
      await _save(kind, response);
      return AppOperationsResult(items);
    } on Object {
      try {
        if (cache != null)
          return AppOperationsResult(
            _parseOperations(cache.response),
            cached: true,
            unavailable: true,
          );
      } on Object {
        /* Invalid cache uses local help. */
      }
      return const AppOperationsResult([], unavailable: true);
    }
  }

  Future<void> dispose() => _changes.close();
}

final appRuntimeRepositoryProvider = Provider<AppRuntimeRepository>((ref) {
  final repository = AppRuntimeRepository(
    ref.watch(sharedApiProvider),
    ref.watch(appSettingsRepositoryProvider),
    enabled: const String.fromEnvironment('SHARED_API_BASE_URL').isNotEmpty,
  );
  ref.onDispose(repository.dispose);
  return repository;
});

final appConfigurationProvider = StreamProvider<AppConfiguration>(
  (ref) => ref.watch(appRuntimeRepositoryProvider).watchConfiguration(),
);

final appOperationsProvider =
    FutureProvider.family<AppOperationsResult, String>(
      (ref, kind) => ref.watch(appRuntimeRepositoryProvider).operations(kind),
    );
