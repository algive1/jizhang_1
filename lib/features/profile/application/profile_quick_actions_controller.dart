import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../settings/data/app_settings_repository.dart';

const _profileQuickActionOrderKey = 'profile.quickActions.order.v1';
const profileQuickActionLimit = 6;

const profileQuickActionDefaults = <String>[
  'books',
  'bill_import',
  'categories',
  'budgets',
  'appearance',
  'autobookkeeping',
];

const profileQuickActionAvailableIds = <String>[
  ...profileQuickActionDefaults,
  'assets',
  'family',
  'receipt_ocr',
  'finance_center',
  'recurring_bills',
  'data',
  'payment_notifications',
  'installments',
  'goals',
];

enum ProfileQuickActionToggleResult {
  added,
  removed,
  atLimit,
  minimumRequired,
}

class ProfileQuickActionsController extends AsyncNotifier<List<String>> {
  @override
  Future<List<String>> build() async {
    final raw = await ref
        .read(appSettingsRepositoryProvider)
        .get(_profileQuickActionOrderKey);
    if (raw == null || raw.trim().isEmpty) {
      return List.unmodifiable(profileQuickActionDefaults);
    }
    final normalized = _normalize(raw.split(','));
    return normalized.isEmpty
        ? List.unmodifiable(profileQuickActionDefaults)
        : normalized;
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

  Future<ProfileQuickActionToggleResult> toggle(String id) async {
    if (!profileQuickActionAvailableIds.contains(id)) {
      return ProfileQuickActionToggleResult.atLimit;
    }
    final current =
        state.value ?? List<String>.from(profileQuickActionDefaults);
    final next = List<String>.from(current);
    if (next.contains(id)) {
      if (next.length <= 1) {
        return ProfileQuickActionToggleResult.minimumRequired;
      }
      next.remove(id);
      await setOrder(next);
      return ProfileQuickActionToggleResult.removed;
    }
    if (next.length >= profileQuickActionLimit) {
      return ProfileQuickActionToggleResult.atLimit;
    }
    next.add(id);
    await setOrder(next);
    return ProfileQuickActionToggleResult.added;
  }

  Future<void> setOrder(Iterable<String> order) async {
    final previous =
        state.value ?? List<String>.from(profileQuickActionDefaults);
    final next = _normalize(order).take(profileQuickActionLimit).toList();
    if (next.isEmpty) return;
    final immutable = List<String>.unmodifiable(next);
    state = AsyncData(immutable);
    try {
      await ref
          .read(appSettingsRepositoryProvider)
          .set(_profileQuickActionOrderKey, immutable.join(','));
    } on Object {
      state = AsyncData(List.unmodifiable(previous));
      rethrow;
    }
  }

  List<String> _normalize(Iterable<String> values) {
    final seen = <String>{};
    final normalized = <String>[];
    for (final value in values) {
      if (!profileQuickActionAvailableIds.contains(value) || !seen.add(value)) {
        continue;
      }
      normalized.add(value);
    }
    return List.unmodifiable(normalized);
  }
}

final profileQuickActionsProvider =
    AsyncNotifierProvider<ProfileQuickActionsController, List<String>>(
      ProfileQuickActionsController.new,
    );
