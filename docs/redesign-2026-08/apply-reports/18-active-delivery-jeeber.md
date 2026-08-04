# 18 · Active delivery (Jeeber) — implementation report

Screen id: `18-active-delivery-jeeber` · Status: **applied**
Instruction set: `docs/redesign-2026-08/per-screen-revised/18-active-delivery-jeeber.md`
Branch: `feat/redesign-24-migration` (no commits, no branch changes)

---

## 1. What shipped

The screen is now the board's band stack, top to bottom:

1. **In-body top bar** — `JeebTopBar.back` (Ø40 tonal circle, 20px glyph, `h2` title), hoisted
   into `_buildScaffold`'s `Column` **above** the mode switch, so loading / error / ready /
   terminal all share one bar. `OMDSAppBar` is gone from both shells. `mark_delivered_back` is new.
2. **5-bar stepper** — `JeebStepper.bars` replaces `OmdsStepIndicator` + the stage-icon `Stack`.
   Five `flex:1` h5 segments (3 navy + accent + pending at AtDoor), the frozen
   `ValueKey('active_delivery_stage_<name>_<state>')`s re-homed onto the segments, and the existing
   `_StageLabel` row kept verbatim in structure — restyled only: current = `label` w800 accent,
   passed **and** upcoming = `label` in periwinkle (the board draws both the same; the state still
   lives in the Semantics label). `_StageIcon` and the `stepIcon` extension are deleted.
