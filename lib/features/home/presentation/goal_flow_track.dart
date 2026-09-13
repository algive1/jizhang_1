import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Paint-only animation: labels and node layout stay stationary.
class GoalFlowTrack extends StatefulWidget {
  const GoalFlowTrack({
    super.key,
    required this.count,
    required this.currentIndex,
    required this.enabled,
  });

  @visibleForTesting
  static bool animationsEnabled = true;

  final int count;
  final int currentIndex;
  final bool enabled;

  @override
  State<GoalFlowTrack> createState() => _GoalFlowTrackState();
}

class _GoalFlowTrackState extends State<GoalFlowTrack>
    with SingleTickerProviderStateMixin, WidgetsBindingObserver {
  late final AnimationController _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 3600),
  );
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(covariant GoalFlowTrack oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _sync();
  }

  void _sync() {
    final running =
        GoalFlowTrack.animationsEnabled &&
        widget.enabled &&
        _foreground &&
        TickerMode.valuesOf(context).enabled &&
        !MediaQuery.disableAnimationsOf(context);
    if (running && !_clock.isAnimating) _clock.repeat();
    if (!running) _clock.stop();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: RepaintBoundary(
      child: CustomPaint(
        painter: _FlowPainter(
          _clock,
          widget.count,
          widget.currentIndex,
          widget.enabled && !MediaQuery.disableAnimationsOf(context),
        ),
        child: const SizedBox.expand(),
      ),
    ),
  );
}

class _FlowPainter extends CustomPainter {
  _FlowPainter(this.clock, this.count, this.current, this.animated)
    : super(repaint: clock);
  final Animation<double> clock;
  final int count;
  final int current;
  final bool animated;
  static const green = Color(0xFF73963B);

  @override
  void paint(Canvas canvas, Size size) {
    if (count < 1) return;
    final inset = size.width / count / 2;
    final span = size.width - inset * 2;
    final step = count > 1 ? span / (count - 1) : 0.0;
    final end = inset + step * current.clamp(0, count - 1);
    const y = 13.0;
    final t = animated ? clock.value : 0.0;
    final line = Paint()
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawLine(
      Offset(inset, y),
      Offset(size.width - inset, y),
      line..color = const Color(0xFFDDE7C8),
    );
    if (current >= 0) {
      canvas.drawLine(Offset(inset, y), Offset(end, y), line..color = green);
    }
    if (animated && current > 0) {
      canvas.save();
      canvas.clipRect(Rect.fromLTRB(inset, 3, end, 23));
      final head = inset + (end - inset + 42) * t;
      final rect = Rect.fromLTWH(head - 42, y - 5, 42, 10);
      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(5)),
        Paint()
          ..shader = const LinearGradient(
            colors: [Color(0x007DB93C), Color(0x887DB93C), Color(0xEFFFFFF1)],
          ).createShader(rect)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2),
      );
      canvas.restore();
      for (var i = 0; i <= current; i++) {
        final x = inset + step * i;
        final strength = (1 - (head - x).abs() / 24).clamp(0.0, 1.0);
        canvas.drawCircle(
          Offset(x, y),
          i == current ? 12 : 10,
          Paint()
            ..color = const Color(0xFFB9DC70).withValues(alpha: strength * .5)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
        );
      }
    }
    if (current >= 0 && animated) {
      final pulse = (math.sin(t * math.pi * 2) + 1) / 2;
      canvas.drawCircle(
        Offset(end, y),
        11 + pulse * 2,
        Paint()
          ..color = green.withValues(alpha: .12 + pulse * .12)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1,
      );
    }
    // Tiny cream-and-gold chest at the goal; never larger than the node slot.
    final chest = Offset(size.width - inset, y);
    final body = Rect.fromCenter(
      center: chest.translate(0, 2),
      width: 15,
      height: 10,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      Paint()..color = const Color(0xFFD8DFAD),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(body, const Radius.circular(2)),
      Paint()
        ..color = green
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(
        Rect.fromCenter(center: chest.translate(0, -3), width: 15, height: 6),
        const Radius.circular(2),
      ),
      Paint()..color = const Color(0xFFEFE4B4),
    );
    canvas.drawLine(
      chest.translate(-7, 0),
      chest.translate(7, 0),
      Paint()
        ..color = green
        ..strokeWidth = 1,
    );
    canvas.drawRect(
      Rect.fromCenter(center: chest.translate(0, 1), width: 3, height: 4),
      Paint()..color = green,
    );
    if (animated) {
      for (var i = 0; i < 3; i++) {
        final pulse = math
            .pow(math.max(0, math.sin((t + i / 3) * math.pi * 2)), 5)
            .toDouble();
        final c = chest.translate(i == 1 ? -10 : 9, i == 2 ? 5 : -8);
        final radius = 2.5 * pulse;
        final star = Path()
          ..moveTo(c.dx, c.dy - radius)
          ..quadraticBezierTo(c.dx, c.dy, c.dx + radius, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy + radius)
          ..quadraticBezierTo(c.dx, c.dy, c.dx - radius, c.dy)
          ..quadraticBezierTo(c.dx, c.dy, c.dx, c.dy - radius);
        canvas.drawPath(
          star,
          Paint()
            ..color = const Color(0xFFADB55C).withValues(alpha: pulse * .8),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _FlowPainter old) =>
      old.count != count || old.current != current || old.animated != animated;
}
