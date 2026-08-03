# W3 · wallet-activity-list + transaction-detail — implementation report

**Status: applied.** Branch `feat/redesign-24-migration`. Three files touched, presentation only.
Cubits / state / domain / data / l10n untouched. Zero new endpoints, zero new user-visible strings,
zero shared-file edits, **no wiring request needed**.

There is **no board render for these two screens** (the board drew 24; these are two of the 46 it
never drew). The reference is the hub they both hang off, **23 · Wallet**
(`screens/23-wallet.png` / `.html`), plus the house precedents `wallet_hub_screen.dart` (the in-body
`JeebTopBar` + `JeebInfoNote` + grouped-exits card) and `notification_row.dart` /
`order_history_card.dart` (the outlined-card list row).

## Files

- `lib/features/wallet/presentation/wallet_activity_list_screen.dart` — header + all four states
  re-skinned in place.
- `lib/features/wallet/presentation/widgets/wallet_activity_row.dart` — the row moved onto
  `JeebOutlinedCard`.
- `lib/features/wallet/presentation/transaction_detail_screen.dart` — header + loaded body re-banded
  (navy amount hero → muted type note → grouped fields card → grouped edges card).

No file created, none deleted, no private copy of a kit widget.

## What changed — wallet-activity-list

| Before | After |
| --- | --- |
| `Scaffold(appBar: OMDSAppBar(title:, showBackButton:))` — a centred M3 bar the hub next door does not have | in-body `JeebTopBar(identifier: 'wallet_activity_back', title:)` inside `SafeArea`, mounted **above** the state switch so it renders identically in loading / failed / loaded; 24px gutter, h2 navy title, Ø40 leading circle |
| back = `onBackPressed: canPop ? pop : go('/')` | **identical logic**, moved to `onLeadingPressed`; `leadingTooltip` = `MaterialLocalizations.backButtonTooltip` (no new ARB key) |
| list = full-bleed rows, `Divider(height: 1, indent: 16)` between them, `vertical: Spacing.small` padding only | `ListView.separated`, 24px gutter, 16 top / 24 bottom, `SizedBox(height: Spacing.small)` separators — **R7/R12: the card outlines are the separation** |
| first-load skeletons = bare `OmdsListItemShimmer` rows + dividers | the same shimmer inside the **same r18 / 14-16 `JeebOutlinedCard`** a real row paints, so the list does not re-flow when the page lands |
| cold-load error = 64px `Icons.error_outline` in `colorScheme.error` + `bodyMedium` + `FilledButton.icon`, vertically centred | `JeebInfoNote.error` (soft `errorContainer` tint, role ink) + a `JeebCtaButton` navy pill, top-aligned in a 24-gutter band, in a `SingleChildScrollView` so 200% text scrolls instead of overflowing |
| empty = `SizedBox(height: MediaQuery.height * 0.18)` + `OmdsEmptyState` | same `OmdsEmptyState`, top-aligned in a 24-gutter / 64-vertical band (R1 — the residual space stays white and top-aligned, no viewport-fraction spacer) |
| load-more footer = shimmer in a bare `Padding`; failure = `TextButton` + `textTheme.bodySmall` | shimmer in the same card shell; failure note on `jeebText.bodySmall` periwinkle + `JeebCtaButton.text` |
| `RefreshIndicator` (a standing `tool/check_design_tokens.sh` violation on this file) | `OmdsPullToRefresh` — the same widget the hub and the inbox use. **The token check no longer names this file** |

### The row

| Before | After |
| --- | --- |
| bare `Row` in a `Padding` + `InkWell`, hairline divider below | `JeebOutlinedCard(radius: 18, padding: 14/16)` — 24's row shell, `onTap` on the card |
| Ø56 `surfaceContainerHighest` icon tile at `OmdsBorderRadius.small` | the tile is gone; the glyph sits inline at `Sizes.medium` in navy (an outlined card does not need a second box) |
| outlined glyph set (`lock_clock_outlined`, `percent_outlined`, …) | the filled twins (R10) — the hub's own `Icons.lock` / `Icons.article` register |
| type label `textTheme.titleSmall` w600 on `onSurface` | `context.jeebText.cardTitle` on `colorScheme.primary` |
| ref + relative time stacked as two extra lines on `onSurfaceVariant` (**`#5C4038` warm brown**) | one meta line — ref at the start, time at the trailing edge — on `jeebText.bodySmall` periwinkle (`onSecondaryContainer`), which is where 24 puts a row's trailing value. The palette reserves brown for outlines/dividers |
| amount `titleSmall` w700, credit `colors.primary` vs debit `colors.onSurface` | `jeebText.cardTitle` w800; credit `context.jeebRoles.success`, debit `colorScheme.primary`. **Navy `#0B1351` vs ink `#0B0E53` are the same colour to the eye** — the old credit/debit tint carried no information at all |
| amount rendered in the ambient paragraph direction | `textDirection: TextDirection.ltr` on the amount only — the copy layer hand-builds `+0.90 USD` (no `MoneyFormat` isolate), so Arabic reordered it to `USD 0.90-` and moved the load-bearing sign to the far edge |