3. **Drop-off card** — `JeebOutlinedCard` (r16, 1.5px outline, no shadow, pad 14/16). Accent pin,
   `cardTitle` 1-line ellipsis, the muted collect line, and a Ø38 `surfaceContainerHigh` directions
   circle with a 48dp tap target (`MinTapTarget`). `OMDSSectionCard` and its "Drop-off address"
   heading are gone (the label survives as the card's Semantics label).
4. **One handoff card** — `JeebAccentFrameCard` (2px accent, r18, pad 16, no shadow) at AtDoor,
   `JeebOutlinedCard` at InTransit. Heading `Complete the handoff`, the h86 tile row, then either
   `mark_delivered_cta` or the door-code block. Orange is spent here and nowhere else (R5).
5. **h86 evidence tiles** (new `handoff_tiles.dart`) — proof photo (filled r12 cell, camera glyph,
   three states) + note (1.5px dashed r12 cell that opens an `OmdsTextField` below the row and
   latches open). The 180px photo placeholder and the always-open text field are gone.
6. **Door code** — `JeebCodeCells.input52` (h52 r12 cells, gap 9, 22/w800 digits, accent focus
   frame, LTR isolate) inside the unchanged `mark_delivered_otp_input` wrapper; the old
   title + instruction pair collapses to one prompt line.
7. **R1 spacer** — the cards scroll in an `Expanded(ListView)` between the pinned stepper and the
   docked footer; the bottom ~40 % stays white. No `Spacer()`, no centring.
8. **Docked 3-pill footer** — screen-local `_QuickActionFooter` of `JeebCtaButton.outline`
   (h50, r999, 16px glyph, 13.5/w600), pad `0/24/32`.

The cash line **re-homed** from its own primaryContainer slab onto the drop-off card, killing two
live copy defects on the way: the `?? ''` fabricated-empty amount and the
`receiptCashToJeeber(amount, party)` fallback that addressed the *address* as the payer.

## 2. Files

**Modified (3)**
- `lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart`
- `lib/features/active_delivery_jeeber/presentation/widgets/delivery_status_stepper.dart`
- `lib/features/active_delivery_jeeber/presentation/widgets/mark_delivered_panel.dart`

**Created (3 lib + 2 test + 1 wiring)**
- `lib/features/active_delivery_jeeber/presentation/widgets/handoff_tiles.dart`
- `lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_l10n.dart`
- `lib/features/active_delivery_jeeber/presentation/active_delivery_muted_ink.dart`
- `test/features/active_delivery_jeeber/handoff_tiles_test.dart`
- `test/features/active_delivery_jeeber/active_delivery_footer_test.dart`
- `docs/redesign-2026-08/wiring/18-active-delivery-jeeber.md`

**Tests edited (1)** — `delivery_status_stepper_test.dart`, exactly the two families §T3 allows:
`byType(OmdsStepIndicator)` → `byType(JeebStepper)` (both polarities) and the `_icons` map +
`find.byIcon` assertion deleted. Labels, identifiers, `'<Label>, <State>'`, the ValueKey family and
the whole advance-CTA block pass **unedited**.

**Untouched, as required:** `gps_permission_banner.dart`, the cubit / state / repository /
`JeeberDelivery`, `app_router.dart`, `injection_container.dart`, `lib/core/theme/*`,
`lib/core/widgets/jeeb/*`, `lib/l10n/*.arb`, `pubspec.yaml`, every other feature dir, the three
committed goldens, every Maestro flow.

## 3. Deliberate deviations from the instruction set

**D1 — two extra lib files (5 in the diff, not 3 + 1).** Both exist to satisfy a constraint the
instruction set could not satisfy on its own.

- `active_delivery_jeeber_l10n.dart` — the lane may not touch `lib/l10n/*`, and
  `AppLocalizations` is **hand-authored**, so "call the getter as if the key exists" would ship
  ten `undefined_getter` **errors**. `live_tracking/presentation/live_tracking_l10n.dart` is the
  shipped precedent for exactly this: a feature-local EN/AR resolver that every consumer reads
  through, so landing the ARB batch is a one-file swap with zero call-site changes. The ARB request
  is filed verbatim in the wiring file, plus an integrator note pointing at this file.
- `active_delivery_muted_ink.dart` — §C6 prescribed
  `Theme.of(context).extension<JeebSemanticColors>()!.mutedText`. That bare `!` **crashed six of
  this feature's own tests** on the first run (`push_landing`, `error_snackbar`, `lifecycle`…),
  because they pump a plain `MaterialApp` with no `AppTheme.light()`. `JeebTopBar` already reads
  the extension defensively for this reason (`jeeb_top_bar.dart:558`). One shared helper, one
  fallback, four call sites.

**D2 — `JeebCodeCells.input52` takes `cellIdentifier`, not `identifier`.** §T7 wrote
`identifier: 'mark_delivered_otp_input'`, but as shipped the kit's `identifier` is the *row*
wrapper (which the panel already owns at `:164`) and `cellIdentifier` is the base for the frozen
`_0.._3` editable leaves. Passing `identifier` would have emitted the id twice and dropped the
per-cell ids — the RC-7 failure the request was written to prevent. Recorded in the wiring file.

**D3 — tile labels use `jeebText.caption` (11.5/w600), not `label` (10.5/w700).** The board's tile
labels are 11.5 (`tpl 1072/1075`); `caption` is the exact rung, `label` is the stepper's 10.5.
§T6's `label` contradicts §1's own "measured from the HTML".

**D4 — the note `Semantics` wraps the whole tile row + editor.** §T6 asked for the id to span "the
WHOLE cell + expanded editor" while the editor "renders below the row". Those only reconcile if the
node spans the row, so it does, with `explicitChildNodes: true` keeping
`mark_delivered_proof_photo` a separately addressable child. Verified in
`handoff_tiles_test.dart`: the id is emitted collapsed **and** expanded, and the proof tile is
still findable.

**D5 — `OmdsLoadingState(size: Sizes.xLarge, padding: EdgeInsets.zero)` in the uploading tile.**
The default is a Ø48 spinner in 20pt padding = 88 tall, which overflowed the h86 tile (caught by
the new test, not by review).

**D6 — the stepper's trailing `SizedBox(Spacing.large)` is now inside the `showAdvance` block.**
It used to render unconditionally, which at InTransit/AtDoor left 20pt of dead air between the bars
and the drop-off card on top of the board's 16. `_AdvanceButton` itself is untouched (C1).

**D7 — `JeebCtaButton.primary` replaces `OmdsLoadingButton` for `mark_delivered_cta` and
`mark_delivered_otp_submit`** (h54, `JeebShadows.ctaNavy` — the board's `0 10 24 rgba(11,19,81,.28)`).
§C6 allowed keeping `OmdsLoadingButton` only *if* the kit shipped without `isLoading`/`isEnabled`;
it ships with both. The Semantics wrappers around them are byte-identical. The advance CTA keeps
`OmdsLoadingButton` (C1).

**Stated, unchanged divergences:** the drop-off pin renders `jeebRoles.accent` red-orange, not the
board's raw `#E02020` (no token carries it); the OTP caret is the platform's, tinted accent; the
footer's bottom inset is 32, not 30.

## 4. Semantics ledger

Every row of §3 holds. Unchanged: `mark_delivered_root` (both shells, same node position and
`explicitChildNodes` polarity), `delivery_completed_state`, the three unsuccessful-terminal ids,
all five `active_delivery_stage_*`, `mark_delivered_advance_cta`, the two GPS-banner ids,
`mark_delivered_otp_input` (+ `_0.._3` from OMDS), `mark_delivered_otp_submit`,
`mark_delivered_proof_photo`, `mark_delivered_note_field`, `mark_delivered_cash_note` (still
emitted at InTransit for Maestro jm-051), `mark_delivered_cta`, the three footer pill ids with
goods-cost still conditional. Frozen keys intact: the stage ValueKeys (re-homed to the bar
segments), `Key('markDelivered.otpInput')`, `Key('markDelivered.otpSubmit')`,
`GpsPermissionBanner.bannerKey`, `ValueKey<String>(_identifier)` on the terminal `OmdsEmptyState`.
New: `mark_delivered_back`, `mark_delivered_directions_cta`, `mark_delivered_note_tile`.

## 5. Gates

- `dart analyze lib/features/active_delivery_jeeber test/features/active_delivery_jeeber` →
  **No issues found.**
- `bash tool/check_design_tokens.sh` → 6 violations, **all pre-existing and all outside this
  feature** (`settlement/`, `location/`, `wallet/`, `reviews/`). Zero in
  `active_delivery_jeeber/`.
- `flutter test test/features/active_delivery_jeeber/` → **all green except the three committed
  goldens** (pixel diff 18.0 % / 16.6 % / 24.3 %, no exceptions, no overflow). Expected: they
  regenerate once in the Wave-5 sweep. Not regenerated, not deleted, not skipped, per §T12.
- The 13 new tests pass: proof tile none/uploading/captured, note collapsed ↔ expanded with the id
  emitted in both, the editor's callback + latch, AR tile copy, three pills in one row at 390pt/1.0,
  stacked at 2.0, the Costs pill absent when unwired, both collect-line variants, the RTL mirror of
  the directions circle, and the LTR isolate on the code cells under `ar`.
- Final combined run (`active_delivery_jeeber/` + `background_location_permission_test`):
  **62 passed / 3 failed**, the three failures being the goldens. One earlier combined run flagged
  `push_landing`'s JEBV4-276 case; it passes in isolation and on every re-run of the same command —
  a runner flake, not a regression.
- Must-pass-unedited set verified green: `active_delivery_push_landing_test`,
  `active_delivery_error_snackbar_test`, `active_delivery_lifecycle_test`,
  `active_delivery_gps_upload_test`, `active_delivery_push_driven_test`,
  `active_delivery_cubit_test`, and the advance-CTA block of the stepper test.

## 6. Left open

- The board's collect line splits the fee from the goods cost (`$8 + $6.50 goods`).
  `JeeberDelivery` carries `amountText` only and no gateway field exposes the goods cost here — a
  marked `TODO(redesign-24)` sits on the line. Omitted, not faked.
- `activeDeliveryProgressTitle`, `activeDeliveryOtpTitle`, `activeDeliveryOtpInstruction` and
  `activeDeliveryStatusDone`-as-a-heading lose their consumers here. The keys stay in the ARBs
  (`activeDeliveryStatusDone` is still the stepper's Done label); deletion of the orphans is the
  integrator's call.
- The "Costs" pill stays conditional on `onEnterGoodsCost`, which `app_router.dart` never passes —
  `GoodsCostScreen` is a verified orphan with a broken endpoint (JEBV4-227). Owner-decision note
  filed in the wiring file; **not** a route request.
