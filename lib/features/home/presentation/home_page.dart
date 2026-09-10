import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../books/presentation/book_selector.dart';
import '../../books/data/book_repository.dart';
import '../../sharing/application/shared_book_sync_service.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/models/dashboard_snapshot.dart';
import '../../../core/models/goal.dart';
import '../../../core/widgets/category_icon.dart';
import '../../../core/widgets/transaction_tile.dart';
import '../../../core/widgets/user_avatar.dart';
import '../../analysis/data/analysis_repository.dart';
import '../../budgets/data/budget_repository.dart';
import '../../accounts/data/account_repository.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../goals/data/goal_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../../transactions/presentation/transaction_actions.dart';
import '../data/home_data.dart';
import 'home_cards.dart';
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
      ref.invalidate(analysisRepositoryProvider);
      ref.invalidate(homeInsightProvider);
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
    final book = ref.watch(activeBookProvider);
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
    final insight = ref.watch(homeInsightProvider);
    final recent = ref.watch(homeRecentTransactionsProvider);
    final accounts = ref.watch(allAccountsProvider).value ?? const [];
    final accountNames = {
      for (final account in accounts) account.id: account.name,
    };
    final dataReady =
        book != null && !transactions.isLoading && !transactions.hasError;
    return DecoratedBox(
      decoration: const BoxDecoration(color: Color(0xFFFAF9F4)),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 110),
          children: [
            _HomeHeader(
              onSearch: () => context.push('/transactions/search'),
              onProfile: () => context.go('/profile'),
              onMembership: () => context.push('/profile/membership'),
              onNotifications: () =>
                  context.push('/profile/payment-notifications'),
            ),
            if (book?.isShared == true)
              InkWell(
                onTap: () => context.push('/profile/family'),
                child: Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.people_outline,
                        size: 16,
                        color: AppColors.primaryDark,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          '${(sharedState?['pending'] as List? ?? []).length} 项待同步 · ${sharedState?['error'] != null ? '需要处理' : '共享成员'}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.primaryDark,
                          ),
                        ),
                      ),
                      const Icon(Icons.chevron_right, size: 18),
                    ],
                  ),
                ),
              ),
            if (transactions.hasError)
              _ReadError(
                label: '账本',
                onRetry: () => ref.invalidate(transactionsProvider),
              )
            else if (transactions.isLoading || book == null)
              const HomeSurface(child: LinearProgressIndicator()),
            const SizedBox(height: 12),
            if (budgets.hasError || goalsState.hasError)
              _ReadError(
                label: '预算与目标',
                onRetry: () {
                  ref.invalidate(currentMonthBudgetsProvider);
                  ref.invalidate(goalsProvider);
                },
              )
            else if (budgets.isLoading || goalsState.isLoading)
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
              ),
            if (dataReady) ...[
              const SizedBox(height: 12),
              HomeInsightCard(insight: insight, onTap: _analysis),
              const SizedBox(height: 12),
              HomeProCard(onTap: () => context.push('/profile/membership')),
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
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          '记下一笔支出，在这里了解钱花在哪里',
                          style: TextStyle(
                            color: AppColors.textSecondary,
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
            const SizedBox(height: 12),
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
                    if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        child: Column(
                          children: [
                            const Text(
                              '每一笔小记录，都让生活更清晰',
                              style: TextStyle(
                                color: AppColors.textSecondary,
                                fontSize: 13,
                              ),
                            ),
                            TextButton.icon(
                              onPressed: () => showModalBottomSheet<void>(
                                context: context,
                                isScrollControlled: true,
                                backgroundColor: Colors.transparent,
                                builder: (_) => const QuickAddSheet(),
                              ),
                              icon: const Icon(Icons.add),
                              label: const Text('记一笔'),
                            ),
                          ],
                        ),
                      )
                    else
                      ...recent.map(
                        (transaction) => TransactionTile(
                          transaction: transaction,
                          homeStyle: true,
                          showDate: true,
                          accountName: accountNames[transaction.accountId],
                          showDivider: transaction != recent.last,
                          onTap: () =>
                              showTransactionActions(context, ref, transaction),
                          onLongPress: () =>
                              showTransactionActions(context, ref, transaction),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _showCalculation(DashboardSnapshot snapshot) =>
      showModalBottomSheet<void>(
        context: context,
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
                const SizedBox(height: 16),
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
                          style: const TextStyle(
                            color: AppColors.textPrimary,
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
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) => Consumer(
        builder: (context, sheetRef, _) {
          final records = (sheetRef.watch(transactionsProvider).value ?? [])
              .where(
                (item) =>
                    item.isExpense &&
                    item.currency.toUpperCase() == 'CNY' &&
                    item.deletedAt == null &&
                    !item.occurredAt.isAfter(DateTime.now()) &&
                    snapshot.range.contains(item.occurredAt) &&
                    (item.categoryId ?? 'uncategorized') == category.id,
              )
              .toList();
          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(context).height * .65,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                children: [
                  Text(
                    '${category.name} · 本月支出',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  const SizedBox(height: 12),
                  if (records.isEmpty) const Text('本月该分类暂无支出'),
                  ...records.map(
                    (record) => TransactionTile(
                      transaction: record,
                      homeStyle: true,
                      showDate: true,
                      onTap: () => showTransactionActions(context, ref, record),
                      onLongPress: () =>
                          showTransactionActions(context, ref, record),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
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
  });
  final VoidCallback onSearch;
  final VoidCallback onProfile;
  final VoidCallback onMembership;
  final VoidCallback onNotifications;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Row(
      children: [
        Semantics(
          button: true,
          label: '打开我的',
          child: InkWell(
            onTap: onProfile,
            borderRadius: BorderRadius.circular(28),
            child: const UserAvatar(radius: 20),
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
                child: const Padding(
                  padding: EdgeInsets.symmetric(vertical: 2),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '我的账本',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 20,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        SizedBox(width: 5),
                        Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 20,
                          color: AppColors.textPrimary,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 1),
              const Text(
                '记录生活  更好地生活',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 11),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onMembership,
          tooltip: '会员',
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: const HomeCrownIcon(),
        ),
        IconButton(
          onPressed: onNotifications,
          tooltip: '支付通知记账',
          constraints: const BoxConstraints.tightFor(width: 34, height: 34),
          padding: EdgeInsets.zero,
          icon: const Icon(
            Icons.notifications_none_rounded,
            color: AppColors.textPrimary,
            size: 25,
          ),
        ),
        IconButton(
          onPressed: onSearch,
          tooltip: '搜索流水',
          style: IconButton.styleFrom(
            backgroundColor: const Color(0xFFF2EEE3),
            minimumSize: const Size(34, 34),
            padding: EdgeInsets.zero,
          ),
          icon: const Icon(
            Icons.search_rounded,
            color: AppColors.textPrimary,
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
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ),
      InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 5),
          child: Text(
            '$action ›',
            style: const TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
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
            const SizedBox(height: 6),
            Text(
              category.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 11,
              ),
            ),
            const SizedBox(height: 2),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.center,
              child: Text(
                '¥${MoneyFormatter.decimal(category.amount)}',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: LinearProgressIndicator(
                    value: ratio,
                    minHeight: 4,
                    borderRadius: BorderRadius.circular(4),
                    color: color,
                    backgroundColor: const Color(0xFFE8EDF2),
                  ),
                ),
                const SizedBox(width: 4),
                Text(
                  '${(ratio * 100).round()}%',
                  style: const TextStyle(
                    fontSize: 9,
                    color: AppColors.textSecondary,
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
        color: AppColors.primarySoft,
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
                    const Icon(
                      Icons.insights_rounded,
                      size: 22,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            '值得关注',
                            style: TextStyle(
                              color: AppColors.primaryDark,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            insight.description,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: AppColors.primaryDark,
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
            icon: const Icon(
              Icons.close,
              size: 18,
              color: AppColors.textSecondary,
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
