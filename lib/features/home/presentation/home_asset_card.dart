import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/account.dart';
import '../../../core/widgets/privacy_amount.dart';
import '../../accounts/domain/asset_overview.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// A compact summary of real account balances. Different currencies stay
/// separate; detailed accounts remain on `/profile/assets`.
class HomeAssetCard extends StatelessWidget {
  const HomeAssetCard({
    required this.accounts,
    required this.amountHidden,
    required this.onTap,
    this.onAmountHiddenChanged,
    this.compactHeight,
    this.investmentByCurrency = const {},
    super.key,
  }) : onRetry = null,
       _state = _HomeAssetCardState.data;

  const HomeAssetCard.loading({super.key})
    : accounts = const [],
      amountHidden = false,
      onTap = null,
      onAmountHiddenChanged = null,
      compactHeight = null,
      investmentByCurrency = const {},
      onRetry = null,
      _state = _HomeAssetCardState.loading;

  const HomeAssetCard.error({required this.onRetry, super.key})
    : accounts = const [],
      amountHidden = false,
      onTap = null,
      onAmountHiddenChanged = null,
      compactHeight = null,
      investmentByCurrency = const {},
      _state = _HomeAssetCardState.error;

  final List<Account> accounts;

  /// Market value of the user's investment positions, by currency.
  ///
  /// Folded into net worth here so the home card and 资产总览 never disagree.
  final Map<String, double> investmentByCurrency;

  final bool amountHidden;
  final VoidCallback? onTap;
  final ValueChanged<bool>? onAmountHiddenChanged;

  /// Optional fixed height used by the full asset overview layout. Keeping
  /// the card's internal scene at the same scale avoids vertically stretching
  /// the artwork with an outer FittedBox.
  final double? compactHeight;
  final VoidCallback? onRetry;
  final _HomeAssetCardState _state;

  @override
  Widget build(BuildContext context) {
    if (_state == _HomeAssetCardState.loading) return _loadingCard();
    if (_state == _HomeAssetCardState.error) return _errorCard();

    final groups = AssetOverview.group(
      accounts,
      investmentByCurrency: investmentByCurrency,
    );
    if (groups.isEmpty) return _emptyCard();

    final overview = groups.first;
    final largeText = MediaQuery.textScalerOf(context).scale(1) > 1.15;
    final compact = !largeText && compactHeight != null;
    return Semantics(
      button: onTap != null,
      label: '查看资产总览，净资产 ${overview.currency}',
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          key: const ValueKey('home-asset-card'),
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Container(
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: context.appSurfaceSoft,
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
            child: SizedBox(
              height: largeText ? null : (compactHeight ?? 165),
              child: Stack(
                fit: largeText ? StackFit.loose : StackFit.expand,
                children: [
                  Positioned.fill(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: RadialGradient(
                          center: const Alignment(-.55, .05),
                          radius: .9,
                          colors: [
                            context.appSurface.withValues(alpha: .80),
                            context.appSurface.withValues(alpha: .42),
                            context.appSurface.withValues(alpha: 0),
                          ],
                          stops: const [0, .38, 1],
                        ),
                      ),
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      14,
                      compact ? 6 : 11,
                      14,
                      compact ? 5 : 10,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _AssetHeader(
                          overview: overview,
                          amountHidden: amountHidden,
                          onAmountHiddenChanged: onAmountHiddenChanged,
                          compact: compact,
                        ),
                        SizedBox(height: compact ? 2 : 7),
                        Text(
                          '账面净资产',
                          style: TextStyle(
                            color: context.appSecondaryText,
                            fontSize: compact ? 9 : 11,
                          ),
                        ),
                        const SizedBox(height: 1),
                        SizedBox(
                          width: largeText ? double.infinity : 180,
                          child: _HomeAssetMoney(
                            amount: overview.netAssets,
                            currency: overview.currency,
                            hidden: amountHidden,
                            prominent: true,
                            compact: compact,
                          ),
                        ),
                        if (groups.length > 1)
                          Text(
                            '另有 ${groups.length - 1} 种币种 · 分开统计',
                            style: TextStyle(
                              color: context.appPrimary,
                              fontSize: 9,
                            ),
                          ),
                        if (largeText)
                          const SizedBox(height: 10)
                        else
                          const Spacer(),
                        _HomeAssetMetricsPanel(
                          overview: overview,
                          hidden: amountHidden,
                          compact: compact,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _emptyCard() => _StateCard(
    icon: Icons.account_balance_wallet_outlined,
    title: '还没有资产数据',
    subtitle: '添加账户后，这里会显示净资产和负债',
    actionLabel: '去添加账户',
    onTap: onTap,
  );

  Widget _loadingCard() => const _StateCard(
    icon: Icons.account_balance_wallet_outlined,
    title: '正在读取资产',
    subtitle: '账户余额加载完成后会显示在这里',
  );

  Widget _errorCard() => _StateCard(
    icon: Icons.sync_problem_outlined,
    title: '资产暂时无法读取',
    subtitle: '没有把读取失败当成 0 元，请稍后重试',
    actionLabel: '重新加载',
    onTap: onRetry,
  );
}

class _AssetHeader extends StatelessWidget {
  const _AssetHeader({
    required this.overview,
    required this.amountHidden,
    required this.onAmountHiddenChanged,
    required this.compact,
  });

  final AssetOverview overview;
  final bool amountHidden;
  final ValueChanged<bool>? onAmountHiddenChanged;
  final bool compact;

  @override
  Widget build(BuildContext context) => Row(
    children: [
      Container(
        width: compact ? 26 : 32,
        height: compact ? 26 : 32,
        decoration: BoxDecoration(
          color: context.appSurface.withValues(alpha: .78),
          shape: BoxShape.circle,
          border: Border.all(color: context.appDivider),
        ),
        child: Icon(
          Icons.account_balance_wallet_outlined,
          color: context.appPrimary,
          size: compact ? 15 : 18,
        ),
      ),
      SizedBox(width: compact ? 5 : 8),
      Expanded(
        child: Text(
          '我的净资产',
          style: TextStyle(
            color: context.appPrimaryText,
            fontSize: compact ? 14 : 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      IconButton(
        key: const ValueKey('home-assets-hide-amount'),
        tooltip: amountHidden ? '显示资产金额' : '隐藏资产金额',
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.zero,
        constraints: BoxConstraints.tightFor(
          width: compact ? 22 : 26,
          height: compact ? 22 : 26,
        ),
        onPressed: onAmountHiddenChanged == null
            ? null
            : () => onAmountHiddenChanged!(!amountHidden),
        icon: Icon(
          amountHidden
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
          color: context.appSecondaryText,
          size: compact ? 15 : 18,
        ),
      ),
      SizedBox(width: compact ? 1 : 2),
      const Spacer(),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: Text(
            '${overview.currency} · ${_assetAccountCount(overview)} 个账户',
            maxLines: 1,
            style: TextStyle(
              color: context.appSecondaryText,
              fontSize: compact ? 9 : 11,
            ),
          ),
        ),
      ),
      const SizedBox(width: 1),
      Icon(
        Icons.chevron_right,
        color: context.appSecondaryText,
        size: compact ? 16 : 19,
      ),
    ],
  );
}

class _HomeAssetMetricsPanel extends StatelessWidget {
  const _HomeAssetMetricsPanel({
    required this.overview,
    required this.hidden,
    required this.compact,
  });

  final AssetOverview overview;
  final bool hidden;
  final bool compact;

  @override
  Widget build(BuildContext context) => Container(
    padding: EdgeInsets.symmetric(
      horizontal: compact ? 9 : 13,
      vertical: compact ? 3 : 6,
    ),
    decoration: BoxDecoration(
      color: context.appSurface.withValues(alpha: .60),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: context.appSurface.withValues(alpha: .70)),
    ),
    child: Row(
      children: [
        Expanded(
          child: _HomeAssetMetric(
            label: '总资产',
            amount: overview.assets,
            currency: overview.currency,
            hidden: hidden,
            icon: Icons.bar_chart_rounded,
            compact: compact,
          ),
        ),
        Container(
          width: 1,
          height: compact ? 22 : 31,
          color: context.appDivider.withValues(alpha: .55),
        ),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(left: compact ? 8 : 15),
            child: _HomeAssetMetric(
              label: '总负债',
              amount: overview.liabilities,
              currency: overview.currency,
              hidden: hidden,
              icon: Icons.pie_chart_outline_rounded,
              compact: compact,
            ),
          ),
        ),
      ],
    ),
  );
}

int _assetAccountCount(AssetOverview overview) => overview.accounts
    .where((account) => account.balance >= 0 && !account.isArchived)
    .length;

enum _HomeAssetCardState { data, loading, error }

class _StateCard extends StatelessWidget {
  const _StateCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.actionLabel,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String? actionLabel;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    borderRadius: BorderRadius.circular(20),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: context.appSurface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: context.appDivider),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.appPrimarySoft,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: context.appPrimary, size: 20),
            ),
            const SizedBox(width: 11),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      color: context.appPrimaryText,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: context.appSecondaryText,
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
            if (actionLabel != null)
              Text(
                '$actionLabel ›',
                style: TextStyle(
                  color: context.appPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
          ],
        ),
      ),
    ),
  );
}

