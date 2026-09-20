import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/database_provider.dart';
import '../../../core/models/dashboard_snapshot.dart';
import '../../../core/models/transaction_record.dart';
import '../../budgets/data/budget_repository.dart';
import '../../insights/application/insight_feed_provider.dart';
import '../../insights/domain/insight_models.dart';
import '../../settings/data/app_settings_repository.dart';
import '../../transactions/data/transactions_repository.dart';

const _homeAmountHiddenSettingPrefix = 'home.amountsHidden.';

enum HomeAmountSection { today, goal, assets }

class HomeCardVisibility {
  const HomeCardVisibility({
    this.today = false,
    this.goal = false,
    this.assets = false,
  });

  final bool today;
  final bool goal;
  final bool assets;

  HomeCardVisibility set(HomeAmountSection section, bool hidden) {
    return switch (section) {
      HomeAmountSection.today => HomeCardVisibility(
        today: hidden,
        goal: goal,
        assets: assets,
      ),
      HomeAmountSection.goal => HomeCardVisibility(
        today: today,
        goal: hidden,
        assets: assets,
      ),
      HomeAmountSection.assets => HomeCardVisibility(
        today: today,
        goal: goal,
        assets: hidden,
      ),
    };
  }

  bool valueFor(HomeAmountSection section) => switch (section) {
    HomeAmountSection.today => today,
    HomeAmountSection.goal => goal,
    HomeAmountSection.assets => assets,
  };
}

class HomeCardVisibilityController
    extends Notifier<Map<String, HomeCardVisibility>> {
  final _loading = <String>{};

  @override
  Map<String, HomeCardVisibility> build() => const {};

  String _key(String bookId, HomeAmountSection section) =>
      'home.amountsHidden.${section.name}.$bookId';

  Future<void> ensureLoaded(String bookId) async {
    if (state.containsKey(bookId) || !_loading.add(bookId)) return;
    try {
      final settings = ref.read(appSettingsRepositoryProvider);
      final values = await Future.wait([
        settings.get(_key(bookId, HomeAmountSection.today)),
        settings.get(_key(bookId, HomeAmountSection.goal)),
        settings.get(_key(bookId, HomeAmountSection.assets)),
        settings.get('$_homeAmountHiddenSettingPrefix$bookId'),
      ]);
      if (state.containsKey(bookId)) return;
      final legacy = values[3] == '1';
      state = {
        ...state,
        bookId: HomeCardVisibility(
          today: values[0] == null ? legacy : values[0] == '1',
          goal: values[1] == null ? legacy : values[1] == '1',
          assets: values[2] == null ? legacy : values[2] == '1',
        ),
      };
    } finally {
      _loading.remove(bookId);
    }
  }

  Future<void> setHidden(
    String bookId,
    HomeAmountSection section,
    bool hidden,
  ) async {
    final previous = state[bookId] ?? const HomeCardVisibility();
    state = {...state, bookId: previous.set(section, hidden)};
    try {
      await ref
          .read(appSettingsRepositoryProvider)
          .set(_key(bookId, section), hidden ? '1' : '0');
    } on Object {
      state = {...state, bookId: previous};
    }
  }
}

final homeCardVisibilityProvider =
    NotifierProvider<
      HomeCardVisibilityController,
      Map<String, HomeCardVisibility>
    >(HomeCardVisibilityController.new);

class HomeAmountVisibilityController extends Notifier<Map<String, bool>> {
  final _loading = <String>{};

  @override
  Map<String, bool> build() => const {};

  Future<void> ensureLoaded(String bookId) async {
    if (state.containsKey(bookId) || !_loading.add(bookId)) return;
    try {
      final value = await ref
          .read(appSettingsRepositoryProvider)
          .get('$_homeAmountHiddenSettingPrefix$bookId');
      if (!state.containsKey(bookId)) {
        state = {...state, bookId: value == '1'};
      }
    } finally {
      _loading.remove(bookId);
    }
  }

