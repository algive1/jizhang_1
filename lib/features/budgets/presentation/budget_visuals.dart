import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../../core/constants/app_assets.dart';
import '../../../core/formatters/money_formatter.dart';
import '../domain/budget_period.dart';

const budgetInk = Color(0xFF0D1429);
const budgetMuted = Color(0xFF657284);
const budgetGreen = Color(0xFF00CB87);
const budgetGold = Color(0xFF8A4707);
TextStyle budgetText(
  double size, {
  FontWeight weight = FontWeight.w400,
  Color color = budgetInk,
}) => TextStyle(
  fontSize: size,
  height: 1.2,
  fontWeight: weight,
  color: color,
  letterSpacing: 0,
  fontFeatures: const [ui.FontFeature.tabularFigures()],
);

class BudgetBackground extends StatelessWidget {
  const BudgetBackground({super.key});
  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Image.asset(
        AppAssets.liquidGlassProfileBackground,
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        filterQuality: FilterQuality.high,
      ),
      const DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00FFF4E6), Color(0x15FFF4E6), Color(0x65F5DABB)],
            stops: [0, .45, 1],
          ),
        ),
      ),
    ],
  );
}

class BudgetSurface extends StatelessWidget {
  const BudgetSurface({
    required this.child,
    super.key,
    this.padding = EdgeInsets.zero,
    this.radius = 16,
    this.frosted = true,
    this.opacity = .88,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final bool frosted;
  final double opacity;
  @override
  Widget build(BuildContext context) {
    final decoration = BoxDecoration(
      borderRadius: BorderRadius.circular(radius),
      border: frosted
          ? Border.all(color: Colors.white.withValues(alpha: .82), width: .8)
          : null,
      color: frosted ? null : Colors.white.withValues(alpha: opacity),
      gradient: frosted
          ? const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xDDFFFFFF), Color(0xB8FFF8F1), Color(0xC9FFF4E5)],
            )
          : null,
    );
    Widget panel = DecoratedBox(
      decoration: decoration,
      child: Padding(padding: padding, child: child),
    );
    if (frosted)
      panel = BackdropFilter.grouped(
        filter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: panel,
      );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: frosted
            ? const [
                BoxShadow(
                  color: Color(0x0A7D4A25),
                  blurRadius: 12,
                  offset: Offset(0, 3),
                ),
              ]
            : null,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: panel,
      ),
    );
  }
}

class BudgetSection extends StatelessWidget {
  const BudgetSection({
    required this.title,
    required this.child,
    required this.onMore,
    super.key,
    this.moreLabel = '查看全部',
  });
  final String title;
  final Widget child;
  final VoidCallback onMore;
  final String moreLabel;
  @override
  Widget build(BuildContext context) => BudgetSurface(
    padding: const EdgeInsets.fromLTRB(6, 0, 6, 7),
    child: Column(
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 5, right: 2),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 33),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: budgetText(16, weight: FontWeight.w800),
                  ),
                ),
                InkWell(
                  onTap: onMore,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: 8,
                      horizontal: 2,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          moreLabel,
                          style: budgetText(
                            10.5,
                            weight: FontWeight.w500,
                            color: budgetMuted,
                          ),
                        ),
                        const SizedBox(width: 4),
                        const Icon(
                          Icons.chevron_right_rounded,
                          size: 15,
                          color: budgetMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        child,
      ],
    ),
  );
}

