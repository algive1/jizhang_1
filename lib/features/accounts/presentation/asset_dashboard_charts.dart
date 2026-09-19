import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../app/theme/app_theme_tokens.dart';
import '../../../core/formatters/money_formatter.dart';
import '../../../core/widgets/monotone_smooth_path.dart';
import '../domain/asset_overview.dart';
import '../domain/asset_history.dart';
import 'asset_dashboard_cards.dart';

const _formColors = [
  Color(0xFFFFBC69),
  Color(0xFF61BAEC),
  Color(0xFF62A491),
  Color(0xFFFFA679),
  Color(0xFFAFA7EB),
  Color(0xFFBAD7AB),
  Color(0xFFDBD4BB),
];

const _assetTrendPeriods = <(int, String)>[
  (7, '近7天'),
  (30, '近30天'),
  (365, '近1年'),
];

class AssetDistribution extends StatelessWidget {
  const AssetDistribution({required this.overview, this.onTap, super.key});
  final AssetOverview overview;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) {
    // Keep each real account visible in the distribution legend. Aggregating
    // by form hides separate bank, wallet, or investment accounts.
    final entries =
        overview.accounts
            .where((account) => account.balance > 0)
            .map((account) => MapEntry(account.displayName, account.balance))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    final panel = AssetPanel(
      key: const ValueKey('asset-distribution-card'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const AssetSectionHeading('资产分布', more: true),
          const SizedBox(height: 12),
          if (entries.isEmpty)
            SizedBox(
              height: 95,
              child: Center(
                child: Text('暂无正余额资产', style: TextStyle(color: context.appSecondaryText)),
              ),
            )
          else
            LayoutBuilder(
              builder: (context, box) => Row(
                children: [
                  SizedBox(
                    width: box.maxWidth * .48,
                    height: 95,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DonutPainter(
                              entries.map((e) => e.value).toList(),
                            ),
                          ),
                        ),
                        FractionallySizedBox(
                          widthFactor: .72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                '总资产',
                                style: TextStyle(
                                  fontSize: 9,
                                  color: context.appSecondaryText,
                                ),
                              ),
                              const SizedBox(height: 3),
                              AssetAmount(
                                overview.assets,
                                currency: overview.currency,
                                size: 12,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 7),
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          for (var i = 0; i < entries.length; i++)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Row(
                                children: [
                                  Container(
                                    width: 5,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      color:
                                          _formColors[i % _formColors.length],
                                      borderRadius: BorderRadius.circular(2),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  Expanded(
                                    child: FittedBox(
                                      alignment: Alignment.centerLeft,
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        entries[i].key,
                                        maxLines: 1,
                                        style: TextStyle(
                                          fontSize: 9,
                                          color: context.appSecondaryText,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 2),
                                  Text(
                                    '${(entries[i].value / overview.assets * 100).toStringAsFixed(1)}%',
                                    style: TextStyle(
                                      fontSize: 9,
                                      color: context.appPrimaryText,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
    if (onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(18),
        child: panel,
      ),
    );
  }
}

class AssetTrend extends StatefulWidget {
  const AssetTrend({
    required this.history,
    required this.currency,
    required this.days,
    required this.onDays,
    this.onTap,
    super.key,
  });
  final AssetHistory history;
  final String currency;
  final int days;
  final ValueChanged<int> onDays;
  final VoidCallback? onTap;

  @override
  State<AssetTrend> createState() => _AssetTrendState();
}

class _AssetTrendState extends State<AssetTrend> {
  @override
  Widget build(BuildContext context) {
    final delta = widget.history.change(widget.days);
    final percent = widget.history.percent(widget.days);
    final panel = AssetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  alignment: Alignment.centerLeft,
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '资产变化',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w800,
                      color: context.appPrimaryText,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 2),
              AssetTrendPeriodSelector(
                days: widget.days,
                onDays: widget.onDays,
              ),
            ],
          ),
          const SizedBox(height: 8),
          if (widget.history.hasFutureRecords)
            const SizedBox(
              height: 115,
              child: Center(
                child: Text(
                  '存在未来日期流水\n历史曲线暂不可用',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12, color: assetMuted),
                ),
              ),
            )
          else ...[
            AssetAmount(
              delta,
              currency: widget.currency,
              signed: true,
              size: 17,
              color: delta < 0 ? assetCoral : assetGreen,
            ),
            const SizedBox(height: 3),
            Text(
              percent == null
                  ? '暂无可比基数'
                  : '${percent >= 0 ? '↑ +' : '↓ '}${percent.toStringAsFixed(1)}%',
              style: TextStyle(
                fontSize: 10,
                color: delta < 0 ? assetCoral : assetGreen,
              ),
            ),
            const SizedBox(height: 6),
            Semantics(
              label:
                  '${widget.days} 天账面净资产趋势，变化 ${MoneyFormatter.decimal(delta)} ${widget.currency}',
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final points = widget.history.points(widget.days);
                  return AssetTrendPlot(
                    points: points,
                    height: 58,
                    fontFamily: Theme.of(context)
                        .textTheme
                        .bodySmall
                        ?.fontFamily,
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
    if (widget.onTap == null) return panel;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        onTap: widget.onTap,
        borderRadius: BorderRadius.circular(18),
        child: panel,
      ),
    );
  }
}

class AssetTrendPeriodSelector extends StatelessWidget {
  const AssetTrendPeriodSelector({
    required this.days,
    required this.onDays,
    this.detail = false,
    super.key,
  });

  final int days;
  final ValueChanged<int> onDays;
  final bool detail;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final option in _assetTrendPeriods)
        SizedBox(
          width: detail ? 58 : 32,
          child: Padding(
            padding: EdgeInsets.only(right: detail ? 4 : 2),
            child: InkWell(
              onTap: () => onDays(option.$1),
              borderRadius: BorderRadius.circular(20),
              child: Container(
                height: detail ? 36 : null,
                padding: EdgeInsets.symmetric(vertical: detail ? 8 : 3),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: days == option.$1
                      ? context.appPrimary
                      : context.appSurfaceSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    option.$2,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 8,
                      color: days == option.$1 ? Colors.white : context.appSecondaryText,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
    ],
  );
}

class AssetDistributionDetail extends StatelessWidget {
  const AssetDistributionDetail({required this.overview, super.key});
  final AssetOverview overview;

  @override
  Widget build(BuildContext context) {
    final entries =
        overview.accounts
            .where((account) => account.balance > 0)
            .map((account) => MapEntry(account.displayName, account.balance))
            .toList()
          ..sort((a, b) => b.value.compareTo(a.value));
    return AssetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (entries.isEmpty)
            const SizedBox(height: 180, child: Center(child: Text('暂无正余额资产')))
          else
            LayoutBuilder(
              builder: (context, box) => Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SizedBox(
                    width: box.maxWidth * .46,
                    height: 180,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        Positioned.fill(
                          child: CustomPaint(
                            painter: _DonutPainter(
                              entries.map((entry) => entry.value).toList(),
                            ),
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Text(
                              '总资产',
                              style: TextStyle(color: assetMuted, fontSize: 12),
                            ),
                            const SizedBox(height: 4),
                            AssetAmount(
                              overview.assets,
                              currency: overview.currency,
                              size: 18,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      children: [
                        for (var i = 0; i < entries.length; i++)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 5),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: _formColors[i % _formColors.length],
                                    borderRadius: BorderRadius.circular(3),
                                  ),
                                ),
                                const SizedBox(width: 7),
                                Expanded(
                                  child: Text(
                                    entries[i].key,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                AssetAmount(
                                  entries[i].value,
                                  currency: overview.currency,
                                  size: 12,
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 12),
          _AssetAnalysisNote(
            key: const ValueKey('asset-distribution-analysis'),
            text: _distributionSummary(entries, overview),
          ),
        ],
      ),
    );
  }
}

class AssetTrendDetail extends StatelessWidget {
  const AssetTrendDetail({
    required this.history,
    required this.currency,
    required this.days,
    this.onDays,
    super.key,
  });
  final AssetHistory history;
  final String currency;
  final int days;
  final ValueChanged<int>? onDays;

  @override
  Widget build(BuildContext context) {
    final points = history.points(days);
    final delta = history.change(days);
    return AssetPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (history.hasFutureRecords)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Expanded(
                  child: SizedBox(
                    height: 180,
                    child: Center(
                      child: Text(
                        '存在未来日期流水\n历史曲线暂不可用',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: assetMuted),
                      ),
                    ),
                  ),
                ),
                if (onDays != null) ...[
                  const SizedBox(width: 10),
                  AssetTrendPeriodSelector(
                    days: days,
                    onDays: onDays!,
                    detail: true,
                    key: const ValueKey('asset-trend-detail-periods'),
                  ),
                ],
              ],
            )
          else ...[
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Expanded(
                      child: AssetAmount(
                        delta,
                        key: const ValueKey('asset-trend-detail-amount'),
                        currency: currency,
                        signed: true,
                        size: 23,
                        color: delta < 0 ? assetCoral : assetGreen,
                      ),
                    ),
                    if (onDays != null) ...[
                      const SizedBox(width: 10),
                      AssetTrendPeriodSelector(
                        days: days,
                        onDays: onDays!,
                        detail: true,
                        key: const ValueKey('asset-trend-detail-periods'),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  history.percent(days) == null
                      ? '暂无可比基数'
                      : '${history.percent(days)! >= 0 ? '↑ +' : '↓ '}${history.percent(days)!.toStringAsFixed(1)}%',
                  style: TextStyle(
                    color: delta < 0 ? assetCoral : assetGreen,
                    fontSize: 13,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            AssetTrendPlot(
              points: points,
              height: 180,
              detail: true,
              plotKey: const ValueKey('asset-trend-detail-plot'),
              currency: currency,
              fontFamily: Theme.of(context).textTheme.bodySmall?.fontFamily,
            ),
            const SizedBox(height: 8),
            Text(
              '统计区间：近${days == 365 ? '1年' : '$days天'} · 账面净资产',
              style: const TextStyle(color: assetMuted, fontSize: 11),
            ),
          ],
          const SizedBox(height: 12),
          _AssetAnalysisNote(
            key: const ValueKey('asset-trend-analysis'),
            text: _trendSummary(history, days),
          ),
        ],
      ),
    );
  }
}

String _distributionSummary(
  List<MapEntry<String, double>> entries,
  AssetOverview overview,
) {
  if (entries.isEmpty) return '当前没有正余额资产，添加或更新账户后可以查看分布。';

  final top = entries.first;
  final share = top.value / overview.assets * 100;
  final prefix =
      '当前共有 ${entries.length} 个正余额账户，${top.key} 占总资产 ${share.toStringAsFixed(1)}%。';
  if (share >= 60) return '$prefix 资金相对集中，可留意资金分散和备用金安排。';
  if (share <= 40 && entries.length >= 3) return '$prefix 资产分布相对分散。';
  return '$prefix 可继续关注各账户的余额变化。';
}

String _trendSummary(AssetHistory history, int days) {
  final period = days == 365 ? '近1年' : '近$days天';
  if (history.hasFutureRecords) {
    return '当前存在未来日期流水，历史曲线暂不可用；修正流水日期后可继续查看。';
  }

  final delta = history.change(days);
  final percent = history.percent(days);
  final direction = delta > 0
      ? '增加'
      : delta < 0
      ? '减少'
      : '基本持平';
  if (delta == 0) return '$period账面净资产$direction。';
  final changeText = MoneyFormatter.decimal(delta.abs());
  if (percent == null) {
    return '$period账面净资产$direction ¥$changeText；起始基数不足，暂不计算百分比。';
  }
  return '$period账面净资产$direction ¥$changeText（${percent.abs().toStringAsFixed(1)}%）。该变化来自账面流水和余额校准，不代表投资收益。';
}

class _AssetAnalysisNote extends StatelessWidget {
  const _AssetAnalysisNote({required this.text, super.key});
  final String text;

  @override
  Widget build(BuildContext context) => Container(
    width: double.infinity,
    padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
    decoration: BoxDecoration(
      color: context.appPrimarySoft,
      borderRadius: BorderRadius.circular(14),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 1),
          child: Icon(Icons.insights_outlined, size: 17, color: context.appPrimary),
        ),
        const SizedBox(width: 7),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: context.appSecondaryText,
            ),
          ),
        ),
      ],
    ),
  );
}

