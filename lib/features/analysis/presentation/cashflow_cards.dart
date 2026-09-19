import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/cashflow_trend_chart.dart';
import '../../../core/widgets/money_text.dart';
import '../../../app/theme/app_theme_tokens.dart';

class CashflowSummaryCard extends StatelessWidget {
  const CashflowSummaryCard({required this.snapshot, this.onTap, super.key});
  final AnalysisSnapshot snapshot;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => InkWell(
    onTap: onTap,
    borderRadius: BorderRadius.circular(24),
    child: AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${snapshot.period.label}收支 · ${snapshot.currency}',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
              if (onTap != null) Icon(Icons.chevron_right),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 24,
            runSpacing: 12,
            children: [
              _amount(context, '收入', snapshot.totalIncome, AppColors.income),
              _amount(
                context,
                '支出',
                snapshot.totalExpense,
                context.appPrimaryText,
              ),
              _amount(
                context,
                '结余',
                snapshot.netCashflow,
                snapshot.netCashflow < 0
                    ? AppColors.warning
                    : context.appPrimary,
              ),
            ],
          ),
          if (onTap == null) ...[
            const SizedBox(height: 12),
            Text(
              '收入 ${snapshot.incomeCount} 笔 · 支出 ${snapshot.expenseCount} 笔',
              style: TextStyle(
                color: context.appSecondaryText,
                fontSize: 12,
              ),
            ),
            Text(
              '转账、初始余额和余额校准不计入收支。',
              style: TextStyle(color: context.appSecondaryText, fontSize: 12),
            ),
          ],
        ],
      ),
    ),
  );
  Widget _amount(
    BuildContext context,
    String title,
    double value,
    Color color,
  ) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: TextStyle(color: context.appSecondaryText, fontSize: 12),
      ),
      MoneyText(
        value,
        currency: snapshot.currency,
        style: TextStyle(
          color: color,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
    ],
  );
}

class CashflowTrendCard extends StatefulWidget {
  const CashflowTrendCard({required this.snapshot, super.key});
  final AnalysisSnapshot snapshot;
  @override
  State<CashflowTrendCard> createState() => _CashflowTrendCardState();
}

class _CashflowTrendCardState extends State<CashflowTrendCard> {
  int? _selected;
  @override
  void didUpdateWidget(CashflowTrendCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.snapshot != widget.snapshot) _selected = null;
  }

  @override
  Widget build(BuildContext context) {
    final points = widget.snapshot.cashflowTrend;
    final hasData =
        widget.snapshot.incomeCount + widget.snapshot.expenseCount > 0;
    final selectedIndex = points.isEmpty
        ? 0
        : (_selected ?? points.length - 1).clamp(0, points.length - 1).toInt();
    final selected = points.isEmpty ? null : points[selectedIndex];
    final averageExpense = widget.snapshot.range.dayCount <= 0
        ? 0.0
        : widget.snapshot.totalExpense / widget.snapshot.range.dayCount;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFFEFB),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFFF0EEE5)),
        boxShadow: const [
          BoxShadow(
            color: Color(0x07000000),
            blurRadius: 10,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '收支趋势',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: context.appPrimaryText,
                  ),
                ),
              ),
              Text(
                '单位 ${widget.snapshot.currency}',
                style: TextStyle(
                  color: context.appSecondaryText,
                  fontSize: 10,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Text(
                  '本期支出 ¥${MoneyFormatter.whole(widget.snapshot.totalExpense)}  · 日均 ¥${MoneyFormatter.whole(averageExpense)}',
                  style: TextStyle(
                    color: context.appPrimary,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Wrap(
                spacing: 8,
                children: [
                  _TrendLegend(color: AppColors.income, label: '收入'),
                  _TrendLegend(color: AppColors.warning, label: '支出'),
                ],
              ),
            ],
          ),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('这个周期还没有收支记录'),
            )
          else ...[
            const SizedBox(height: 8),
            Semantics(
              label: '每日收入支出趋势，点击图表查看当天金额',
              child: CashflowTrendChart(
                key: const ValueKey('cashflow-trend-plot'),
                points: points,
                selected: selectedIndex,
                showIncome: true,
                showExpense: true,
                onSelected: (index) => setState(() => _selected = index),
                bubbleLabel:
                    '支 ${MoneyFormatter.whole(selected?.expense ?? 0)}',
              ),
            ),
            if (selected != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text('${_date(selected.date)} ·'),
                    Text(
                      '收入 ${MoneyFormatter.decimal(selected.income)}',
                      style: const TextStyle(color: AppColors.income),
                    ),
                    Text('支出 ${MoneyFormatter.decimal(selected.expense)}'),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime date) => '${date.month}月${date.day}日';
}

class _TrendLegend extends StatelessWidget {
  const _TrendLegend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 6,
          height: 6,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(
          label,
          style: TextStyle(color: context.appSecondaryText, fontSize: 10),
        ),
      ],
    );
  }
}

class CashflowCategoriesCard extends StatefulWidget {
  const CashflowCategoriesCard({
    required this.title,
    required this.items,
    required this.total,
    required this.currency,
    super.key,
  });
  final String title;
  final List<CashflowCategory> items;
  final double total;
  final String currency;
  @override
  State<CashflowCategoriesCard> createState() => _CashflowCategoriesCardState();
}

class _CashflowCategoriesCardState extends State<CashflowCategoriesCard> {
  bool _expanded = false;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        if (widget.items.isEmpty)
          Text(
            '本期暂无记录',
            style: TextStyle(color: context.appSecondaryText),
          ),
        for (final item in widget.items.take(
          _expanded ? widget.items.length : 5,
        ))
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 12,
                  runSpacing: 4,
                  children: [
                    Text(item.name),
                    Text(
                      '${MoneyFormatter.decimal(item.amount)} ${widget.currency}',
                    ),
                    Text(
                      '${item.count} 笔 · ${(widget.total == 0 ? 0 : item.amount / widget.total * 100).toStringAsFixed(1)}%',
                      style: TextStyle(color: context.appSecondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: widget.total == 0
                      ? 0
                      : (item.amount / widget.total).clamp(0, 1),
                  color: context.appPrimary,
                  backgroundColor: context.appPrimarySoft,
                  borderRadius: BorderRadius.circular(4),
                ),
              ],
            ),
          ),
        if (widget.items.length > 5)
          TextButton(
            onPressed: () => setState(() => _expanded = !_expanded),
            child: Text(_expanded ? '收起' : '查看全部分类'),
          ),
      ],
    ),
  );
}
