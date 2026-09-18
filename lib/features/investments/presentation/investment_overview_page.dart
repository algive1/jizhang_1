import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme/app_colors.dart';
import '../data/investment_repository.dart';
import '../domain/investment_asset.dart';
import '../domain/investment_portfolio.dart';
import '../domain/investment_quote.dart';
import 'holding_item.dart';
import 'investment_chart.dart';
import 'investment_states.dart';
import 'investment_summary_card.dart';
import 'investment_type_picker.dart';
import 'investment_widgets.dart';

/// The five top-level tabs. `null` is the 总览 tab.
typedef _InvestmentTab = InvestmentAssetType?;

class InvestmentOverviewPage extends ConsumerStatefulWidget {
  const InvestmentOverviewPage({super.key, this.initialTab});

  /// Optional class tab to open on, used when arriving from a deep link.
  final InvestmentAssetType? initialTab;

  @override
  ConsumerState<InvestmentOverviewPage> createState() =>
      _InvestmentOverviewPageState();
}

class _InvestmentOverviewPageState
    extends ConsumerState<InvestmentOverviewPage> {
  late _InvestmentTab _tab = widget.initialTab;
  bool _hidden = false;
  PortfolioRange _range = PortfolioRange.month;

  @override
  Widget build(BuildContext context) {
    final portfolioState = ref.watch(investmentPortfolioProvider);
    final portfolio = portfolioState.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7EE),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            _Header(
              onBack: _goBack,
              onAdd: _startAdd,
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
              child: _InvestmentTabBar(
                selected: _tab,
                onChanged: (value) => setState(() => _tab = value),
              ),
            ),
            Expanded(
              child: portfolioState.hasError && portfolio == null
                  ? ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        InvestmentErrorState(
                          message: '投资数据加载失败，请重试',
                          onRetry: () => ref.invalidate(
                            investmentPortfolioProvider,
                          ),
                        ),
                      ],
                    )
                  : portfolio == null
                  ? const SingleChildScrollView(
                      padding: EdgeInsets.fromLTRB(16, 4, 16, 24),
                      child: InvestmentSkeleton(),
                    )
                  : _tab == null
                  ? _OverviewTab(
                      portfolio: portfolio,
                      hidden: _hidden,
                      range: _range,
                      onRange: (value) => setState(() => _range = value),
                      onHidden: (value) => setState(() => _hidden = value),
                      onAdd: _startAdd,
                      onOpenType: (type) => context.push(
                        '/profile/investments/holdings/${type.name}',
                      ),
                      onOpenHolding: _openHolding,
                    )
                  : _CategoryTab(
                      type: _tab!,
                      portfolio: portfolio.scopedTo(_tab!),
                      hidden: _hidden,
                      onAdd: () => _startAdd(type: _tab),
                      onOpenHolding: _openHolding,
                    ),
            ),
          ],
        ),
      ),
    );
  }

  void _goBack() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/profile/assets');
    }
  }

  Future<void> _startAdd({InvestmentAssetType? type}) async {
    final selected = type ?? await showInvestmentTypePicker(context);
    if (selected == null || !mounted) return;
    context.push('/profile/investments/add?type=${selected.name}');
  }

  void _openHolding(String holdingId) {
    context.push('/profile/investments/holdings/detail/$holdingId');
  }
}

/// Lightweight 5-item tab strip.
///
/// A plain label row with a soft pill behind the active item — chosen over the
/// existing segmented control because five Chinese labels do not fit that
/// control's fixed-width capsules on a 320 dp screen, and because the
/// securities-style high-contrast tab bar is explicitly out of scope.
class _InvestmentTabBar extends StatelessWidget {
  const _InvestmentTabBar({required this.selected, required this.onChanged});

  final _InvestmentTab selected;
  final ValueChanged<_InvestmentTab> onChanged;

