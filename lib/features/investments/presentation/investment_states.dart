import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';

import '../../../app/theme/app_colors.dart';
import '../domain/investment_asset.dart';
import 'investment_widgets.dart';

/// Friendly empty state. A user with no investments sees one invitation to add
/// the first one instead of a wall of ¥0.00 cards.
class InvestmentEmptyState extends StatelessWidget {
  const InvestmentEmptyState({
    required this.onAdd,
    this.type,
    this.title,
    this.actionLabel = '添加第一笔投资',
    super.key,
  });

  /// Null renders the whole-portfolio wording; a type renders “暂无股票持仓”.
  final InvestmentAssetType? type;
  final VoidCallback onAdd;
  final String? title;
  final String actionLabel;

  @override
  Widget build(BuildContext context) {
    final resolvedTitle = title ?? type?.emptyLabel ?? '还没有投资资产';
    final subtitle = type == null
        ? '添加股票、基金、债券或虚拟币，\n随时看到投了多少、现在值多少。'
        : '记录一笔${type!.label}，即可看到市值与收益。';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      decoration: BoxDecoration(
        color: context.appSurface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: context.appDivider.withValues(alpha: .7)),
      ),
      child: Column(
        children: [
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              color: Color.alphaBlend(
                (type?.accent ?? context.appPrimary).withValues(alpha: .14),
                context.appSurfaceSoft,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              type?.icon ?? Icons.trending_up,
              size: 28,
              color: type?.accent ?? context.appPrimary,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            resolvedTitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w700,
              color: context.appPrimaryText,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: context.appSecondaryText,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            key: const ValueKey('investment-empty-add'),
            onPressed: onAdd,
            style: FilledButton.styleFrom(
              backgroundColor: context.appPrimary,
              foregroundColor: Theme.of(context).colorScheme.onPrimary,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(22),
              ),
            ),
            child: Text(
              actionLabel,
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}

/// Skeleton shown while the first quote round-trip is in flight.
///
/// Mirrors the real layout's block sizes so the page does not jump when data
/// arrives.
class InvestmentSkeleton extends StatelessWidget {
  const InvestmentSkeleton({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const _SkeletonBlock(height: 132, radius: 20),
      const SizedBox(height: 10),
      Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            const Expanded(child: _SkeletonBlock(height: 92, radius: 18)),
            if (i == 0) const SizedBox(width: 8),
          ],
        ],
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          for (var i = 0; i < 2; i++) ...[
            const Expanded(child: _SkeletonBlock(height: 92, radius: 18)),
            if (i == 0) const SizedBox(width: 8),
          ],
        ],
      ),
      const SizedBox(height: 12),
      const _SkeletonBlock(height: 168, radius: 20),
      const SizedBox(height: 12),
      const _SkeletonBlock(height: 120, radius: 20),
    ],
  );
}

class _SkeletonBlock extends StatelessWidget {
  const _SkeletonBlock({required this.height, required this.radius});

  final double height;
  final double radius;

  @override
  Widget build(BuildContext context) => Container(
    height: height,
    decoration: BoxDecoration(
      color: context.appSurfaceSoft,
      borderRadius: BorderRadius.circular(radius),
    ),
  );
}

/// Failure card used when the local store cannot be read at all. A failed
/// *quote* refresh is never fatal: cached values stay on screen with a
/// [QuoteStatus] label instead.
class InvestmentErrorState extends StatelessWidget {
  const InvestmentErrorState({
    required this.message,
    required this.onRetry,
    super.key,
  });

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.appSurface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.appDivider),
    ),
    child: Column(
      children: [
        const Icon(
          Icons.error_outline,
          size: 28,
          color: AppColors.warning,
        ),
        const SizedBox(height: 8),
        Text(
          message,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 13,
            color: context.appSecondaryText,
          ),
        ),
        const SizedBox(height: 12),
        OutlinedButton(
          key: const ValueKey('investment-error-retry'),
          onPressed: onRetry,
          child: const Text('重新加载'),
        ),
      ],
    ),
  );
}

/// Section heading with an optional trailing widget, matching 资产总览.
class InvestmentSectionHeader extends StatelessWidget {
  const InvestmentSectionHeader({
    required this.title,
    this.trailing,
    this.action,
    this.onAction,
    super.key,
  });

  final String title;
  final Widget? trailing;
  final String? action;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 6),
    child: Row(
      children: [
        Expanded(
          child: Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: context.appPrimaryText,
            ),
          ),
        ),
        ?trailing,
        if (action != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: context.appSecondaryText,
              padding: EdgeInsets.zero,
              minimumSize: const Size(0, 24),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(
              '$action ›',
              style: const TextStyle(fontSize: 12),
            ),
          ),
      ],
    ),
  );
}
