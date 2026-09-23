import 'dart:ui' show Rect;

/// Geometry shared between the bar shell, the bar lens, and the
/// moving selection pill of the liquid-glass bottom nav bar.
///
/// The animated bottom nav bar uses a dual liquid-glass pipeline: an
/// INNER view captures the wallpaper + bar capsule, and an OUTER
/// view composites the moving selection pill on top. The result is a
/// selection pill that refracts the bar capsule's own glass output
/// — the iOS-26 "morphing pill" feel.
///
/// The non-animated [LiquidGlassTabBarShell] only needs this
/// for sizing; the moving-pill fields are consumed by the
/// animated variant.
///
/// ## The centre gap (vendored addition)
///
/// Upstream splits the bar's inner width into [itemCount] equal cells.
/// A bar with a **docked centre action** — the common "four tabs and a
/// raised add button" layout — needs one cell-free span in the middle
/// instead, otherwise the action has to sit on top of a tab.
///
/// [centerGap] adds exactly that: a slot-free span of that width,
/// inserted between tab [centerGapAfter] and the tab that follows it.
/// It is expressed in **tab units** (`1` = one tab cell), so the bar
/// stays proportional at any width.
///
/// The two index spaces this creates are kept strictly apart:
///
///  * **tab space** — `0 .. itemCount - 1`, one step per real tab. This
///    is what every public callback, `selectedIndex` and the spring's
///    fractional position use. Callers never see the gap.
///  * **slot space** — tab space plus one extra step for the gap, i.e.
///    `0 .. itemCount`, used only for geometry. Tab `i` occupies slot
///    [slotOf]; slot [gapSlot] is the empty span.
///
/// Conversions between them are the helpers below ([slotOf], [tabOf],
/// [slotLeftOf], [slotCenterOf], [tabFractionToSlot]). Without a gap
/// the two spaces are identical and every helper degrades to the
/// upstream arithmetic.
class LiquidGlassTabBarLayout {
  final int itemCount;
  final double width;
  final double height;
  final double bottomMargin;
  final double padding;

  /// How much taller the moving selection pill is than the bar's
  /// inner cell height. A positive value makes the pill extend above
  /// and below the bar so it reads as a clear "raised" element.
  final double pillExtraHeight;

  /// Width of the slot-free centre gap, in **tab units** (`1` = one tab
  /// cell). `0` (the default) reproduces upstream's evenly split bar.
  final double centerGap;

  /// Tab the centre gap is inserted **after**: the gap falls between tab
  /// [centerGapAfter] and tab `centerGapAfter + 1`. Ignored when
  /// [centerGap] is `0`.
  ///
  /// On a four-tab bar the usual value is `1` — two tabs, the gap, two
  /// tabs.
  final int centerGapAfter;

  const LiquidGlassTabBarLayout({
    required this.itemCount,
    this.width = 280,
    this.height = 64,
    this.bottomMargin = 28,
    this.padding = 6,
    this.pillExtraHeight = 36,
    this.centerGap = 0,
    int? centerGapAfter,
  }) : centerGapAfter =
            centerGapAfter ?? (itemCount > 2 ? (itemCount ~/ 2) - 1 : 0);

  /// Whether a slot-free span is reserved at all.
  bool get hasCenterGap => centerGap > 0 && itemCount > 1;

  /// Steps in slot space: one per tab, plus one for the gap when present.
  int get slotCount => itemCount + (hasCenterGap ? 1 : 0);

  /// Slot index the centre gap occupies, or `-1` when there is none.
  int get gapSlot => hasCenterGap ? centerGapAfter + 1 : -1;

  double get _innerWidth => width - padding * 2;

  /// Size of one tab slot. The gap is carved out of the inner width
  /// first, so the tabs keep a sensible cell width and the bar simply
  /// grows a hole in the middle.
  double get cellWidth => _innerWidth / (itemCount + centerGap);

  double get cellHeight => height - padding * 2;

  /// Size of the reserved span itself.
  double get gapWidth => cellWidth * centerGap;

  double get pillWidth => cellWidth;
  double get pillHeight => cellHeight + pillExtraHeight;

  /// The slot a tab lives in. Identity without a gap.
  int slotOf(int tab) => hasCenterGap && tab > centerGapAfter ? tab + 1 : tab;

