# Liquid Glass Card and Navigation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Introduce explicit content/frosted card materials and make the liquid navigation pill follow a held horizontal finger drag before snapping to a tab.

**Architecture:** Keep the existing `AppGlassSurface` and `liquid_glass_easy` dependency. Add a small `AppCardMaterial` switch at the `AppCard` boundary; keep ordinary cards opaque and opt feature cards into the existing frosted surface. Keep `AppBottomNavigation` routing and the center FAB unchanged, but move navigation input to one parent gesture layer that drives the existing pill position and spring ticker.

**Tech Stack:** Flutter/Dart, `liquid_glass_easy ^4.3.1`, Flutter widget tests, existing Android emulator/release APK workflow.

---

### Task 1: Add failing coverage for card materials and nav dragging

**Files:**
- Modify: `E:/jizhang_1/repo/test/app_scaffold_navigation_test.dart`
- Create: `E:/jizhang_1/repo/test/app_card_material_test.dart`

- [x] **Step 1: Add the navigation drag test before implementation**

Append a widget test to `app_scaffold_navigation_test.dart` that pumps the liquid-glass theme, finds `ValueKey('app-nav-gesture-overlay')`, holds for 120 ms, moves 24 logical pixels to the right, and asserts the `LiquidGlassMotionPill.center.dx` is greater than its resting position. The move must remain inside the first tab so the test does not require a GoRouter ancestor:

```dart
testWidgets('liquid nav pill follows a held horizontal drag', (tester) async {
  await tester.binding.setSurfaceSize(const Size(393, 844));
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(BuiltInThemes.liquidGlass),
      home: const Scaffold(
        bottomNavigationBar: AppBottomNavigation(location: '/'),
      ),
    ),
  );
  await tester.pump();

  final overlay = find.byKey(const ValueKey('app-nav-gesture-overlay'));
  expect(overlay, findsOneWidget);
  double pillX() => tester
      .widget<LiquidGlassMotionPill>(find.byType(LiquidGlassMotionPill))
      .center
      .dx;

  final start = pillX();
  final gesture = await tester.startGesture(tester.getCenter(overlay));
  await tester.pump(const Duration(milliseconds: 120));
  await gesture.moveBy(const Offset(24, 0));
  await tester.pump();

  expect(pillX(), greaterThan(start));
  await gesture.up();
  await tester.pump(const Duration(milliseconds: 420));
});
```

- [x] **Step 2: Add the card material tests before implementation**

Create `test/app_card_material_test.dart` with two tests. The first verifies the default content card adds no `BackdropFilter`; the second verifies an explicit frosted card keeps one backdrop filter:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jizhang_app/app/theme/app_theme.dart';
import 'package:jizhang_app/app/theme/app_theme_definition.dart';
import 'package:jizhang_app/core/widgets/app_card.dart';

