# 11 · Offers — implementation report

Branch `feat/redesign-24-migration`. Instruction set: `per-screen-revised/11-offers.md`
(its §0 "`lib/core/widgets/jeeb/` does not exist yet" is VOID — the Wave-1 kit shipped and is
consumed here).

Status: **applied**, with one wiring dependency (the l10n batch) that keeps the feature from
compiling until the integrator lands it.

---

## Kit consumed (no private copies)

| Kit widget | Where |
|---|---|
| `JeebTopBar.back` | the screen's in-body header (`title` + `subtitle` + `identifier: offer_review_back`) |
| `JeebSelectChip(role: sort)` + `JeebChipRow` | all three sort chips |
| `JeebMeter` (bar, nullable `value`) | the window strip's 70×5 meter |
| `JeebInfoNote` — `accent` / `warning` / `error` / `muted` | the window strip, the closed banner, the dismissible error banner |
| `jeebPillRadius` (from `jeeb_select_chip.dart`) | the `Best value` and `Fastest` pills |

All four cross-feature kit requests in the instruction set's §6 were re-checked against the shipped
kit and are **already satisfied** — no kit change is requested. `JeebCtaFooter` was NOT used: this
footer's note is `bodySmall/w700/accent` centred over an OMDS **text** button whose type is pinned
by two tests (`OmdsPrimaryButton` under `offer-review-cancel-cta`), which `.textStack` cannot host.

## Files changed

- `lib/features/client_offers/domain/offer_ranking.dart` **(new)** — Borda ranking + the two badge
  selectors, pure Dart.
- `lib/features/client_offers/domain/offers_repository.dart` — `OffersSnapshot.requestTitle`
  (optional, defaults null, so `test/support/scripted_offers_repository.dart` compiles unchanged).
- `lib/features/client_offers/data/dio_offers_repository.dart` — parses `requestData['title']`
  off the row `fetchOffers` already reads. No new call.
- `lib/features/client_offers/data/fake_offers_repository.dart` — demo title.
- `lib/features/client_offers/application/client_offers_state.dart` — `OfferSortMode.best` (new
  default), `windowTotal`, `requestTitle`, `windowProgress`, derived `bestValueOfferId` /
  `fastestOfferId`.
- `lib/features/client_offers/application/client_offers_cubit.dart` — `best` sort branch;
  session-observed `windowTotal`; title pass-through.
- `lib/features/client_offers/presentation/widgets/offer_window_timer.dart` — rebuilt **in place**
  (path is grepped by `no_raw_semantic_colors_test.dart:21`).
- `lib/features/client_offers/presentation/widgets/offer_sort_bar.dart` — 2 chips → 3, prefix label
  deleted.
- `lib/features/client_offers/presentation/widgets/offer_card.dart` — re-anatomised to two rows.
- `lib/features/client_offers/presentation/client_offers_screen.dart` — `OMDSAppBar` deleted,
  in-body top bar, fixed header, `Expanded(ListView)`, docked footer.
- Tests: `test/features/client_offers/offer_ranking_test.dart` (new),
  `test/offer_window_timer_test.dart` (rewritten), `test/offer_card_test.dart` (+4, additive),
  `test/client_offers_screen_test.dart` (mechanism updates + 4 new),
  `test/client_offers_cubit_test.dart` (2 updates), `test/dio_offers_repository_test.dart` (+1).
- `docs/redesign-2026-08/wiring/11-offers.md` (new).

## ⚠️ Two things the reviewer must know

**1. PRODUCT CHANGE — the default sort is now `best`, not `byPrice`.** Which offer the customer
sees first changed. `client_offers_cubit_test.dart`'s renamed
*"emits loaded snapshot sorted by best value (default)"* is the documentation of it. The ranking is
a Borda count over fee-asc / rating-desc / ETA-asc; an unrated Jeeber contributes a **neutral**
rating rank (never a fabricated 0.0-star score), and ties break newest-first so the order cannot
churn between pushes.

