import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../insights/domain/insight_models.dart';
import '../../settings/data/app_settings_repository.dart';
import 'home_promotional_cards.dart';

/// The parent keys this drawer by book and local date.
class HomeInsightDrawer extends ConsumerStatefulWidget {
  const HomeInsightDrawer({
    required this.bookId,
    required this.day,
    required this.insight,
    required this.available,
    this.cooldownDays = 7,
    this.amountHidden = false,
    required this.onTap,
    super.key,
  });

  final String bookId;
  final DateTime day;
  final FinancialInsightItem? insight;
  final bool available;
  final int cooldownDays;
  final bool amountHidden;
  final VoidCallback onTap;

  @override
  ConsumerState<HomeInsightDrawer> createState() => _HomeInsightDrawerState();
}

class _HomeInsightDrawerState extends ConsumerState<HomeInsightDrawer> {
  bool _checked = false;
  bool _expanded = false;
  double _dragDistance = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOnceToday());
  }

  @override
  void didUpdateWidget(HomeInsightDrawer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.insight?.id != widget.insight?.id ||
        oldWidget.available != widget.available) {
      _checked = false;
      _expanded = false;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _showOnceToday());
  }

  Future<void> _showOnceToday() async {
    if (!mounted ||
        _checked ||
        !widget.available ||
        widget.insight == null) {
      return;
    }
    _checked = true;
    final settings = ref.read(appSettingsRepositoryProvider);
    final insight = widget.insight!;
    final dailyKey = 'home.insight.lastShown.${widget.bookId}';
    final insightKey =
        'home.insight.lastShown.${widget.bookId}.${insight.id}';
    try {
      final values = await Future.wait([
        settings.get(dailyKey),
        settings.get(insightKey),
      ]);
      final lastAny = values[0] == null
          ? null
          : DateTime.tryParse(values[0]!);
      final lastInsight = values[1] == null
          ? null
          : DateTime.tryParse(values[1]!);
      final now = widget.day;
      if (lastAny != null && DateUtils.isSameDay(lastAny, now)) {
        return;
      }
      if (lastInsight != null &&
          now.difference(DateUtils.dateOnly(lastInsight)).inDays <
              widget.cooldownDays) {
        return;
      }
      if (!mounted) return;
      if (!widget.available || widget.insight == null) {
        _checked = false;
        return;
      }
      final stamp = widget.day.toIso8601String();
      await Future.wait([
        settings.set(dailyKey, stamp),
        settings.set(insightKey, stamp),
      ]);
      if (mounted) setState(() => _expanded = true);
    } catch (error, stack) {
      debugPrint('Home insight display state failed: $error\n$stack');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('值得关注提醒状态读取或保存失败'),
          action: SnackBarAction(
            label: '重试',
            onPressed: () {
              _checked = false;
              _showOnceToday();
            },
          ),
        ),
      );
    }
  }

  void _dismiss() => setState(() => _expanded = false);

  @override
  Widget build(BuildContext context) {
    final visible =
        widget.available && widget.insight != null && _expanded;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: visible ? 1 : 0),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : const Duration(milliseconds: 320),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => ClipRect(
        child: Align(
          alignment: Alignment.topCenter,
          heightFactor: value,
          child: FractionalTranslation(
            translation: Offset(0, value - 1),
            child: child,
          ),
        ),
      ),
      child: widget.insight == null
          ? const SizedBox.shrink()
          : IgnorePointer(
              ignoring: !visible,
              child: ExcludeSemantics(
                excluding: !visible,
                child: GestureDetector(
                  onVerticalDragStart: (_) => _dragDistance = 0,
                  onVerticalDragUpdate: (details) {
                    _dragDistance += details.delta.dy;
                    if (_dragDistance < -24) _dismiss();
                  },
                  onVerticalDragEnd: (details) {
                    if ((details.primaryVelocity ?? 0) < -100) _dismiss();
                  },
                  child: Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Column(
                      children: [
                        HomeInsightCard(
                          insight: widget.insight!,
                          amountHidden: widget.amountHidden,
                          onTap: widget.onTap,
                        ),
                        TextButton.icon(
                          onPressed: _dismiss,
                          icon: const Icon(
                            Icons.keyboard_arrow_up,
                            size: 18,
                          ),
                          label: const Text('向上滑动可收起'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
