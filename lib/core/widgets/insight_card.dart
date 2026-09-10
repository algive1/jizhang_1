import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
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
            const Row(
              children: [
                Icon(Icons.eco_outlined, color: AppColors.primary, size: 20),
                SizedBox(width: 8),
                Text(
                  '值得关注',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                ),
              ],
            ),
            const SizedBox(height: 7),
            Row(
              children: [
                Container(
                  width: 54,
                  height: 54,
                  decoration: const BoxDecoration(
                    color: Color(0xFFFFEBDD),
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
                            style: const TextStyle(
                              color: AppColors.textPrimary,
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
                                      ? AppColors.textSecondary
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
                        style: const TextStyle(
                          color: AppColors.textSecondary,
                          fontSize: 12,
                          height: 1.35,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.textSecondary,
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
