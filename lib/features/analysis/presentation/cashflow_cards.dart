import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_colors.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/models/analysis.dart';
import '../../../core/widgets/app_card.dart';
import '../../../core/widgets/money_text.dart';

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
              if (onTap != null) const Icon(Icons.chevron_right),
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
                AppColors.textPrimary,
              ),
              _amount(
                context,
                '结余',
                snapshot.netCashflow,
                snapshot.netCashflow < 0
                    ? AppColors.warning
                    : AppColors.primaryDark,
              ),
            ],
          ),
          if (onTap == null) ...[
            const SizedBox(height: 12),
            Text(
              '收入 ${snapshot.incomeCount} 笔 · 支出 ${snapshot.expenseCount} 笔',
              style: const TextStyle(
                color: AppColors.textSecondary,
                fontSize: 12,
              ),
            ),
            const Text(
              '转账、初始余额和余额校准不计入收支。',
              style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
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
    final selected = points.isEmpty
        ? null
        : points[_selected ?? points.length - 1];
    final maximum = points.fold<double>(
      0,
      (max, p) => math.max(max, math.max(p.income, p.expense)),
    );
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('收支趋势', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: 6),
          Wrap(
            spacing: 16,
            children: [
              Text('● 收入', style: TextStyle(color: AppColors.income)),
              const Text('● 支出', style: TextStyle(color: AppColors.warning)),
              Text(
                '单位 ${widget.snapshot.currency}',
                style: const TextStyle(fontSize: 12),
              ),
            ],
          ),
          if (!hasData)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Text('这个周期还没有收支记录'),
            )
          else ...[
            const SizedBox(height: 14),
            Text(
              '最高 ${MoneyFormatter.decimal(maximum)}',
              style: const TextStyle(
                fontSize: 11,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 6),
            LayoutBuilder(
              builder: (context, constraints) => Semantics(
                label: '每日收入支出趋势，点击图表查看当天金额',
                child: GestureDetector(
                  onTapDown: (event) {
                    final index =
                        ((event.localPosition.dx / constraints.maxWidth) *
                                (points.length - 1))
                            .round()
                            .clamp(0, points.length - 1);
                    setState(() => _selected = index);
                  },
                  child: SizedBox(
                    height: 140,
                    width: double.infinity,
                    child: CustomPaint(
                      key: const ValueKey('cashflow-trend-plot'),
                      painter: _CashflowPainter(points, maximum, _selected),
                    ),
                  ),
                ),
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(_date(points.first.date)),
                Text(_date(points.last.date)),
              ],
            ),
            const SizedBox(height: 12),
            if (selected != null)
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text('${_date(selected.date)} ·'),
                  Text(
                    '收入 ${MoneyFormatter.decimal(selected.income)}',
                    style: TextStyle(color: AppColors.income),
                  ),
                  Text('支出 ${MoneyFormatter.decimal(selected.expense)}'),
                ],
              ),
          ],
        ],
      ),
    );
  }

  String _date(DateTime date) => '${date.month}月${date.day}日';
}

class _CashflowPainter extends CustomPainter {
  _CashflowPainter(this.points, this.maximum, this.selected);
  final List<CashflowPoint> points;
  final double maximum;
  final int? selected;
  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = AppColors.divider
      ..strokeWidth = 1;
    for (var row = 0; row <= 3; row++) {
      final y = 5 + (size.height - 10) * row / 3;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }
    for (var kind = 0; kind < 2; kind++) {
      final color = kind == 0 ? AppColors.income : AppColors.warning;
      final line = Paint()
        ..color = color
        ..strokeWidth = 2
        ..style = PaintingStyle.stroke;
      final path = Path();
      for (var i = 0; i < points.length; i++) {
        final value = kind == 0 ? points[i].income : points[i].expense;
        final x = points.length == 1
            ? size.width / 2
            : i / (points.length - 1) * size.width;
        final y =
            size.height - 5 - value / math.max(1, maximum) * (size.height - 10);
        if (i == 0) {
          path.moveTo(x, y);
        } else {
          path.lineTo(x, y);
        }
        if (i == selected || points.length == 1) {
          canvas.drawCircle(Offset(x, y), 4, Paint()..color = color);
        }
      }
      canvas.drawPath(path, line);
    }
  }

  @override
  bool shouldRepaint(_CashflowPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.maximum != maximum ||
      oldDelegate.selected != selected;
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
          const Text(
            '本期暂无记录',
            style: TextStyle(color: AppColors.textSecondary),
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
                      style: const TextStyle(color: AppColors.textSecondary),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                LinearProgressIndicator(
                  value: widget.total == 0
                      ? 0
                      : (item.amount / widget.total).clamp(0, 1),
                  color: AppColors.primary,
                  backgroundColor: AppColors.primarySoft,
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
