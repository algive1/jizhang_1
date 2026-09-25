import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/widgets/privacy_amount.dart';
import '../domain/investment_asset.dart';
import '../../../app/theme/app_theme_tokens.dart';

/// Formats a return rate, or renders “暂无可比基数” when the cost basis is
/// zero. A missing rate is never shown as 0%.
///
/// The text is wrapped in a `scaleDown` FittedBox, mirroring
/// [InvestmentAmountText]: inside a bounded width (a `Flexible` or a
/// `ConstrainedBox`) a long rate at a large text scale shrinks instead of
/// breaking the card. With no bound the box is a passthrough, so it is safe to
/// use anywhere. Pass [alignment] to match the surrounding row's alignment.
class ProfitText extends StatelessWidget {
  const ProfitText({
    required this.percent,
    this.showArrow = true,
    this.fontSize = 11,
    this.weight = FontWeight.w600,
    this.alignment = Alignment.centerLeft,
    super.key,
  });

  final double? percent;
  final bool showArrow;
  final double fontSize;
  final FontWeight weight;
  final Alignment alignment;

  @override
  Widget build(BuildContext context) {
    final value = percent;
    final text = value == null
        ? Text(
            '暂无可比基数',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              color: context.appSecondaryText,
            ),
          )
        : Text(
            '${_arrow(value)}${value >= 0 ? '+' : ''}'
            '${value.toStringAsFixed(2)}%',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: weight,
              color: value == 0
                  ? context.appSecondaryText
                  : profitColor(value, context: context),
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          );
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: alignment,
      child: text,
    );
  }

  String _arrow(double value) {
    if (!showArrow) return '';
    return value > 0
        ? '↑ '
        : value < 0
        ? '↓ '
        : '';
  }
}

/// Southern-market convention, matching the existing 资产总览 page: a gain is
/// warm red, a loss is soft green.
Color profitColor(double value, {BuildContext? context}) {
  if (value > 0) return AppColors.expense;
  if (value < 0) return AppColors.success;
  return context?.appSecondaryText ?? AppColors.textSecondary;
}

/// Money amount with an explicit sign, reusing the app-wide privacy mask so a
/// hidden amount renders as the same small dot row as the asset page.
class InvestmentAmountText extends StatelessWidget {
  const InvestmentAmountText(
    this.amount, {
    this.hidden = false,
    this.signed = false,
    this.size = 16,
    this.color,
    this.currency = 'CNY',
    this.weight = FontWeight.w800,
    super.key,
  });

  final double amount;
  final bool hidden;
  final bool signed;
  final double size;
  final Color? color;
  final String currency;
  final FontWeight weight;

  @override
  Widget build(BuildContext context) {
    final symbol = currency == 'CNY' ? '¥' : '$currency ';
    final sign = amount < 0
        ? '-'
        : signed && amount > 0
        ? '+'
        : '';
    return PrivacyAmount(
      text: '$sign$symbol${_decimal(amount.abs())}',
      hidden: hidden,
      fit: true,
      style: TextStyle(
        fontSize: size,
        fontWeight: weight,
        height: 1.15,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: color ?? context.appPrimaryText,
      ),
    );
  }

  static String _decimal(double value) => value.toStringAsFixed(2).replaceAllMapped(
    RegExp(r'\B(?=(\d{3})+(?!\d))'),
    (_) => ',',
  );
}

/// Small “行情更新失败 / 行情更新于 x 分钟前” label required by the
/// stale-while-revalidate contract.
class QuoteStatus extends StatelessWidget {
  const QuoteStatus({
    required this.timestamp,
    this.isStale = false,
    this.now,
    super.key,
  });

  final DateTime? timestamp;
  final bool isStale;
  final DateTime? now;

  @override
  Widget build(BuildContext context) {
    if (timestamp == null && !isStale) return const SizedBox.shrink();
    final at = now ?? DateTime.now();
    final text = isStale
        ? '行情更新失败'
        : '行情更新于 ${_ago(timestamp!, at)}';
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          isStale ? Icons.cloud_off_outlined : Icons.cloud_done_outlined,
          size: 12,
          color: isStale ? AppColors.warning : context.appSecondaryText,
        ),
        const SizedBox(width: 3),
        Flexible(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 10,
              color: isStale ? AppColors.warning : context.appSecondaryText,
            ),
          ),
        ),
      ],
    );
  }

  static String _ago(DateTime value, DateTime now) {
    final delta = now.difference(value);
    if (delta.inSeconds < 60) return '刚刚';
    if (delta.inMinutes < 60) return '${delta.inMinutes} 分钟前';
    if (delta.inHours < 24) return '${delta.inHours} 小时前';
    return '${delta.inDays} 天前';
  }
}

/// Rounded pill used for the 类型 / 行情标签 rows.
class InvestmentChip extends StatelessWidget {
  const InvestmentChip({
    required this.label,
    this.color,
    this.background,
    this.icon,
    super.key,
  });

  final String label;
  final Color? color;
  final Color? background;
  final IconData? icon;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: background ?? context.appSurfaceSoft,
      borderRadius: BorderRadius.circular(20),
    ),
    child: Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (icon != null) ...[
          Icon(icon, size: 12, color: color ?? context.appSecondaryText),
          const SizedBox(width: 3),
        ],
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: color ?? context.appSecondaryText,
          ),
        ),
      ],
    ),
  );
}

/// Circular asset-class icon used by the category cards and list rows.
class InvestmentTypeAvatar extends StatelessWidget {
  const InvestmentTypeAvatar({
    required this.type,
    this.size = 40,
    super.key,
  });

  final InvestmentAssetType type;
  final double size;

  @override
  Widget build(BuildContext context) => Container(
    width: size,
    height: size,
    decoration: BoxDecoration(
      color: Color.alphaBlend(
        type.accent.withValues(alpha: .14),
        context.appSurfaceSoft,
      ),
      borderRadius: BorderRadius.circular(size * .3),
    ),
    child: Icon(type.icon, size: size * .52, color: type.accent),
  );
}
