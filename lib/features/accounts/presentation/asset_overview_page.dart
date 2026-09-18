import '../../../core/widgets/app_action_sheet.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/transaction_date_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/models/account_balance_effect.dart';
import '../../../core/models/transaction_record.dart';
import '../../../core/widgets/app_card.dart';
import '../../bookkeeping/presentation/quick_add_sheet.dart';
import '../../books/data/book_repository.dart';
import '../../transactions/data/transactions_repository.dart';
import '../data/account_repository.dart';
import '../domain/asset_history.dart';
import '../domain/asset_overview.dart';
import '../../investments/data/investment_repository.dart';
import '../../home/presentation/home_asset_card.dart';
import 'account_forms.dart';
import 'asset_dashboard_cards.dart';
import 'asset_dashboard_icons.dart';
import 'asset_liability_section.dart';
import 'asset_dashboard_charts.dart';

class AssetOverviewPage extends ConsumerStatefulWidget {
  const AssetOverviewPage({super.key});

  @override
  ConsumerState<AssetOverviewPage> createState() => _AssetOverviewPageState();
}

class _AssetOverviewPageState extends ConsumerState<AssetOverviewPage> {
  bool _hidden = false;
  int _days = 30;
  String? _currency;
  final _trendKey = GlobalKey();

  @override
  Widget build(BuildContext context) {
    final accountState = ref.watch(assetDashboardAccountsProvider);
    final transactionState = ref.watch(allTransactionsProvider);
    final activeBook = ref.watch(activeBookProvider);
    final allAccounts = accountState.value ?? const <Account>[];
    final groups = AssetOverview.group(
      allAccounts,
      investmentByCurrency: ref.watch(investmentValueByCurrencyProvider),
    );
    final selected =
        groups.where((g) => g.currency == _currency).firstOrNull ??
        groups.firstOrNull;
    if (selected != null && _currency != selected.currency) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() => _currency = selected.currency);
      });
    }
    final records = transactionState.value ?? const <TransactionRecord>[];
    final history = selected == null
        ? null
        : AssetHistory(selected.accounts, records, DateTime.now());
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFF3F6E9), Color(0xFFF7F8EE)],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            _Header(
              onBack: () =>
                  context.canPop() ? context.pop() : context.go('/profile'),
              currencies: groups.map((g) => g.currency).toList(),
              selectedCurrency: selected?.currency,
              onCurrency: (value) => setState(() => _currency = value),
            ),
            const SizedBox(height: 8),
            if (accountState.hasError)
              _ErrorCard(
                onRetry: () => ref.invalidate(assetDashboardAccountsProvider),
              )
            else if (selected == null)
              _EmptyCard(onAdd: () => showAccountEditor(context))
            else ...[
              HomeAssetCard(
                accounts: selected.accounts,
                investmentByCurrency: {
                  selected.currency: selected.investmentValue,
                },
                amountHidden: _hidden,
                compactHeight: 130,
                onAmountHiddenChanged: (value) =>
                    setState(() => _hidden = value),
                onTap: () {
                  final current = history;
                  if (current != null) {
                    _showAssetOverviewSheet(context, selected, current);
                  }
                },
              ),
              const SizedBox(height: 8),
              AssetShortcuts(
                accountCount: selected.accounts
                    .where(
                      (account) => account.balance >= 0 && !account.isArchived,
                    )
                    .length,
                onAccounts: () => context.push('/profile/accounts'),
                onInvestments: () => context.push('/profile/investments'),
                onTransfers: () => showQuickAddSheet(
                  context,
                  initialType: TransactionType.transfer,
                ),
                onReport: () => context.push('/analysis'),
              ),
              const SizedBox(height: 8),
              _AccountSection(
                accounts: selected.accounts
                    .where((a) => a.balance >= 0 && !a.isArchived)
                    .toList(),
                overview: selected,
                hidden: _hidden,
                onManage: () => context.push('/profile/accounts'),
                onTap: (account) =>
                    context.push('/profile/accounts/${account.id}'),
                onAction: (account, action) =>
                    _accountAction(context, account, action),
                history: history!,
              ),
              const SizedBox(height: 8),
              _ChartPair(
                key: _trendKey,
                history: history,
                selected: selected,
                days: _days,
                onDays: (days) => setState(() => _days = days),
                onDistribution: () => _showDistributionSheet(context, selected),
                onTrend: () => _showTrendSheet(context, selected, history),
              ),
              const SizedBox(height: 8),
              AssetLiabilitySection(
                accounts: selected.accounts,
                onAccounts: () => context.push('/profile/accounts'),
              ),
              const SizedBox(height: 8),
              _RecentChanges(
                records: records,
                accountIds: selected.accounts.map((a) => a.id).toSet(),
                onViewAll: () => context.push('/transactions'),
              ),
              if (activeBook?.usesPrimaryAssets == true)
                const Padding(
                  padding: EdgeInsets.only(top: 10),
                  child: Text(
                    '当前账本使用主账本资产；归档账户仍计入资产合计。',
                    style: TextStyle(
                      fontSize: 11,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _showAssetOverviewSheet(
    BuildContext context,
    AssetOverview selected,
    AssetHistory history,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) =>
        _AssetOverviewSheet(overview: selected, history: history, days: _days),
  );

  Future<void> _showDistributionSheet(
    BuildContext context,
    AssetOverview selected,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _DistributionSheet(overview: selected),
  );

  Future<void> _showTrendSheet(
    BuildContext context,
    AssetOverview selected,
    AssetHistory history,
  ) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => _TrendSheet(
      overview: selected,
      history: history,
      days: _days,
      onDays: (days) => setState(() => _days = days),
    ),
  );

  Future<void> _accountAction(
    BuildContext context,
    Account account,
    String action,
  ) async {
    if (action == 'detail') {
      context.push('/profile/accounts/${account.id}');
      return;
    }
    if (action == 'edit') {
      await showAccountEditor(context, account: account);
      return;
    }
    if (action == 'calibrate') {
      await showBalanceCalibration(context, account);
      return;
    }
    if (action == 'archive') {
      final shouldArchive = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('归档账户？'),
          content: const Text('历史流水和余额仍保留，继续计入资产。以后可恢复使用。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('归档'),
            ),
          ],
        ),
      );
      if (shouldArchive != true) return;
    }
    try {
      final repository = ref.read(accountRepositoryProvider);
      if (action == 'restore')
        await repository.restore(account.id);
      else
        await repository.archive(account.id);
    } on Object catch (error) {
      if (context.mounted)
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('操作失败：$error')));
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.onBack,
    required this.currencies,
    required this.selectedCurrency,
    required this.onCurrency,
  });
  final VoidCallback onBack;
  final List<String> currencies;
  final String? selectedCurrency;
  final ValueChanged<String?> onCurrency;
  @override
  Widget build(BuildContext context) => SizedBox(
    height: 38,
    child: Stack(
      alignment: Alignment.center,
      children: [
        const Text(
          '资产总览',
          style: TextStyle(
            fontSize: 19,
            fontWeight: FontWeight.w800,
            color: assetInk,
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: IconButton(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_ios_new, size: 18),
            tooltip: '返回',
          ),
        ),
        if (currencies.length > 1)
          Align(
            alignment: Alignment.centerRight,
            child: AppActionMenuButton<String>(
              onSelected: onCurrency,
              tooltip: '选择币种',
              itemBuilder: (_) => [
                for (final currency in currencies)
                  PopupMenuItem(
                    value: currency,
                    child: Text(currency == 'CNY' ? '人民币（CNY）' : currency),
                  ),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 11,
                  vertical: 7,
                ),
                decoration: BoxDecoration(
                  color: const Color(0xEFFFFFFB),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  selectedCurrency ?? currencies.first,
                  style: const TextStyle(fontSize: 11, color: assetInk),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _AccountSection extends StatelessWidget {
  const _AccountSection({
    required this.accounts,
    required this.overview,
    required this.hidden,
    required this.onManage,
    required this.onTap,
    required this.onAction,
    required this.history,
  });
  final List<Account> accounts;
  final AssetOverview overview;
  final bool hidden;
  final VoidCallback onManage;
  final ValueChanged<Account> onTap;
  final void Function(Account, String) onAction;
  final AssetHistory history;
  @override
  Widget build(BuildContext context) {
    final percent = {
      for (final account in accounts)
        account.id: history.percent(30, accountId: account.id),
    };
    return AssetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetSectionHeading(
            '账户资产',
            action: '${accounts.length} 个账户',
            onTap: onManage,
          ),
          const SizedBox(height: 8),
          LayoutBuilder(
            builder: (context, box) {
              const count = 4;
              final width = (box.maxWidth - 7 * (count - 1)) / count;
              return Wrap(
                spacing: 7,
                runSpacing: 7,
                children: [
                  for (final account in accounts)
                    SizedBox(
                      width: width,
                      child: _AccountAssetCard(
                        account: account,
                        hidden: hidden,
                        percent: percent[account.id],
                        onTap: () => onTap(account),
                        onAction: (action) => onAction(account, action),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _AccountAssetCard extends StatelessWidget {
  const _AccountAssetCard({
    required this.account,
    required this.hidden,
    required this.percent,
    required this.onTap,
    required this.onAction,
  });
  final Account account;
  final bool hidden;
  final double? percent;
  final VoidCallback onTap;
  final ValueChanged<String> onAction;
  @override
  Widget build(BuildContext context) {
    final material = Material(
      color: const Color(0xFFF9F9F2),
      borderRadius: BorderRadius.circular(13),
      child: InkWell(
        onTap: onTap,
        onLongPress: () async {
          final value = await AppActionSheet.show<String>(
            context,
            title: account.displayName,
            items: [
              const PopupMenuItem(value: 'detail', child: Text('查看明细')),
              if (!account.isArchived) ...[
                const PopupMenuItem(value: 'edit', child: Text('编辑账户')),
                const PopupMenuItem(value: 'calibrate', child: Text('校准余额')),
                const PopupMenuItem(value: 'archive', child: Text('归档账户')),
              ] else
                const PopupMenuItem(value: 'restore', child: Text('恢复账户')),
            ],
          );
          if (value != null && context.mounted) onAction(value);
        },
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.all(4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  AssetVectorIcon(accountGlyph(account), size: 22, tile: true),
                  const Spacer(),
                  AppActionMenuButton<String>(
                    padding: EdgeInsets.zero,
                    onSelected: onAction,
                    itemBuilder: (_) => [
                      const PopupMenuItem(value: 'detail', child: Text('查看明细')),
                      if (!account.isArchived) ...[
                        const PopupMenuItem(
                          value: 'calibrate',
                          child: Text('校准余额'),
                        ),
                        const PopupMenuItem(value: 'edit', child: Text('编辑账户')),
                        const PopupMenuItem(
                          value: 'archive',
                          child: Text('归档账户'),
                        ),
                      ] else
                        const PopupMenuItem(
                          value: 'restore',
                          child: Text('恢复账户'),
                        ),
                    ],
                    child: const SizedBox(
                      width: 20,
                      height: 20,
                      child: Icon(
                        Icons.chevron_right,
                        size: 16,
                        color: assetMuted,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
              Text(
                account.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11, color: assetInk),
              ),
              const SizedBox(height: 2),
              AssetAmount(
                account.type.isDebt ? account.balance.abs() : account.balance,
                currency: account.currency,
                hidden: hidden,
                size: 14,
                color: account.type.isDebt ? assetCoral : assetInk,
              ),
              const SizedBox(height: 2),
              Text(
                account.isArchived
                    ? '已归档 · 仍计入合计'
                    : hidden
                    ? '••••'
                    : percent == null
                    ? '暂无可比基数'
                    : '${percent! > 0
                          ? '↑'
                          : percent! < 0
                          ? '↓'
                          : '−'} ${percent!.abs().toStringAsFixed(1)}%',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11,
                  color: percent != null && percent! < 0
                      ? assetCoral
                      : assetGreen,
                ),
              ),
            ],
          ),
        ),
      ),
    );
    return MediaQuery.textScalerOf(context).scale(1) > 1.15
        ? material
        : SizedBox(height: 84, child: material);
  }
}

class _ChartPair extends StatelessWidget {
  const _ChartPair({
    required this.history,
    required this.selected,
    required this.days,
    required this.onDays,
    required this.onDistribution,
    required this.onTrend,
    super.key,
  });
  final AssetHistory history;
  final AssetOverview selected;
  final int days;
  final ValueChanged<int> onDays;
  final VoidCallback onDistribution;
  final VoidCallback onTrend;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      if (box.maxWidth < 380)
        return Column(
          children: [
            AssetDistribution(overview: selected, onTap: onDistribution),
            const SizedBox(height: 8),
            AssetTrend(
              history: history,
              currency: selected.currency,
              days: days,
              onDays: onDays,
              onTap: onTrend,
            ),
          ],
        );
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 51,
            child: AssetDistribution(overview: selected, onTap: onDistribution),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 49,
            child: AssetTrend(
              history: history,
              currency: selected.currency,
              days: days,
              onDays: onDays,
              onTap: onTrend,
            ),
          ),
        ],
      );
    },
  );
}

class _RecentChanges extends StatefulWidget {
  const _RecentChanges({
    required this.records,
    required this.accountIds,
    required this.onViewAll,
  });
  final List<TransactionRecord> records;
  final Set<String> accountIds;
  final VoidCallback onViewAll;
  @override
  State<_RecentChanges> createState() => _RecentChangesState();
}

class _RecentChangesState extends State<_RecentChanges> {
  String _filter = '全部';
  bool _showTip = true;

  @override
  Widget build(BuildContext context) {
    final records = widget.records;
    final accountIds = widget.accountIds;
    final recent =
        records
            .where(
              (r) =>
                  r.deletedAt == null &&
                  (accountIds.contains(r.accountId) ||
                      accountIds.contains(r.destinationAccountId)),
            )
            .toList()
          ..sort((a, b) => b.occurredAt.compareTo(a.occurredAt));
    final filtered = recent.where(_matchesFilter).toList();
    final visible = filtered.take(3).toList(growable: false);
    return AssetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          AssetSectionHeading(
            '近期资产变动',
            action: '查看全部',
            onTap: widget.onViewAll,
          ),
          const SizedBox(height: 4),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final filter in const ['全部', '收入', '支出', '转账', '资产变动'])
                  Padding(
                    padding: const EdgeInsets.only(right: 5),
                    child: ChoiceChip(
                      label: Text(filter),
                      selected: _filter == filter,
                      onSelected: (_) => setState(() => _filter = filter),
                      showCheckmark: false,
                      side: BorderSide.none,
                      visualDensity: const VisualDensity(
                        horizontal: -2,
                        vertical: -2,
                      ),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 0,
                      ),
                      labelStyle: TextStyle(
                        fontSize: 10,
                        color: _filter == filter ? Colors.white : assetMuted,
                      ),
                      backgroundColor: assetCream,
                      selectedColor: const Color(0xff83a25d),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          if (filtered.isEmpty)
            const Padding(
              padding: EdgeInsets.all(8),
              child: Text(
                '暂无近期资产变动',
                style: TextStyle(fontSize: 12, color: assetMuted),
              ),
            )
          else
            for (var index = 0; index < visible.length; index++) ...[
              _RecentRow(record: visible[index], accountIds: accountIds),
              if (index < visible.length - 1)
                const Divider(height: 1, indent: 44, color: Color(0xFFE8EBDD)),
            ],
          if (_showTip) ...[
            const SizedBox(height: 5),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F6E9),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.lightbulb_outline,
                    size: 17,
                    color: Color(0xffdca83f),
                  ),
                  const SizedBox(width: 6),
                  const Expanded(
                    child: Text(
                      '小贴士：定期更新资产信息，才能更准确地掌握你的财务状况哦～',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(fontSize: 10, color: assetMuted),
                    ),
                  ),
                  IconButton(
                    onPressed: () => setState(() => _showTip = false),
                    icon: const Icon(Icons.close, size: 16, color: assetGreen),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 22,
                      height: 22,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  bool _matchesFilter(TransactionRecord record) {
    return switch (_filter) {
      '收入' => record.isIncome,
      '支出' => record.isExpense,
      '转账' => record.type == TransactionType.transfer,
      '资产变动' =>
        record.type == TransactionType.adjustment ||
            record.type == TransactionType.assetPurchase ||
            record.type == TransactionType.assetSale,
      _ => true,
    };
  }
}

class _RecentRow extends StatelessWidget {
  const _RecentRow({required this.record, required this.accountIds});
  final TransactionRecord record;
  final Set<String> accountIds;
  @override
  Widget build(BuildContext context) {
    final effects = accountBalanceEffect(record);
    final cents = effects.entries
        .where((e) => accountIds.contains(e.key))
        .fold(0, (sum, e) => sum + e.value);
    final amount = cents / 100;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: const BoxDecoration(
              color: Color(0xFFF3F5E8),
              shape: BoxShape.circle,
            ),
            child: Icon(
              record.type == TransactionType.transfer
                  ? Icons.sync_alt
                  : record.isIncome
                  ? Icons.arrow_downward
                  : Icons.arrow_upward,
              size: 17,
              color: amount >= 0 ? assetGreen : assetCoral,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  record.displayTitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: assetInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${record.occurredAt.month}/${record.occurredAt.day} ${TransactionDateFormatter.time(record.occurredAt)} · ${record.displayCategoryLabel}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 11, color: assetMuted),
                ),
              ],
            ),
          ),
          AssetAmount(
            amount,
            currency: record.currency,
            signed: true,
            size: 15,
            color: amount >= 0 ? assetGreen : assetInk,
          ),
        ],
      ),
    );
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.onAdd});
  final VoidCallback onAdd;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        const Text('先添加一个账户，记录已有存款或欠款'),
        TextButton(onPressed: onAdd, child: const Text('添加账户')),
      ],
    ),
  );
}

