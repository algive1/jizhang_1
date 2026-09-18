import 'dart:async';
import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/settings/data/app_settings_repository.dart';
import '../../features/sharing/data/shared_api.dart';
import '../../features/sharing/data/session_repository.dart';

/// A small local ring buffer for operational diagnostics.
///
/// It deliberately stores event metadata rather than notification contents,
/// account identifiers, attachment paths, or stack traces. Upload is best
/// effort and only happens after the shared API has an authenticated session.
class OperationLogService {
  OperationLogService(this._settings, this._api);

  static const pendingKey = 'diagnostics.pending.v1';
  static const maxPending = 200;
  static int _sequence = 0;

  final AppSettingsRepository _settings;
  final SharedApi _api;
  Future<void> _writeQueue = Future<void>.value();
  bool _flushing = false;

  Future<void> record({
    required String kind,
    String level = 'info',
    String? screen,
    String? message,
    Map<String, Object?> data = const {},
  }) {
    final operation = _writeQueue = _writeQueue
        .then((_) async {
          final events = await _read();
          final now = DateTime.now();
          final event = <String, Object?>{
            'event_id': '${now.microsecondsSinceEpoch}-${_sequence++}',
            'occurred_at': now.millisecondsSinceEpoch ~/ 1000,
            'level': level == 'warn' || level == 'error' ? level : 'info',
            'kind': _limit(kind.trim().isEmpty ? 'unknown' : kind.trim(), 64),
            if (screen != null && screen.trim().isNotEmpty)
              'screen': _limit(screen.trim(), 120),
            if (message != null && message.trim().isNotEmpty)
              'message': _limit(message.trim(), 500),
            'data': _sanitize(data),
          };
          events.add(event);
          if (events.length > maxPending) {
            events.removeRange(0, events.length - maxPending);
          }
          await _settings.set(pendingKey, jsonEncode(events));
        })
        .catchError((_) {
          // A widget/provider can be disposed while a best-effort diagnostic
          // write is in flight. Logging must never surface a second error.
        });
    unawaited(operation.then((_) => flush()));
    return operation;
  }

  Future<void> flush() async {
    if (_flushing || _api.sessionToken == null) return;
    _flushing = true;
    try {
      final events = await _read();
      if (events.isEmpty || _api.sessionToken == null) return;
      final response = await _api.request(
        '/diagnostics/events',
        method: 'POST',
        body: {'events': events},
      );
      if (response['accepted'] is num || response['duplicates'] is num) {
        final ids = events.map((event) => event['event_id']).toSet();
        final remaining = (await _read())
            .where((event) => !ids.contains(event['event_id']))
            .toList(growable: false);
        await _settings.set(pendingKey, jsonEncode(remaining));
      }
    } on Object {
      // Keep the queue for a later authenticated/network-available attempt.
    } finally {
      _flushing = false;
    }
  }

  Future<List<Map<String, Object?>>> pendingEvents() => _read();

  Future<List<Map<String, Object?>>> _read() async {
    final raw = await _settings.get(pendingKey);
    if (raw == null || raw.isEmpty) return [];
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return [];
      return [
        for (final item in decoded)
          if (item is Map)
            item.map((key, value) => MapEntry(key.toString(), value)),
      ].cast<Map<String, Object?>>();
    } on Object {
      return [];
    }
  }

  Map<String, Object?> _sanitize(Map<String, Object?> data) {
    final result = <String, Object?>{};
    for (final entry in data.entries) {
      if (!RegExp(
        r'^(?!.*(token|password|notification|account|card|phone|path|stack))[a-zA-Z][a-zA-Z0-9_]{0,31}$',
        caseSensitive: false,
      ).hasMatch(entry.key)) {
        continue;
      }
      final value = entry.value;
      if (value == null || value is bool || value is num) {
        result[entry.key] = value;
      } else if (value is String) {
        result[entry.key] = _limit(value, 160);
      }
      if (result.length >= 24) break;
    }
    return result;
  }

  String _limit(String value, int max) =>
      value.length <= max ? value : value.substring(0, max);
}

final operationLogServiceProvider = Provider<OperationLogService>((ref) {
  return OperationLogService(
    ref.watch(appSettingsRepositoryProvider),
    ref.watch(sharedApiProvider),
  );
});
