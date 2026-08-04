# 24 · Order history — apply report

Status: **applied**, with one wiring dependency (the l10n batch in
`docs/redesign-2026-08/wiring/24-order-history.md`) that keeps the feature from compiling until
the integrator lands it. That is the instruction set's own Task 1 expectation, not a surprise.

Presentation tree only. Cubit / state / repository / domain / `orders_resume_refetcher.dart` /
`order_history_date_filter_sheet.dart` are untouched — no new field, no new call, no new endpoint,
no route, no DI, no theme edit, no kit edit, no ARB edit.

## Files changed

| File | What |
|---|---|
| `lib/features/order_history/presentation/order_status_chip.dart` | Widget + `_paletteFor` + `_ChipPalette` deleted; the status→string switch survives as the top-level `orderStatusLabel(status, l10n)`. **File kept on disk and hex-free** (`no_raw_semantic_colors_test.dart:36` lists this exact path). |
| `lib/features/order_history/presentation/order_history_card.dart` | Full rebuild onto the kit: `JeebAccentFrameCard` / `JeebOutlinedCard` shell (status-driven), `_IdentityRow` (glyph · where-from · amount), `_MetaRow` (tier · date · dot · status · pill). `_Header`, `_AddressLine`, `_Footer`, `_TierBadge` deleted. |
| `lib/features/order_history/presentation/order_history_screen.dart` | `_FilterBar` → `_HistoryHeader` (title + date-range chip); `TabBar` → `JeebChipRow.scrollable` of `JeebSelectChip`s; list chrome re-gutter + divider removal + the two new row callbacks. |
| `test/features/order_history/order_history_card_test.dart` | Date expectation `yMMMd().add_jm()` → `MMMd()` (deliberate, board meta reads `Jun 26`; `.toLocal()` is still the subject). Added the `redesign-24 shell + row CTAs` group. |
| `test/order_history_screen_test.dart` | `_host` gained a `locale` param and a named `request-type` route; `_pickDate`'s day-cell finder scoped to `DatePickerDialog`; added the `redesign-24 header, tab pills and row CTAs` group. |
| `docs/redesign-2026-08/wiring/24-order-history.md` | The one wiring batch (5 l10n keys). |

## Kit widgets consumed (nothing hand-rolled)

`JeebOutlinedCard` · `JeebAccentFrameCard` · `JeebSelectChip` (`filter` for the tabs,
`quickReply` for the date chip, `inlineAction` for both row pills) · `JeebChipRow.scrollable` ·
`JeebTierChip.custom` + `JeebTierChip.emojiFor` · `JeebShadows.stepGlow` · `context.jeebText`
(`h2`, `cardTitle`, `body`, `bodySmall`) · `context.jeebRoles` (`accent`, `success`).
`JeebSemanticColors` is deliberately **not** read (the `wrapForTest` harness themes with
`ThemeData.light()` and the bang would crash).

## Semantics — §1 verified by grep

