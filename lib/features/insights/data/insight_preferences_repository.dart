import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/app_settings_repository.dart';
import '../domain/insight_models.dart';

const _intentsKey = 'insights.intents';
const _focusKey = 'insights.focus';
const _toneKey = 'insights.tone';
const _configuredKey = 'insights.configured';
const _dismissedKey = 'insights.dismissed';

class InsightPreferencesRepository {
  const InsightPreferencesRepository(this._settings);

  final AppSettingsRepository _settings;

  Future<InsightPreferences> load() async {
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
      kindAdjustments: {
        for (var index = 0; index < FinancialInsightKind.values.length; index++)
          if (double.tryParse(values[5 + index] ?? '') case final value?)
            FinancialInsightKind.values[index]: value,
      },
    );
  }

  Future<void> save(InsightPreferences value) async {
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
    final current = await load();
    await save(
      current.copyWith(dismissedIds: {...current.dismissedIds, insightId}),
    );
  }

  Future<void> recordFeedback(
    String insightId,
    FinancialInsightKind kind,
    String action,
  ) async {
    await _settings.set('insights.feedback.$insightId', action);
    final current = await load();
    final previous = current.kindAdjustments[kind] ?? 0;
    final delta = switch (action) {
      'helpful' => 2.0,
      'inaccurate' => -4.0,
      _ => 0.0,
    };
    if (delta == 0) return;
    final next = (previous + delta).clamp(-12, 12).toDouble();
    await save(
      current.copyWith(
        kindAdjustments: {...current.kindAdjustments, kind: next},
      ),
    );
  }

  Set<T> _decode<T extends Enum>(String? value, List<T> all) {
    if (value == null || value.trim().isEmpty) return <T>{};
    final names = value.split(',').toSet();
    return all.where((item) => names.contains(item.name)).toSet();
  }
}

final insightPreferencesRepositoryProvider =
    Provider<InsightPreferencesRepository>((ref) {
  return InsightPreferencesRepository(ref.watch(appSettingsRepositoryProvider));
});

final insightPreferencesProvider = FutureProvider<InsightPreferences>((ref) {
  return ref.watch(insightPreferencesRepositoryProvider).load();
});
