# Responsive Overflow Fixes — Design

## Goal

Remove the two reproduced Flutter layout overflows and check nearby screens for the same class of issue:

1. The account summary card overflows horizontally on a 320 dp viewport with 1.6x text scaling.
2. The profile settings bottom sheet reports `BOTTOM OVERFLOWED BY 55 PIXELS` because its full menu is laid out as a non-scrollable column.

## Proposed behavior

- Preserve the account summary card's current arrangement on ordinary phone widths. At compact widths or larger text scales, adapt the decorative slogan so the amount, title, and visibility control remain visible without horizontal overflow.
- Keep every settings destination available. Bound the sheet to the available viewport and make its menu content scrollable, while retaining the drag handle and safe-area padding.
- Audit other app pages and sheets for the same overflow pattern. Make additional changes only when a concrete compact-screen, large-text, or short-height reproduction confirms an issue; avoid unrelated visual redesigns.

## Alternatives considered

- Reduce or remove the slogan at every width: simple, but changes the established layout on normal devices.
- Build a shared responsive-sheet framework: reusable, but broader than these failures and increases regression risk.
- Recommended: make the account card adaptive only when needed, make this menu scroll within its available height, and fix further confirmed instances surgically.

## Verification

- Add widget regression coverage for the account card at 320 dp / 1.6x text scale and for the settings sheet at constrained height.
- Confirm no `RenderFlex` overflow exception and that the bottom-sheet destinations can be reached by scrolling.
- Run focused tests, `flutter analyze lib`, and the relevant project tests; visually inspect compact and ordinary layouts where practical.

## Scope and safety

- Preserve existing account brand-icon work and all unrelated working-tree modifications.
- Do not change product navigation, menu contents, account totals, theme tokens, or persistence behavior.
- Do not push to the remote repository.