Frozen, byte-identical: `order_history_root`, `order_history_active_tab`,
`order_history_completed_tab`, `order_history_cancelled_tab` (emitted as
`'order_history_${tab.name}_tab'`), `order_history_filter_chip`,
`order_history_card_${order.id}` (re-homed onto the kit card's `identifier:`, with
`orderHistoryCardSemanticLabel` on `semanticLabel:`), and all six sheet ids (file untouched).
Frozen keys intact: `order-history-filter-chip`, `order-history-loading`, `order-history-error`,
`order-history-empty-<tab>`, `order-history-list-<tab>`, `order-history-loading-more`,
`order-history-card-<id>` (now the kit card's `key:`).

New: `order_history_track_cta_${order.id}`, `order_history_reorder_cta_${order.id}`. They resolve
**because** the kit card emits `explicitChildNodes: true`; a hand-rolled `Semantics` + `InkWell`
sandwich around the kit card would have produced nested duplicate button nodes and swallowed them.

## Divergences from the board (each one-line reversible)

| Board | Shipped | Why |
|---|---|---|
| `ETA 20 min` | omitted | no ETA field on `GET /v1/requests`; TODO in `order_history_screen.dart`, not faked |
| item title `Medicine — Pharmacie du Musée` | `order.pickupAddress` (empty → `orderHistoryAddressMissing`) | no item/description on the list DTO |
| `Karim · ★ rated 4` | `date · status` | no jeeber identity or rating on the list DTO |
| `no offers` in the amount slot | `—` + `Amount unavailable` | money truth (T11/SW-02), pinned by `order_history_card_test.dart:46-67` |
| `Re-broadcast` | `Jeeb it again` (same pill) | `expired` folds into `cancelled` (`order_summary.dart:66-69`, pinned at `order_status_bucketing_test.dart:57`) and no re-broadcast endpoint exists |
| cancelled card at `opacity: .65` | full opacity | `.65` over 12/w600 periwinkle drops below AA; the kit's `dormant` doc forbids shipping use |
| `Active 1` unconditional | count only when `ready && !hasMore && orders.isNotEmpty` | a loaded-lower-bound count is a lie; a lazy tab has no number at all |
| `Jun 26 · Karim · …` as one string | date `Text` · Ø3 dot `Container` · status `Text` | `orders_stale_status_chip_test.dart` pins `find.text('Pending'/'Picked up'/'En route')` |
| pill scales 9/18, 8/14, 8/15 | kit `filter` / `quickReply` / `inlineAction` | the kit normalized all five pill scales once (R2) |
| board's live row shows no date | date **is** rendered on live rows too | one meta grammar for all four row states; the board's live row spends that slot on the ETA we do not have |

Dropped row content, per the board: the **dropoff address** and, on non-active rows, the **tier
chip**. Both remain on `/orders/:id`.

Two implementation notes worth the owner's eye:

- `_MetaRow` uses `Expanded(child: Row(...))` rather than the instruction set's literal
  `Spacer()`. A `Spacer` shares free space with the loose `Flexible` meta texts, so the trailing
  pill would stop short of the card's trailing edge instead of hugging it — visibly wrong against
  `tpl 1435`/`1445`. Same visual contract, correct flex arithmetic.
- The row `onTap` destination logic is byte-identical; it is now bound once as a local
  `openDetail()` closure inside `itemBuilder` so `onTrack` reuses the exact same expression
  (BUG-A stays single-sourced).

## Gates

| Gate | Result |
|---|---|
| `dart analyze lib/features/order_history test/features/order_history test/order_history_screen_test.dart` | **5 errors, all the pending l10n members**, zero other issues, zero warnings/infos |
| `bash tool/check_design_tokens.sh` | 6 pre-existing violations in `settlement` / `location` / `wallet` / `reviews`; **zero in `order_history`** |
| `grep -rn "identifier:" lib/features/order_history/` | every §1 value present, nothing renamed (see above) |
| `flutter test …` | **NOT RUN — blocked.** See below. |

### Why no test run

The feature does not compile without the 5 l10n members. The lane-11 precedent was to apply the
batch locally, run, then revert byte-for-byte — I deliberately did **not** do that here:
`git status` shows `lib/l10n/app_ar.arb` and `lib/l10n/app_localizations.dart` are **already dirty
with another lane's in-flight edits** (05-voice-recording keys). Snapshot-and-restore under a
concurrent writer would either clobber their work or silently re-add it after they revert. The
file-ownership rule wins over the convenience of a green run.

**Integrator: after landing the l10n batch, please run**

```
flutter test test/order_history_screen_test.dart test/features/order_history/ \
             test/core/theme/no_raw_semantic_colors_test.dart test/decision_violations_test.dart
```

The new assertions in both test files are written but **unexecuted**. The two I would check first
if anything is red:

1. `_pickDate`'s day-cell finder — I scoped it to `DatePickerDialog` because the redesigned tab
   pill now renders a bare count digit (`3` for that fixture) into the tree *behind* the
   non-opaque dialog route, and today's date is the 3rd. Unscoped, `find.text('3')` would have
   matched twice. This is a strengthening, not a weakening.
2. The nested-tap tests (`Track` / `Jeeb it again`): the pill's `InkWell` is a descendant of the
   kit card's `InkWell`, so the inner recognizer must win the gesture arena. If `Jeeb it again`
   lands on `/orders/c1` instead of `request-type`, that assumption is what broke.

## Maestro (not CI — silent rot risk)

`.maestro/jeeb/devices/RFCX306JSRT/flows/pages/_delivery-history.yaml` drives this screen **by
coordinates** (`50%,8%` filter chip; `17|50|83%,14%` tabs). The new title row pushes both bands
down (~14% / ~24%). The flow is screenshot-only, so a mis-tap produces wrong screenshots
silently. Re-verify on the S22 after landing — or better, convert the page object to `id:`
selectors: all four ids it needs are frozen and present.
