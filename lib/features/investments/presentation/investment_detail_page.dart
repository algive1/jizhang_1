import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../data/investment_repository.dart';
import '../domain/investment_asset.dart';
import '../domain/investment_holding.dart';
import '../domain/investment_input.dart';
import '../domain/investment_portfolio.dart';
import '../domain/investment_quote.dart';
import 'investment_chart.dart';
import 'investment_states.dart';
import 'investment_transaction_sheet.dart';
import 'investment_widgets.dart';
import 'transaction_item.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// 单个投资详情. Every asset class shares this layout; only the small set of
/// extra fields below the fold differs.
class InvestmentDetailPage extends ConsumerStatefulWidget {
  const InvestmentDetailPage({required this.holdingId, super.key});

  final String holdingId;

  @override
  ConsumerState<InvestmentDetailPage> createState() =>
      _InvestmentDetailPageState();
}

class _InvestmentDetailPageState extends ConsumerState<InvestmentDetailPage> {
  InvestmentRange _range = InvestmentRange.month;
  bool _hidden = false;

  @override
  Widget build(BuildContext context) {
    final holdingState = ref.watch(investmentHoldingProvider(widget.holdingId));
    final transactions = ref
        .watch(investmentTransactionsProvider(widget.holdingId))
        .value;
    final position = holdingState.value;

    return Scaffold(
      backgroundColor: const Color(0xFFF6F7EE),
      body: SafeArea(
        bottom: false,
        child: holdingState.isLoading && position == null
            ? const Center(child: CircularProgressIndicator())
            : position == null
            ? Column(
                children: [
                  _Header(
                    title: '投资详情',
                    onBack: _goBack,
                    onAddTransaction: null,
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                      children: [
                        InvestmentErrorState(
                          message: '未找到该持仓，可能已被删除',
                          onRetry: () => ref.invalidate(
                            investmentHoldingProvider(widget.holdingId),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              )
            : Column(
                children: [
                  _Header(
                    title: position.holding.asset.name,
                    onBack: _goBack,
                    onAddTransaction: () => _openTransactionSheet(position),
                  ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 28),
                      children: [
                        _PositionHeaderCard(
                          position: position,
                          hidden: _hidden,
                          onHidden: (value) => setState(() => _hidden = value),
                        ),
                        const SizedBox(height: 12),
                        _PositionStatsCard(position: position, hidden: _hidden),
                        const SizedBox(height: 12),
                        _TrendCard(
                          position: position,
                          range: _range,
                          onRange: (value) => setState(() => _range = value),
                        ),
                        const SizedBox(height: 14),
                        InvestmentSectionHeader(
                          title: '交易记录',
                          action: '+ 记录',
                          onAction: () => _openTransactionSheet(position),
                        ),
                        if (transactions == null)
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 20),
                            child: Center(child: CircularProgressIndicator()),
                          )
                        else if (transactions.isEmpty)
                          const _NoTransactions()
                        else
                          Column(
                            children: [
                              for (final transaction in transactions)
                                Padding(
                                  padding: const EdgeInsets.only(bottom: 8),
                                  child: TransactionItem(
                                    transaction: transaction,
                                    unit: _unitLabel(position.holding.asset.type),
                                  ),
                                ),
                            ],
                          ),
                      ],
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
      context.go('/profile/investments');
    }
  }

  Future<void> _openTransactionSheet(ValuedHolding position) async {
    final changed = await showInvestmentTransactionSheet(
      context,
      holding: position.holding,
    );
    if (changed == true) {
      ref.invalidate(investmentTransactionsProvider(widget.holdingId));
      ref.invalidate(investmentHoldingProvider(widget.holdingId));
      ref.invalidate(investmentPortfolioProvider);
    }
  }
}

String _unitLabel(InvestmentAssetType type) => switch (type) {
  InvestmentAssetType.fund => '份',
  InvestmentAssetType.crypto => '个',
  InvestmentAssetType.bond => '张',
  InvestmentAssetType.stock => '股',
};

class _Header extends StatelessWidget {
  const _Header({
    required this.title,
    required this.onBack,
    required this.onAddTransaction,
  });

  final String title;
  final VoidCallback onBack;
  final VoidCallback? onAddTransaction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(6, 6, 10, 0),
    child: Row(
      children: [
        IconButton(
          key: const ValueKey('investment-detail-back'),
          onPressed: onBack,
          icon: Icon(Icons.chevron_left, size: 26),
          color: context.appPrimaryText,
          tooltip: '返回',
        ),
        Expanded(
          child: Text(
            title,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w800,
              color: context.appPrimaryText,
            ),
          ),
        ),
        IconButton(
          key: const ValueKey('investment-detail-add-transaction'),
          onPressed: onAddTransaction,
          icon: Icon(Icons.add_circle_outline, size: 22),
          color: context.appPrimary,
          tooltip: '记录交易',
        ),
      ],
    ),
  );
}

/// Headline block: current price, today's move and the headline market value.
class _PositionHeaderCard extends StatelessWidget {
  const _PositionHeaderCard({
    required this.position,
    required this.hidden,
    required this.onHidden,
  });

  final ValuedHolding position;
  final bool hidden;
  final ValueChanged<bool> onHidden;

  @override
  Widget build(BuildContext context) {
    final holding = position.holding;
    final asset = holding.asset;
    final quote = position.quote;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 13, 14, 13),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              InvestmentTypeAvatar(type: asset.type, size: 36),
              const SizedBox(width: 9),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      asset.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: context.appPrimaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Text(
                          asset.displayCode,
                          style: TextStyle(
                            fontSize: 11,
                            color: context.appSecondaryText,
                          ),
                        ),
                        const SizedBox(width: 6),
                        InvestmentChip(
                          label: asset.type.label,
                          color: asset.type.accent,
                          background: asset.type.surface,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Semantics(
                button: true,
                label: hidden ? '显示投资金额' : '隐藏投资金额',
                child: InkWell(
                  key: const ValueKey('investment-detail-hide-toggle'),
                  onTap: () => onHidden(!hidden),
                  borderRadius: BorderRadius.circular(20),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(
                      hidden
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 17,
                      color: context.appSecondaryText,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, box) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                    Text(
                      _priceLabel(asset.type),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¥${InvestmentInput.formatPriceLabel(position.price)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: context.appPrimaryText,
                          fontFeatures: [FontFeature.tabularFigures()],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              // Bounded so a large change value scales down instead of
              // overflowing the card.
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * .42),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      _changeLabel(asset.type),
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 2),
                    InvestmentAmountText(
                      quote?.change ?? 0,
                      hidden: hidden,
                      signed: true,
                      size: 14,
                      color: quote == null
                          ? context.appSecondaryText
                          : profitColor(quote.change),
                    ),
                    ProfitText(
                      percent: quote?.changePercent,
                      fontSize: 11,
                      alignment: Alignment.centerRight,
                    ),
                  ],
                ),
              ),
            ],
            ),
          ),
          if (quote != null) ...[
            const SizedBox(height: 6),
            QuoteStatus(
              timestamp: quote.timestamp,
              isStale: quote.isStale,
            ),
          ],
          const Divider(height: 20),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '当前市值',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    InvestmentAmountText(
                      position.marketValue,
                      hidden: hidden,
                      size: 17,
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '累计收益',
                      style: TextStyle(
                        fontSize: 11,
                        color: context.appSecondaryText,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Row(
                      children: [
                        Flexible(
                          child: InvestmentAmountText(
                            position.profit,
                            hidden: hidden,
                            signed: true,
                            size: 17,
                            color: position.profitPercent == null
                                ? context.appSecondaryText
                                : profitColor(position.profit),
                          ),
                        ),
                        const SizedBox(width: 5),
                        Flexible(
                          child: ProfitText(
                            percent: position.profitPercent,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  static String _priceLabel(InvestmentAssetType type) => switch (type) {
    InvestmentAssetType.fund => '最新净值',
    _ => '当前价格',
  };

  static String _changeLabel(InvestmentAssetType type) => switch (type) {
    InvestmentAssetType.crypto => '24H涨跌',
    _ => '今日涨跌',
  };
}

/// 持仓数据: average cost and quantity, plus the small per-class extras.
class _PositionStatsCard extends StatelessWidget {
  const _PositionStatsCard({required this.position, required this.hidden});

  final ValuedHolding position;
  final bool hidden;

  @override
  Widget build(BuildContext context) {
    final holding = position.holding;
    final asset = holding.asset;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '持仓数据',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: context.appPrimaryText,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _StatTile(
                label: '平均成本',
                value:
                    '¥${InvestmentInput.formatPriceLabel(holding.averageCost)}',
              ),
              _StatTile(
                label: _quantityLabel(asset.type),
                value:
                    '${InvestmentTransaction.formatQuantity(holding.quantity)} ${_unitLabel(asset.type)}',
              ),
              _StatTile(
                label: '持仓成本',
                value: '¥${MoneyFormatter.decimal(holding.cost)}',
                hiddenValue: hidden,
              ),
              for (final extra in _extras(asset, position.price))
                _StatTile(label: extra.$1, value: extra.$2),
            ],
          ),
          if (asset.currency != 'CNY') ...[
            const SizedBox(height: 8),
            Text(
              '计价货币 ${asset.currency}，暂不折算为本位币',
              style: TextStyle(
                fontSize: 11,
                color: context.appSecondaryText,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Class-specific fields that a data source may or may not provide.
  ///
  /// Only a fund's NAV date is currently known. A bond's 票面利率 / 到期日 and
  /// a stock's 今日涨跌 detail are intentionally omitted until a real quote
  /// source supplies them — showing an invented value is worse than showing
  /// nothing.
  static List<(String, String)> _extras(
    InvestmentAsset asset,
    double price,
  ) {
    switch (asset.type) {
      case InvestmentAssetType.fund:
        return [
          ('净值日期', DateFormat('yyyy-MM-dd').format(DateTime.now())),
        ];
      case InvestmentAssetType.bond:
      case InvestmentAssetType.stock:
      case InvestmentAssetType.crypto:
        return const [];
    }
  }

  static String _quantityLabel(InvestmentAssetType type) => switch (type) {
    InvestmentAssetType.fund => '持有份额',
    InvestmentAssetType.bond => '持有数量（张）',
    InvestmentAssetType.crypto => '持有数量（个）',
    InvestmentAssetType.stock => '持有数量（股）',
  };
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.label,
    required this.value,
    this.hiddenValue = false,
  });

  final String label;
  final String value;
  final bool hiddenValue;

  @override
  Widget build(BuildContext context) => Container(
    constraints: const BoxConstraints(minWidth: 104),
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
    decoration: BoxDecoration(
      color: const Color(0xFFF7F8EE),
      borderRadius: BorderRadius.circular(14),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: context.appSecondaryText,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          hiddenValue ? '••••' : value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: context.appPrimaryText,
            fontFeatures: [FontFeature.tabularFigures()],
          ),
        ),
      ],
    ),
  );
}

/// Price / net-value trend. Same three ranges as the overview chart.
class _TrendCard extends ConsumerWidget {
  const _TrendCard({
    required this.position,
    required this.range,
    required this.onRange,
  });

  final ValuedHolding position;
  final InvestmentRange range;
  final ValueChanged<InvestmentRange> onRange;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asset = position.holding.asset;
    final history = ref.watch(
      investmentHistoryProvider(
        PriceHistoryKey(asset.symbol, asset.type, range),
      ),
    );
    final points = history.maybeWhen(
      data: (rows) => [
        for (final point in rows) (date: point.date, value: point.value),
      ],
      orElse: () => const <({DateTime date, double value})>[],
    );
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 12, 12, 10),
      decoration: BoxDecoration(
        color: const Color(0xF7FFFFFC),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider.withValues(alpha: .7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  asset.type == InvestmentAssetType.fund ? '净值走势' : '价格走势',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w800,
                    color: context.appPrimaryText,
                  ),
                ),
              ),
              Flexible(
                child: InvestmentRangeSelector<InvestmentRange>(
                  keyPrefix: 'holding-range',
                  items: [
                    for (final option in InvestmentRange.values)
                      (option, option.label),
                  ],
                  selected: range,
                  onChanged: onRange,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (history.isLoading && points.isEmpty)
            const SizedBox(height: 118, child: _TrendSkeleton())
          else if (history.hasError && points.isEmpty)
            SizedBox(
              height: 118,
              child: Center(
                child: Text(
                  '行情更新失败',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.warning,
                  ),
                ),
              ),
            )
          else
            InvestmentChart(
              keyPrefix: 'holding-trend',
              points: points,
              amountHidden: false,
              lineColor: asset.type.accent,
              valueFormatter: (value) =>
                  '¥${InvestmentInput.formatPriceLabel(value)}',
              emptyLabel: '暂无走势数据',
            ),
        ],
      ),
    );
  }
}

class _TrendSkeleton extends StatelessWidget {
  const _TrendSkeleton();

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

class _NoTransactions extends StatelessWidget {
  const _NoTransactions();

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(vertical: 22),
    decoration: BoxDecoration(
      color: const Color(0xF7FFFFFC),
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: context.appDivider.withValues(alpha: .7)),
    ),
    child: const Column(
      children: [
        Icon(
          Icons.receipt_long_outlined,
          size: 22,
          color: context.appSecondaryText,
        ),
        SizedBox(height: 6),
        Text(
          '暂无交易记录',
          style: TextStyle(fontSize: 12, color: context.appSecondaryText),
        ),
      ],
    ),
  );
}
