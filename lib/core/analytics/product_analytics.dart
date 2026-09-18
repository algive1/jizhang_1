import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../utils/entity_id.dart';
import '../../features/settings/data/app_settings_repository.dart';
import '../../features/sharing/data/session_repository.dart';
import '../../features/sharing/data/shared_api.dart';

class ProductAnalytics {
  ProductAnalytics(this._api, this._settings);

  static const enabledKey = 'analytics.enabled.v1';
  static const installationIdKey = 'analytics.installation_id.v1';
  static const queueKey = 'analytics.queue.v1';
  static const _allowedEvents = <String>{
    'app_open',
    'app_foreground',
    'screen_view',
    'bookkeeping_saved',
    'bookkeeping_updated',
  };
  static final _restrictedPropertyKey = RegExp(
    r'(amount|merchant|note|transaction|account|card|phone|path|attachment|token|password|category)',
    caseSensitive: false,
  );

  final SharedApi _api;
  final AppSettingsRepository _settings;
  bool _flushing = false;

  Future<bool> isEnabled() async {
    return await _settings.get(enabledKey) == 'true';
  }

  Future<void> setEnabled(bool enabled) async {
    await _settings.set(enabledKey, enabled ? 'true' : 'false');
    if (!enabled) {
      await _settings.set(queueKey, '[]');
      return;
    }
    await _installationId();
  }

  Future<void> track(
    String name, {
    String? screen,
    Map<String, Object?> properties = const {},
  }) async {
    if (!_allowedEvents.contains(name) || !await isEnabled()) return;

    final queue = await _readQueue();
    queue.add({
      'eventId': newEntityId(),
      'occurredAt': DateTime.now().millisecondsSinceEpoch ~/ 1000,
      'name': name,
      if (screen != null) 'screen': normalizeScreen(screen),
      'properties': _sanitizeProperties(properties),
    });
    if (queue.length > 100) {
      queue.removeRange(0, queue.length - 100);
    }
    await _writeQueue(queue);

    unawaited(
      flush().catchError((Object _) {
        // Product analytics is always best effort and must never block app use.
      }),
    );
  }

  Future<void> flush() async {
    if (_flushing || !await isEnabled()) return;
    final queue = await _readQueue();
    if (queue.isEmpty) return;

    _flushing = true;
    final batch = queue.take(50).toList(growable: false);
    try {
      await _api.request(
        '/analytics/events',
        method: 'POST',
        body: {
          'installationId': await _installationId(),
          'events': batch,
        },
      );
      final sentIds = batch.map((event) => event['eventId']).toSet();
      final latest = await _readQueue();
      latest.removeWhere((event) => sentIds.contains(event['eventId']));
      await _writeQueue(latest);
    } finally {
      _flushing = false;
    }
  }

  static String normalizeScreen(String value) {
    var screen = value.split('?').first.trim();
    if (screen.isEmpty) return '/';
    screen = screen.replaceFirst(
      RegExp(r'^/transactions/[^/]+$'),
      '/transactions/:transactionId',
    );
    screen = screen.replaceFirst(
      RegExp(r'^/goals/[^/]+$'),
      '/goals/:goalId',
    );
    screen = screen.replaceFirst(
      RegExp(r'^/profile/accounts/[^/]+$'),
      '/profile/accounts/:accountId',
    );
    screen = screen.replaceFirst(
      RegExp(r'^/profile/installments/[^/]+$'),
      '/profile/installments/:planId',
    );
    return screen.length <= 100 ? screen : screen.substring(0, 100);
  }

  Map<String, Object?> _sanitizeProperties(Map<String, Object?> source) {
    final output = <String, Object?>{};
    for (final entry in source.entries) {
      if (output.length >= 12) break;
      final key = entry.key.trim();
      if (key.isEmpty ||
          key.length > 32 ||
          _restrictedPropertyKey.hasMatch(key) ||
          !RegExp(r'^[a-zA-Z][a-zA-Z0-9_]*$').hasMatch(key)) {
        continue;
      }
      final value = entry.value;
      if (value is String) {
        output[key] = value.length <= 64 ? value : value.substring(0, 64);
      } else if (value is num && value.isFinite) {
        output[key] = value;
      } else if (value is bool || value == null) {
        output[key] = value;
      }
    }
    return output;
  }

  Future<String> _installationId() async {
    final current = (await _settings.get(installationIdKey))?.trim();
    if (current != null && RegExp(r'^[a-f0-9]{32}$').hasMatch(current)) {
      return current;
    }
    final created = newEntityId();
    await _settings.set(installationIdKey, created);
    return created;
  }

  Future<List<Map<String, Object?>>> _readQueue() async {
    final raw = await _settings.get(queueKey);
    if (raw == null || raw.trim().isEmpty) return <Map<String, Object?>>[];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return <Map<String, Object?>>[];
      return decoded
          .whereType<Map>()
          .map(
            (item) => item.map(
              (key, value) => MapEntry(key.toString(), value),
            ),
          )
          .toList(growable: true);
    } on Object {
      return <Map<String, Object?>>[];
    }
  }

  Future<void> _writeQueue(List<Map<String, Object?>> queue) {
    return _settings.set(queueKey, jsonEncode(queue));
  }
}

final productAnalyticsProvider = Provider<ProductAnalytics>((ref) {
  return ProductAnalytics(
    ref.watch(sharedApiProvider),
    ref.watch(appSettingsRepositoryProvider),
  );
});
