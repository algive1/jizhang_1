# Responsive Overflow Fixes — Design

## Goal

Remove the two reproduced Flutter layout overflows and check nearby screens for the same class of issue:

1. The account summary card overflows horizontally on a 320 dp viewport with 1.6x text scaling; the same run also found three account rows overflowing by 15–37 dp because their trailing balances do not adapt to enlarged text.
2. The profile settings bottom sheet reports `BOTTOM OVERFLOWED BY 55 PIXELS` because its full menu is laid out as a non-scrollable column.
3. The receivable reminder sheet overflows by 19 px at 320×520 dp with 1.6x text.
4. The membership-theme prompt overflows by 65 px at the same compact, large-text size when membership gating is enabled.

## Proposed behavior

- Preserve the account summary card and account-row arrangement on ordinary phone widths. At compact widths or larger text scales, move the decorative slogan and account balances into available vertical space so labels, amounts, and visibility controls remain readable without horizontal overflow.
- Keep every settings destination available. Bound the sheet to the available viewport and make its menu content scrollable, while retaining the drag handle and safe-area padding.
- Apply the same bounded, scrollable sheet behavior to the receivable reminder and membership-theme prompts; preserve their existing choices, copy, and callbacks.
- Audit other app pages and sheets for the same overflow pattern. Make additional changes only when a concrete compact-screen, large-text, or short-height reproduction confirms an issue; avoid unrelated visual redesigns.

## Alternatives considered

- Reduce or remove the slogan at every width: simple, but changes the established layout on normal devices.
- Build a shared responsive-sheet framework: reusable, but broader than these failures and increases regression risk.
- Recommended: make the account card adaptive only when needed, make this menu scroll within its available height, and fix further confirmed instances surgically.

## Verification

- Add widget regression coverage for the account page at 320 dp / 1.6x text scale (including account rows), the profile settings and receivable reminder sheets, and the gated membership-theme prompt.
- Confirm no `RenderFlex` overflow exception and that the bottom-sheet destinations can be reached by scrolling; also run comparable investment, calendar, home, and asset-overview widget suites.
- Run focused tests, `flutter analyze lib`, and the relevant project tests; visually inspect compact and ordinary layouts where practical.

## Scope and safety

- Preserve existing account brand-icon work and all unrelated working-tree modifications.
- Do not change product navigation, menu contents, account totals, theme tokens, or persistence behavior.
- Do not push to the remote repository.