class _DonutPainter extends CustomPainter {
  _DonutPainter(this.values);
  final List<double> values;
  @override
  void paint(Canvas canvas, Size size) {
    final radius = math.min(size.width, size.height) / 2;
    final stroke = radius * .3;
    final rect = Rect.fromCircle(
      center: size.center(Offset.zero),
      radius: radius - stroke / 2,
    );
    final total = values.fold(0.0, (a, b) => a + b);
    var start = -math.pi / 2;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * math.pi * 2;
      canvas.drawArc(
        rect,
        start,
        math.max(0, sweep - .018),
        false,
        Paint()
          ..color = _formColors[i % _formColors.length]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke,
      );
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter oldDelegate) =>
      oldDelegate.values != values;
}

class AssetTrendPlot extends StatefulWidget {
  const AssetTrendPlot({
    required this.points,
    required this.height,
    this.detail = false,
    this.currency,
    this.fontFamily,
    this.plotKey,
    super.key,
  });

  final List<AssetHistoryPoint> points;
  final double height;
  final bool detail;
  final String? currency;
  final String? fontFamily;
  final Key? plotKey;

  @override
  State<AssetTrendPlot> createState() => _AssetTrendPlotState();
}

class _AssetTrendPlotState extends State<AssetTrendPlot> {
  int? _selectedIndex;

