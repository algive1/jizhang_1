import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/app_settings_repository.dart';
import '../../sharing/data/session_repository.dart';
import '../../sharing/data/shared_api.dart';
import '../domain/insight_models.dart';

const _intentsKey = 'insights.intents';
const _focusKey = 'insights.focus';
const _toneKey = 'insights.tone';
const _configuredKey = 'insights.configured';
const _dismissedKey = 'insights.dismissed';

class InsightPreferencesRepository {
  const InsightPreferencesRepository(
    this._settings,
    this._session,
    this._api,
  );

  final AppSettingsRepository _settings;
  final SessionRepository _session;
  final SharedApi _api;

  Future<InsightPreferences> load() async {
    final local = await _loadLocal();
    try {
      await _session.initialize();
      if (_session.userId == null || _api.sessionToken == null) return local;
      final remote = await _api
          .request('/insights/profile')
          .timeout(const Duration(seconds: 3));
      if (remote['configured'] != true) return local;
      final remoteIntents = (remote['intents'] as List? ?? const [])
          .whereType<String>()
          .toSet();
      final remoteFocus = (remote['focus'] as List? ?? const [])
          .whereType<String>()
          .toSet();
      final toneName = remote['tone'] as String?;
      final merged = local.copyWith(
        intents: BookkeepingIntent.values
            .where((item) => remoteIntents.contains(item.name))
            .toSet(),
        focus: InsightFocus.values
            .where((item) => remoteFocus.contains(item.name))
            .toSet(),
        tone: InsightTone.values
            .where((item) => item.name == toneName)
            .firstOrNull ?? local.tone,
        configured: true,
      );
      await _writeLocal(merged);
      return merged;
    } on SharedApiException catch (error) {
      if (error.status == 401) await _session.markSessionExpired();
      return local;
    } on Object {
      return local;
    }
  }

  Future<InsightPreferences> _loadLocal() async {
    final values = await Future.wait([
      _settings.get(_intentsKey),
      _settings.get(_focusKey),
      _settings.get(_toneKey),
      _settings.get(_configuredKey),
      _settings.get(_dismissedKey),
      for (final kind in FinancialInsightKind.values)
        _settings.get('insights.kindAdjustment.${kind.name}'),
    ]);
    final tones = InsightTone.values.where((item) => item.name == values[2]);
    return InsightPreferences(
      intents: _decode<BookkeepingIntent>(
        values[0],
        BookkeepingIntent.values,
      ),
      focus: _decode<InsightFocus>(values[1], InsightFocus.values),
      tone: tones.isEmpty ? InsightTone.balanced : tones.first,
      configured: values[3] == '1',
      dismissedIds: (values[4] ?? '')
          .split('|')
          .where((item) => item.trim().isNotEmpty)
          .toSet(),
      kindAdjustments: _kindAdjustments(values),
    );
  }


  Future<void> save(InsightPreferences value) async {
    await _writeLocal(value);
    unawaited(_syncProfile(value));
  }

  Future<void> _syncProfile(InsightPreferences value) async {
    try {
      await _session.initialize();
      if (_session.userId == null || _api.sessionToken == null) return;
      await _api
          .request(
            '/insights/profile',
            method: 'PUT',
            body: {
              'intents': value.intents.map((item) => item.name).toList(),
              'focus': value.focus.map((item) => item.name).toList(),
              'tone': value.tone.name,
              'configured': value.configured,
            },
          )
          .timeout(const Duration(seconds: 4));
    } on SharedApiException catch (error) {
      if (error.status == 401) await _session.markSessionExpired();
    } on Object {
      // Local settings remain authoritative while offline.
    }
  }

  Future<void> _writeLocal(InsightPreferences value) async {
    await Future.wait([
      _settings.set(_intentsKey, value.intents.map((e) => e.name).join(',')),
      _settings.set(_focusKey, value.focus.map((e) => e.name).join(',')),
      _settings.set(_toneKey, value.tone.name),
      _settings.set(_configuredKey, value.configured ? '1' : '0'),
      _settings.set(_dismissedKey, value.dismissedIds.join('|')),
      for (final kind in FinancialInsightKind.values)
        _settings.set(
          'insights.kindAdjustment.${kind.name}',
          (value.kindAdjustments[kind] ?? 0).toString(),
        ),
    ]);
  }

  Future<void> dismiss(String insightId) async {
    final current = await _loadLocal();
    await _writeLocal(
      current.copyWith(dismissedIds: {...current.dismissedIds, insightId}),
    );
    unawaited(_sendFeedback(insightId, null, 'dismissed'));
  }

  Future<void> recordFeedback(
    String insightId,
    FinancialInsightKind kind,
    String action,
  ) async {
    await _settings.set('insights.feedback.$insightId', action);
    final current = await _loadLocal();
    final previous = current.kindAdjustments[kind] ?? 0;
    final delta = switch (action) {
      'helpful' => 2.0,
      'inaccurate' => -4.0,
      _ => 0.0,
    };
    if (delta != 0) {
      final next = (previous + delta).clamp(-12, 12).toDouble();
      await _writeLocal(
        current.copyWith(
          kindAdjustments: {...current.kindAdjustments, kind: next},
        ),
      );
    }
    unawaited(_sendFeedback(insightId, kind, action));
  }

  Future<void> _sendFeedback(
    String insightId,
    FinancialInsightKind? kind,
    String action,
  ) async {
    try {
      await _session.initialize();
      if (_session.userId == null || _api.sessionToken == null) return;
      await _api
          .request(
            '/insights/${Uri.encodeComponent(insightId)}/feedback',
            method: 'POST',
            body: {
              'action': action,
              if (kind != null) 'kind': kind.name,
            },
          )
          .timeout(const Duration(seconds: 3));
    } on SharedApiException catch (error) {
      if (error.status == 401) await _session.markSessionExpired();
    } on Object {
      // Feedback is still persisted locally and can influence this device.
    }
  }

  Map<FinancialInsightKind, double> _kindAdjustments(
    List<String?> values,
  ) {
    final result = <FinancialInsightKind, double>{};
    for (var index = 0; index < FinancialInsightKind.values.length; index++) {
      final value = double.tryParse(values[5 + index] ?? '');
      if (value != null) result[FinancialInsightKind.values[index]] = value;
    }
    return result;
  }

  Set<T> _decode<T extends Enum>(String? value, List<T> all) {
    if (value == null || value.trim().isEmpty) return <T>{};
    final names = value.split(',').toSet();
    return all.where((item) => names.contains(item.name)).toSet();
  }
}

final insightPreferencesRepositoryProvider =
    Provider<InsightPreferencesRepository>((ref) {
  return InsightPreferencesRepository(
    ref.watch(appSettingsRepositoryProvider),
    ref.watch(sessionRepositoryProvider),
    ref.watch(sharedApiProvider),
  );
});

final insightPreferencesProvider = FutureProvider<InsightPreferences>((ref) {
  return ref.watch(insightPreferencesRepositoryProvider).load();
});
