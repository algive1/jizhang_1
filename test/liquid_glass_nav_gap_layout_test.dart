import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_easy/src/widgets/components/bottom_nav_bar/liquid_glass_nav_bar_layout.dart';

/// The vendored `centerGap` must not disturb anything about the upstream
/// evenly-split layout, and with a gap it must keep the two index spaces
/// (tab vs slot) strictly apart.
void main() {
  const even = LiquidGlassTabBarLayout(
    itemCount: 4,
    width: 361,
    height: 60,
    padding: 3,
  );

  const gapped = LiquidGlassTabBarLayout(
    itemCount: 4,
    width: 361,
    height: 60,
    padding: 3,
    centerGap: 1,
    centerGapAfter: 1,
  );

  test('without a centre gap every helper is the upstream arithmetic', () {
    expect(even.hasCenterGap, isFalse);
    expect(even.slotCount, 4);
    expect(even.gapSlot, -1);
    expect(even.cellWidth, closeTo((361 - 6) / 4, 1e-9));
    expect(even.gapWidth, 0);
    for (var i = 0; i < 4; i++) {
      expect(even.slotOf(i), i);
      expect(even.tabOf(i), i);
      expect(even.slotLeftOf(i), closeTo(3 + i * even.cellWidth, 1e-9));
      expect(even.tabFractionToSlot(i.toDouble()), closeTo(i.toDouble(), 1e-9));
    }
  });

  test('a centre gap reserves exactly one tab-width slot', () {
    expect(gapped.hasCenterGap, isTrue);
    expect(gapped.slotCount, 5);
    expect(gapped.gapSlot, 2);
    // Tabs keep their cell width; the gap is carved out of the inner row.
    expect(gapped.cellWidth, closeTo((361 - 6) / 5, 1e-9));
    expect(gapped.gapWidth, closeTo(gapped.cellWidth, 1e-9));
    expect(gapped.pillWidth, closeTo(gapped.cellWidth, 1e-9));

    expect(gapped.slotOf(0), 0);
    expect(gapped.slotOf(1), 1);
    expect(gapped.slotOf(2), 3);
    expect(gapped.slotOf(3), 4);
    expect(gapped.tabOf(0), 0);
    expect(gapped.tabOf(1), 1);
    expect(gapped.tabOf(2), -1);
    expect(gapped.tabOf(3), 2);
    expect(gapped.tabOf(4), 3);
  });

  test('the gap is centred in the bar, tab spacing either side matches', () {
    final double gapCentre = gapped.slotCenterOf(gapped.gapSlot);
    expect(gapCentre, closeTo(361 / 2, 1e-9));

    // Equal numbers of tabs on both sides means the tabs are mirrored
    // about the bar's centre.
    for (var i = 0; i < 2; i++) {
      final double left = gapped.tabCenterOf(i);
      final double right = gapped.tabCenterOf(3 - i);
      expect(left + right, closeTo(361, 1e-9));
    }
    // The two tabs flanking the gap sit one gap-width further apart than
    // the outer pairs do.
    final double innerPitch = gapped.tabCenterOf(2) - gapped.tabCenterOf(1);
    final double outerPitch = gapped.tabCenterOf(1) - gapped.tabCenterOf(0);
    expect(innerPitch, closeTo(outerPitch * 2, 1e-9));
  });

  test('pill travel maps tab fractions onto tab centres', () {
    for (var i = 0; i < 4; i++) {
      final double slot = gapped.tabFractionToSlot(i.toDouble());
      final double x = gapped.padding + slot * gapped.cellWidth;
      expect(
        x + gapped.pillWidth / 2,
        closeTo(gapped.tabCenterOf(i), 1e-9),
        reason: 'tab $i must rest centred on its own slot',
      );
    }

    // Halfway between the gap-flanking tabs is the gap's centre: the pill
    // crosses the span at a constant rate rather than sprinting.
    final double midX = gapped.padding +
        gapped.tabFractionToSlot(1.5) * gapped.cellWidth +
        gapped.pillWidth / 2;
    expect(midX, closeTo(gapped.slotCenterOf(gapped.gapSlot), 1e-9));

    // The travel is monotonic and never jumps backwards.
    var previous = -1.0;
    for (var step = 0; step <= 40; step++) {
      final double frac = step / 40 * 3;
      final double x = gapped.padding +
          gapped.tabFractionToSlot(frac) * gapped.cellWidth +
          gapped.pillWidth / 2;
      expect(x, greaterThanOrEqualTo(previous));
      previous = x;
    }
  });

  test('a tap in the reserved span belongs to no tab', () {
    // Inside a tab slot: always resolves to that tab.
    for (var i = 0; i < 4; i++) {
      expect(gapped.tabAtBarLocalX(gapped.tabCenterOf(i)), i);
    }
    // The gap's own centre, and points just inside it, resolve to nothing.
    expect(gapped.tabAtBarLocalX(gapped.slotCenterOf(gapped.gapSlot)), isNull);
    final double gapLeft = gapped.slotLeftOf(gapped.gapSlot);
    expect(gapped.tabAtBarLocalX(gapLeft + gapped.gapWidth * .25), isNull);
    expect(gapped.tabAtBarLocalX(gapLeft + gapped.gapWidth * .75), isNull);
    // Outside the inner row entirely.
    expect(gapped.tabAtBarLocalX(-20), isNull);
    expect(gapped.tabAtBarLocalX(400), isNull);
    // The padding slop reaches into the bar's own edge, not the gap.
    expect(gapped.tabAtBarLocalX(1, slop: gapped.padding), 0);
    expect(gapped.tabAtBarLocalX(360, slop: gapped.padding), 3);
  });

  test('copyWith carries the gap configuration', () {
    final copy = gapped.copyWith(bottomMargin: 12);
    expect(copy.centerGap, 1);
    expect(copy.centerGapAfter, 1);
    expect(copy.bottomMargin, 12);
    expect(copy.gapSlot, gapped.gapSlot);
  });
}
