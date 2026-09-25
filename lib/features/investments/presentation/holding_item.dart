import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/investment_portfolio.dart';
import 'investment_widgets.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// One 持仓列表 row: name, code, current market value, profit and return.
///
/// Deliberately limited to what answers “这个投资现在多少钱、赚亏多少” — no
/// extra market indicators.
class HoldingItem extends StatelessWidget {
  const HoldingItem({
    required this.position,
    required this.onTap,
    this.amountHidden = false,
    this.trailing,
    super.key,
  });

  final ValuedHolding position;
  final VoidCallback onTap;
  final bool amountHidden;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final holding = position.holding;
    final asset = holding.asset;
    final percent = position.profitPercent;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        key: ValueKey('investment-holding-${holding.id}'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 11, 12, 11),
          decoration: BoxDecoration(
            color: context.appSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: context.appDivider.withValues(alpha: .7)),
          ),
          child: LayoutBuilder(
            builder: (context, box) => Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                InvestmentTypeAvatar(type: asset.type, size: 38),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        asset.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                          color: context.appPrimaryText,
                        ),
                      ),
                      const SizedBox(height: 1),
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              asset.displayCode,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 11,
                                color: context.appSecondaryText,
                              ),
                            ),
                          ),
                          if (position.isStale) ...[
                            const SizedBox(width: 5),
                            const Icon(
                            Icons.cloud_off_outlined,
                            size: 11,
                            color: AppColors.warning,
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
              ),
                const SizedBox(width: 8),
                // The amount column is capped so an extreme position can never
                // break the card: PrivacyAmount's FittedBox scales down inside
                // a bounded width, but does nothing with an unbounded one.
                ConstrainedBox(
                  constraints: BoxConstraints(maxWidth: box.maxWidth * .46),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      InvestmentAmountText(
                        position.marketValue,
                        hidden: amountHidden,
                        size: 14,
                      ),
                      const SizedBox(height: 2),
                      InvestmentAmountText(
                        position.profit,
                        hidden: amountHidden,
                        signed: true,
                        size: 11,
                        weight: FontWeight.w600,
                        color: percent == null
                            ? context.appSecondaryText
                            : profitColor(percent, context: context),
                      ),
                      ProfitText(
                        percent: percent,
                        fontSize: 10,
                        weight: FontWeight.w400,
                        alignment: Alignment.centerRight,
                      ),
                    ],
                  ),
                ),
                if (trailing != null) ...[const SizedBox(width: 4), trailing!],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact single-line row used by 投资资产变动 on the overview page.
class HoldingMiniRow extends StatelessWidget {
  const HoldingMiniRow({
    required this.position,
    required this.onTap,
    this.amountHidden = false,
    super.key,
  });

  final ValuedHolding position;
  final VoidCallback onTap;
  final bool amountHidden;

  @override
  Widget build(BuildContext context) {
    final asset = position.holding.asset;
    final percent = position.profitPercent;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
        child: LayoutBuilder(
          builder: (context, box) => Row(
            children: [
              InvestmentTypeAvatar(type: asset.type, size: 32),
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
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: context.appPrimaryText,
                      ),
                    ),
                    Text(
                      asset.displayCode,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 10,
                        color: context.appSecondaryText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(maxWidth: box.maxWidth * .45),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    InvestmentAmountText(
                      position.marketValue,
                      hidden: amountHidden,
                      size: 13,
                    ),
                    ProfitText(
                      percent: percent,
                      fontSize: 10,
                      weight: FontWeight.w400,
                      alignment: Alignment.centerRight,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