  static const _items = <(_InvestmentTab, String)>[
    (null, '总览'),
    (InvestmentAssetType.stock, '股票'),
    (InvestmentAssetType.fund, '基金'),
    (InvestmentAssetType.bond, '债券'),
    (InvestmentAssetType.crypto, '虚拟币'),
  ];

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(3),
    decoration: BoxDecoration(
      color: const Color(0xFFEDEFE0),
      borderRadius: BorderRadius.circular(24),
    ),
    child: Row(
      children: [
        for (final item in _items)
          Expanded(
            child: Semantics(
              selected: selected == item.$1,
              button: true,
              child: InkWell(
                key: ValueKey(
                  'investment-tab-${item.$1?.name ?? 'overview'}',
                ),
                onTap: () => onChanged(item.$1),
                borderRadius: BorderRadius.circular(20),
                child: AnimatedContainer(
                  duration: MediaQuery.disableAnimationsOf(context)
                      ? Duration.zero
                      : const Duration(milliseconds: 200),
                  curve: Curves.easeOutCubic,
                  padding: const EdgeInsets.symmetric(vertical: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: selected == item.$1
                        ? AppColors.primary
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    item.$2,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: selected == item.$1
                          ? FontWeight.w700
                          : FontWeight.w500,
                      color: selected == item.$1
                          ? Colors.white
                          : AppColors.textSecondary,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    ),
  );
}

class _Header extends StatelessWidget {
  const _Header({required this.onBack, required this.onAdd});

  final VoidCallback onBack;
  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 6, 10, 0),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('investment-back'),
          onPressed: onBack,
          icon: const Icon(Icons.chevron_left, size: 26),
          color: AppColors.textPrimary,
          tooltip: '返回资产总览',
        ),
        const Expanded(
          child: Text(
            '投资管理',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('investment-add-action'),
          onPressed: onAdd,
          icon: const Icon(Icons.add_circle_outline, size: 22),
          color: AppColors.primaryDark,
          tooltip: '添加投资',
        ),
      ],
    ),
  );
}

class _OverviewTab extends ConsumerWidget {
  const _OverviewTab({
    required this.portfolio,
    required this.hidden,
    required this.range,
    required this.onRange,
    required this.onHidden,
    required this.onAdd,
    required this.onOpenType,
    required this.onOpenHolding,
  });

  final InvestmentPortfolio portfolio;
  final bool hidden;
  final PortfolioRange range;
  final ValueChanged<PortfolioRange> onRange;
  final ValueChanged<bool> onHidden;
  final VoidCallback onAdd;
  final ValueChanged<InvestmentAssetType> onOpenType;
  final ValueChanged<String> onOpenHolding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (portfolio.isEmpty) {
      return ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [InvestmentEmptyState(onAdd: onAdd)],
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        InvestmentSummaryCard(
          portfolio: portfolio,
          amountHidden: hidden,
          onAmountHiddenChanged: onHidden,
          staleLabel: portfolio.hasStaleQuote
              ? const QuoteStatus(timestamp: null, isStale: true)
              : null,
        ),
        const SizedBox(height: 12),
        const InvestmentSectionHeader(title: '投资分类'),
        _CategoryGrid(
          portfolio: portfolio,
          hidden: hidden,
          onOpenType: onOpenType,
        ),
        const SizedBox(height: 14),
        _TrendSection(range: range, onRange: onRange),
        const SizedBox(height: 14),
        InvestmentSectionHeader(
          title: '投资资产变动',
          action: '查看全部',
          onAction: () => onOpenType(portfolio.positions.first.holding.asset.type),
        ),
        _PositionsList(
          positions: portfolio.positions.take(5).toList(growable: false),
          hidden: hidden,
          onOpenHolding: onOpenHolding,
        ),
      ],
    );
  }
}

class _CategoryGrid extends StatelessWidget {
  const _CategoryGrid({
    required this.portfolio,
    required this.hidden,
    required this.onOpenType,
  });

  final InvestmentPortfolio portfolio;
  final bool hidden;
  final ValueChanged<InvestmentAssetType> onOpenType;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      const spacing = 8.0;
      final width = (box.maxWidth - spacing) / 2;
      return Wrap(
        spacing: spacing,
        runSpacing: spacing,
        children: [
          for (final summary in portfolio.categories)
            SizedBox(
              width: width,
              child: InvestmentCategoryCard(
                summary: summary,
                amountHidden: hidden,
                onTap: () => onOpenType(summary.type),
              ),
            ),
        ],
      );
    },
  );
}

class _TrendSection extends ConsumerWidget {
  const _TrendSection({required this.range, required this.onRange});

