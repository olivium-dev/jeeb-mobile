# w4 — `delivery_status` onto the Jeeb design system

**Status: done.** `dart analyze lib/features/delivery_status` → *No issues found*.
`flutter test test/delivery_status_screen_test.dart test/delivery_status_cubit_test.dart
test/core/theme/no_raw_semantic_colors_test.dart` → **40 passed, 0 failed** (no new failures; no
test edited).

There is no render for this screen. The reference was **`12-live-tracking.png`**, the redesigned
surface next to it in the customer's journey.

---

## ⚠️ Read this first: the screen is a tagged ORPHAN

`delivery_status_screen.dart:28` carries `ORPHAN (JEBV4-227, verified 2026-07-12): dead parallel
re-implementation of tracking, zero external refs`. Verified again today: **no route in
`lib/core/router/app_router.dart` mounts `DeliveryStatusScreen`**; its only importers are
`lib/devtool/catalog/entries/batch_03_entries.dart` and `test/delivery_status_screen_test.dart`.
The live customer tracking surface is `live_tracking/` (screen 12), already redesigned.

It is **not** on the migration plan's never-touch list (§ HARD CONSTRAINT 10 names four other
files), so the work was done as briefed and the screen now matches its neighbour. But the parent
should know the visual payoff lands in the devtool catalog, not in the shipped app.

---

## What changed

### `presentation/delivery_status_screen.dart`
- `OMDSAppBar` → **`JeebTopBar.back`** mounted *inside* the body, above the `BlocConsumer`, so
  loading / error / ready all keep a way out (12's `_TrackingBackBar` rationale). New id
  `delivery_status_back` on the leading circle.
- The delivery-id line (`Delivery #d-1`) moved from a grey `bodySmall` run floating above the
  stepper into the **top bar's subtitle slot** — 12's `title` + meta-subtitle pattern.
- Body: `SingleChildScrollView` → `Column[Expanded(scroll), footer]`. Gutters are 24 (`Spacing
  .xLarge`, `EdgeInsetsDirectional`), block rhythm is a named `_kBlockRhythm = 28` citing
  `_ds/readme.md`.
- Action bar: two `OmdsPrimaryButton`s stacked at the end of the scroll → **`JeebCtaFooter.single`**
  docked at the foot, `JeebCtaButton.primary` (Contact, `leadingIcon: Icons.phone`) with
  `JeebCtaButton.outline` (Cancel) in the `below` slot. Same two actions, same order, same
  `canContactJeeber` / `canCancel` gating, same terminal-state collapse.
- `_ErrorView` padding 20 → 24 (the board gutter). `OmdsLoadingState` / `OmdsErrorState` kept — 12
  and `order_history` keep theirs too.

### `widgets/delivery_stage_indicator.dart`
- `OMDSLabeledStepperProgress` → **`JeebStepper`** (node form): Ø26 discs, orange active node,
  bounded reduce-motion-gated pulse. `currentIndex: -1` for a cancelled row reproduces the old
  `completedSteps: 0` (all nodes pending). Step ids coined `delivery_status_step_*` — deliberately
  **not** `tracking_step_*`, which live-tracking owns.
- The milestone list → **`JeebOutlinedCard.grouped` of `JeebListRow`s**. Row keys
  (`delivery-stage-row-<stage>`) and `listKey` unchanged.
- **Deleted the bespoke `_StageDot`** and its `AnimationController.repeat()`. The kit stepper is now
  the screen's single motion (the board asks for one, not a decorative loop per row); the active
  row instead takes the rationed accent on its glyph, mirroring the stepper's active node.

### `widgets/delivery_details_card.dart`
- `OMDSSectionCard` + three hand-rolled rows with peach `primaryContainer` icon discs →
  **`JeebSectionLabel` + `JeebOutlinedCard.grouped` + three `JeebListRow`s**.
- The address is the fact so it takes the row title; the field name is the qualifier and joins the
  subtitle with the optional second address line — `Hamra Main St` / `Pickup · Floor 3`. All three
  existing strings still render; nothing was added to the ARB.
- `location_on_outlined` → `location_on` (R10: filled glyphs).

### `widgets/delivery_jeeber_card.dart`
- `OMDSSectionCard` → `JeebSectionLabel` + **`JeebOutlinedCard`**; `OmdsProfileAvatar` →
  **`JeebAvatar`**; name in `cardTitle` navy; the peach `tertiaryContainer` rating chip folded into
  the single qualifier line (`4.8 ★ · Scooter`) via `MixedDirectionText` — the courier meta run 12
  draws. Waiting state kept, re-toned.

### `widgets/delivery_eta_badge.dart`
- Bespoke `primaryContainer` pill → **`JeebInfoNote.muted`** strip: navy filled `Icons.timer`, the
  `ETA` label, the minutes as a navy `cardTitle` trailing — structurally identical to 12's
  `Door code … 2144` row.

### `widgets/delivery_lifecycle_banner.dart`
- Hand-rolled container → **`JeebInfoNote.success` / `.error`**. The sprint-009 success/error tone
  split is preserved and now resolved by the kit off `jeebRoles`; the pinned
  `no_raw_semantic_colors_test` entry still passes.

---

## Refused / deliberately not done

| Idea the language invites | Why not |
|---|---|
| A map card like 12's | `DeliverySnapshot` carries no coordinates and there is no position feed on this gateway. Inventing one would be a fabricated contract. |
| Ø40 phone circle on the courier card (12 draws one) | Contact is this screen's docked CTA and has been since it shipped. Two emitters of one action, or moving it, is a flow change — out of scope for a re-skin. |
| Amber `starRatingColor` on the rating star | `deliveryJeeberRating` is `'{rating} ★'` — the glyph is baked into the ARB string, so colouring it alone needs an l10n split (a wiring request), not a fake. Left in the run's ink. |
| `JeebTierChip` on the tier row | `DeliveryTier` is a **vehicle** enum (bike/scooter/car/pickup), not the 5-tier urgency spectrum `JeebTier` models. `fromId` would mis-map every value. |
| Deleting the milestone list (the board has no such list) | It is the only place the reached-at timestamps render. Deleting it is a product decision, not a re-skin. |

No l10n keys added, no pubspec change, no shared file touched — **no wiring request needed**.

## Semantics

Preserved byte-identical: `delivery_status_root`, `delivery_status_contact_cta`,
`delivery_status_cancel_cta`. All `Key`s preserved (`delivery-status-screen`, `-scroll`,
`-loading`, `-error`, `-details`, `-jeeber-card`, `-eta-badge`, `-lifecycle-banner`,
`-stage-list`, `delivery-stage-row-*`, both CTA keys).
Added: `delivery_status_back`, `delivery_status_step_{matched,picked_up,in_transit,delivered}`.
Removed: `Key('delivery-status-active-dot')` — private to the deleted `_StageDot`, zero references
repo-wide (grepped `lib/`, `test/`, `integration_test/`).

## Verification

- `dart analyze lib/features/delivery_status` → No issues found.
- `dart analyze lib/devtool/catalog/entries/batch_03_entries.dart` (the only importer) → No issues.
- 40/40 tests green across the three suites that touch this feature.
- A throwaway 440×956 harness (since deleted) pumped six states — active LTR, active RTL, active at
  2× text scale, pre-match (no jeeber, no ETA), cancelled, completed — with zero overflow.
