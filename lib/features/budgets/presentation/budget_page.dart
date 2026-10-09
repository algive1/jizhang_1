import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/models/budget.dart';
import '../../../core/widgets/app_bottom_sheet.dart';
import '../../books/data/book_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../../goals/presentation/goals_page.dart' show createGoalFromSheet;
import '../application/budget_alert_notification_service.dart';
import '../application/budget_weekly_review_service.dart';
import '../data/budget_period_provider.dart';
import '../data/budget_preferences_repository.dart';
import '../data/budget_repository.dart';
import '../domain/budget_period.dart';
import 'budget_editor.dart';
import 'budget_sections.dart';
import 'budget_sheets.dart';
import 'budget_visuals.dart';

class BudgetPage extends ConsumerStatefulWidget {
  const BudgetPage({super.key});
  @override
  ConsumerState<BudgetPage> createState() => _BudgetPageState();
}

class _BudgetPageState extends ConsumerState<BudgetPage> {
  BudgetPeriod _period = BudgetPeriod.month(DateTime.now());
  bool _routeHandled = false, _savingPreference = false, _editing = false;

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(budgetPeriodOverviewProvider(_period));
    final preferences = ref.watch(budgetPreferencesProvider);
    final goals = ref.watch(goalsProvider);
    final base = Theme.of(context);
    final theme = base.copyWith(
      brightness: Brightness.light,
      colorScheme: ColorScheme.fromSeed(
        seedColor: budgetGold,
        brightness: Brightness.light,
        surface: const Color(0xFFFFFAF1),
      ),
      scaffoldBackgroundColor: Colors.transparent,
      textTheme: base.textTheme.apply(
        bodyColor: budgetInk,
        displayColor: budgetInk,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: budgetGold,
          foregroundColor: Colors.white,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: budgetGold),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: Color(0xFFFFFAF1),
        surfaceTintColor: Colors.transparent,
      ),
    );
    return Theme(
      data: theme,
      child: Builder(
        builder: (page) {
          if (!_routeHandled &&
              data.hasValue &&
              GoRouter.maybeOf(page) != null) {
            _routeHandled = true;
            WidgetsBinding.instance.addPostFrameCallback(
              (_) => _handleRoute(page),
            );
          }
          return AnnotatedRegion<SystemUiOverlayStyle>(
            value: SystemUiOverlayStyle.light.copyWith(
              statusBarColor: Colors.transparent,
              systemNavigationBarColor: Colors.transparent,
              systemNavigationBarIconBrightness: Brightness.dark,
            ),
            child: Stack(
              children: [
                const Positioned.fill(child: BudgetBackground()),
                Scaffold(
                  backgroundColor: Colors.transparent,
                  body: SafeArea(
                    bottom: false,
                    child: Column(
                      children: [
                        SizedBox(
                          height: 46,
                          child: Row(
                            children: [
                              SizedBox(
                                width: 44,
                                child: IconButton(
                                  tooltip: '返回',
                                  icon: const Icon(
                                    Icons.chevron_left_rounded,
                                    size: 28,
                                    color: Colors.white,
                                  ),
                                  onPressed: () {
                                    final router = GoRouter.maybeOf(page);
                                    if (router?.canPop() ?? false) {
                                      router!.pop();
                                    } else if (router != null) {
                                      router.go('/profile');
                                    } else {
                                      Navigator.maybePop(page);
                                    }
                                  },
                                ),
                              ),
                              Expanded(
                                child: Text(
                                  '预算与目标',
                                  textAlign: TextAlign.center,
                                  style: budgetText(
                                    18,
                                    weight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 44),
                            ],
                          ),
                        ),
                        Expanded(
                          child: BackdropGroup(
                            child: data.when(
                              data: (overview) => ListView(
                                key: const ValueKey('budget-scroll'),
                                padding: const EdgeInsets.fromLTRB(6, 4, 6, 8),
                                children: [
                                  BudgetOverviewCard(
                                    data: overview,
                                    onDate: () => _selectDate(page),
                                    onPeriod: (kind) =>
                                        _selectPeriod(page, kind),
                                  ),
                                  const SizedBox(height: 7),
                                  CategoryBudgetSection(
                                    rows: overview.overview.categories,
                                    onMore: () => _showCategories(page),
                                    onEdit: (row) => _edit(
                                      page,
                                      categoryId: row.budget.categoryId,
                                    ),
                                    onRemove: (row) => _remove(page, row),
                                  ),
                                  const SizedBox(height: 7),
                                  SavingsGoalsSection(
                                    goals: goals.value ?? [],
                                    onMore: () => page.push('/goals'),
                                    onGoal: (goal) =>
                                        page.push('/goals/${goal.id}'),
                                    onCreate: () =>
                                        createGoalFromSheet(page, ref),
                                  ),
                                  const SizedBox(height: 7),
                                  if (preferences.hasValue &&
                                      !preferences.isLoading)
                                    ReminderStrategySection(
                                      preferences: preferences.value!,
                                      busy: _savingPreference,
                                      onChanged: (preference, enabled) =>
                                          _setPreference(
                                            page,
                                            preference,
                                            enabled,
                                          ),
                                      onSettings: () => _showSettings(page),
                                      onReview: () =>
                                          showBudgetWeeklyReviews(page),
                                    )
                                  else
                                    BudgetSurface(
                                      padding: const EdgeInsets.all(16),
                                      child: preferences.hasError
                                          ? TextButton(
                                              onPressed: () => ref.invalidate(
                                                budgetPreferencesProvider,
                                              ),
                                              child: const Text(
                                                '提醒设置读取失败，点击重试',
                                              ),
                                            )
                                          : const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                    ),
                                  BudgetAdviceBanner(
                                    data: overview,
                                    enabled:
                                        preferences.value?.smartAdvice ?? false,
                                    onDetails: () =>
                                        preferences.value?.smartAdvice == true
                                        ? showBudgetAdviceDetails(
                                            page,
                                            overview,
                                          )
                                        : _showSettings(page),
                                  ),
                                ],
                              ),
                              loading: () => const Center(
                                child: CircularProgressIndicator(
                                  color: Colors.white,
                                ),
                              ),
                              error: (_, _) => Center(
                                child: Padding(
                                  padding: const EdgeInsets.all(24),
                                  child: BudgetSurface(
                                    padding: const EdgeInsets.all(20),
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          '预算暂时无法读取',
                                          style: budgetText(
                                            16,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                        const SizedBox(height: 12),
                                        FilledButton(
                                          onPressed: _retry,
                                          child: const Text('重新加载'),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SafeArea(
                          top: false,
                          minimum: const EdgeInsets.fromLTRB(6, 0, 6, 6),
                          child: Row(
                            children: [
                              Expanded(
                                flex: 49,
                                child: BudgetActionButton(
                                  label: '新增目标',
                                  onTap: () => createGoalFromSheet(page, ref),
                                ),
                              ),
                              const SizedBox(width: 5),
                              Expanded(
                                flex: 51,
                                child: BudgetActionButton(
                                  label: '编辑预算',
                                  primary: true,
                                  onTap: () => _edit(page),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  void _retry() {
    ref.invalidate(budgetPeriodBudgetsProvider(_period));
    ref.invalidate(budgetPeriodTransactionsProvider(_period));
    ref.invalidate(allCategoriesProvider);
    ref.invalidate(goalsProvider);
    ref.invalidate(budgetPeriodOverviewProvider(_period));
  }

  Future<void> _handleRoute(BuildContext page) async {
    if (!mounted) return;
    final uri = GoRouterState.of(page).uri;
    if (uri.queryParameters['review'] == '1') {
      try {
        final bookId = uri.queryParameters['bookId'];
        if (bookId != null && bookId != ref.read(activeBookIdProvider)) {
          await ref.read(activeBookIdProvider.notifier).select(bookId);
        }
        if (page.mounted) await showBudgetWeeklyReviews(page);
      } on Object {
        if (page.mounted)
          ScaffoldMessenger.of(page)
              .showSnackBar(const SnackBar(content: Text('该账本暂不可用，请选择可访问的账本')));
      }
    } else if (uri.queryParameters['recommend'] == '1' &&
        uri.queryParameters['categoryId'] != null) {
      await _edit(page, categoryId: uri.queryParameters['categoryId']);
      if (page.mounted) page.replace('/profile/budgets');
    }
  }

  Future<void> _selectDate(BuildContext page) async {
    if (_period.kind == BudgetPeriodKind.custom) {
      await _selectPeriod(page, BudgetPeriodKind.custom);
      return;
    }
    final date = await showBudgetMonthPicker(
      page,
      _period.start,
      yearOnly: _period.kind == BudgetPeriodKind.year,
    );
    if (date != null && mounted)
      setState(
        () => _period = _period.kind == BudgetPeriodKind.year
            ? BudgetPeriod.year(date)
            : BudgetPeriod.month(date),
      );
  }

  Future<void> _selectPeriod(BuildContext page, BudgetPeriodKind kind) async {
    if (kind == BudgetPeriodKind.custom) {
      final range = await showDateRangePicker(
        context: page,
        firstDate: DateTime(1900),
        lastDate: DateTime(DateTime.now().year + 10, 12, 31),
        helpText: '选择预算日期范围',
        saveText: '确认',
        initialDateRange: DateTimeRange(
          start: _period.start,
          end: DateTime(
            _period.end.year,
            _period.end.month,
            _period.end.day - 1,
          ),
        ),
      );
      if (range != null && mounted)
        setState(
          () => _period = BudgetPeriod(
            range.start,
            DateTime(range.end.year, range.end.month, range.end.day + 1),
            kind,
          ),
        );
    } else if (mounted) {
      setState(
        () => _period = kind == BudgetPeriodKind.year
            ? BudgetPeriod.year(_period.start)
            : BudgetPeriod.month(_period.start),
      );
    }
  }

  Future<void> _edit(
    BuildContext page, {
    String? categoryId,
    bool addCategory = false,
  }) async {
    if (_editing) return;
    _editing = true;
    try {
      final month = _period.kind == BudgetPeriodKind.month
          ? _period.start
          : await showBudgetMonthPicker(page, _period.start);
      if (month != null && page.mounted)
        await showBudgetEditor(
          page,
          ref,
          month: month,
          categoryId: categoryId,
          categoryBudget: addCategory,
        );
    } finally {
      _editing = false;
    }
  }

  Future<void> _remove(BuildContext page, BudgetProgress row) async {
    final month = _period.kind == BudgetPeriodKind.month
        ? _period.start
        : await showBudgetMonthPicker(page, _period.start);
    if (month == null || !page.mounted) return;
    final repository = ref.read(budgetRepositoryProvider);
    final bookId = ref.read(activeBookIdProvider);
    try {
      final actual = (await repository.getMonth(budgetMonthKey(month)))
          .where((b) => b.categoryId == row.budget.categoryId)
          .firstOrNull;
      if (actual == null || !page.mounted) return;
      if (await AppConfirmDialog.show(
            page,
            title: '移除预算？',
            message: '移除 ${month.year}年${month.month}月的分类预算，已有流水保留。',
          ) &&
          page.mounted &&
          ref.read(activeBookIdProvider) == bookId)
        await repository.removeBudget(actual.id);
    } on Object {
      if (page.mounted)
        ScaffoldMessenger.of(page)
            .showSnackBar(const SnackBar(content: Text('预算移除失败，请重试')));
    }
  }

  Future<void> _showCategories(BuildContext page) => showModalBottomSheet<void>(
    context: page,
    useRootNavigator: true,
    isScrollControlled: true,
    builder: (sheet) => SafeArea(
      child: SizedBox(
        height: MediaQuery.sizeOf(sheet).height * .78,
        child: Consumer(
          builder: (context, ref, _) => Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 12, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '分类预算 · ${_period.label}',
                        style: budgetText(16, weight: FontWeight.w700),
                      ),
                    ),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(sheet);
                        _edit(page, addCategory: true);
                      },
                      child: const Text('添加'),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ref
                    .watch(budgetPeriodOverviewProvider(_period))
                    .when(
                      data: (value) => ListView.separated(
                        padding: const EdgeInsets.all(12),
                        itemCount: value.overview.categories.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 6),
                        itemBuilder: (_, i) {
                          final row = value.overview.categories[i];
                          return CategoryBudgetRow(
                            progress: row,
                            onTap: () {
                              Navigator.pop(sheet);
                              _edit(page, categoryId: row.budget.categoryId);
                            },
                            onLongPress: () {
                              Navigator.pop(sheet);
                              _remove(page, row);
                            },
                          );
                        },
                      ),
                      loading: () =>
                          const Center(child: CircularProgressIndicator()),
                      error: (_, _) => const Center(child: Text('分类预算读取失败')),
                    ),
              ),
            ],
          ),
        ),
      ),
    ),
  );

  Future<void> _setPreference(
    BuildContext page,
    BudgetPreference preference,
    bool enabled,
  ) async {
    if (_savingPreference) return;
    setState(() => _savingPreference = true);
    try {
      await ref
          .read(budgetPreferencesProvider.notifier)
          .setEnabled(preference, enabled);
      if (enabled && preference != BudgetPreference.smartAdvice)
        await ref
            .read(budgetAlertNotificationServiceProvider)
            .requestPermission();
      if (!mounted) return;
      if (preference == BudgetPreference.weeklyReview)
        ref.invalidate(budgetWeeklyReviewsProvider);
      if (enabled && preference == BudgetPreference.overspend)
        await ref
            .read(budgetAlertNotificationServiceProvider)
            .sync(ref.read(budgetOverviewProvider));
    } catch (_) {
      if (page.mounted)
        ScaffoldMessenger.of(page)
            .showSnackBar(const SnackBar(content: Text('设置保存失败，请重试')));
    } finally {
      if (mounted) setState(() => _savingPreference = false);
    }
  }

  Future<void> _showSettings(BuildContext page) => showBudgetSettings(
    page,
    onChanged: (preference, enabled) =>
        _setPreference(page, preference, enabled),
  );
}
