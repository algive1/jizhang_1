import 'package:flutter/material.dart';

import '../../app/theme/finance_ui.dart';

/// One continuous selection capsule, shared by trend periods and entry types.
class SlidingSegmentedControl<T> extends StatelessWidget {
  const SlidingSegmentedControl({
    super.key,
    required this.items,
    required this.selected,
    required this.onChanged,
    this.colors = const [FinanceUi.teal, Color(0xFF3DCDBB)],
    this.backgroundColor = const Color(0xFFEEF3F7),
    this.inactiveTextColor = FinanceUi.muted,
    this.keyPrefix = 'segment',
    this.compact = false,
  });
  final List<(T, String)> items;
  final T selected;
  final ValueChanged<T> onChanged;
  final List<Color> colors;
  final Color backgroundColor;
  final Color inactiveTextColor;
  final String keyPrefix;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final index = items.indexWhere((item) => item.$1 == selected);
    final duration = MediaQuery.disableAnimationsOf(context)
        ? Duration.zero
        : FinanceUi.motion;
    final height =
        (compact ? 32.0 : 46.0) +
        (MediaQuery.textScalerOf(context).scale(14) - 14).clamp(0, 30);
    return LayoutBuilder(
      builder: (context, constraints) {
        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            final next =
                (details.localPosition.dx /
                        (constraints.maxWidth / items.length))
                    .floor()
                    .clamp(0, items.length - 1);
            if (items[next].$1 != selected) onChanged(items[next].$1);
          },
          child: Container(
            height: height,
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              color: backgroundColor,
              borderRadius: BorderRadius.circular(30),
            ),
            child: Stack(
              children: [
                if (index >= 0)
                  AnimatedAlign(
                    duration: duration,
                    curve: Curves.easeOutCubic,
                    alignment: Alignment(
                      items.length == 1
                          ? 0
                          : -1 + 2 * index / (items.length - 1),
                      0,
                    ),
                    child: FractionallySizedBox(
                      widthFactor: 1 / items.length,
                      heightFactor: 1,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(colors: colors),
                          borderRadius: BorderRadius.circular(28),
                          border: Border.all(
                            color: Colors.white.withValues(alpha: .6),
                          ),
                        ),
                      ),
                    ),
                  ),
                Row(
                  children: items
                      .map(
                        (item) => Expanded(
                          child: Semantics(
                            selected: selected == item.$1,
                            button: true,
                            child: InkWell(
                              key: ValueKey(
                                '$keyPrefix-${item.$1 is Enum ? (item.$1 as Enum).name : item.$1}',
                              ),
                              borderRadius: BorderRadius.circular(28),
                              onTap: () => onChanged(item.$1),
                              child: Center(
                                child: AnimatedDefaultTextStyle(
                                  duration: duration,
                                  style: TextStyle(
                                    fontFamily: 'PingFang SC',
                                    fontSize: compact ? 12 : 15,
                                    color: selected == item.$1
                                        ? Colors.white
                                        : inactiveTextColor,
                                    fontWeight: selected == item.$1
                                        ? FontWeight.w600
                                        : FontWeight.w400,
                                  ),
                                  child: Text(item.$2, maxLines: 1),
                                ),
                              ),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
