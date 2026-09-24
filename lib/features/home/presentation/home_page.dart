import '../../assistant/presentation/assistant_entry_button.dart';

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/database/database_provider.dart';
import '../../../core/formatters/book_title_formatter.dart';
import '../../../core/formatters/transaction_date_formatter.dart';
import '../../books/presentation/book_selector.dart';
import '../../books/data/book_repository.dart';
import '../../sharing/application/shared_book_sync_service.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/dashboard_snapshot.dart';
import '../../../core/models/goal.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/membership_button.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../analysis/domain/statistical_analysis_service.dart';
import '../../budgets/data/budget_repository.dart';
import '../../accounts/data/account_repository.dart';
import '../../accounts/data/account_management_repository.dart';
import '../../investments/data/investment_repository.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../goals/data/goal_repository.dart';
import '../../insights/application/insight_feed_provider.dart';
import '../../insights/data/insight_preferences_repository.dart';
import '../../insights/domain/insight_models.dart';
import '../../insights/presentation/insight_preferences_sheet.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';
import '../data/home_data.dart';
import 'home_cards.dart';
import 'home_asset_card.dart';
import 'home_insight_drawer.dart';
import 'home_expense_trend.dart';
import 'home_promotional_cards.dart';

class HomePage extends ConsumerStatefulWidget {
  const HomePage({super.key});
  @override
  ConsumerState<HomePage> createState() => _HomePageState();
}

