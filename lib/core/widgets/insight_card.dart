import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../../app/theme/app_theme_tokens.dart';
import '../models/dashboard_snapshot.dart';
import 'app_card.dart';

class InsightCard extends StatelessWidget {
  const InsightCard({required this.insight, super.key, this.onTap});

  final FinancialInsight insight;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.fromLTRB(16, 11, 10, 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.eco_outlined, color: context.appPrimary, size: 20),
                const SizedBox(width: 8),
                Text(
                  '值得关注',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: context.appPrimaryText,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: BoxDecoration(
                    color: Color.alphaBlend(
                      AppColors.warning.withValues(alpha: .14),
                      context.appSurfaceSoft,
                    ),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.nightlight_round,
                    color: AppColors.warning,
                    size: 30,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          maxLines: 1,
                          text: TextSpan(
                            style: TextStyle(
                              color: context.appPrimaryText,
                              fontSize: 15,
                              height: 1.3,
                            ),
                            children: [
                              TextSpan(
                                text:
                                    '${insight.timeLabel} ¥${insight.amount.toStringAsFixed(2)}，较上月同期 ',
                              ),
                              TextSpan(
                                text: insight.increasePercent == null
                                    ? '暂无基线'
                                    : '${insight.increasePercent! >= 0 ? '+' : ''}${insight.increasePercent!}%',
                                style: TextStyle(
                                  color: insight.increasePercent == null
                                      ? context.appSecondaryText
                                      : AppColors.warning,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        insight.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: context.appSecondaryText,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: context.appSecondaryText,
                  size: 26,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
