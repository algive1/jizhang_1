# Responsive Overflow Hardening Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the confirmed account-summary horizontal overflow and profile-settings bottom-sheet vertical overflow, then check comparable pages and sheets for reproducible overflow.

**Architecture:** Add focused widget regressions using the existing in-memory database and app router. Keep the account summary unchanged at ordinary sizes, but let the decorative slogan move out of the constrained row for compact or scaled text. Reuse the existing `AppBottomSheet` viewport constraint and scrolling behavior for the profile settings menu.

**Tech Stack:** Flutter/Dart, flutter_test, Riverpod, GoRouter, Drift in-memory database.

---

## Files and responsibilities

- `test/responsive_overflow_regression_test.dart` — tests the account route and profile settings sheet at compact dimensions and enlarged text; must not capture or write screenshot files.
- `lib/features/accounts/presentation/account_management_page.dart` — adaptive layout for `_SummaryCard`; preserve the existing payment-brand icon edit in this file.
- `lib/features/profile/presentation/profile_page.dart` — route the settings menu through the existing bounded, scrollable `AppBottomSheet` helper.
- `lib/features/accounts/presentation/receivable_detail_page.dart` and `lib/features/settings/presentation/theme_settings_page.dart` — reuse that helper for the confirmed short-screen reminder and membership prompts.
- `lib/core/widgets/app_bottom_sheet.dart` — inspect as the established pattern; change only if the regression test proves the helper itself overflows.

## Task 1: Add regressions for the two confirmed screens

- [x] Add a test harness that creates `createMemoryDatabase()`, seeds it with `DatabaseSeeder`, overrides `databaseProvider` (and `sessionProvider` for the profile route), builds `MaterialApp.router` with `appRouterProvider`, and disposes the container/database after unmounting the app.
- [x] Add tests for `/profile/accounts` at 320×874 dp with `TextScaler.linear(1.6)` and 393×874 dp at 1.0x; assert the summary and seeded account rows render with `tester.takeException()` null after settling.
- [x] Add a test for `/profile` at 320×520 dp with `TextScaler.linear(1.6)`; tap the `设置` tooltip, assert no exception, scroll the modal until `关于好好记账` is visible, and assert the item lies inside the bottom-sheet bounds.
- [x] Run `flutter test test/responsive_overflow_regression_test.dart`; before production changes, both regressions failed due expected `RenderFlex overflow` (account summary by 102 px, account rows by 15–37 px, settings sheet by 261 px at 320×520/1.6x).

## Task 2: Fix the account summary at constrained widths

- [x] Adapt `_SummaryCard.build`: retain the current title/visibility/slogan row at ordinary width and scale; at compact width or enlarged text, keep title and visibility control in one row and place the decorative slogan on its own available-width row. Adapt `_AccountRow` similarly so the balance moves below the account name/platform at compact width or enlarged text while the chevron remains visible. Do not scale down user text or change totals/metric semantics.
- [x] Re-run `flutter test test/responsive_overflow_regression_test.dart --plain-name 'account management'`; both compact large-text and ordinary 393 dp account cases passed.

## Task 3: Make the profile settings menu fit short screens

- [x] Replace the settings menu's direct non-scrollable `showModalBottomSheet` with `AppBottomSheet.show<void>` and retain the same title, eight destinations, ordering, tap callbacks, and close-before-navigation behavior. The helper supplies a 90%-viewport maximum, safe-area handling, and a scrollable body.
- [x] Re-run the settings regression at 320×520/1.6x; no exception was raised and `关于好好记账` was reachable by scrolling.
- [x] Do not run screenshot-writing profile/asset/transaction reference tests while their outputs are user-owned or modified; the dedicated regression tests exercise the affected routes without writing QA images.

## Task 4: Audit comparable pages and verify

- [x] Audit the identified fixed-column sheet candidates with 320×520/1.6x reproductions. The receivable reminder overflowed by 19 px and the gated theme-membership prompt by 65 px before their fixes; both now use `AppBottomSheet`.
- [x] Run `flutter test test/responsive_overflow_regression_test.dart test/investment_responsive_test.dart test/consumption_calendar_test.dart test/home_redesign_visual_test.dart test/asset_overview_interaction_test.dart`; all 24 tests passed. Run the membership-prompt regression with `--dart-define=ALL_FEATURES_FREE_FOR_TESTING=false`; it passed.
- [x] Run `flutter analyze lib` and `git diff --check`; review task diffs and the dirty working tree to preserve user changes. Analyzer reported no issues.

## Acceptance criteria

- The 320 dp / 1.6x account-page test raises no Flutter exception in either the summary card or account rows.
- The 320 dp / 1.6x settings-sheet test raises no Flutter exception and can scroll to every menu option, including `关于好好记账`.
- Ordinary-size account summary and all existing settings destinations remain intact.
- The comparable-page audit records any confirmed issue and reproduces it before changing its code.
- Focused and comparable-page tests and `flutter analyze lib` pass; no screenshot baselines or unrelated working-tree changes are overwritten.
