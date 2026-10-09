import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../books/data/book_repository.dart';
import '../../settings/data/app_settings_repository.dart';

enum BudgetPreference { overspend, weeklyReview, smartAdvice }

String budgetPreferenceKey(String bookId, BudgetPreference preference) =>
    'budget.preferences.$bookId.${preference.name}';

class BudgetPreferences {
  const BudgetPreferences({
    this.overspend = true,
    this.weeklyReview = true,
    this.smartAdvice = true,
  });
  final bool overspend;
  final bool weeklyReview;
  final bool smartAdvice;
  bool enabled(BudgetPreference preference) => switch (preference) {
    BudgetPreference.overspend => overspend,
    BudgetPreference.weeklyReview => weeklyReview,
    BudgetPreference.smartAdvice => smartAdvice,
  };
  BudgetPreferences withValue(BudgetPreference preference, bool value) =>
      BudgetPreferences(
        overspend: preference == BudgetPreference.overspend ? value : overspend,
        weeklyReview: preference == BudgetPreference.weeklyReview
            ? value
            : weeklyReview,
        smartAdvice: preference == BudgetPreference.smartAdvice
            ? value
            : smartAdvice,
      );
}

class BudgetPreferencesController extends AsyncNotifier<BudgetPreferences> {
  @override
  Future<BudgetPreferences> build() async {
    final bookId = ref.watch(activeBookIdProvider);
    final settings = ref.watch(appSettingsRepositoryProvider);
    final values = await Future.wait([
      for (final preference in BudgetPreference.values)
        settings.get(budgetPreferenceKey(bookId, preference)),
    ]);
    return BudgetPreferences(
      overspend: values[0] != '0',
      weeklyReview: values[1] != '0',
      smartAdvice: values[2] != '0',
    );
  }

  Future<void> setEnabled(BudgetPreference preference, bool value) async {
    final bookId = ref.read(activeBookIdProvider);
    final previous = state.isLoading
        ? await future
        : state.value ?? await future;
    if (!ref.mounted || ref.read(activeBookIdProvider) != bookId)
      throw StateError('账本已切换');
    state = AsyncData(previous.withValue(preference, value));
    try {
      await ref
          .read(appSettingsRepositoryProvider)
          .set(budgetPreferenceKey(bookId, preference), value ? '1' : '0');
    } catch (_) {
      if (ref.mounted && ref.read(activeBookIdProvider) == bookId)
        state = AsyncData(
          (state.value ?? previous).withValue(
            preference,
            previous.enabled(preference),
          ),
        );
      rethrow;
    }
  }
}

final budgetPreferencesProvider =
    AsyncNotifierProvider<BudgetPreferencesController, BudgetPreferences>(
      BudgetPreferencesController.new,
    );