void main() {
  testWidgets('content AppCard is opaque and does not blur its backdrop', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: const Scaffold(body: AppCard(child: Text('content'))),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('frosted AppCard keeps the shared glass surface', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(BuiltInThemes.liquidGlass),
        home: const Scaffold(
          body: AppCard(
            material: AppCardMaterial.frosted,
            child: Text('frosted'),
          ),
        ),
      ),
    );
    await tester.pump();

    expect(find.byType(BackdropFilter), findsOneWidget);
  });
}
```

- [x] **Step 3: Run the new tests and confirm they fail for the intended reason**

Run from `E:/jizhang_1/repo`:

```powershell
flutter test test/app_card_material_test.dart test/app_scaffold_navigation_test.dart
```

Expected: compilation fails because `AppCardMaterial` and the navigation gesture overlay do not exist yet. Do not change production code until this failure is observed.

### Task 2: Implement the explicit AppCard material boundary

**Files:**
- Modify: `E:/jizhang_1/repo/lib/core/widgets/app_card.dart`

- [x] **Step 1: Add the two-value material enum and optional constructor parameter**

Add `enum AppCardMaterial { content, frosted }` above `AppCard`. Add `this.material = AppCardMaterial.content` to the constructor and a `final AppCardMaterial material` field. Keep all existing constructor parameters and defaults unchanged.

- [x] **Step 2: Keep the existing glass path behind the frosted branch**

When `material == AppCardMaterial.frosted`, return the current `AppGlassSurface` configuration unchanged: `padding`, `borderRadius`, `tint`, `border`, `blurSigma: 12`, and `chromaticEdge: false`.

- [x] **Step 3: Add an opaque content branch with the same geometry contract**

For `content`, return a `Container` using the existing padding, `color ?? context.appSurface` with alpha `.96` only for the liquid-glass theme, `borderRadius`, the caller border or `context.appDivider`, and the existing small shadow. Do not use `BackdropFilter`, animation, or a new theme/provider. Preserve the `child` tree and hit testing.

- [x] **Step 4: Run the material tests**

```powershell
flutter test test/app_card_material_test.dart
```

Expected: 2 tests pass.

### Task 3: Migrate the first visible card surfaces

**Files:**
- Modify: `E:/jizhang_1/repo/lib/features/home/presentation/home_cards.dart`
- Modify: `E:/jizhang_1/repo/lib/features/home/presentation/home_promotional_cards.dart`
- Modify: `E:/jizhang_1/repo/lib/core/widgets/transaction_summary_card.dart`
- Modify: `E:/jizhang_1/repo/lib/features/accounts/presentation/asset_overview_page.dart`
- Modify: `E:/jizhang_1/repo/lib/features/analysis/presentation/cashflow_cards.dart`
- Modify: `E:/jizhang_1/repo/lib/core/widgets/transaction_date_group.dart`

- [x] **Step 1: Mark image/summary cards as frosted**

Replace direct `AppGlassSurface` wrappers for `HomeSurface` and promotional cards with `AppCard(material: AppCardMaterial.frosted, ...)`. Add `material: AppCardMaterial.frosted` to `TransactionSummaryCard` and only the asset/cashflow summary cards that contain an illustration, chart, or summary background.

- [x] **Step 2: Leave transaction groups and ordinary detail cards on the content material**

Do not add a frosted material to `TransactionDateGroup`. Its `AppCard` call should use the new default content material. Keep all row separators, transaction tap handlers, amounts, and account labels unchanged.

- [x] **Step 3: Run focused UI tests**

```powershell
flutter test test/home_redesign_visual_test.dart test/home_header_cards_test.dart test/home_spending_goal_card_preview_test.dart test/quick_add_redesign_test.dart
```

Expected: all existing focused tests pass; failures must be investigated as visual/layout regressions, not hidden by changing test expectations.

### Task 4: Make the liquid navigation pill follow a held drag

**Files:**
- Modify: `E:/jizhang_1/repo/lib/core/widgets/app_bottom_navigation.dart`
- Modify: `E:/jizhang_1/repo/test/app_scaffold_navigation_test.dart`

- [x] **Step 1: Move tab press semantics to the parent gesture layer**

Import `package:flutter/gestures.dart`. Keep `_NavItem` as a visual/semantic child with `Semantics(button: true, onTap: onTap)`, but remove its competing `GestureDetector`. Pass a `pressed` boolean from `_LiquidGlassNavBar` so the existing `.97` scale feedback remains available.

- [x] **Step 2: Add gesture state and fractional geometry conversion**

Add `_targetIndex`, `_dragging`, `_dragPosition`, `_pressSlot`, and `_draggedRealMove` to `_LiquidGlassNavBarState`. Add helpers that use `_NavMetrics.slotCenterX` to convert a local x coordinate to a clamped fractional slot and reject taps in the central FAB gap. The fractional conversion must interpolate between adjacent slot centers, including the center gap, so the pill moves continuously across the gap during a drag.

- [x] **Step 3: Add a unified `RawGestureDetector` overlay**

Place a `RawGestureDetector` with `ValueKey('app-nav-gesture-overlay')` above the visual row and below no hit-tested FAB. Configure a `TapGestureRecognizer` for press scale and selection, and a `LongPressGestureRecognizer(duration: Duration(milliseconds: 100))` for grab/move/end/cancel. During move, update `_dragPosition`, set `_lifted = true`, and start the existing ticker. On release, round `_dragPosition` to the nearest valid slot, set `_targetIndex`, turn off `_dragging`, and call `widget.onSelect` only when the target differs from `widget.selectedIndex`.

- [x] **Step 4: Retarget the existing spring to `_targetIndex`**

Use `_targetIndex.toDouble()` instead of `widget.selectedIndex.toDouble()` in the spring step. In `didUpdateWidget`, synchronize `_targetIndex` when routing changes outside the gesture. While dragging, build the pill center from `_dragPosition`; otherwise build it from `_position`. Keep `LiquidGlassMotionPill` active during the drag so its internal motion sampler receives the continuous center updates.

- [x] **Step 5: Make the resting selection appearance consistent**

Replace the page-dependent translucent rest cover with an opaque, theme-derived tint such as `Color.alphaBlend(context.appPrimary.withValues(alpha: .12), context.appSurface)`. Keep the active motion pill refractive; only the settled fallback becomes stable and equally visible on all four routes.

- [x] **Step 6: Run navigation tests**

```powershell
flutter test test/app_scaffold_navigation_test.dart
```

Expected: all navigation tests pass, including the new continuous-drag assertion and the existing press-scale, route-index, single-glass-layer, and FAB geometry tests.

### Task 5: Update documentation and verify the release build

**Files:**
- Modify: `E:/jizhang_1/repo/docs/development/2026-09-21-liquid-glass-design-directives.md`
- Modify: `E:/jizhang_1/repo/docs/superpowers/specs/2026-09-21-liquid-glass-card-and-nav-design.md`

- [x] **Step 1: Record the implemented material and gesture contract**

Update the design directives to state that ordinary content cards do not use backdrop blur, feature cards opt into `AppCardMaterial.frosted`, and navigation dragging is a 100 ms hold followed by fractional position tracking and nearest-slot spring snap. Record that the settled selection uses a stable theme-derived fill.

- [ ] **Step 2: Run repository verification**

```powershell
flutter test test/app_card_material_test.dart test/app_scaffold_navigation_test.dart test/home_redesign_visual_test.dart test/home_header_cards_test.dart test/home_spending_goal_card_preview_test.dart test/quick_add_redesign_test.dart
flutter analyze
git diff --check
```

Expected: targeted tests pass; `flutter analyze` may retain the pre-existing temporary-test import warning and the existing `alipay_kit` iOS plugin warning, but no new diagnostics may be introduced by this work.

- [ ] **Step 3: Build and inspect the Android release APK**

```powershell
flutter build apk --release
```

Install the generated `build/app/outputs/flutter-apk/app-release.apk` on the already configured emulator. Capture home, transactions, assets, analysis, and profile screens; perform a held drag across the navigation tabs; verify the center FAB remains clickable and the selected pill is consistently visible on every route.

- [ ] **Step 4: Record remaining risks**

If the software-rendered emulator cannot show obvious live refraction, record that limitation separately from the verified gesture/layout behavior. Do not claim GPU optical fidelity without an Impeller-capable device check.