class _HomeAssetMetric extends StatelessWidget {
  const _HomeAssetMetric({
    required this.label,
    required this.amount,
    required this.currency,
    required this.hidden,
    required this.icon,
    required this.compact,
  });

  final String label;
  final double amount;
  final String currency;
  final bool hidden;
  final IconData icon;
  final bool compact;

  @override
  Widget build(BuildContext context) => Stack(
    alignment: Alignment.centerLeft,
    children: [
      SizedBox(
        width: double.infinity,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: compact ? 9 : 11,
              ),
            ),
            _HomeAssetMoney(
              amount: amount,
              currency: currency,
              hidden: hidden,
              compact: compact,
            ),
          ],
        ),
      ),
      Positioned(
        right: 0,
        child: Icon(
          icon,
          size: compact ? 18 : 24,
          color: context.appPrimary.withValues(alpha: .18),
        ),
      ),
    ],
  );
}

class _HomeAssetMoney extends StatelessWidget {
  const _HomeAssetMoney({
    required this.amount,
    required this.currency,
    required this.hidden,
    this.prominent = false,
    this.compact = false,
  });

  final double amount;
  final String currency;
  final bool hidden;
  final bool prominent;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final symbol = currency.toUpperCase() == 'CNY'
        ? '¥'
        : '${currency.toUpperCase()} ';
    final prefix = amount < 0 ? '-' : '';
    final style = TextStyle(
      color: prominent ? context.appPrimary : context.appPrimaryText,
      fontSize: prominent ? (compact ? 22 : 26) : (compact ? 13 : 16),
      fontWeight: FontWeight.w700,
      height: 1,
    );
    return PrivacyAmount(
      text: '$prefix$symbol${MoneyFormatter.decimal(amount.abs())}',
      hidden: hidden,
      fit: true,
      alignment: Alignment.centerLeft,
      style: style,
    );
  }
}