  Future<void> setHidden(String bookId, bool hidden) async {
    final previous = state[bookId] ?? false;
    state = {...state, bookId: hidden};
    try {
      await ref
          .read(appSettingsRepositoryProvider)
          .set('$_homeAmountHiddenSettingPrefix$bookId', hidden ? '1' : '0');
    } on Object {
      state = {...state, bookId: previous};
    }
  }
}

final homeAmountVisibilityProvider =
    NotifierProvider<HomeAmountVisibilityController, Map<String, bool>>(
      HomeAmountVisibilityController.new,
    );

final dashboardSnapshotProvider = Provider<DashboardSnapshot>((ref) {
  final transactions = ref.watch(transactionsProvider).value ?? const [];
  final now = DateTime.now();
  final monthTransactions = transactions.where(
    (item) =>
        item.currency.toUpperCase() == 'CNY' &&
        item.deletedAt == null &&
        !item.occurredAt.isAfter(now) &&
        item.occurredAt.year == now.year &&
        item.occurredAt.month == now.month,
  );
  final income =
      monthTransactions
          .where((item) => item.isIncome)
          .fold<int>(0, (total, item) => total + (item.amount * 100).round()) /
      100;
  final spending =
      monthTransactions
          .where((item) => item.isConsumptionExpense)
          .fold<int>(
            0,
            (total, item) => total + (item.netExpenseAmount * 100).round(),
          ) /
      100;
  final forecastBalance = income - spending;
  final budgetOverview = ref.watch(budgetOverviewProvider);
  return DashboardSnapshot(
    safeToSpend: budgetOverview.total?.dailyAvailable ?? 0,
    forecastBalance: forecastBalance,
    hasBudget: budgetOverview.total != null,
    month: DateTime(now.year, now.month),
    income: income,
    expense: spending,
    budgetAmount: budgetOverview.total?.budget.amount ?? 0,
    availableAmount: budgetOverview.total?.remaining ?? 0,
    remainingDays: DateTime(now.year, now.month + 1, 0).day - now.day + 1,
    goalReservation: budgetOverview.total?.goalReservation ?? 0,
  );
});

final homeInsightProvider = Provider<FinancialInsightItem?>((ref) {
  return ref.watch(insightFeedProvider).homeCandidate;
});

const homeRecentTransactionLimit = 10;

final homeRecentTransactionsProvider = StreamProvider<List<TransactionRecord>>((
  ref,
) async* {
  await ref.watch(databaseBootstrapProvider.future);
  yield* ref
      .watch(transactionRepositoryProvider)
      .watchRecent(limit: homeRecentTransactionLimit);
});

class HomeMonthController extends Notifier<DateTime?> {
  @override
  DateTime? build() => null;
  void select(DateTime month) {
    final now = DateTime.now();
    final normalized = DateTime(month.year, month.month);
    if (normalized.isAfter(DateTime(now.year, now.month))) return;
    state = normalized == DateTime(now.year, now.month) ? null : normalized;
  }
}

final selectedHomeMonthProvider =
    NotifierProvider<HomeMonthController, DateTime?>(HomeMonthController.new);

MonthlyLedgerSummary monthlySummary(
  Iterable<TransactionRecord> records,
  DateTime month,
  DateTime now,
) {
  var income = 0;
  var expense = 0;
  for (final item in records) {
    if (item.deletedAt != null ||
        item.currency.toUpperCase() != 'CNY' ||
        item.occurredAt.isAfter(now) ||
        item.occurredAt.year != month.year ||
        item.occurredAt.month != month.month)
      continue;
    if (item.isIncome) income += (item.amount * 100).round();
    if (item.isConsumptionExpense)
      expense += (item.netExpenseAmount * 100).round();
  }
  return MonthlyLedgerSummary(
    month: DateTime(month.year, month.month),
    income: income / 100,
    expense: expense / 100,
  );
}

final homeMonthlySummaryProvider = Provider<MonthlyLedgerSummary>((ref) {
  final now = DateTime.now();
  return monthlySummary(
    ref.watch(transactionsProvider).value ?? [],
    ref.watch(selectedHomeMonthProvider) ?? now,
    now,
  );
});
