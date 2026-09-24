# Asset overview and investment inclusion design

## Goal

Restore the asset distribution and asset change cards to one row on phone
screens, show investment positions in the asset overview when they are marked
for inclusion, make the distribution detail readable, remove the black bands
from the detail sheet, and let users decide whether each new investment counts
toward the asset total shown on Home.

The attached screenshot is a visual reference for the distribution detail. The
three requirements in the user's message define the requested behavior.

## Current behavior and findings

- `_ChartPair` stacks the two cards when the available width is below 380 dp.
- `AssetOverview` already receives investment market value by currency and
  includes it in the aggregate total, but both distribution lists are built
  only from account balances. That makes the total and the chart segments
  disagree.
- `AssetHistory` reconstructs balances from account and ledger transaction
  history. Investment snapshots are portfolio-wide and do not retain currency
  breakdowns, so they cannot safely be used to claim historical investment
  changes for a selected currency.
- The investment add flow persists a position through `InvestmentHolding` and
  `investment_holdings`; this is the appropriate scope for an individual
  inclusion choice.
- The asset detail sheet uses a clipped rounded `Material` inside a modal
  bottom sheet. The black bands must be reproduced and traced to the specific
  route/compositing or clipping behavior before the fix is chosen.

## Product behavior

### Investment inclusion

- Add a persisted boolean to each investment holding for inclusion in Home's
  book net assets.
- The add-investment switch defaults to off. The database migration also
  initializes existing holdings to off, per the user's correction. Existing
  holdings remain intact and fully visible in Investment Management; after
  migration their market values no longer contribute to Home and asset
  overview totals until explicitly included.
- The adjacent info affordance opens a concise, accessible hint with the user
  wording: “关闭后，投资类金额仅在投资管理页面展示，不计入首页展示的账目净资产。”
- Investment Management totals, holdings, transactions, and snapshots continue
  to use the full portfolio regardless of this flag.
- Home asset cards, asset overview totals, distribution, and asset change
  summaries consume only the included-by-currency value provider.

### Asset overview cards and detail

- Keep “资产分布” and “资产变化” in the same row at narrow phone widths. The
  two cards may compact their internal chart and labels, but do not switch to a
  vertical stack solely because available width is below 380 dp.
- Show the current included investment market value in both cards. For
  “资产变化”, show it separately from the period change so the ledger history
  is not presented as investment performance.
- Distribution chart and detail use the same entries: each positive-balance
  account plus one aggregated “投资管理” entry when the included investment
  value is positive. Sort by amount, and show each entry's amount and share of
  total assets. Guard the zero-total case.
- Tapping each card opens its matching detail sheet. The distribution sheet
  uses a balanced donut-and-list layout with right-aligned amount and share,
  without black bands, clipping artifacts, or overflow.
- Keep existing ledger-derived historical chart semantics. Do not manufacture
  investment history or attribute currency-less legacy snapshots to a
  currency. The current included investment value is labeled separately in
  the change card and detail.

## Data flow and components

1. Add the inclusion field to `InvestmentHolding`, `AddInvestmentRequest`, and
   the Drift `investment_holdings` table; bump the schema version and add a
   forward-only migration with a false default.
2. Map the persisted value in repository reads and writes. Keep the existing
   all-investment portfolio provider unchanged for Investment Management, and
   add a provider that aggregates only included position market value by
   currency.
3. Feed the included-by-currency provider to Home and asset overview totals.
4. Build one shared distribution-entry calculation used by the compact card
   and detail sheet, including the investment aggregate and percentages.
5. Keep the two cards side by side on small widths with responsive internal
   sizing. Reproduce and fix the detail-sheet black bands at their source.
6. Add the inclusion switch and tappable hint to the investment add form.

## Verification criteria

- New investment holdings default to excluded; a saved enabled value survives
  reload and is reflected in Home and asset overview.
- Existing holdings receive the specified excluded value during migration and
  remain fully available in Investment Management.
- Investment Management totals are unchanged by the inclusion flag.
- Distribution totals and detail rows agree; investment appears as its own
  aggregate row with accurate amount and percentage.
- The asset cards remain in one row at 320 dp and 393 dp widths without
  overflow; tapping either opens the expected detail sheet.
- The detail sheet renders without the black bands at the reproduced viewport
  and its content remains scrollable.
- The investment form exposes a default-off switch and displays the exact hint
  when its info affordance is tapped.
- Targeted Flutter tests and static analysis pass; a debug build succeeds.

## Risks and constraints

- The false migration default intentionally changes the Home/asset overview
  total for existing users with investments. Investment Management remains the
  source of their complete investment values.
- The existing worktree contains many unrelated modified and untracked files,
  including a user change in `asset_overview_page.dart`. Preserve all such
  changes and keep edits limited to this feature.
- Do not rewrite investment history, merge currencies, fabricate investment
  returns, or alter unrelated home/account semantics.
- Do not commit, reset, clean, merge, or rebase the user's existing work.
