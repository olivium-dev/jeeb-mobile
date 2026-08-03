# 19 · Earnings — implementation report

Instruction set: `docs/redesign-2026-08/per-screen-revised/19-earnings.md` (followed in full).
Status: **applied**, with one deliberate, reported analyze error (the §8-A wiring grant).

## Files changed

| file | change |
|---|---|
| `lib/features/earnings/presentation/earnings_dashboard_screen.dart` | presentation tree rebuilt in place (581 → 660 LOC) |
| `lib/features/earnings/presentation/earnings_dashboard_l10n.dart` | task 2 — 5 values replaced, 1 getter added, 2 deleted, rate interpolated |
| `lib/features/earnings/application/earnings_state.dart` | task 3 — `walletBalance` field / ctor / `copyWith` / `props` |
| `lib/features/earnings/application/earnings_cubit.dart` | task 3 — optional `WalletRepository?` + fire-and-forget `_loadWalletBalance` |
| `test/features/earnings/earnings_dashboard_data_truth_test.dart` | 2 casing edits + 6 additive tests |
| `test/features/earnings/earnings_dashboard_layout_test.dart` | **NEW** — 390pt phone × {en, ar} × {100%, 200%} overflow cover |
| `test/earnings_cubit_test.dart` | 2 additive tests for the wallet-read contract |
| `docs/redesign-2026-08/wiring/19-earnings.md` | **NEW** — §A (blocking) + §B (follow-up) |

Untouched, as required: `lib/features/shell/*` (incl. `earnings_tab.dart`), `app_router.dart`,
`injection_container.dart`, `lib/core/theme/*`, `lib/core/widgets/jeeb/*`,
`lib/core/formatting/*`, `lib/l10n/*`, `pubspec.yaml`, `.maestro/*`, the wallet feature,
`test/support/*`, `lib/devtool/*`.

## Gates

- `dart analyze lib/features/earnings test/features/earnings test/earnings_cubit_test.dart`
  → **1 error, and it is the expected §8-A block** (`MoneyFormat.format(…, signed: true)` at
  `earnings_dashboard_screen.dart:632`). Nothing else. No new warnings, no new infos.
- `flutter test test/features/earnings/ test/earnings_cubit_test.dart` → **33/33 green**
  (verified by temporarily applying the §8-A patch locally and then restoring
  `money_format.dart` byte-identically — `shasum b3c3a609…`, and `git status` on
  `lib/core/formatting/` is clean).
- `bash tool/check_design_tokens.sh` → **0 violations in `lib/features/earnings`**. The 6 it
  reports are other lanes (settlement ×3, location, wallet-activity, reviews).
- `grep -rn "identifier: '" lib/features/earnings/` → **13 literals, byte-identical to §1**,
  zero new identifiers, zero kit widgets carrying an `identifier:`.
- `flutter test test/features/wallet/wallet_hub_screen_test.dart` → 13/13 green (jm-053's
  `earnings_total_cash` hand-off survives). `shell_role_tabs_test` and
  `decision_violations_test` do not compile right now for reasons entirely outside this lane —
  other concurrent lanes call `AppLocalizations` getters that do not exist yet
  (`availabilityInactivityInlineWarning`, `mutualRatingStarLabel4`, `homeRepliesOffersFloor`, …).
  No earnings symbol appears anywhere in those errors.

## The one blocked call site (needs the integrator)

`wiring/19-earnings.md` §A adds `bool signed = false` to `MoneyFormat.format`. Per the
instruction set (task 1) the row-amount code is written as if it were granted, so the lane does
not compile until it lands. If §A is refused, delete the single `signed: true` argument at
`earnings_dashboard_screen.dart:632` — the `+` is decorative. It is **not** acceptable to write
`'+' + MoneyFormat.format(…)`: `U+002B` is bidi-class ES and renders on the wrong side of the
amount in Arabic.

## Two deviations from the instruction set (both deliberate, both flagged)

1. **`SafeArea` consumes the top inset too** (§Task 4 sketch says `SafeArea(top: false)`).
   The reasoning behind `top: false` — "the shell already consumed it" — holds for the shell
   tab, but `/earnings` is a plain top-level `GoRoute` (`app_router.dart:1645-1650`) with no
   shell `SafeArea` above it, and the rebuild deletes the `OMDSAppBar` that used to absorb the
   status bar there. `top: true` is a no-op inside the shell and the only thing keeping the
   title off the status bar on the pushed route, so it is a strict superset.
2. **The period row is `JeebChipRow.scrollable`, not the fixed form.** This is a real defect
   the render re-view caught: at a 390pt viewport the fixed `Row` overflows
   (`RenderFlex overflowed by 70px`, and by 370px at the 200% scale AC T-mobile-036 requires).
   The kit's scrollable form is non-lazy by design precisely so every `earnings_period_*`
   identifier stays resolvable when a pill scrolls off — pinned by a new test. Visually
   identical at 1x, because both forms start-pack behind the same 24px gutter. The gutter moved
   onto the scroll view itself (kit §2.3: "the trailing gutter scrolls with the last pill
   instead of clipping it").

## Divergences from the board (as decided in the instruction set §2)

Kept verbatim, and worth repeating in the PR: header is a bare `Text(title, h2)` not
`JeebProfileHeader`; the fee strip is a `JeebOutlinedCard` single-value row not
`JeebMoneyBreakdown` (19 has no breakdown — no label/value rows, no divider, no total);
`Total cash earned` keeps its string and gains only the uppercase treatment; **`Jeeb fees paid`
is REFUSED** in favour of `Platform fees paid` (D41/D44, plan row 481); **`★ 4.8 / This week` is
REFUSED** — no period-scoped rating exists on any contract, so hero stat #3 is member-since;
`10%` is interpolated from `kJeebCommissionPercent`; the row tier emoji and item name are data
gaps (`{deliveryId, amount, syncedAt}`) and are omitted with a `TODO(redesign-24)`, never faked;
the wallet balance suffix appears only once a real `WalletBalance` has loaded.

## Consequence to call out in the PR

Deleting `OMDSAppBar` removes the automatic back button on the **pushed** `/earnings` route
(wallet hub → earnings, jm-053 AC4). The board is a tab root with no top bar; system and
predictive back still pop, and jm-053 only asserts `earnings_total_cash` visibility (`:143`),
which is unaffected.
