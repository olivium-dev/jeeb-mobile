# 17 · Offer composer — implementation report

**Status: applied.** Presentation layer rebuilt on the Wave-1 kit; state layer, repositories, route
and every constructor seam untouched.

## What shipped

| Task | Result |
|---|---|
| T1 wiring | `docs/redesign-2026-08/wiring/17-offer-composer.md` written. WR-2/3/4 turned out to be **already shipped by Wave 1** (verified in the kit source, not just the doc) — noted as satisfied. WR-1, WR-5, WR-6 remain open. |
| T2 `quickOptions` | `offer_eta_band.dart` — additive pure-Dart getter. 60-ceiling band → `[20,40,60]` (the board); 5..120 fallback → `[40,80,120]`; ≤3 options returned verbatim. |
| T3 copy | `offer_composer_l10n.dart` — new title/section labels/hint/other/row labels/wallet/CTA copy, board note placeholder, `currencyMark`, `money`/`negativeMoney` (through `MoneyFormat`, LTR-isolated), `_ltr` helper; every `10%` now interpolates `kJeebCommissionPercent` (EN **and** the AR strings that previously hardcoded ١٠٪). |
| T4 header | `OMDSAppBar` + `_OrderRefHeader` deleted → `JeebTopBar.close` in-body, `SafeArea` body. |
| T5 scaffold | `Column` → top bar → `Expanded(SingleChildScrollView, 24/20/24/0)` → docked `JeebCtaFooter.single`. |
| T6 price | `_PriceField` deleted → `JeebMoneyField` (new, feature-local — see below) with `±1` steppers, floor at 0, no invented ceiling. |
| T7 ETA | `_EtaDropdown` deleted → `JeebChipRow.expanded` of `role: choice` chips inside the frozen `offer_composer_eta_dropdown` container (`ColoredBox(Colors.transparent)` keeps the legacy row tap a real no-op). `Other` pill on the fallback band; picker kept, its rows re-prefixed `offer_composer_eta_sheet_option_<i>`; `_EtaError` renders `state.etaError`. |
| T8 note/breakdown/wallet | Placeholder-only `OmdsTextField` (label → `Semantics.label`, counter → `LengthLimitingTextInputFormatter`, resting border hidden via one `OmdsColorTokens` override); `_EconomicsCard`/`_EconLine` deleted → `JeebMoneyBreakdown`; `JeebInfoNote.accent` wallet strip, omitted entirely when `_wallet == null`. |
| T9 CTA | `_SendButton` deleted → `JeebCtaButton.primary(height: 58, isLoading:)` in `JeebCtaFooter.single`; label restates the kept amount. |
| T10 sweep | `dart analyze lib/features/offers test/features/offers` → **No issues found**. `check_design_tokens.sh` → **zero violations under `lib/features/offers`** (the 8 it reports are other lanes: settlement, wallet, location, reviews). |
| T11 tests | 4 new files, 31 tests green (see below). |
| T12 freeze matrix | See below. |

## Decisions & deviations (read these)

1. **C2 adopted — `offer_composer_net_line` changes meaning** from "You earn (cash): full price" to
   **"You keep: price − platform fee"**, per the board, the designer note, and `netPerOffer`
   (`earnings_summary.dart:170`). The `(cash)` qualifier is dropped — under this reading it is
   literally wrong (cash in hand is the full offer); the reserve footnote carries the mechanics.
   Flagged here and in WR-5 for owner review; reverting is one l10n line.
2. **C1 held** — "Platform fee (10%)", never "Jeeb fee"/"Commission" (D41/D44). The `10` comes from
   `kJeebCommissionPercent` everywhere, including the pending sentences and the AR copy.