  /// The tab a slot holds, or `-1` for the gap slot.
  int tabOf(int slot) =>
      slot == gapSlot ? -1 : (hasCenterGap && slot > gapSlot ? slot - 1 : slot);

  /// Width of a slot in bar-local coordinates.
  double slotSpanOf(int slot) => slot == gapSlot ? gapWidth : cellWidth;

  /// Left edge of a slot, measured from the bar's left edge.
  double slotLeftOf(int slot) {
    var x = padding;
    for (var s = 0; s < slot; s++) {
      x += slotSpanOf(s);
    }
    return x;
  }

  /// Centre of a slot, measured from the bar's left edge.
  double slotCenterOf(int slot) => slotLeftOf(slot) + slotSpanOf(slot) / 2;

  /// Centre of a tab, measured from the bar's left edge.
  double tabCenterOf(int tab) => slotCenterOf(slotOf(tab));

  /// Bar-local rect of a slot — the pill's resting footprint when that
  /// slot holds a tab.
  Rect slotRect(int slot) =>
      Rect.fromLTWH(slotLeftOf(slot), 0, slotSpanOf(slot), cellHeight);

  /// Maps the spring's fractional **tab** position onto the pill
  /// expression's fractional slot index, interpolating between tab
  /// centres.
  ///
  /// The caller places the pill with the upstream expression
  /// `padding + index * cellWidth + pillWidth / 2`, and `pillWidth` is
  /// `cellWidth`, so the index that rests the pill on a tab centre is
  /// **one half less** than the tab's position in cell units. Returning
  /// the index (rather than a centre) is what lets the unchanged
  /// upstream expression keep working.
  ///
  /// This is what keeps the pill's travel honest across a gap: it moves
  /// between the two tab centres at a constant rate instead of stepping
  /// through slot space, which would make it sprint across the gap and
  /// crawl across a tab.
  double tabFractionToSlot(double fraction) {
    if (!hasCenterGap) return fraction;
    final double clamped = fraction.clamp(0.0, (itemCount - 1).toDouble());
    final int lower = clamped.floor();
    final int upper = clamped.ceil();
    final double lowerCentre = tabCenterOf(lower);
    final double upperCentre = tabCenterOf(upper);
    final double centre =
        lowerCentre + (upperCentre - lowerCentre) * (clamped - lower);
    return (centre - padding) / cellWidth - 0.5;
  }

  /// The tab whose drawn slot contains [barLocalX], or `null` when the
  /// point falls inside the reserved centre gap (or outside the inner
  /// row entirely).
  ///
  /// [slop] widens each slot on both sides, so a tap that lands in the
  /// padding beside a tab still counts as that tab.
  int? tabAtBarLocalX(double barLocalX, {double slop = 0}) {
    final double inner = barLocalX - padding;
    if (inner < -slop || inner > _innerWidth + slop) return null;
    // Nearest slot centre wins, which keeps the answer monotonic across
    // slot boundaries and lets `slop` extend the edge slots.
    var bestSlot = 0;
    var bestDistance = double.infinity;
    for (var slot = 0; slot < slotCount; slot++) {
      final double distance = (slotCenterOf(slot) - padding - inner).abs();
      if (distance < bestDistance) {
        bestDistance = distance;
        bestSlot = slot;
      }
    }
    if (bestSlot == gapSlot) return null;
    return tabOf(bestSlot);
  }

  LiquidGlassTabBarLayout copyWith({
    int? itemCount,
    double? width,
    double? height,
    double? bottomMargin,
    double? padding,
    double? pillExtraHeight,
    double? centerGap,
    int? centerGapAfter,
  }) {
    return LiquidGlassTabBarLayout(
      itemCount: itemCount ?? this.itemCount,
      width: width ?? this.width,
      height: height ?? this.height,
      bottomMargin: bottomMargin ?? this.bottomMargin,
      padding: padding ?? this.padding,
      pillExtraHeight: pillExtraHeight ?? this.pillExtraHeight,
      centerGap: centerGap ?? this.centerGap,
      centerGapAfter: centerGapAfter ?? this.centerGapAfter,
    );
  }
}
