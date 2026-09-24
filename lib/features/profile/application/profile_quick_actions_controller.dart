import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/app_settings_repository.dart';

const _profileQuickActionOrderKey = 'profile.quickActions.order.v1';

const profileQuickActionDefaults = <String>[
  'books',
  'bill_import',
  'categories',
  'budgets',
  'appearance',
  'autobookkeeping',
];

class ProfileQuickActionsController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final raw = await ref
        .read(appSettingsRepositoryProvider)
        .get(_profileQuickActionOrderKey);
    if (raw == null || raw.trim().isEmpty) {
      return List.unmodifiable(profileQuickActionDefaults);
    }
    return _normalize(raw.split(','));
  }

  Future<void> reorder(int oldIndex, int newIndex) async {
    final current =
        state.value ?? List<String>.from(profileQuickActionDefaults);
    if (oldIndex < 0 || oldIndex >= current.length) return;
    final destination = newIndex.clamp(0, current.length - 1).toInt();

    final next = List<String>.from(current);
    final item = next.removeAt(oldIndex);
    next.insert(destination, item);
    await setOrder(next);
  }

  Future<void> setOrder(Iterable<String> order) async {
    final previous =
        state.value ?? List<String>.from(profileQuickActionDefaults);
    final next = _normalize(order);
    state = AsyncData(next);
    try {
      await ref
          .read(appSettingsRepositoryProvider)
          .set(_profileQuickActionOrderKey, next.join(','));
    } on Object {
      state = AsyncData(List.unmodifiable(previous));
      rethrow;
    }
  }

  List<String> _normalize(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      if (!profileQuickActionDefaults.contains(value) || !seen.add(value)) {
        continue;
      }
      normalized.add(value);
    }
    for (final value in profileQuickActionDefaults) {
      if (seen.add(value)) normalized.add(value);
    }
    return List.unmodifiable(normalized);
  }
}

final profileQuickActionsProvider =
    AsyncNotifierProvider<ProfileQuickActionsController, List<String>>(
      ProfileQuickActionsController.new,
    );
