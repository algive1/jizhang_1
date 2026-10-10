import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/app_scaffold.dart';
import '../../accounts/data/account_repository.dart';
import '../../books/data/book_repository.dart';
import '../../budgets/data/budget_repository.dart';
import '../../categories/data/category_repository.dart';
import '../../goals/data/goal_repository.dart';
import '../../recurring/data/recurring_bill_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../application/insight_feed_provider.dart';
import '../data/insight_preferences_repository.dart';
import '../domain/insight_models.dart';
import '../domain/insight_month_summary.dart';
import 'insight_preferences_sheet.dart';

enum _InsightFilter { all, important, changes, discovery }

class InsightsPage extends ConsumerStatefulWidget {
  const InsightsPage({super.key});
  @override
  ConsumerState<InsightsPage> createState() => _InsightsPageState();
}

class _InsightsPageState extends ConsumerState<InsightsPage> {
  _InsightFilter _filter = _InsightFilter.all;
  String? _error;

  Future<void> _refresh() async {
    ref.invalidate(insightRecentTransactionsProvider);
    ref.invalidate(insightPendingReimbursementsProvider);
    ref.invalidate(insightLargeExpenseThresholdProvider);
    ref.invalidate(allAccountsProvider);
    ref.invalidate(allCategoriesProvider);
    ref.invalidate(goalsProvider);
    ref.invalidate(recurringBillsProvider);
    ref.invalidate(currentMonthBudgetsProvider);
    final now = DateTime.now();
    ref.invalidate(
      transactionsForMonthProvider((year: now.year, month: now.month)),
    );
    ref.invalidate(insightPreferencesProvider);
    ref.invalidate(confirmedInsightFeedProvider);
    try {
      await ref.read(insightRecentTransactionsProvider.future);
    } on Object {
      /* The page renders the source error and retry action. */
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(insightDataStateProvider);
    final feed = ref.watch(insightFeedProvider);
    final preferences =
        ref.watch(insightPreferencesProvider).value ??
        const InsightPreferences();
    final summary = ref.watch(insightMonthSummaryProvider);
    final bookName = ref.watch(activeBookProvider)?.name ?? '当前账本';
    final now = DateTime.now();
    final ready = state.hasValue && !state.hasError && !state.isLoading;
    final items =
        feed.items
            .where(
              (item) => switch (_filter) {
                _InsightFilter.all => true,
                _InsightFilter.important =>
                  item.isImportant ||
                      item.kind == FinancialInsightKind.risk ||
                      item.kind == FinancialInsightKind.goal,
                _InsightFilter.changes =>
                  item.kind == FinancialInsightKind.behavior ||
                      item.kind == FinancialInsightKind.positive ||
                      item.kind == FinancialInsightKind.financial,
                _InsightFilter.discovery =>
                  item.kind == FinancialInsightKind.discovery ||
                      item.kind == FinancialInsightKind.life,
              },
            )
            .toList()
          ..sort((a, b) {
            final priority = b.priority.index.compareTo(a.priority.index);
            return priority != 0 ? priority : b.score.compareTo(a.score);
          });
    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _refresh,
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: EdgeInsets.fromLTRB(
            16,
            12,
            16,
            AppScaffold.reservedBottomInset(context),
          ),
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '洞察',
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$bookName · ${now.month}月1日至今',
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: '刷新洞察',
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded),
                ),
                IconButton(
                  tooltip: '关注设置',
                  onPressed: () => _showPreferences(preferences),
                  icon: const Icon(Icons.tune_rounded),
                ),
              ],
            ),
            const SizedBox(height: 18),
            if (state.hasError)
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '账务数据暂时没有读取成功',
                      style: TextStyle(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 8),
                    const Text('暂不生成结论，已有账本和记录不受影响。'),
                    TextButton.icon(
                      onPressed: _refresh,
                      icon: const Icon(Icons.refresh),
                      label: const Text('重新加载'),
                    ),
                  ],
                ),
              )
            else if (!ready)
              const AppCard(
                child: Column(
                  children: [
                    LinearProgressIndicator(),
                    SizedBox(height: 16),
                    Text('正在整理当前账本…'),
                  ],
                ),
              )
            else ...[
              _MonthCard(summary: summary),
              const SizedBox(height: 18),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      '值得关注',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${feed.items.length} 条',
                    style: TextStyle(color: context.appSecondaryText),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    for (final entry in const [
                      (_InsightFilter.all, '全部'),
                      (_InsightFilter.important, '待处理'),
                      (_InsightFilter.changes, '收支变化'),
                      (_InsightFilter.discovery, '消费发现'),
                    ])
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(entry.$2),
                          selected: _filter == entry.$1,
                          onSelected: (_) => setState(() => _filter = entry.$1),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                AppCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_graph_rounded,
                        color: context.appPrimary,
                        size: 30,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        feed.items.isNotEmpty
                            ? '这个分类暂时没有新发现'
                            : summary.count == 0
                            ? '本月还没有可分析的消费记录'
                            : '暂时没有明显变化需要提醒',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        summary.count == 0
                            ? '记下真实支出后，这里会展示变化、依据和可做的调整。'
                            : '结论只来自已记录的数据；历史不足时不推测涨跌原因。',
                        style: TextStyle(color: context.appSecondaryText),
                      ),
                      if (feed.items.isNotEmpty)
                        TextButton(
                          onPressed: () =>
                              setState(() => _filter = _InsightFilter.all),
                          child: const Text('查看全部'),
                        ),
                    ],
                  ),
                )
              else
                for (final item in items)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InsightCard(
                      item: item,
                      onDetails: () => context.push(
                        '/insights/${Uri.encodeComponent(item.id)}',
                        extra: item,
                      ),
                      onAction: item.actionRoute == null
                          ? null
                          : () => _openAction(item),
                      onDismiss: () => _dismiss(item),
                    ),
                  ),
              const SizedBox(height: 8),
              Text(
                feed.isServerConfirmed ? '已更新分析 · 结论可查看具体依据' : '本地分析 · 离线也可查看',
                style: TextStyle(color: context.appSecondaryText, fontSize: 12),
              ),
            ],
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 22),
            Text('把发现变成行动', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 10),
            AppCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  _ActionRow(
                    icon: Icons.account_balance_wallet_outlined,
                    title: '调整预算',
                    subtitle: '按自己的节奏安排本月支出',
                    route: '/profile/budgets',
                  ),
                  Divider(height: 1, indent: 56, color: context.appDivider),
                  _ActionRow(
                    icon: Icons.flag_outlined,
                    title: '储蓄目标',
                    subtitle: '查看进度，安排下一笔存入',
                    route: '/goals',
                  ),
                  Divider(height: 1, indent: 56, color: context.appDivider),
                  _ActionRow(
                    icon: Icons.autorenew,
                    title: '周期账单',
                    subtitle: '检查订阅和固定支出',
                    route: '/profile/recurring-bills',
                  ),
                  Divider(height: 1, indent: 56, color: context.appDivider),
                  _ActionRow(
                    icon: Icons.bar_chart_rounded,
                    title: '收支分析',
                    subtitle: '查看完整趋势和分类明细',
                    route: '/analysis',
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _openAction(FinancialInsightItem item) {
    final route = item.actionRoute;
    if (route == '/transactions' && item.relatedTransactionIds.isNotEmpty) {
      context.push('/transactions/search', extra: item.relatedTransactionIds);
    } else if (route != null) {
      context.push(route);
    }
  }

  Future<void> _dismiss(FinancialInsightItem item) async {
    try {
      await ref.read(insightPreferencesRepositoryProvider).dismiss(item.id);
      ref.invalidate(insightPreferencesProvider);
    } on Object {
      if (mounted) setState(() => _error = '未能保存这次设置，请重试');
    }
  }

  Future<void> _showPreferences(InsightPreferences current) async {
    final saved = await showInsightPreferencesSheet(context, current);
    if (saved == null || !mounted) return;
    try {
      await ref.read(insightPreferencesRepositoryProvider).save(saved);
      ref.invalidate(insightPreferencesProvider);
    } on Object {
      if (mounted) setState(() => _error = '关注设置保存失败，请重试');
    }
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.summary});
  final InsightMonthSummary summary;
  @override
  Widget build(BuildContext context) {
    final change = summary.changePercent;
    return AppCard(
      color: context.appPrimarySoft,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '本月个人消费',
            style: TextStyle(color: context.appColors.onPrimaryContainer),
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              '¥${MoneyFormatter.decimal(summary.spent)}',
              style: Theme.of(context).textTheme.headlineLarge
                  ?.copyWith(color: context.appColors.onPrimaryContainer),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                '${summary.count} 笔消费',
                style: TextStyle(color: context.appColors.onPrimaryContainer),
              ),
              Text(
                change == null
                    ? '上月同期记录不足，暂不比较'
                    : '较上月同期${change >= 0 ? '增加' : '减少'} ${change.abs().toStringAsFixed(1)}%',
                style: TextStyle(
                  color: context.appColors.onPrimaryContainer,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            '人民币消费 · 已扣退款和报销 · 不含转账及投资',
            style: TextStyle(
              color: context.appColors.onPrimaryContainer,
              fontSize: 12,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  const _InsightCard({
    required this.item,
    required this.onDetails,
    required this.onDismiss,
    this.onAction,
  });
  final FinancialInsightItem item;
  final VoidCallback onDetails, onDismiss;
  final VoidCallback? onAction;

  String _value(InsightEvidence evidence) {
    final n = evidence.value;
    if (evidence.unit == 'CNY') return '¥${MoneyFormatter.decimal(n)}';
    return '${n.toStringAsFixed(n % 1 == 0 ? 0 : 1)}${evidence.unit ?? ''}';
  }

  @override
  Widget build(BuildContext context) => AppCard(
    padding: const EdgeInsets.all(16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(
              item.isImportant
                  ? Icons.priority_high_rounded
                  : Icons.auto_graph_rounded,
              size: 18,
              color: item.isImportant
                  ? Theme.of(context).colorScheme.error
                  : context.appPrimary,
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                item.kind.label,
                style: TextStyle(color: context.appSecondaryText, fontSize: 12),
              ),
            ),
            IconButton(
              tooltip: '隐藏这条',
              onPressed: onDismiss,
              icon: const Icon(Icons.close_rounded, size: 18),
            ),
          ],
        ),
        Text(
          item.title,
          style: Theme.of(context).textTheme.titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          item.summary,
          style: TextStyle(color: context.appSecondaryText, height: 1.5),
        ),
        if (item.evidence.isNotEmpty) ...[
          const SizedBox(height: 14),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: context.appSurfaceSoft,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Wrap(
              spacing: 20,
              runSpacing: 12,
              children: [
                for (final evidence in item.evidence.take(2))
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        evidence.label,
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 12,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _value(evidence),
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: context.appPrimaryText,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            if (onAction != null)
              FilledButton.tonal(
                onPressed: onAction,
                child: Text(item.actionLabel ?? '去处理'),
              ),
            TextButton(onPressed: onDetails, child: const Text('查看依据')),
          ],
        ),
      ],
    ),
  );
}

class _ActionRow extends StatelessWidget {
  const _ActionRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.route,
  });
  final IconData icon;
  final String title, subtitle, route;
  @override
  Widget build(BuildContext context) => ListTile(
    leading: Icon(icon, color: context.appPrimary),
    title: Text(title),
    subtitle: Text(subtitle),
    trailing: const Icon(Icons.chevron_right),
    onTap: () => context.push(route),
  );
}