class _ErrorCard extends StatelessWidget {
  const _ErrorCard({required this.onRetry});
  final VoidCallback onRetry;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      children: [
        const Text('资产读取失败'),
        TextButton(onPressed: onRetry, child: const Text('重新加载')),
      ],
    ),
  );
}

class _AssetOverviewSheet extends StatelessWidget {
  const _AssetOverviewSheet({
    required this.overview,
    required this.history,
    required this.days,
  });
  final AssetOverview overview;
  final AssetHistory history;
  final int days;

  @override
  Widget build(BuildContext context) => _AssetSheetFrame(
    title: '资产详情',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      children: [
        AssetDistributionDetail(overview: overview),
        const SizedBox(height: 10),
        AssetTrendDetail(
          history: history,
          currency: overview.currency,
          days: days,
        ),
      ],
    ),
  );
}

class _DistributionSheet extends StatelessWidget {
  const _DistributionSheet({required this.overview});
  final AssetOverview overview;

  @override
  Widget build(BuildContext context) => _AssetSheetFrame(
    title: '资产分布详情',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      children: [AssetDistributionDetail(overview: overview)],
    ),
  );
}

class _TrendSheet extends StatefulWidget {
  const _TrendSheet({
    required this.overview,
    required this.history,
    required this.days,
    required this.onDays,
  });
  final AssetOverview overview;
  final AssetHistory history;
  final int days;
  final ValueChanged<int> onDays;