  final PortfolioRange range;
  final ValueChanged<PortfolioRange> onRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final snapshots = ref.watch(investmentSnapshotsProvider(range.days));
    final trend = snapshots.maybeWhen(
      data: (rows) => InvestmentTrend.from(
        rows,
        now: DateTime.now(),
        days: range.days,
      ),
      orElse: () => const InvestmentTrend([]),
    );
    final points = [
      for (final point in trend.points)
        (date: point.date, value: point.value),
    ];
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '投资资产趋势',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Flexible(
                child: InvestmentRangeSelector<PortfolioRange>(
                  keyPrefix: 'portfolio-range',
                  items: [
                    for (final option in PortfolioRange.values)
                      (option, option.label),
                  ],
                  selected: range,
                  onChanged: onRange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (snapshots.isLoading && points.isEmpty)
            const SizedBox(height: 118, child: Center(child: _ChartSkeleton()))
          else
            InvestmentChart(
              keyPrefix: 'portfolio-trend',
              points: points,
              amountHidden: false,
              emptyLabel: '明天起显示资产趋势',
            ),
        ],
      ),
    );
  }
}

class _ChartSkeleton extends StatelessWidget {
  const _ChartSkeleton();

  @override
  Widget build(BuildContext context) => Container(
    height: 90,
    margin: const EdgeInsets.symmetric(horizontal: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF1F2E6),
      borderRadius: BorderRadius.circular(14),
    ),
  );
}

class _PositionsList extends StatelessWidget {
  const _PositionsList({
    required this.positions,
    required this.hidden,
    required this.onOpenHolding,
  });

  final List<ValuedHolding> positions;
  final bool hidden;
  final ValueChanged<String> onOpenHolding;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    decoration: BoxDecoration(
      color: const Color(0xF7FFFFFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.divider.withValues(alpha: .7)),
    ),
    child: Column(
      children: [
        for (var i = 0; i < positions.length; i++) ...[
          HoldingMiniRow(
            position: positions[i],
            amountHidden: hidden,
            onTap: () => onOpenHolding(positions[i].holding.id),
          ),
          if (i != positions.length - 1)
            const Divider(height: 1, color: AppColors.divider),
        ],
      ],
    ),
  );
}

/// One 分类 tab: the class summary plus its holdings. Stocks, funds, bonds and
/// crypto all reuse this exact widget — the class is the only variable.
class _CategoryTab extends StatelessWidget {
  const _CategoryTab({
    required this.type,
    required this.portfolio,
    required this.hidden,
    required this.onAdd,
    required this.onOpenHolding,
  });

  final InvestmentAssetType type;
  final InvestmentPortfolio portfolio;
  final bool hidden;
  final VoidCallback onAdd;
  final ValueChanged<String> onOpenHolding;

  @override
  Widget build(BuildContext context) {
    final summary = portfolio.categoryOf(type);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
      children: [
        if (portfolio.isEmpty)
          InvestmentEmptyState(type: type, onAdd: onAdd)
        else ...[
          _CategorySummaryCard(summary: summary, hidden: hidden),
          const SizedBox(height: 12),
          InvestmentSectionHeader(
            title: '持仓列表',
            trailing: TextButton.icon(
              key: ValueKey('investment-category-add-${type.name}'),
              onPressed: onAdd,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('添加', style: TextStyle(fontSize: 12)),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.primaryDark,
                padding: const EdgeInsets.symmetric(horizontal: 6),
                minimumSize: const Size(0, 28),
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ),
          for (final position in portfolio.positions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: HoldingItem(
                position: position,
                amountHidden: hidden,
                onTap: () => onOpenHolding(position.holding.id),
              ),
            ),
        ],
      ],
    );
  }
}

class _CategorySummaryCard extends StatelessWidget {
  const _CategorySummaryCard({required this.summary, required this.hidden});

  final InvestmentCategorySummary summary;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final type = summary.type;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.divider.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InvestmentTypeAvatar(type: type, size: 34),
              const SizedBox(width: 9),
              Expanded(
                child: Text(
                  '${type.label}总资产',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
              InvestmentChip(
                label: '${summary.holdingCount} 笔持仓',
                color: type.accent,
                background: type.surface,
              ),
            ],
          ),
          const SizedBox(height: 8),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: InvestmentAmountText(
              summary.value,
              hidden: hidden,
              size: 26,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 2),
          // Both the amount and the rate are Flexible: a big position or a
          // 1.6 text scale shrinks them instead of breaking the card.
          Row(
            children: [
              const Text(
                '累计收益',
                style: TextStyle(fontSize: 11, color: AppColors.textSecondary),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: InvestmentAmountText(
                  summary.profit,
                  hidden: hidden,
                  signed: true,
                  size: 13,
                  color: summary.profitPercent == null
                      ? AppColors.textSecondary
                      : profitColor(summary.profit),
                ),
              ),
              const SizedBox(width: 6),
              Flexible(
                child: ProfitText(
                  percent: summary.profitPercent,
                  fontSize: 11,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
