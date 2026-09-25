import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../domain/investment_asset.dart';
import '../domain/investment_portfolio.dart';
import 'investment_widgets.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// Top card on 投资管理总览.
///
/// The headline is deliberately labelled 投资资产 and not 总资产, so the
/// invested amount can never be mistaken for the net worth shown on the
/// existing 资产总览 page.
class InvestmentSummaryCard extends StatelessWidget {
  const InvestmentSummaryCard({
    required this.portfolio,
    required this.amountHidden,
    required this.onAmountHiddenChanged,
    this.title = '投资资产',
    this.staleLabel,
    super.key,
  });

  final InvestmentPortfolio portfolio;
  final bool amountHidden;
  final ValueChanged<bool>? onAmountHiddenChanged;
  final String title;

  /// Rendered under the headline when a quote refresh failed.
  final Widget? staleLabel;

  @override
  Widget build(BuildContext context) {
    final today = portfolio.todayProfit;
    final total = portfolio.totalProfit;
    final dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: context.appSurface,
        image: const DecorationImage(
          image: AssetImage(AppAssets.homeAssetScene),
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider.withValues(alpha: .72)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x0C65713F),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned.fill(
            child: DecoratedBox(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(-.6, .05),
                  radius: .95,
                  colors: dark
                      ? [
                          context.appSurface.withValues(alpha: .92),
                          context.appSurface.withValues(alpha: .58),
                          context.appSurface.withValues(alpha: .08),
                        ]
                      : const [
                          Color(0xDBFFFEF8),
                          Color(0x80FFFEF8),
                          Color(0x00FFFEF8),
                        ],
                  stops: const [0, .4, 1],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.savings_outlined,
                      size: 15,
                      color: Color(0xFF6D8A4A),
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF5F6B52),
                        ),
                      ),
                    ),
                    if (onAmountHiddenChanged != null)
                      _HideToggle(
                        hidden: amountHidden,
                        onChanged: onAmountHiddenChanged!,
                      ),
                    const SizedBox(width: 2),
                    Text(
                      '${portfolio.currency} · ${portfolio.positions.length} 笔',
                      style: const TextStyle(
                        fontSize: 10,
                        color: Color(0xFF7C8570),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: InvestmentAmountText(
                    portfolio.investmentValue,
                    hidden: amountHidden,
                    size: 28,
                    color: const Color(0xFF2C3A22),
                    currency: portfolio.currency,
                  ),
                ),
                if (staleLabel != null) ...[
                  const SizedBox(height: 2),
                  staleLabel!,
                ],
                const SizedBox(height: 8),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: _SummaryMetric(
                        label: '今日涨跌',
                        amount: today,
                        percent: portfolio.todayProfitPercent,
                        hidden: amountHidden,
                        currency: portfolio.currency,
                      ),
                    ),
                    Container(
                      width: 1,
                      height: 32,
                      color: const Color(0x33788A5C),
                    ),
                    Expanded(
                      child: _SummaryMetric(
                        label: '累计收益',
                        amount: total,
                        percent: portfolio.totalProfitPercent,
                        hidden: amountHidden,
                        currency: portfolio.currency,
                        showSign: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SummaryMetric extends StatelessWidget {
  const _SummaryMetric({
    required this.label,
    required this.amount,
    required this.percent,
    required this.hidden,
    required this.currency,
    this.showSign = true,
  });

  final String label;
  final double amount;
  final double? percent;
  final bool hidden;
  final String currency;
  final bool showSign;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(fontSize: 10, color: Color(0xFF7C8570)),
        ),
        const SizedBox(height: 2),
        InvestmentAmountText(
          amount,
          hidden: hidden,
          signed: showSign,
          size: 15,
          currency: currency,
          color: percent == null
              ? context.appSecondaryText
              : profitColor(percent!),
        ),
        ProfitText(percent: percent, fontSize: 10),
      ],
    ),
  );
}

class _HideToggle extends StatelessWidget {
  const _HideToggle({required this.hidden, required this.onChanged});

  final bool hidden;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    label: hidden ? '显示投资金额' : '隐藏投资金额',
    child: InkWell(
      key: const ValueKey('investment-amount-toggle'),
      onTap: () => onChanged(!hidden),
      borderRadius: BorderRadius.circular(20),
      child: Padding(
        padding: const EdgeInsets.all(3),
        child: Icon(
          hidden ? Icons.visibility_off_outlined : Icons.visibility_outlined,
          size: 15,
          color: const Color(0xFF6D8A4A),
        ),
      ),
    ),
  );
}

/// One row of the 投资分类卡片 grid. Shows the class total and its return.
class InvestmentCategoryCard extends StatelessWidget {
  const InvestmentCategoryCard({
    required this.summary,
    required this.onTap,
    this.amountHidden = false,
    super.key,
  });

  final InvestmentCategorySummary summary;
  final VoidCallback onTap;
  final bool amountHidden;

  @override
  Widget build(BuildContext context) {
    final type = summary.type;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('investment-category-${type.name}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: const Color(0xF5FFFFFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.appDivider.withValues(alpha: .7)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 30,
                    height: 30,
                    decoration: BoxDecoration(
                      color: type.surface,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(type.icon, size: 16, color: type.accent),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: Text(
                      type.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: context.appPrimaryText,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: InvestmentAmountText(
                  summary.value,
                  hidden: amountHidden,
                  size: 15,
                  weight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 2),
              ProfitText(percent: summary.profitPercent, fontSize: 10),
            ],
          ),
        ),
      ),
    );
  }
}