  @override
  State<_TrendSheet> createState() => _TrendSheetState();
}

class _TrendSheetState extends State<_TrendSheet> {
  late int _days = widget.days;

  @override
  void didUpdateWidget(covariant _TrendSheet oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) _days = widget.days;
  }

  @override
  Widget build(BuildContext context) => _AssetSheetFrame(
    title: '资产变化详情',
    child: ListView(
      padding: const EdgeInsets.fromLTRB(14, 0, 14, 28),
      children: [
        AssetTrendDetail(
          history: widget.history,
          currency: widget.overview.currency,
          days: _days,
          onDays: (days) {
            setState(() => _days = days);
            widget.onDays(days);
          },
        ),
      ],
    ),
  );
}

class _AssetSheetFrame extends StatelessWidget {
  const _AssetSheetFrame({required this.title, required this.child});
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: FractionallySizedBox(
      heightFactor: .52,
      alignment: Alignment.bottomCenter,
      child: Material(
        key: const ValueKey('asset-sheet-frame'),
        color: const Color(0xfff8faf1),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        clipBehavior: Clip.antiAlias,
        child: Column(
          children: [
            const SizedBox(height: 10),
            Container(
              width: 42,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xffd6dcc8),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            SizedBox(
              height: 52,
              child: Center(
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: assetInk,
                  ),
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    ),
  );
}