class _HomePageState extends ConsumerState<HomePage>
    with WidgetsBindingObserver {
  Timer? _dayTimer;
  DateTime _day = DateUtils.dateOnly(DateTime.now());
  bool _insightPreferencePromptScheduled = false;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _scheduleRefresh();
  }

  void _scheduleRefresh() {
    _dayTimer?.cancel();
    final now = DateTime.now();
    _dayTimer = Timer(
      DateTime(now.year, now.month, now.day + 1).difference(now),
      _refreshDay,
    );
  }

  void _refreshDay() {
    final today = DateUtils.dateOnly(DateTime.now());
    if (today != _day) {
      _day = today;
      ref.invalidate(currentMonthBudgetsProvider);
      ref.invalidate(budgetOverviewProvider);
      ref.invalidate(dashboardSnapshotProvider);
      ref.invalidate(homeMonthlySummaryProvider);
      ref.invalidate(homeRecentTransactionsProvider);
      ref.invalidate(analysisRepositoryProvider);
      ref.invalidate(insightFeedProvider);
      if (mounted) setState(() {});
    }
    _scheduleRefresh();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshDay();
  }

  @override
  void dispose() {
    _dayTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _analysis() {
    ref
        .read(analysisPeriodProvider.notifier)
        .select(AnalysisPeriod.currentMonth);
    ref.read(analysisCurrencyProvider.notifier).select('CNY');
    context.push('/analysis');
  }

  @override
  Widget build(BuildContext context) {
    final booksState = ref.watch(booksProvider);
    final book = ref.watch(activeBookProvider);
    final insightPreferencesAsync = ref.watch(insightPreferencesProvider);
    final cardVisibility = ref.watch(homeCardVisibilityProvider);
    if (book != null) {
      ref.read(homeCardVisibilityProvider.notifier).ensureLoaded(book.id);
    }
    final visibility = book == null
        ? const HomeCardVisibility()
        : cardVisibility[book.id] ?? const HomeCardVisibility();
    final sharedState = ref.watch(activeSharedStateProvider).value;
    final goalsState = ref.watch(goalsProvider);
    final goal = (goalsState.value ?? const <Goal>[])
        .where((g) => g.status == GoalStatus.active)
        .firstOrNull;
    final transactions = ref.watch(transactionsProvider);
    final budgets = ref.watch(currentMonthBudgetsProvider);
    final snapshot = ref.watch(dashboardSnapshotProvider);
    final analysis = ref
        .watch(analysisRepositoryProvider)
        .analyze(period: AnalysisPeriod.currentMonth);
    final insightFeed = ref.watch(insightFeedProvider);
    final insight = ref.watch(homeInsightProvider);
    final recentState = ref.watch(homeRecentTransactionsProvider);
    final recent = recentState.value ?? const <TransactionRecord>[];
    final accountsState = ref.watch(allAccountsProvider);
    final accounts = accountsState.value ?? const [];
    final excludedAssetAccountIds =
        ref.watch(excludedAssetAccountIdsProvider).value ?? const <String>{};
    final accountsForAssetTotal = accounts
        .where((account) => !excludedAssetAccountIds.contains(account.id))
        .toList(growable: false);
    final accountNames = {
      for (final account in accounts) account.id: account.displayName,
    };
    // Empty transaction history is a valid final state. Keep already loaded
    // content visible while a provider refreshes so startup/import invalidation
    // never collapses the home page back to a blank shell.
    final dataReady = book != null && transactions.hasValue;
    final insightPreferences =
        insightPreferencesAsync.value ?? const InsightPreferences();
    if (dataReady &&
        insightPreferencesAsync.hasValue &&
        !insightPreferences.configured &&
        !_insightPreferencePromptScheduled) {
      _insightPreferencePromptScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        if (!mounted) return;
        final saved = await showInsightPreferencesSheet(
          context,
          insightPreferences,
          firstRun: true,
        );
        if (saved == null || !mounted) return;
        await ref.read(insightPreferencesRepositoryProvider).save(saved);
        ref.invalidate(insightPreferencesProvider);
      });
    }
    return SafeArea(
      child: ListView(
        // The liquid-glass navigation bar floats over the page, so the body
        // has to leave its whole footprint free — capsule, raised action
        // button and safe area. The value comes from the bar's own geometry
        // rather than a hand-tuned constant.
        padding: EdgeInsets.fromLTRB(
          16,
          10,
          16,
          AppScaffold.reservedBottomInset(context),
        ),
        children: [
            _HomeHeader(
              onSearch: () => context.push('/transactions/search'),
              onProfile: () => context.go('/profile'),
              onMembership: _showMembership,
              onNotifications: () => context.push('/assistant'),
              onCalendar: () => context.push('/transactions/calendar'),
            ),
            HomeInsightDrawer(
              key: ValueKey('insight-${book?.id}-${_day.toIso8601String()}'),
              bookId: book?.id ?? '',
              day: _day,
              insight: insight,
              available: dataReady,
              cooldownDays: insightFeed.cooldownDays,
              onTap: () {
                final item = insight;
                if (item == null) return;
                context.push(
                  '/insights/${Uri.encodeComponent(item.id)}',
                  extra: item,
                );
              },
            ),
            if (book?.isShared == true)
              InkWell(
                onTap: () => context.push('/profile/family'),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      Icon(
                        Icons.people_outline,
                        size: 16,
                        color: context.appPrimary,
                      ),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${(sharedState?['pending'] as List? ?? []).length} 项待同步 · ${sharedState?['error'] != null ? '需要处理' : '共享成员'}',
                          style: TextStyle(
                            fontSize: 12,
                            color: context.appPrimary,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            if (booksState.hasError ||
                (transactions.hasError && !transactions.hasValue))
              _ReadError(
                label: '账本',
                onRetry: () {
                  ref.invalidate(databaseBootstrapProvider);
                  ref.invalidate(booksProvider);
                  ref.invalidate(transactionsProvider);
                },
              )
            else if (!booksState.hasValue ||
                book == null ||
                !transactions.hasValue)
              const HomeSurface(child: LinearProgressIndicator())
            else if (transactions.hasError)
              HomeSurface(
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '流水刷新失败，正在继续显示上次已加载的数据',
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => ref.invalidate(transactionsProvider),
                      child: const Text('重试'),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 12),
            if (budgets.hasError || goalsState.hasError)
              _ReadError(
                label: '预算与目标',
                onRetry: () {
                  ref.invalidate(currentMonthBudgetsProvider);
                  ref.invalidate(goalsProvider);
                },
              )
            else if ((budgets.isLoading && !budgets.hasValue) ||
                (goalsState.isLoading && !goalsState.hasValue))
              const HomeSurface(child: LinearProgressIndicator())
            else if (dataReady)
              HomeSpendingGoalCard(
                bookType: book.type,
                snapshot: snapshot,
                goal: goal,
                onBudget: () => context.push('/profile/budgets'),
                onCalculation: () => _showCalculation(snapshot),
                onGoal: () =>
                    context.push(goal == null ? '/goals' : '/goals/${goal.id}'),
                todayAmountHidden: visibility.today,
                goalAmountHidden: visibility.goal,
                onTodayAmountHiddenChanged: (hidden) => ref
                    .read(homeCardVisibilityProvider.notifier)
                    .setHidden(book.id, HomeAmountSection.today, hidden),
                onGoalAmountHiddenChanged: (hidden) => ref
                    .read(homeCardVisibilityProvider.notifier)
                    .setHidden(book.id, HomeAmountSection.goal, hidden),
              ),
            if (dataReady) ...[
              const SizedBox(height: 12),
              if (accountsState.hasError)
                HomeAssetCard.error(
                  onRetry: () => ref.invalidate(allAccountsProvider),
                )
              else if (accountsState.isLoading && !accountsState.hasValue)
                const HomeAssetCard.loading()
              else
                HomeAssetCard(
                  accounts: accountsForAssetTotal,
                  investmentByCurrency: ref.watch(
                    investmentValueByCurrencyProvider,
                  ),
                  amountHidden: visibility.assets,
                  onAmountHiddenChanged: (hidden) => ref
                      .read(homeCardVisibilityProvider.notifier)
                      .setHidden(book.id, HomeAmountSection.assets, hidden),
                  onTap: () => context.push('/profile/assets'),
                ),
              const SizedBox(height: 12),
              const HomeExpenseTrend(),
              const SizedBox(height: 12),
              HomeSurface(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _SectionHeading(
                      title: '分类支出',
                      action: '查看全部',
                      onTap: _analysis,
                    ),
                    const SizedBox(height: 10),
                    if (analysis.expenseCategories.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '记下一笔支出，在这里了解钱花在哪里',
                          style: TextStyle(
                            color: context.appSecondaryText,
                            fontSize: 12,
                          ),
                        ),
                      )
                    else
                      LayoutBuilder(
                        builder: (context, constraints) {
                          final columns =
                              constraints.maxWidth < 290 ||
                                  MediaQuery.textScalerOf(context).scale(14) >
                                      19
                              ? 2
                              : 5;
                          return Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: analysis.expenseCategories
                                .take(5)
                                .map(
                                  (category) => SizedBox(
                                    width:
                                        (constraints.maxWidth -
                                            8 * (columns - 1)) /
                                        columns,
                                    child: _CategoryExpense(
                                      category: category,
                                      total: analysis.totalExpense,
                                      onTap: () =>
                                          _showCategory(category, analysis),
                                    ),
                                  ),
                                )
                                .toList(),
                          );
                        },
                      ),
                  ],
                ),
              ),
            ],
            SizedBox(height: 12),
            if (dataReady)
              HomeSurface(
                child: Column(
                  children: [
                    _SectionHeading(
                      title: '最近交易',
                      action: '查看更多',
                      onTap: () => context.go('/transactions'),
                    ),
                    const SizedBox(height: 6),
                    if (recentState.hasError)
                      _ReadError(
                        label: '最近交易',
                        onRetry: () =>
                            ref.invalidate(homeRecentTransactionsProvider),
                      )
                    else if (recentState.isLoading && !recentState.hasValue)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 18),
                        child: Center(child: CircularProgressIndicator()),
                      )
                    else if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          children: [
                            Text(
                              '每一笔小记录，都让生活更清晰',
                              style: TextStyle(
                                color: context.appSecondaryText,
                                fontSize: 13,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => showQuickAddSheet(context),
                              icon: const Icon(Icons.add),
                              label: const Text('记一笔'),
                            ),
                          ],
                        ),
                      )
                    else
                      ..._buildRecentGroups(recent, accountNames),
                  ],
                ),
              ),
          ],
        ),
    );
  }

  Future<void> _showMembership() async {
    final openMembership = await showModalBottomSheet<bool>(
      context: context,
      useRootNavigator: true,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) => SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
          child: HomeProCard(onTap: () => Navigator.pop(sheetContext, true)),
        ),
      ),
    );
    if (openMembership == true && mounted) {
      context.push('/profile/membership');
    }
  }

  List<Widget> _buildRecentGroups(
    List<TransactionRecord> transactions,
    Map<String, String> accountNames,
  ) {
    final groups = <DateTime, List<TransactionRecord>>{};
    for (final transaction in transactions) {
      final date = DateUtils.dateOnly(transaction.occurredAt.toLocal());
      groups.putIfAbsent(date, () => []).add(transaction);
    }
    final entries = groups.entries.toList(growable: false);
    return [
      for (var groupIndex = 0; groupIndex < entries.length; groupIndex++)
        Padding(
          padding: EdgeInsets.only(
            top: groupIndex == 0 ? 0 : 10,
            bottom: groupIndex == entries.length - 1 ? 0 : 4,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.only(left: 2, bottom: 2),
                child: Text(
                  TransactionDateFormatter.groupLabel(entries[groupIndex].key),
                  style: TextStyle(
                    color: context.appSecondaryText,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              for (
                var itemIndex = 0;
                itemIndex < entries[groupIndex].value.length;
                itemIndex++
              )
                Builder(
                  builder: (context) {
                    final record = entries[groupIndex].value[itemIndex];
                    final source = accountNames[record.accountId];
                    final destination = record.destinationAccountId == null
                        ? null
                        : accountNames[record.destinationAccountId!];
                    return TransactionTile(
                      transaction: record,
                      homeStyle: true,
                      accountName: source == null
                          ? null
                          : destination == null
                          ? source
                          : '$source → $destination',
                      showDivider:
                          !(groupIndex == entries.length - 1 &&
                              itemIndex ==
                                  entries[groupIndex].value.length - 1),
                      onTap: () => openTransactionDetail(context, record),
                      onLongPress: () =>
                          showTransactionActions(context, ref, record),
                    );
                  },
                ),
            ],
          ),
        ),
    ];
  }

  Future<void> _showCalculation(DashboardSnapshot snapshot) =>
      showModalBottomSheet<void>(
        context: context,
        useRootNavigator: true,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (context) => SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  '安心可花 · 计算依据',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                SizedBox(height: 16),
                for (final item in [
                  (
                    '本月预算',
                    snapshot.hasBudget
                        ? '¥${MoneyFormatter.decimal(snapshot.budgetAmount)}'
                        : '未设置',
                  ),
                  ('已发生支出', '− ¥${MoneyFormatter.decimal(snapshot.expense)}'),
                  (
                    '已开启的目标预留',
                    '− ¥${MoneyFormatter.decimal(snapshot.goalReservation)}',
                  ),
                  (
                    '本期可用支出',
                    snapshot.hasBudget
                        ? '¥${MoneyFormatter.decimal(snapshot.availableAmount)}'
                        : '—',
                  ),
                  ('剩余天数（含今天）', '${snapshot.remainingDays} 天'),
                ])
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Wrap(
                      alignment: WrapAlignment.spaceBetween,
                      spacing: 16,
                      runSpacing: 4,
                      children: [
                        Text(item.$1),
                        Text(
                          item.$2,
                          style: TextStyle(
                            color: context.appPrimaryText,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                const Divider(),
                const SizedBox(height: 12),
                const Text(
                  '今日安心可花 = 可用支出（最低为 0）÷ 剩余天数。仅统计人民币；目标预留汇总所有进行中的目标，不会自动扣款。\n\n未来计划支出、固定账单与周期支出尚未纳入计算。',
                  style: TextStyle(fontSize: 13),
                ),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () {
                    Navigator.pop(context);
                    this.context.push('/profile/budgets');
                  },
                  child: const Text('管理本月预算'),
                ),
              ],
            ),
          ),
        ),
      );

  Future<void> _showCategory(
    CashflowCategory category,
    AnalysisSnapshot snapshot,
  ) {
    var sortField = _CategoryExpenseSort.date;
    var descending = true;
    return showModalBottomSheet<void>(
      context: context,
      useRootNavigator: true,
      showDragHandle: false,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, sheetRef, _) {
          return StatefulBuilder(
            builder: (context, setSheetState) {
              final records =
                  (sheetRef.watch(transactionsProvider).value ?? [])
                      .where(
                        (item) =>
                            item.isExpense &&
                            item.currency.toUpperCase() == 'CNY' &&
                            item.deletedAt == null &&
                            !item.occurredAt.isAfter(DateTime.now()) &&
                            snapshot.range.contains(item.occurredAt) &&
                            cashflowCategoryKey(item) == category.id,
                      )
                      .toList()
                    ..sort((a, b) {
                      final comparison = sortField == _CategoryExpenseSort.date
                          ? a.occurredAt.compareTo(b.occurredAt)
                          : a.netExpenseAmount.compareTo(b.netExpenseAmount);
                      if (comparison == 0) {
                        return a.occurredAt.compareTo(b.occurredAt) *
                            (descending ? -1 : 1);
                      }
                      return comparison * (descending ? -1 : 1);
                    });
              final sheetAccounts =
                  sheetRef.watch(allAccountsProvider).value ?? const [];
              final sheetAccountNames = {
                for (final account in sheetAccounts)
                  account.id: account.displayName,
              };
              return SizedBox(
                height: MediaQuery.sizeOf(context).height * .5,
                child: SafeArea(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Center(
                        child: Container(
                          width: 32,
                          height: 4,
                          margin: const EdgeInsets.only(top: 10, bottom: 12),
                          decoration: BoxDecoration(
                            color: context.appDivider,
                            borderRadius: BorderRadius.circular(4),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 0, 16, 10),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${category.name} · 本月支出',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                            ),
                            const SizedBox(width: 8),
                            _CategoryExpenseSortButton(
                              label: '日期',
                              selected:
                                  sortField == _CategoryExpenseSort.date,
                              descending: descending,
                              onPressed: () => setSheetState(() {
                                if (sortField == _CategoryExpenseSort.date) {
                                  descending = !descending;
                                } else {
                                  sortField = _CategoryExpenseSort.date;
                                  descending = true;
                                }
                              }),
                            ),
                            const SizedBox(width: 6),
                            _CategoryExpenseSortButton(
                              label: '金额',
                              selected:
                                  sortField == _CategoryExpenseSort.amount,
                              descending: descending,
                              onPressed: () => setSheetState(() {
                                if (sortField == _CategoryExpenseSort.amount) {
                                  descending = !descending;
                                } else {
                                  sortField = _CategoryExpenseSort.amount;
                                  descending = true;
                                }
                              }),
                            ),
                          ],
                        ),
                      ),
                      Divider(height: 1, color: context.appDivider),
                      Expanded(
                        child: records.isEmpty
                            ? Center(
                                child: Text(
                                  '本月该分类暂无支出',
                                  style: TextStyle(
                                    color: context.appSecondaryText,
                                    fontSize: 13,
                                  ),
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.fromLTRB(20, 4, 20, 16),
                                itemCount: records.length,
                                itemBuilder: (context, index) {
                                  final record = records[index];
                                  final source =
                                      sheetAccountNames[record.accountId];
                                  final destination =
                                      record.destinationAccountId == null
                                      ? null
                                      : sheetAccountNames[
                                          record.destinationAccountId!
                                        ];
                                  return TransactionTile(
                                    transaction: record,
                                    homeStyle: true,
                                    showDate: true,
                                    accountName: source == null
                                        ? null
                                        : destination == null
                                        ? source
                                        : '$source → $destination',
                                    onTap: () =>
                                        openTransactionDetail(context, record),
                                    onLongPress: () => showTransactionActions(
                                      context,
                                      ref,
                                      record,
                                    ),
                                  );
                                },
                              ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

enum _CategoryExpenseSort { date, amount }

class _CategoryExpenseSortButton extends StatelessWidget {
  const _CategoryExpenseSortButton({
    required this.label,
    required this.selected,
    required this.descending,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final bool descending;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final foreground = selected ? Colors.white : context.appSecondaryText;
    return Semantics(
      button: true,
      selected: selected,
      label: '按$label排序，${selected ? (descending ? '降序' : '升序') : '未选中'}',
      child: Material(
        color: selected ? context.appPrimary : context.appSurfaceSoft,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    color: foreground,
                    fontSize: 11,
                    fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  ),
                ),
                const SizedBox(width: 2),
                Icon(
                  selected
                      ? descending
                            ? Icons.arrow_downward_rounded
                            : Icons.arrow_upward_rounded
                      : Icons.swap_vert_rounded,
                  size: 13,
                  color: foreground,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HomeHeader extends ConsumerWidget {
  const _HomeHeader({
    required this.onSearch,
    required this.onProfile,
    required this.onMembership,
    required this.onNotifications,
    required this.onCalendar,
  });
  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final VoidCallback onMembership;
  final VoidCallback onNotifications;
  final VoidCallback onCalendar;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final book = ref.watch(activeBookProvider);
    final bookTitle = formatBookTitle(book);
    return Row(
      children: [
        Semantics(
          button: true,
          label: '打开我的',
          child: InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(28),
            child: UserAvatar(radius: 20),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              InkWell(
                onTap: () => showBookSelectorSheet(context, ref),
                borderRadius: BorderRadius.circular(10),
                child: SizedBox(
                  width: double.infinity,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: Row(
                      children: [
                        Flexible(
                          child: Tooltip(
                            message: book?.name ?? bookTitle,
                            child: Text(
                              key: const ValueKey('home-book-title'),
                              bookTitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: context.appPrimaryText,
                                fontSize: 20,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: context.appPrimaryText,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(height: 1),
              Text(
                '记录生活  更好地生活',
                style: TextStyle(color: context.appSecondaryText, fontSize: 11),
              ),
            ],
          ),
        ),
        MembershipButton(onPressed: onMembership),
        AssistantEntryButton(onPressed: onNotifications),
        IconButton(
          onPressed: onCalendar,
          tooltip: '消费日历',
          constraints: const BoxConstraints.tightFor(width: 36, height: 36),
          padding: EdgeInsets.zero,
          icon: Icon(
            Icons.calendar_month_outlined,
            color: context.appPrimaryText,
            size: 23,
          ),
        ),
        IconButton(
          onPressed: onSearch,
          tooltip: '搜索流水',
          style: IconButton.styleFrom(
            backgroundColor: context.appSurfaceSoft,
            minimumSize: const Size(36, 36),
            maximumSize: const Size(36, 36),
            padding: EdgeInsets.zero,
            shape: const CircleBorder(),
          ),
          icon: Icon(
            Icons.search_rounded,
            color: context.appPrimaryText,
            size: 22,
          ),
        ),
      ],
    );
  }
}

class _SectionHeading extends StatelessWidget {
  const _SectionHeading({
    required this.title,
    required this.action,
    required this.onTap,
  });
  final String title;
  final String action;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: context.appPrimaryText,
          ),
        ),
      ),
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            '$action ›',
            style: TextStyle(
              fontSize: 11,
              color: context.appSecondaryText,
            ),
          ),
        ),
      ),
    ],
  );
}

class _CategoryExpense extends StatelessWidget {
  const _CategoryExpense({
    required this.category,
    required this.total,
    required this.onTap,
  });
  final CashflowCategory category;
  final double total;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) {
    final color = CategoryIcon.accentFor(category.name, iconKey: category.icon);
    final ratio = total <= 0 ? 0.0 : (category.amount / total).clamp(0.0, 1.0);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
        decoration: BoxDecoration(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CategoryIcon(
              category: category.name,
              iconKey: category.icon,
              size: 44,
              monochrome: true,
            ),
            SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color: context.appPrimaryText,
                fontSize: 11,
              ),
            ),
            SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                '¥${MoneyFormatter.decimal(category.amount)}',
                style: TextStyle(
                  color: context.appPrimaryText,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                    color: color,
                    backgroundColor: context.appDivider,
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(ratio * 100).round()}%',
                  style: TextStyle(
                    fontSize: 9,
                    color: context.appSecondaryText,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/*
class _InsightBanner extends ConsumerWidget {
  const _InsightBanner({required this.insight, required this.onTap});
  final AnalysisInsight insight;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final fingerprint =
        '${ref.watch(activeBookIdProvider)}-${insight.type.name}-${insight.generatedAt.year}-${insight.generatedAt.month}-${insight.categoryId ?? "all"}-${(insight.amount / 100).floor()}-${(insight.deltaPercent / 10).floor()}';
    final dismissed = ref.watch(_dismissedInsightProvider(fingerprint));
    if (dismissed.value != false) return const SizedBox.shrink();
    return Container(
      decoration: BoxDecoration(
        color: context.appPrimarySoft,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              onTap: onTap,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 0, 12),
                child: Row(
                  children: [
                    Icon(
                      Icons.insights_rounded,
                      size: 22,
                      color: context.appPrimary,
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '值得关注',
                            style: TextStyle(
                              color: context.appPrimary,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          SizedBox(height: 3),
                          Text(
                            insight.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: context.appPrimary,
                              fontSize: 11,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            tooltip: '关闭本条洞察',
            icon: Icon(
              Icons.close,
              size: 18,
              color: context.appSecondaryText,
            ),
            onPressed: () async {
              try {
                await ref
                    .read(appSettingsRepositoryProvider)
                    .set('home.insight.$fingerprint', 'dismissed');
                ref.invalidate(_dismissedInsightProvider(fingerprint));
              } catch (_) {
                if (context.mounted) {
                  ScaffoldMessenger.of(
                    context,
                  ).showSnackBar(const SnackBar(content: Text('未能保存关闭状态，请重试')));
                }
              }
            },
          ),
        ],
      ),
    );
  }
}
*/

class _ReadError extends StatelessWidget {
  const _ReadError({required this.label, required this.onRetry});
  final String label;
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => HomeSurface(
    child: Row(
      children: [
        Expanded(
          child: Text('$label读取失败，请重试', style: const TextStyle(fontSize: 13)),
        ),
        TextButton(onPressed: onRetry, child: const Text('重试')),
      ],
    ),
  );
}
