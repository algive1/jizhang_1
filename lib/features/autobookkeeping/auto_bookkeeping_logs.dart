import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart';

class AutoBookkeepingLogEntry {
  const AutoBookkeepingLogEntry({
    required this.timestamp,
    required this.stage,
    required this.detail,
  });

  final DateTime timestamp;
  final String stage;
  final String detail;

  factory AutoBookkeepingLogEntry.fromMap(Map<Object?, Object?> map) {
    final rawTimestamp = map['timestamp'];
    final timestamp = rawTimestamp is int
        ? DateTime.fromMillisecondsSinceEpoch(rawTimestamp)
        : DateTime.now();
    return AutoBookkeepingLogEntry(
      timestamp: timestamp,
      stage: map['stage']?.toString() ?? 'unknown',
      detail: map['detail']?.toString() ?? '',
    );
  }
}

class AutoBookkeepingLogsBridge {
  const AutoBookkeepingLogsBridge();

  static const _channel = MethodChannel('jizhang/autobookkeeping_logs');

  Future<List<AutoBookkeepingLogEntry>> getLogs() async {
    try {
      final result = await _channel.invokeMethod<List<Object?>>('get');
      return (result ?? const <Object?>[])
          .whereType<Map>()
          .map((item) {
            return AutoBookkeepingLogEntry.fromMap(
              Map<Object?, Object?>.from(item),
            );
          })
          .toList(growable: false);
    } on MissingPluginException {
      return const <AutoBookkeepingLogEntry>[];
    }
  }

  Future<void> recordDetailed(String stage, String detail) async {
    if (!kDebugMode) return;
    try {
      await _channel.invokeMethod<void>('recordDetailed', {
        'stage': stage,
        'detail': detail,
      });
    } on MissingPluginException {
      // Logs are Android-only; no-op on other platforms.
    } on PlatformException {
      // Diagnostics must never interrupt bookkeeping.
    }
  }

  Future<void> clear() async {
    try {
      await _channel.invokeMethod<void>('clear');
    } on MissingPluginException {
      // Logs are Android-only; no-op on other platforms.
    }
  }
}