3. **`JeebMoneyField` is feature-local, not kit** — Wave 1 §5 deliberately left it to this lane
   ("screen-17-local by assignment"), and the kit is frozen. It therefore lives at
   `lib/features/offers/presentation/widgets/jeeb_money_field.dart` and pays two prices the gate
   imposes on `lib/features`: the type is snapped (`$` → `jeebText.price` 21/w800 vs the board's 24;
   amount → `jeebText.h1`@w800 24/w800 vs the board's 26), and the raw `TextField(` line carries an
   `EXEMPT(flutter-omds-design-system-usage)` comment. **WR-1 is a file move that restores both.**
4. **Header subtitle is `ORD-…` only.** `Pharmacy run · ⚡ Flash` needs data this route does not
   carry (`:id` only, verified at both call sites) — omitted with a `TODO(redesign-24)`, not faked.
   Same reason the ETA hint reads `· ≤ 120 min` (the fallback band ceiling) instead of the board's
   `· Flash allows ≤ 60 min`, and why the row shows 3 pills **+ `Other`** instead of exactly 3.
   WR-6 collapses both to the board.
5. **Two responsive adaptations** the board does not describe, both found by the 200% AR test:
   past ~130% text the ETA row switches from equal-width to a scrollable row of natural-width pills
   (a `choice` chip does not ellipsize inside a tight `Expanded` — it overflowed by 145px), and the
   wallet strip tightens its inset/gap (`JeebInfoNote`'s trailing link takes natural width — it
   overflowed by 5px). Both are call-site params; the kit is untouched.

## Frozen contracts

All 16 existing `Semantics(identifier:)` values are emitted byte-identically. Re-homed:
`offer_composer_close_cta` → `JeebTopBar` leading, `offer_composer_order_ref` → its subtitle
(`header: true`), `offer_composer_price_field` → the money field's editable core (still the FIRST
`EditableText` in the tree), `offer_composer_eta_dropdown` → the chip-row container,
`offer_composer_eta_option_<i>` → the inline pills, `_fee_line`/`_net_line`/`_reserve_note` →
`JeebMoneyBreakdown` rows, `offer_composer_send_cta` → the docked CTA.
`_InsufficientBalanceSheet` and its five ids are byte-identical.
New: `offer_composer_offer_line`, `_price_decrement`, `_price_increment`, `_eta_more_cta`,
`_eta_sheet_option_<i>`, `_wallet_strip`, `_wallet_topup_cta`.

## Verification

- `dart analyze lib/features/offers test/features/offers` → **No issues found** (also re-analyzed
  `batch_07_entries.dart` + `app_router.dart`: clean — the ctor seam is untouched).
- `flutter test test/features/offers/` → **31 passed**, including the frozen
  `offer_composer_error_l10n_test` **unmodified** (it taps `_eta_dropdown` then `_eta_option_0`,
  which now selects 40 min inline).
- `flutter test test/core/router/back_nav_offer_composer_test.dart` → **passed unmodified**.
- `flutter test test/offer_form_cubit_test.dart test/batch_j_supplementary_test.dart
  test/core/jeeb_commission_test.dart` → passed.
- `bash tool/check_design_tokens.sh` → zero violations in `lib/features/offers`.
- **Blocked by other lanes, not by this change:** `test/decision_violations_test.dart` and
  `test/core/router/back_nav_all_routes_test.dart` currently fail to *compile* because
  `mutual_rating_screen.dart` (lane 15) and `replies_card.dart` (lane 04) call ARB keys the
  integrator has not landed yet (`mutualRatingStarLabel4`, `homeRepliesOffersFloor`, …). Nothing in
  those errors touches `lib/features/offers`. Re-run after the l10n integration pass.
- Maestro `jm-045` / `jm-046` / `jm-044`: unmodified; the tap sequences hold by construction
  (§2 analysis) but were **not** executed here — they need the S22 per the real-flow standard.

## New tests

`test/features/offers/offer_eta_band_quick_options_test.dart` (5) ·
`offer_composer_price_stepper_test.dart` (5) · `offer_composer_wallet_strip_test.dart` (3) ·
`offer_composer_rtl_smoke_test.dart` (2 — AR mirroring at 200% with no overflow, and amounts as
LTR-isolated runs inside Arabic sentences).