  @override
  void didUpdateWidget(covariant AssetTrendPlot oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_sameTimeline(oldWidget.points, widget.points)) {
      _selectedIndex = null;
    } else if (_selectedIndex != null && widget.points.isNotEmpty) {
      _selectedIndex = _selectedIndex!.clamp(0, widget.points.length - 1);
    }
  }

  bool _sameTimeline(
    List<AssetHistoryPoint> oldPoints,
    List<AssetHistoryPoint> newPoints,
  ) {
    if (oldPoints.length != newPoints.length || oldPoints.isEmpty) {
      return false;
    }
    return oldPoints.first.date == newPoints.first.date &&
        oldPoints.last.date == newPoints.last.date;
  }

  int get _activeIndex {
    if (widget.points.isEmpty) return 0;
    return (_selectedIndex ?? widget.points.length - 1).clamp(
      0,
      widget.points.length - 1,
    );
  }

  void _selectAt(double dx, double width) {
    if (widget.points.length < 2) return;
    const left = 27.0;
    const right = 5.0;
    final plotWidth = math.max(1.0, width - left - right);
    final ratio = ((dx - left) / plotWidth).clamp(0.0, 1.0);
    final index = (ratio * (widget.points.length - 1)).round();
    if (index == _activeIndex) return;
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (widget.points.isEmpty) {
      return SizedBox(height: widget.height);
    }
    final labelCount = widget.detail
        ? widget.points.length <= 7
              ? widget.points.length
              : 5
        : 3;
    final selected = widget.points[_activeIndex];
    final selectedLabel = widget.currency == null
        ? '${selected.date.month}/${selected.date.day} · 账面净资产 ${MoneyFormatter.decimal(selected.balance)}'
        : '${selected.date.month}/${selected.date.day} · 账面净资产 ${MoneyFormatter.decimal(selected.balance)} ${widget.currency}';

    return SizedBox(
      height: widget.height,
      width: double.infinity,
      child: Column(
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => GestureDetector(
                key: widget.plotKey ?? const ValueKey('asset-trend-plot'),
                behavior: HitTestBehavior.opaque,
                onTapDown: (details) =>
                    _selectAt(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragStart: (details) =>
                    _selectAt(details.localPosition.dx, constraints.maxWidth),
                onHorizontalDragUpdate: (details) =>
                    _selectAt(details.localPosition.dx, constraints.maxWidth),
                child: CustomPaint(
                  painter: _AssetTrendPainter(
                    widget.points,
                    widget.fontFamily,
                    selectedIndex: _activeIndex,
                    labelCount: labelCount,
                  ),
                  child: const SizedBox.expand(),
                ),
              ),
            ),
          ),
          if (widget.detail)
            SizedBox(
              height: 20,
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  key: const ValueKey('asset-trend-selected'),
                  selectedLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 10, color: assetMuted),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Unlike a cashflow chart this scale includes negative net assets.
class _AssetTrendPainter extends CustomPainter {
  _AssetTrendPainter(
    this.points,
    this.fontFamily, {
    required this.selectedIndex,
    required this.labelCount,
  });
  final List<AssetHistoryPoint> points;
  final String? fontFamily;
  final int selectedIndex;
  final int labelCount;
  @override
  void paint(Canvas canvas, Size size) {
    final low = points.map((p) => p.balance).reduce(math.min);
    final high = points.map((p) => p.balance).reduce(math.max);
    final padding = math.max((high - low) * .2, math.max(high.abs() * .05, 1));
    final floor = low - padding, ceiling = high + padding;
    const left = 27.0, top = 8.0;
    final width = math.max(1.0, size.width - left - 5),
        bottom = size.height - 17;
    Offset position(int i) => Offset(
      left + width * (points.length == 1 ? .5 : i / (points.length - 1)),
      bottom - (points[i].balance - floor) / (ceiling - floor) * (bottom - top),
    );
    for (var row = 0; row < 4; row++) {
      final y = top + (bottom - top) * row / 3;
      for (var x = left; x < size.width; x += 5) {
        canvas.drawLine(
          Offset(x, y),
          Offset(math.min(x + 2.5, size.width), y),
          Paint()
            ..color = const Color(0xFFDDDFD5)
            ..strokeWidth = .5,
        );
      }
      final value = ceiling - (ceiling - floor) * row / 3;
      label(
        canvas,
        value.abs() >= 10000
            ? '${(value / 10000).toStringAsFixed(1)}万'
            : MoneyFormatter.whole(value),
        Offset(0, y - 4),
        26,
      );
    }
    final line = buildMonotoneSmoothLinePath(
      values: [for (final point in points) point.balance],
      position: (value, index) => position(index),
    );
    final coordinates = line.coordinates;
    final path = line.path;
    final area = Path.from(path)
      ..lineTo(coordinates.last.dx, bottom)
      ..lineTo(left, bottom)
      ..close();
    canvas.drawPath(
      area,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x508AA950), Color(0x068AA950)],
        ).createShader(Rect.fromLTWH(left, top, width, bottom - top)),
    );
    final activeIndex = selectedIndex.clamp(0, points.length - 1);
    final active = coordinates[activeIndex];
    canvas.drawLine(
      Offset(active.dx, top),
      Offset(active.dx, bottom),
      Paint()
        ..color = const Color(0x5583A25D)
        ..strokeWidth = .7,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF73963B)
        ..strokeWidth = 1.6
        ..style = PaintingStyle.stroke,
    );
    for (var i = 0; i < points.length; i++) {
      if (i % math.max(1, points.length ~/ 8) != 0 && i != points.length - 1)
        continue;
      canvas.drawCircle(coordinates[i], 2.5, Paint()..color = Colors.white);
      canvas.drawCircle(coordinates[i], 1.8, Paint()..color = assetGreen);
    }
    canvas.drawCircle(active, 4.2, Paint()..color = Colors.white);
    canvas.drawCircle(active, 2.8, Paint()..color = assetGreen);
    final activeText = MoneyFormatter.whole(points[activeIndex].balance);
    final activePainter = TextPainter(
      text: TextSpan(
        text: activeText,
        style: TextStyle(
          color: Colors.white,
          fontSize: 7,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: 44);
    final bubbleWidth = activePainter.width + 10;
    final bubbleRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(
        (active.dx - bubbleWidth + 4).clamp(left, size.width - bubbleWidth),
        (active.dy - 22).clamp(top, bottom - 18),
        bubbleWidth,
        16,
      ),
      const Radius.circular(6),
    );
    canvas.drawRRect(bubbleRect, Paint()..color = assetGreen);
    activePainter.paint(
      canvas,
      Offset(bubbleRect.left + 5, bubbleRect.top + 4),
    );
    final safeLabelCount = math.max(1, math.min(labelCount, points.length));
    final labelIndices = <int>{
      for (var index = 0; index < safeLabelCount; index++)
        safeLabelCount == 1
            ? 0
            : ((points.length - 1) * index / (safeLabelCount - 1)).round(),
    };
    for (final i in labelIndices) {
      final date = points[i].date;
      label(
        canvas,
        '${date.month}/${date.day}',
        Offset((coordinates[i].dx - 11).clamp(0, size.width - 26), bottom + 7),
        26,
      );
    }
  }

  void label(Canvas canvas, String value, Offset at, double width) {
    final text = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          fontSize: 7,
          color: assetMuted,
          fontFamily: fontFamily,
        ),
      ),
      maxLines: 1,
      ellipsis: '…',
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: width);
    text.paint(canvas, at);
  }

  @override
  bool shouldRepaint(covariant _AssetTrendPainter old) =>
      old.points != points ||
      old.fontFamily != fontFamily ||
      old.selectedIndex != selectedIndex ||
      old.labelCount != labelCount;
}
