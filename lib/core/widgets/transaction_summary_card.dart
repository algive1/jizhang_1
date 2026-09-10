import 'package:flutter/material.dart';

import '../../app/theme/app_colors.dart';
import '../constants/app_assets.dart';
import 'app_card.dart';
import 'money_text.dart';

class TransactionSummaryCard extends StatelessWidget {
  const TransactionSummaryCard({
    required this.spending,
    required this.income,
    this.periodLabel = '本月',
    super.key,
  });

  final String periodLabel;
  final double spending;
  final double income;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(23),
        child: SizedBox(
          height: 108,
          child: Stack(
            children: [
              const Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.surface, Color(0xFFF6F4E8)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    ),
                  ),
                ),
              ),
              Positioned(
                right: -22,
                top: -18,
                bottom: -22,
                width: 164,
                child: Image.asset(
                  AppAssets.transactionsStillLife,
                  fit: BoxFit.contain,
                  alignment: Alignment.centerRight,
                ),
              ),
              Positioned.fill(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 12, 12),
                  child: LayoutBuilder(
                    builder: (context, constraints) {
                      final imageReserve = constraints.maxWidth < 300
                          ? 54.0
                          : 78.0;
                      return Row(
                        children: [
                          Expanded(
                            child: _SummaryItem(
                              label: '$periodLabel支出',
                              amount: spending,
                              positive: false,
                            ),
                          ),
                          Container(
                            width: 1,
                            height: 64,
                            color: AppColors.divider,
                          ),
                          Expanded(
                            child: _SummaryItem(
                              label: '$periodLabel收入',
                              amount: income,
                              positive: true,
                            ),
                          ),
                          SizedBox(width: imageReserve),
                        ],
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.amount,
    required this.positive,
  });

  final String label;
  final double amount;
  final bool positive;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            maxLines: 1,
            style: const TextStyle(
              color: AppColors.textSecondary,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 6),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: MoneyText(
              amount,
              positive: positive,
              style: const TextStyle(fontSize: 27, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