**2. BASELINE FLIP — `client_offers_screen_test` is GREEN.** The `_BASELINE.md` pre-existing red
(*"offer sort chips expose tokenized minimum hit targets"*) passes: `JeebSelectChip(role: sort)`
carries no minimum height, so the capsule (~33dp) renders strictly shorter than its `MinTapTarget`
(48dp), which `OmdsChip` could never do. The test now covers **three** chips, not two. All 17 tests
in that file pass.

## Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/client_offers` | **6 errors, all the pending l10n members** (see below). Zero other issues. |
| `dart analyze` (same, with the l10n batch applied locally) | **No issues found** |
| `flutter test` — screen / card / timer / cubit / ranking / overflow / accept-sheet / 429 / push / resume / failure-copy / dio-repo / no-raw-semantic-colors / decision-violations | **all green** (verified with the l10n batch applied locally, then reverted byte-for-byte) |
| `bash tool/check_design_tokens.sh` | 8 violations, **none in `lib/features/client_offers/`** — settlement (2 files), wallet (2), location (1), reviews (1); pre-existing, other lanes |
| `grep -rn "identifier:"` vs §1 | every frozen id present, plus the 6 new ones |

### The l10n dependency (expected, per the instruction set's Task 1)

`lib/features/client_offers/` does not compile until the integrator lands
`docs/redesign-2026-08/wiring/11-offers.md`. Four missing members, six call sites:
`offersSortByBest`, `offersCardBestValueBadge`, `offersCardFastestBadge`, `offersWindowStrip(int,
String)`. To verify the work I applied that exact batch locally, ran the suites, and restored all
three l10n files **byte-for-byte** (SHA-1 verified against a pre-edit copy). Nothing of mine
remains in `lib/l10n/`.

### Two suites blocked by ANOTHER lane

`test/features/client_offers/offer_accept_double_accept_b01_test.dart` and
`test/devtool/catalog_network_guard_test.dart` fail to **load** on
`lib/features/home_client/presentation/widgets/replies_card.dart:177 — l10n.homeRepliesOffersFloor
isn't defined`. That is screen 04's pending l10n wiring, not this lane's; both suites are otherwise
untouched by this change.

## Deliberate divergences from the board (all carried from the instruction set)

| Board | Shipped | Why |
|---|---|---|
| title `Offers` | `offersScreenTitle` ("Choose a Jeeber") | already translated; the strip carries the "3 offers in" fact |
| `$8` | `⁦$8.00⁩` (`MoneyFormat`) | pinned by three tests; LTR-isolated for RTL |
| `in 40 mins` | `40 min ETA` | exists in both locales, asserted twice |
| `04:12` | `4:12` | `CountdownFormat`'s unpadded leading field is deliberate and bidi-safe |
| `Accept only one offer.` | `chatOfferAcceptOnlyOne` (no period) | existing key; no near-duplicate minted |
| `3 km away` | vehicle label | **no distance field exists** anywhere on the wire — TODO in `_MetaLine`, never faked |
| `… — Pharmacie du Musée` | item title only | `/v1/requests/:id` carries no dropoff address — TODO on the subtitle |
| third card dimmed (.75), no actions | full-strength card, full action row | plan §7.2-C4: every offer stays acceptable |

## One divergence from the instruction set itself

§3 Task 7 prescribes `OmdsStarRatingDisplay(totalReviews:, reviewsLabelBuilder: (c) => '$c')`.
Shipped instead: `showReviewCount: false` plus the count as its **own** `Text` sibling in the meta
`Wrap`. OMDS lays the count inside its own unbreakable `Row`, and a seven-figure review count at
200% text overflows that row by ~234px — `offer_card_overflow_test` (411dp, pinned) fails on it.
As a sibling the count ellipsizes and wraps. `find.text('4.7')` and `find.text('(132)')` both still
resolve, and `find.byType(OmdsStarRatingDisplay)` is still present/absent exactly as before.