class BudgetOverviewCard extends StatelessWidget {
  const BudgetOverviewCard({
    required this.data,
    required this.onDate,
    required this.onPeriod,
    super.key,
  });
  final BudgetPeriodOverview data;
  final VoidCallback onDate;
  final ValueChanged<BudgetPeriodKind> onPeriod;
  @override
  Widget build(BuildContext context) {
    final total = data.overview.total;
    final large = MediaQuery.textScalerOf(context).scale(12) > 16;
    final stats = _BudgetMetrics(data: data);
    final ring = BudgetProgressRing(value: total?.percentage ?? 0);
    return BudgetSurface(
      padding: const EdgeInsets.fromLTRB(12, 9, 6, 10),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: InkWell(
                  onTap: onDate,
                  borderRadius: BorderRadius.circular(8),
                  child: Padding(
                    padding: const EdgeInsets.only(left: 7, top: 4, bottom: 4),
                    child: Row(
                      children: [
                        Flexible(
                          child: Text(
                            data.period.label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: budgetText(15, weight: FontWeight.w700),
                          ),
                        ),
                        const SizedBox(width: 5),
                        const Icon(
                          Icons.keyboard_arrow_down_rounded,
                          size: 16,
                          color: budgetMuted,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              SizedBox(
                width: large ? 168 : 157,
                child: _BudgetPeriodSelector(
                  selected: data.period.kind,
                  onChanged: onPeriod,
                ),
              ),
            ],
          ),
          const SizedBox(height: 5),
          if (large) ...[
            ring,
            const SizedBox(height: 8),
            stats,
          ] else
            Row(
              children: [
                ring,
                const SizedBox(width: 7),
                Expanded(child: stats),
              ],
            ),
        ],
      ),
    );
  }
}

class _BudgetPeriodSelector extends StatelessWidget {
  const _BudgetPeriodSelector({
    required this.selected,
    required this.onChanged,
  });
  final BudgetPeriodKind selected;
  final ValueChanged<BudgetPeriodKind> onChanged;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      color: const Color(0x66FFF5DC),
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: Colors.white, width: 1),
    ),
    child: Padding(
      padding: const EdgeInsets.all(1),
      child: Row(
        children: [
          for (final kind in BudgetPeriodKind.values)
            Expanded(
              child: Semantics(
                selected: selected == kind,
                button: true,
                child: InkWell(
                  key: ValueKey('budget-period-${kind.name}'),
                  onTap: () => onChanged(kind),
                  borderRadius: BorderRadius.circular(20),
                  child: AnimatedContainer(
                    duration: MediaQuery.disableAnimationsOf(context)
                        ? Duration.zero
                        : const Duration(milliseconds: 160),
                    padding: const EdgeInsets.symmetric(vertical: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(20),
                      color: selected == kind
                          ? const Color(0xFFFFE5AF)
                          : Colors.transparent,
                    ),
                    child: Center(
                      child: Text(
                        switch (kind) {
                          BudgetPeriodKind.month => '本月',
                          BudgetPeriodKind.year => '本年',
                          BudgetPeriodKind.custom => '自定义',
                        },
                        style: budgetText(
                          10.5,
                          weight: selected == kind
                              ? FontWeight.w600
                              : FontWeight.w400,
                          color: selected == kind ? budgetGold : budgetMuted,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    ),
  );
}

class _BudgetMetrics extends StatelessWidget {
  const _BudgetMetrics({required this.data});
  final BudgetPeriodOverview data;
  @override
  Widget build(BuildContext context) {
    final total = data.overview.total;
    final change = data.changePercent;
    final remaining = total?.remaining;
    Widget stat(String label, double? amount, Widget footnote) => Expanded(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: budgetText(
                11.5,
                weight: FontWeight.w500,
                color: budgetMuted,
              ),
            ),
            const SizedBox(height: 10),
            if (amount == null)
              Text('未设置', style: budgetText(14, weight: FontWeight.w700))
            else
              _BudgetAmount(amount: amount),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: footnote,
            ),
          ],
        ),
      ),
    );
    return BudgetSurface(
      frosted: false,
      opacity: .36,
      radius: 13,
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: IntrinsicHeight(
        child: Row(
          children: [
            stat(
              '总预算',
              total?.budget.amount,
              Text(
                '日均 ¥ ${MoneyFormatter.decimal(data.dailyBudget)}',
                style: budgetText(10.5, color: budgetMuted),
              ),
            ),
            const VerticalDivider(
              width: .5,
              thickness: .5,
              color: Color(0xFFD8D1D0),
            ),
            stat(
              '已支出',
              data.spent,
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (change != null) ...[
                    Icon(
                      change >= 0
                          ? Icons.arrow_upward_rounded
                          : Icons.arrow_downward_rounded,
                      size: 12,
                      color: change >= 0 ? Colors.red : budgetGreen,
                    ),
                    Text(
                      '${change.abs().round()}%',
                      style: budgetText(
                        11.5,
                        weight: FontWeight.w700,
                        color: change >= 0 ? Colors.red : budgetGreen,
                      ),
                    ),
                    const SizedBox(width: 5),
                  ],
                  Text(
                    change == null
                        ? '暂无对比'
                        : switch (data.period.kind) {
                            BudgetPeriodKind.month => '较上月',
                            BudgetPeriodKind.year => '较上年',
                            BudgetPeriodKind.custom => '较前期',
                          },
                    style: budgetText(10, color: budgetMuted),
                  ),
                ],
              ),
            ),
            const VerticalDivider(
              width: .5,
              thickness: .5,
              color: Color(0xFFD8D1D0),
            ),
            stat(
              '预算剩余',
              remaining,
              Text(
                remaining == null
                    ? '设置预算'
                    : remaining < 0
                    ? '已超出预算'
                    : '剩余 ${(remaining / total!.budget.amount * 100).round()}%',
                style: budgetText(10.5, color: budgetMuted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BudgetAmount extends StatelessWidget {
  const _BudgetAmount({required this.amount});
  final double amount;
  @override
  Widget build(BuildContext context) {
    final parts = MoneyFormatter.decimal(amount).split('.');
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text.rich(
        maxLines: 1,
        TextSpan(
          style: budgetText(16, weight: FontWeight.w800),
          children: [
            const TextSpan(text: '¥ ', style: TextStyle(fontSize: 13)),
            TextSpan(text: parts.first),
            TextSpan(
              text: '.${parts.last}',
              style: const TextStyle(fontSize: 11),
            ),
          ],
        ),
      ),
    );
  }
}

class BudgetProgressRing extends StatelessWidget {
  const BudgetProgressRing({required this.value, super.key});
  final double value;
  @override
  Widget build(BuildContext context) => Semantics(
    label: '预算进度 ${(value * 100).round()}%',
    child: SizedBox(
      width: 94 * (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1, 2),
      height:
          94 * (MediaQuery.textScalerOf(context).scale(12) / 12).clamp(1, 2),
      child: CustomPaint(
        painter: _BudgetRingPainter(value),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  '${(value * 100).round()}%',
                  maxLines: 1,
                  style: budgetText(23, weight: FontWeight.w800),
                ),
              ),
              const SizedBox(height: 3),
              Text('预算进度', style: budgetText(10.5, color: budgetMuted)),
            ],
          ),
        ),
      ),
    ),
  );
}

class _BudgetRingPainter extends CustomPainter {
  const _BudgetRingPainter(this.value);
  final double value;
  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2 - 6);
    canvas.drawCircle(
      center,
      size.width / 2 - 12,
      Paint()..color = const Color(0x33FFFFFF),
    );
    canvas.drawOval(
      rect,
      Paint()
        ..color = const Color(0x77FFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11,
    );
    canvas.drawOval(
      Rect.fromCircle(center: center, radius: size.width / 2 - .5),
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    if (value <= 0) return;
    canvas.drawArc(
      rect,
      -math.pi / 2,
      math.pi * 2 * value.clamp(0, 1),
      false,
      Paint()
        ..shader = const SweepGradient(
          transform: GradientRotation(-math.pi / 2),
          colors: [
            Color(0xFFFFCB3E),
            Color(0xFFFF8731),
            Color(0xFFFF8731),
            Color(0xFFFFCB3E),
          ],
          stops: [0, .3, .9, 1],
        ).createShader(rect)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 11
        ..strokeCap = StrokeCap.round,
    );
  }

  @override
  bool shouldRepaint(_BudgetRingPainter old) => value != old.value;
}

class BudgetActionButton extends StatelessWidget {
  const BudgetActionButton({
    required this.label,
    required this.onTap,
    super.key,
    this.primary = false,
    this.compact = false,
  });
  final String label;
  final VoidCallback onTap;
  final bool primary;
  final bool compact;
  @override
  Widget build(BuildContext context) => DecoratedBox(
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(25),
      border: Border.all(color: Colors.white, width: 1),
      gradient: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: primary
            ? const [Color(0xFFFFDC86), Color(0xFFE29B42), Color(0xFFFFCF73)]
            : const [Color(0xFFFFF9E7), Color(0xFFFFEACA)],
      ),
    ),
    child: Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(25),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: compact ? 8 : 12,
            vertical: compact ? 8 : 10,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (!compact &&
                  MediaQuery.textScalerOf(context).scale(14) < 19 &&
                  MediaQuery.sizeOf(context).width >= 350) ...[
                if (primary)
                  const BudgetCrown(size: 23, color: Colors.white)
                else
                  Container(
                    width: 27,
                    height: 27,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Color(0xFFFFF5D4), Color(0xFFFFD98D)],
                      ),
                    ),
                    child: const Icon(
                      Icons.add_rounded,
                      size: 23,
                      color: budgetGold,
                    ),
                  ),
                const SizedBox(width: 11),
              ],
              Flexible(
                child: Text(
                  label,
                  maxLines: 1,
                  textAlign: TextAlign.center,
                  style: budgetText(
                    compact ? 10.5 : 14,
                    weight: FontWeight.w700,
                    color: primary && !compact
                        ? Colors.white
                        : compact
                        ? budgetGold
                        : budgetInk,
                  ),
                ),
              ),
              if (compact)
                const Icon(
                  Icons.chevron_right_rounded,
                  size: 14,
                  color: budgetGold,
                ),
            ],
          ),
        ),
      ),
    ),
  );
}

class BudgetCrown extends StatelessWidget {
  const BudgetCrown({super.key, this.size = 12, this.color = budgetGold});
  final double size;
  final Color color;
  @override
  Widget build(BuildContext context) => SizedBox.square(
    dimension: size,
    child: CustomPaint(painter: _CrownPainter(color)),
  );
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 24, size.height / 24);
    final paint = Paint()..color = color;
    canvas.drawPath(
      Path()
        ..moveTo(3, 9)
        ..lineTo(8, 13)
        ..lineTo(12, 5)
        ..lineTo(16, 13)
        ..lineTo(21, 9)
        ..lineTo(18.5, 20)
        ..lineTo(5.5, 20)
        ..close(),
      paint,
    );
    for (final point in const [Offset(3, 8), Offset(12, 4), Offset(21, 8)]) {
      canvas.drawCircle(point, 1.5, paint);
    }
    canvas.drawPath(
      Path()
        ..moveTo(12, 12)
        ..lineTo(14, 15)
        ..lineTo(12, 18)
        ..lineTo(10, 15)
        ..close(),
      Paint()..color = const Color(0xFFD98E26),
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_CrownPainter oldDelegate) => color != oldDelegate.color;
}