## What changed — transaction-detail

| Before | After |
| --- | --- |
| `Scaffold(appBar: OMDSAppBar(...))` | in-body `JeebTopBar(identifier: 'txn_detail_back', …)`, same back logic, renders in every state |
| body gutter 16 | 24 gutter, 16 top, 32 bottom |
| type heading + body = a bare `Row(Icon + titleMedium)` over `bodyMedium` on brown, floating on white | `JeebInfoNote.muted` (stacked form: glyph 19, `mutedSurface` fill, r16) — the hub's own note treatment |
| amount = the first `_DetailRow`, `titleMedium` w700 | **the navy stat hero**: `JeebNavySurfaceCard(radius 20, JeebShadows.heroNavy, rings: [statBottomEnd])` with `JeebSectionLabel(Amount)` over `jeebText.statHero` in `onPrimary`, LTR-isolated. 23's signature element, spent on the one number this screen exists to state |
| date / fee rate / accepted price / dispute ref / reference = loose label-value rows on the white body, `bodyMedium` brown + `bodyLarge` | the same rows, same order, inside one `JeebOutlinedCard.grouped` (the kit draws the 1px inset dividers). Label `jeebText.bodySmall` periwinkle, value `jeebText.body` w700 navy, `JeebListRow.defaultPadding` (14/16) so a field row and an edge row share a rhythm |
| `OmdsSettingsRow` × 2 for the order / dispute edges | `JeebListRow` × 2 (filled `Icons.receipt_long` / `Icons.gavel`, directional chevron) inside a second `JeebOutlinedCard.grouped` — 23's grouped-exits card, verbatim |
| `_DetailRow.emphasize` | dropped — its only consumer was the amount, which is now the hero |

Kit widgets consumed: `JeebTopBar` · `JeebOutlinedCard` (+ `.grouped`) · `JeebNavySurfaceCard`
(+ `JeebNavyRing.statBottomEnd`) · `JeebInfoNote` (`.error`, `.muted`) · `JeebCtaButton` (+ `.text`)
· `JeebListRow` · `JeebSectionLabel`.
Tokens: `context.jeebText.statHero / .cardTitle / .body / .bodySmall`, `JeebShadows.heroNavy`,
`context.jeebRoles.success`, `colorScheme.primary / .onPrimary / .onSecondaryContainer`,
`Spacing.*` / `Sizes.*`. Every inset is `EdgeInsetsDirectional`. Zero `Color(0x…)`, zero raw
`TextStyle`, zero `fontSize:`.

## What deliberately did NOT change

Behaviour, navigation and business logic are byte-identical: the 4-state machine, the
`ScrollController` infinite-scroll trigger and its single-flighted `loadMore`, pull-to-refresh, the
`_resolveRepository` seams, both `pushNamed` edges and their param shapes, `ServerTime` date
formatting, and every string in `wallet_activity_l10n.dart` / `transaction_detail_l10n.dart`. No
step added, no affordance removed, no copy meaning changed.

## Refusals (things the hub has that these screens must not invent)

1. **No filter / type chip row.** `WalletLedgerRepository.fetchLedger` takes `page` + `pageSize`
   only — there is no type or date query parameter behind a "Reserves / Fees / Top-ups" pill row,
   and the chips would need new ARB keys. A filter that filters nothing is a lie.
2. **No `Today` / `Earlier` `JeebSectionLabel` grouping.** Two new user-visible strings plus a
   structural change to the list — a product change, not a re-skin, and the l10n parity gate would
   need an ARB edit.
3. **No running-balance column and no `JeebMoneyBreakdown`.** The ledger row carries `amount` +
   `sign`, never a balance-after; and `JeebMoneyBreakdown` debug-asserts that any `N%` equals
   `kJeebCommissionPercent`, so a server row with a non-10% `feeRate` would *throw* — the exact
   D37 field this screen has to render honestly. The fee rate stays a plain field row.
