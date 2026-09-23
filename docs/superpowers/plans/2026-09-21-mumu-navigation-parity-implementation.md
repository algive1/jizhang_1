# 木木导航栏交互对齐 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax.

**Goal:** Make the existing four-tab Flutter navigation behave like the verified 木木记账 liquid-glass navigation: consistent selected feedback, smooth fractional drag follow, nearest-slot spring snap, and an independent center FAB gap.

**Architecture:** Keep `AppBottomNavigation` and its current `LiquidGlassLens`/`LiquidGlassMotionPill` stack. Replace the direct drag-position assignment with a small bar-owned state machine: a 100 ms long press starts a fractional drag target, a shared ticker smoothly chases that target, and release retargets the same travel spring to the nearest tab. Keep routing, safe-area geometry, accessibility semantics, theme fallback, and the center FAB outside this change.

**Tech Stack:** Flutter/Dart, `liquid_glass_easy ^4.3.1`, Flutter widget tests, existing GoRouter shell.

---

### Task 1: Add a failing regression test for 木木-style drag follow and snap

**Files:**
- Modify: `E:/jizhang_1/repo/test/app_scaffold_navigation_test.dart`

- [x] **Step 1: Add a test that observes smoothed fractional movement and one route commit**

Pump a four-route `GoRouter` with the liquid-glass theme, hold on the home tab for 120 ms, move to the profile tab, assert the pill is between its original and target centers during the drag, release, and assert the router ends at `/profile` after the spring settles.

- [x] **Step 2: Run the focused test and verify it fails for the current direct-follow behavior**

Run:

```powershell
flutter test test/app_scaffold_navigation_test.dart
```

Expected: the new movement assertion fails because the current implementation renders the finger target directly and the pointer-up path can also re-run the original tap selection after the long press ends.

### Task 2: Implement the minimal bar-owned drag state machine

**Files:**
- Modify: `E:/jizhang_1/repo/lib/core/widgets/app_bottom_navigation.dart`

- [x] **Step 1: Separate finger target from rendered follow position**

Add `_dragFollow`, `_pressPosition`, `_draggedRealMove`, and `_suppressTap`. Keep `_dragPosition` as the finger target. During a drag, the ticker updates `_dragFollow` toward `_dragPosition` with the same 50 ms follow time constant used by the verified package implementation.

- [x] **Step 2: Prevent a long-press release from becoming a second tap**

Set `_suppressTap` when long press starts; clear it on pointer-up/cancel after skipping `_selectTabAtX`. Preserve normal tap behavior for pointer sequences that never enter the long-press state.

- [x] **Step 3: Snap the rendered drag position through the existing spring**

On drag release, round `_dragFollow` when the finger moved more than 0.2 slots, otherwise use the press slot. Set `_position` to the rendered follow position, retarget `_targetIndex`, keep `_lifted` through the snap, and call `onSelect` at most once when the nearest target differs from the route-selected index.

- [x] **Step 4: Match the verified 木木 visual tuning while retaining accessibility fallback**

Use the verified capsule tint/refraction and motion values for the normal liquid-glass theme (`0x16FFFFFF`, blur 2, refraction `.07/28/.002`, pill grow 9, pill refraction `.04/12`, travel spring `280/31.4`, motion `.3/.00007/.12/.18`). Keep the existing opaque high-contrast branch and `disableAnimations` direct positioning.

### Task 3: Verify navigation behavior and affected build surfaces

**Files:**
- Inspect: `E:/jizhang_1/repo/lib/core/widgets/app_scaffold.dart`
- Inspect: `E:/jizhang_1/repo/lib/app/router/app_router.dart`
- Inspect: `E:/jizhang_1/repo/test/app_scaffold_navigation_test.dart`

- [x] **Step 1: Run focused navigation tests**

```powershell
flutter test test/app_scaffold_navigation_test.dart
```

- [x] **Step 2: Run static checks for the changed Dart surface**

```powershell
flutter analyze lib/core/widgets/app_bottom_navigation.dart test/app_scaffold_navigation_test.dart
git diff --check
```

- [x] **Step 3: Build the Android release artifact**

```powershell
flutter build apk --release
```

Record any pre-existing warnings separately; do not claim visual GPU fidelity from widget tests alone.

### Task 4: Report scope and remaining visual risk

- [x] Confirm the navigation widget, navigation test, supporting parity/design notes, and this plan are the files changed for this task.
- [x] Report that database, API, Android accessibility service, notification listener, and other existing worktree changes were not modified.
- [x] Report device visual validation as remaining risk because no Impeller-capable device screenshot was available in this run.