4. **No "1 live offer ·" style count** anywhere (the hub's own open TODO) — the same missing
   count, not faked here either.
5. **No CTA footer on transaction-detail.** A "Top up" or "Open dispute" pill would be a new edge;
   the screen's two honest edges are the two rows it already had.
6. **No orange.** Neither screen has a do-it-now moment: the accent appears only as the hero card's
   one off-canvas decorative ring, exactly as on 23.
7. **`JeebListRow` not used for the ledger row.** The row carries four text elements at two type
   sizes plus a signed amount; `JeebListRow` is title/subtitle/icon/trailing. Bespoke content
   inside a kit card is the sanctioned house pattern (`OrderHistoryCard`, `NotificationRow`).

## Frozen contracts

All ten identifiers are byte-identical: `wallet_activity_root` · `wallet_activity_loading` ·
`wallet_activity_error` · `wallet_activity_retry_cta` · `wallet_activity_empty` ·
`wallet_activity_row_<id>` · `wallet_activity_load_more` · `wallet_activity_load_more_retry` ·
`txn_detail` / `txn_detail_root` (both, still nested) · `txn_detail_type_label` /
`txn_detail_type_summary` (both, still nested) · `txn_detail_amount` ·
`txn_detail_fee_percentage_label` / `txn_detail_fee_rate` (both) · `txn_detail_pinned_price` ·
`txn_detail_order_ref` · `txn_detail_order_link` · `txn_detail_dispute_link`.

Five of them are re-homed onto the kit widget that now paints them
(`wallet_activity_row_<id>` → `JeebOutlinedCard`, `wallet_activity_error` → `JeebInfoNote`,
`wallet_activity_retry_cta` / `wallet_activity_load_more_retry` → `JeebCtaButton`,
`txn_detail_type_summary` → `JeebInfoNote`, both `txn_detail_*_link` → `JeebListRow`), each of
which emits the same `Semantics(identifier:, button:, container:)` shape as the hand-rolled wrapper
it replaces — the `NotificationRow` precedent. The row's tap target is still exactly one `InkWell`
(the kit card's), so the existing tap-through test is unaffected.

Two ids added, both `<screen>_<element>`: `wallet_activity_back`, `txn_detail_back`.

## Verification

- `dart analyze lib/features/wallet` → **No issues found!**
- `flutter test test/features/wallet/ --no-pub` → **43 passed, 0 failed** (unchanged count).
- `flutter test test/core/router/w3_w4_routes_resolve_test.dart test/decision_violations_test.dart`
  → **13 passed**.
- `bash tool/check_design_tokens.sh` → the two wallet files are **no longer named** (the pre-existing
  `RefreshIndicator` violation on `wallet_activity_list_screen.dart` is fixed; the two remaining
  repo violations are other lanes' files).
- Rendered EN + AR at 440×956 through a throwaway golden harness and inspected the output
  (list / cold-load error / detail / detail-RTL); the harness and its PNGs were deleted.

## Self-critique (remaining inconsistencies vs 23)

1. **Credit amounts are green (`jeebRoles.success`).** Defensible (the hub paints its positive
   state green, and navy-vs-ink was invisible) but 23 itself has no green *text*, and a ledger of
   mostly credits reads greener than the board's white/navy discipline. One-line reversal if the
   owner prefers navy everywhere.
2. **"Platform fee" appears twice on a fee_won detail** — as the note title and as the fee-rate
   field label. Pre-existing copy; deduping needs an l10n change, so it was left alone.
3. **The empty and error states still render OMDS bodies** (`OmdsEmptyState`, `OmdsLoadingState`,
   `OmdsErrorState` on transaction-detail). They are house-standard and every other W3 lane kept
   them, but they are not board-drawn shapes.
4. **Block rhythm is a uniform 16** between bands on transaction-detail, against 23's mixed 12/16;
   the board has no rhythm for a screen with four bands, so one number was chosen over guessing.
5. **The skeleton is still `OmdsListItemShimmer`** inside the card — the kit ships no skeleton
   primitive, and inventing one is a kit change, not a screen change.
6. **`ListView.separated` keeps a 12px gap above the load-more footer** where the old code drew
   none; harmless, and it stops the footer jumping when it appears.
7. **The detail's field values are not LTR-isolated** (only the two signed amounts are). In Arabic
   `15.00 USD` renders `USD 15.00`, which is the ordering `MoneyFormat` itself uses for non-USD
   codes — wrong-looking is not the same as wrong, and forcing it would need the l10n layer.
