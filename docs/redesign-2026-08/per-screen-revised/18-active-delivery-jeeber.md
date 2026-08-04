# 18 · Active delivery — Jeeber — REVISED instruction set (authoritative)

Screen id: `18-active-delivery-jeeber` · Wave 4 (owns 3 committed goldens — regenerate Wave 5 only)
Design: `screens/18-active-delivery-jeeber.{png,html,note.md}` — the PNG is the **AtDoor + otpRequired** frame.
Feature dir (the ONLY writable code surface): `lib/features/active_delivery_jeeber/`
plus this screen's tests under `test/features/active_delivery_jeeber/` and the wiring file
`docs/redesign-2026-08/wiring/18-active-delivery-jeeber.md`.

Verdict: **rebuild** — shell becomes Column + docked footer, stepper changes form (icon circles →
flat bars), the at-door panel is recomposed into one accent-framed card, proof/note become an h86
tile row, the cash note re-homes onto the drop-off card.

Every `file:line` below was re-verified against the tree on 2026-08-03. Where this document
disagrees with `per-screen/18-active-delivery-jeeber.md`, **this document wins**.

---

## 0. Corrections to the original proposal (verified, binding)

### C1 — The `mark_delivered_advance_cta` move is REFUSED. It stays in the stepper widget.

The proposal moved the advance CTA out of `delivery_status_stepper.dart` into the action panel
while simultaneously demanding (its §8.2) that `delivery_status_stepper_test.dart`'s advance-CTA
block "keep passing verbatim". Those are mutually exclusive: the test pumps **only**
`DeliveryStatusStepper` (`delivery_status_stepper_test.dart:42-46`) and asserts
`mark_delivered_advance_cta` findsOneWidget at ordered/picked, asserts the "Mark as Picked" /
"Mark as In Transit" labels, and taps it (`:81-95`). Move the CTA out and that test fails.
By the proposal's own criterion, the proposal is wrong.

Resolution: `_AdvanceButton` (`delivery_status_stepper.dart:213-259`) is **untouched** —
identifier, label switch, `OmdsLoadingButton`, callback, `showAdvance` gating all stay exactly as
shipped. The board renders only the AtDoor frame, where `showAdvance` is false anyway; the
ordered/picked frames are not on the board, so nothing in the design demands relocating this
button. The only change it sees is losing the `OMDSSectionCard` wrapper around its parent.
Consequence: the proposal's "ordered/picked action card with heading `activeDeliveryProgressTitle`"
is **cut** (invented, zero design evidence), `MarkDeliveredPanel` keeps rendering only at
inTransit/atDoor (`screen.dart:340-342` untouched), and the stepper test needs exactly two edit
families (§6.2) — nothing in the advance block.

### C2 — Kit edits are wiring requests, not lane edits; the bars variant sheds its label API.

`lib/core/widgets/jeeb/` is a shared surface (it does not exist yet — the kit lane builds it).
This lane may not create or edit files there. All three §5 corrections (JeebStepper `bars`,
JeebCodeCells wrapping `OmdsOtpInput`, the keypad consumer-list fix) become cross-feature requests
in the wiring file (§8), and the screen code is written as if granted.

Additionally the `bars` API shrinks: **labels stay feature-side.** `_StageLabel`
(`stepper.dart:159-211`) already owns the frozen `active_delivery_stage_<name>` identifiers, the
`'<Label>, <State>'` Semantics labels, and the `find.text(...)` targets — keep that Row and only
restyle its inks. The kit needs just `JeebStepper.bars({stepCount, currentIndex, segmentKeys})`.
This removes the proposal's `labels`/`semanticsLabels` params (which would have needed a fourth,
unproposed `identifiers` param to keep the test passing — a hole in the original spec).

### C3 — The "Sizes has the needed rungs" claim is FALSE; and the token gate was over-claimed.

Verified `Spacing`/`Sizes` rungs (omds `lib/src/tokens/spacing.dart`): there is **no 86, no 22,
no 18**. Nearest rungs: 88 (`nineXLarge`), 24 (`xLarge`), 20 (`large`). Also verified
`tool/check_design_tokens.sh`: it forbids `Color(0x…)`, `Colors.*`, bare
`SizedBox(width|height: N)`, `EdgeInsets.<m>(N…`, `BorderRadius.circular(N)`, `fontSize: N`, and
raw Material widgets — it does **not** scan `Icon(size:)`, `Container(height:)`, or
`BoxConstraints`. Resolution for `handoff_tiles.dart`: tile height and glyph sizes are file-level
named consts with a one-line why comment (`const double _kTileHeight = 86; // design tpl 1069`),
radius is `OmdsBorderRadius.small`, gaps/padding use `Spacing` tokens. That passes the gate as
written and keeps design-exact px greppable. No `SizedBox(height: 86)` single-arg form anywhere.

### C4 — The OmdsOtpInput wrap lives inside the kit's `JeebCodeCells.input52`, not in the panel.

Verified `omds_otp_input.dart`: params `length, boxWidth, boxHeight, spacing, autoFocus, fillColor,
focusedBorderColor, errorBorderColor, hasError, textStyle, identifier` all exist (`:22-36`);
per-cell ids `<base>_0.._3` are emitted at `:289-296`; cell radius is already
`OmdsBorderRadius.small` (12 — the design value); resting border is `tokens.inputBorderColor`.
The proposal's snippet (boxHeight 52, spacing 9, `LayoutBuilder` flex emulation, fill
`surfaceContainerHigh`, focused border accent, 22/w800 digit style, resting-border kill via
`OmdsColorTokensProvider(copyWith(inputBorderColor: …))`, caret tint via
`TextSelectionTheme(cursorColor: accent)`, LTR isolate) is correct **but belongs inside the kit
widget** — raw `fontSize: 22` in `mark_delivered_panel.dart` fails the token gate. The panel
consumes `JeebCodeCells.input52` and passes only behavior: `key`, `identifier`, `hasError`,
`onChanged`, `onCompleted`. Note `context.jeebText.codeInput` is 29/w800 (sized for 03's h74
cells) — the kit carries a local 22/w800 const for `input52`, it does not reuse `codeInput`.

### C5 — The top bar must survive loading / error / terminal modes.

The proposal deletes `appBar: OMDSAppBar(...)` but leaves `_buildBody`'s loading
(`Center(OmdsLoadingState)`) and error (`OmdsErrorState`) returns bare — those modes would render
with no title and no back affordance. Resolution: `JeebTopBar` is hoisted into `_buildScaffold`'s
Column, **above** the mode switch, so all four modes (loading / error / ready / terminal) share
one bar. `_ReadyContent` then starts at the stepper.

### C6 — Smaller verified fixes to the proposal

- `JeebShadows.focusRing` already exists at spreadRadius 3 (`jeeb_shadows.dart:119-124`) but its
  color is periwinkle @.35, not accent @.18 — so the proposal's "kit-local const for the bar glow"
  stands (confirmed necessary, not just preferred).
- FSI/PDI wrapping of `amountText` is **dropped** — invisible control chars in a Semantics-visible
  string for a problem the Wave-5 AR golden review will catch anyway. The `{amount}` placeholder
  goes through the ARB, which handles bidi placement.
- `JeebSemanticColors` has no static accessor — spell it
  `Theme.of(context).extension<JeebSemanticColors>()!.mutedText` (verified: no `context.jeebSemantic`
  sugar exists; `context.jeebText` / `context.jeebRoles` do exist).
- `activeDeliveryOtpSubmit` value change verified safe: single consumer `panel.dart:191`, no test
  or Maestro flow pins "Complete Delivery". Value change (not append) is finalized in §8.
- `activeDeliveryOtpTitle` / `activeDeliveryOtpInstruction` become unused after the prompt swap —
  **leave the keys in the ARBs** (parity gate cares about EN/AR parity, not orphans; deletion is
  the integrator's call).
- The footer form: build a **screen-local `_QuickActionFooter`** in the screen file. No
  `JeebCtaFooter.actionRow` kit request — this row shape exists on 18 only; a kit variant for one
  consumer is scope creep. Metrics come from `JeebCtaButton.outline` + `Spacing` tokens.
- If `JeebCtaButton` ships without `isLoading`/`enabled` support by Wave 4, keep the existing
  `OmdsLoadingButton`s inside their (unchanged) Semantics wrappers for `mark_delivered_cta`,
  `mark_delivered_otp_submit`, and the advance CTA — the redesign of those three is the card
  around them, not the button widget. State this in the PR notes if taken.

### Verified-and-upheld refusals (unchanged from the proposal)

- **5 bars, not 4** — `jeeberDeliveryProgressStages` is five stages; `active_delivery_stage_done`
  + its ValueKeys + the 'Done' label text are frozen by `delivery_status_stepper_test.dart:53-79`
  and `push_landing_test` (~`:203`). Render five `flex:1` bars; at AtDoor that is 3 navy + 1 accent
  + 1 pending.
- **No `JeebNumericKeypad` on 18** — the render's lower ~40% is empty; only the 3-pill footer sits
  below. Plan §5 #13's consumer list "03 18" is wrong (correction filed in §8).
- **Two-phase OTP gate kept** — `push_landing_test` (verified: `mark_delivered_cta` findsOneWidget
  at AtDoor, findsNothing after tap, `delivery_completed_state` never) forbids auto-raising
  `otpRequired`. The design's unification is achieved by putting both phases inside the same
  `JeebAccentFrameCard`. Cubit/state/repo/domain files: **zero edits**.
- **No goods-cost split in the collect line** — `JeeberDelivery` carries `amountText` only
  (verified `jeeber_delivery.dart`); no goods-cost field, no gateway read. Render
  `Collect {amount} cash on delivery` + the NoAmount degraded variant; leave
  `// TODO(redesign-24): gateway goods-cost missing from the delivery snapshot — omitted, not faked.`
- **"Costs" pill stays conditional, no route** — `GoodsCostScreen` is a verified ORPHAN
  (`goods_cost_screen.dart:25`, JEBV4-227, broken endpoint) and `app_router.dart:1482-1529` never
  passes `onEnterGoodsCost` (verified). Production shows two pills; the design's third renders
  wherever a caller wires the callback. Owner-decision note filed in §8 — NOT a route request.
- **Destination pin ink = `context.jeebRoles.accent`** — raw `Color(0xFFE02020)` fails the token
  gate; `colorScheme.error` is semantically wrong. Stated divergence: pin renders red-orange.
- **No conflict with `decision_violations_test.dart`** — verified: zero references to this feature.

---

## 1. The design contract (measured from the HTML, corrected)

| Block | Spec | Build with |
|---|---|---|
| Top bar | in-body row pad 14/24/0, Ø40 circle + 20px back glyph, title 20/w700 | `JeebTopBar` (kit #1), `identifier: 'mark_delivered_back'` |
| Stepper | 5 `flex:1` bars h5 r9 gap 6; passed navy, active accent + `0 0 0 3` accent@.18 ring, pending `surfaceContainerHighest`; label row beneath | `JeebStepper.bars` (kit, §8 request) + existing `_StageLabel` row restyled |
| Drop-off card | pad 14/16, r16, 1.5px outline, no shadow, no section title; pin 20px accent; title `cardTitle` 1-line ellipsis; collect line muted; trailing Ø38 `surfaceContainerHigh` circle, 17px navy directions glyph | `JeebOutlinedCard` (kit #3) |
| Handoff panel | 2px accent frame, r18, pad 16, **no shadow**; heading 15.5/w700; h86 tile row; prompt line; 4 code cells h52 r12; navy pill CTA h54 | `JeebAccentFrameCard` (kit #5) at atDoor, `JeebOutlinedCard` at inTransit; `JeebCodeCells.input52` (kit #12) |
| Spacer | `flex:1` — bottom ~40% stays white | `Expanded(child: ListView(...))`, content top-aligned. Never `Spacer()` between cards, never centre |
| Footer | 3 equal outline pills h50 r999, 16px navy glyph + 13.5/w600 label, pad 0/24/30→**32** (02-PLAN-ENHANCED §3.2, verified: "pick 32 and note the divergence") | screen-local `_QuickActionFooter` of `JeebCtaButton.outline` |

Not built: 440×956 frame chrome, `9:41` row, the keypad that isn't there.

---

## 2. Task list — execute top to bottom

**T1 — Write the wiring file.** Create `docs/redesign-2026-08/wiring/18-active-delivery-jeeber.md`
with exactly the content in §8. Do this first — l10n and kit requests have integrator lead time.
From here on, code as if every request is granted.

**T2 — `delivery_status_stepper.dart`: bars form.**
- In `_DeliveryProgress` (`:56-131`): delete the `Stack` + `OmdsStepIndicator` + the
  `ExcludeSemantics(Row(_StageIcon…))` block. Replace with
  `JeebStepper.bars(stepCount: jeeberDeliveryProgressStages.length, currentIndex: currentIndex,
  segmentKeys: [...])` where the keys reproduce today's exact strings:
  `ValueKey<String>('active_delivery_stage_${status.name.toLowerCase()}_${_stateAt(index, currentIndex).name}')`.
  Keep `_stateAt` and the `_DeliveryStageState` enum.
- Keep the label `Row` of `Expanded(_StageLabel(...))` verbatim in structure and semantics
  (identifier `active_delivery_stage_<name>`, label `'<Label>, <State>'`, `ExcludeSemantics` text).
  Restyle `_textStyle` only: current → `context.jeebText.label.copyWith(fontWeight: FontWeight.w800)`
  ink `context.jeebRoles.accent`; completed and upcoming → `context.jeebText.label` ink
  `Theme.of(context).extension<JeebSemanticColors>()!.mutedText` (the render draws passed and
  upcoming labels in the same periwinkle; a11y state lives in the Semantics label).
- Delete `_StageIcon` (`:135-157`) and the `stepIcon` extension getter (`:261-279`), keeping
  `statusLabel`.
- **Do not touch `_AdvanceButton` (`:213-259`)** — C1.

**T3 — Stepper test edits (`delivery_status_stepper_test.dart`), exactly two families:**
- `:52` and `:123`: `find.byType(OmdsStepIndicator)` → `find.byType(JeebStepper)` (same
  findsOneWidget / findsNothing polarity; adjust import).
- `:69` `find.byIcon(_icons[stage]!)` and the `_icons` map `:18-24`: delete.
- Everything else — labels, identifiers, `'<Label>, <State>'`, ValueKeys, the whole advance-CTA
  block `:81-95` — must pass **without edits**. If it doesn't, your T2 diff is wrong; fix the code,
  not the test.

**T4 — Screen shell (`active_delivery_jeeber_screen.dart`).**
- `_buildScaffold` (`:223-235`): delete `appBar: OMDSAppBar(...)`. New shape:
  `Scaffold(body: SafeArea(child: Semantics(identifier: 'mark_delivered_root',
  explicitChildNodes: true, child: Column(children: [JeebTopBar(title: l10n.activeDeliveryTitle,
  identifier: 'mark_delivered_back', onBack: () => Navigator.of(context).maybePop()),
  Expanded(child: _buildBody(context, state, l10n))]))))` — the bar survives loading/error/terminal
  (C5). `mark_delivered_root` node position and `explicitChildNodes` unchanged.
- `_Unavailable` (`:138-154`): same shell; its `mark_delivered_root` Semantics stays as-is (no
  `explicitChildNodes` there today — don't add one).
- `_ReadyContent.build` (`:329-413`): `ListView` → `Column(children: [DeliveryStatusStepper(...)
  (pinned, pad STEB(xLarge, medium, xLarge, 0) via the widget's placement),
  Expanded(child: ListView(padding: EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.medium,
  Spacing.xLarge, Spacing.medium), children: [gps banner (first, unchanged), completed panel,
  address card, mark-delivered panel])), _QuickActionFooter(...)])`.
  The unsuccessful-terminal short-circuit (`:331-333`) stays first and unchanged — terminals get
  top bar + `_UnsuccessfulTerminalContent`, no stepper, no footer (as today).
- Delete both `OMDSSectionCard` wrappers: the "Delivery progress" card `:374-382` (the stepper is
  bare under the bar; `activeDeliveryProgressTitle` key simply stops being consumed here — leave
  the key) and `_AddressCard`'s (T5).

**T5 — `_AddressCard` rebuild (`:522-568`).**
`JeebOutlinedCard` (r16, 1.5px `colorScheme.outline`, no shadow, pad 14/16), Semantics label
`l10n.activeDeliveryDropOffLabel` on the card. Row(gap `Spacing.small`):
1. `Icons.location_on` (filled), size `Sizes.large` (20), ink `context.jeebRoles.accent`.
2. Expanded Column: `delivery.dropOff.label` in `context.jeebText.cardTitle`, `maxLines: 1`,
   `TextOverflow.ellipsis`; then the collect line — `Semantics(identifier:
   'mark_delivered_cash_note', child: Text(line))` in `context.jeebText.bodySmall` ink
   `…extension<JeebSemanticColors>()!.mutedText`, `maxLines: 2`, ellipsis:
   ```dart
   final amount = delivery.amountText;
   final cash = amount == null || amount.isEmpty
       ? l10n.activeDeliveryCollectCashNoAmount
       : l10n.activeDeliveryCollectCash(amount);
   final detail = delivery.dropOff.detail;
   final line = detail == null ? cash : '$detail · $cash';
   ```
   This kills the two live copy defects at `panel.dart:328-329` (`?? ''` fabricated-empty amount;
   "Pay $8 cash to Drop-off address" party fallback). Do not re-introduce them.
3. Trailing Ø38 circle (`OmdsBorderRadius.pill`, `colorScheme.surfaceContainerHigh`), 17px→
   `Sizes.medium` (16) navy `Icons.directions`, tap = `onOpenMaps` (new param threaded from
   `_ReadyContent`, which already has it), wrapped
   `Semantics(identifier: 'mark_delivered_directions_cta', button: true,
   label: l10n.activeDeliveryDirectionsCta)`. Give the tap target a ≥48dp hit area (padding around
   the circle), keep the visual Ø38.

**T6 — `handoff_tiles.dart` (new, `presentation/widgets/`).** Screen-local; named consts per C3.
Row(gap 10 → `Spacing.small` is 12, accept) of two Expanded h86 tiles, r12 `OmdsBorderRadius.small`:
- **Proof tile** — the `Semantics` wrapper from `panel.dart:230-236` moves here **verbatim**
  (`identifier: 'mark_delivered_proof_photo'`, `button: true`, `image: true`,
  `label: l10n.receiptProofPhotoLabel`, `enabled: !uploading`, `onTap`). States: none →
  `surfaceContainerHigh` fill + navy `Icons.photo_camera` (`Sizes.xLarge`) + label
  `l10n.activeDeliveryProofPhotoTile` in `context.jeebText.label` navy; uploading →
  `OmdsLoadingState` in place of the glyph; captured → `Image.memory(bytes)` /
  `OmdsCachedImage(url)` `BoxFit.cover` behind the r12 clip + a small `Icons.check` beside the
  label. The thumbnail survives (JEBV4-200) even though the board doesn't draw the captured state.
  The 180px placeholder dies.
- **Note tile** — outer `Semantics(identifier: 'mark_delivered_note_field', container: true,
  explicitChildNodes: true)` wraps the WHOLE cell + expanded editor, so the id is emitted collapsed
  or expanded. Collapsed: 1.5px dashed `colorScheme.outline` via a small `CustomPainter` (no dep),
  `Icons.notes` (`Sizes.large`) + `l10n.offerSubmissionNoteLabel` (already exactly
  "Note (optional)" — verified, no new key) in muted ink; the tap target carries new
  `Semantics(identifier: 'mark_delivered_note_tile', button: true)`. Expanded (StatefulWidget,
  stays expanded once opened): tile flips to `surfaceContainerHigh` fill and an
  `OmdsTextField(maxLines: 3, maxLength: 280, onChanged: onNoteChanged)` renders below the row
  inside the same node. Callback and limits unchanged from `panel.dart:303-309`.

**T7 — `mark_delivered_panel.dart` recomposition.**
- Delete the panel title `Text(l10n.activeDeliveryStatusDone)` `:77-80` (a "Done"-as-heading copy
  bug; the key itself stays — the stepper labels consume it).
- One card, stage-driven: `JeebOutlinedCard` at inTransit, `JeebAccentFrameCard` (2px accent, r18,
  pad 16, no shadow) at atDoor — orange only at the door (R5). Contents in both: heading
  `l10n.activeDeliveryHandoffTitle` in `context.jeebText.cardTitle`; the T6 tile row; then either
  `_MarkDeliveredCta` (unchanged Semantics `:378-391`) or, when `otpRequired`, the door-code block.
- `_DoorOtpEntry`: delete title+instruction `:152-162`; replace with the single prompt
  `l10n.activeDeliveryDoorCodePrompt` in `context.jeebText.bodySmall` muted. The input becomes
  `JeebCodeCells.input52(key: const Key('markDelivered.otpInput'), identifier:
  'mark_delivered_otp_input', hasError: hasError, onChanged: …, onCompleted: (_) => _submit())` —
  behavior identical (auto-verify on 4th digit already ships at `:173`). Keep the outer
  `Semantics(identifier: 'mark_delivered_otp_input', container: true)` wrapper `:164-166`. Error
  text: `context.jeebText.caption` + `colorScheme.error`. Submit pill keeps
  `Key('markDelivered.otpSubmit')`, `identifier 'mark_delivered_otp_submit'`, `isEnabled`
  `_code.length == 4 && !isVerifying`, text `l10n.activeDeliveryOtpSubmit` (value now
  "Verify code & complete" via §8).
- Delete `_ProofPhoto` (`:204-288`), `_NoteField` (`:291-312`), `_CashNote` (`:315-358`) — replaced
  by T6 and T5. Confirm `receiptCashToJeeber` keeps its other consumer
  (`delivery_receipt_screen.dart:202`) — do not touch that file.

**T8 — Footer (`screen.dart:570-704`).** Replace `_ActionButtons`/`_QuickActions`/
`_GoodsCostAction` with `_QuickActionFooter`: padding
`EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, 0, Spacing.xLarge, Spacing.twoXLarge)` (32 — noted
divergence from the HTML's 30), Row of Expanded `JeebCtaButton.outline` pills (h50, r999, 1.5px
outline, 16px navy glyph, label 13.5/w600 via the kit):
- `mark_delivered_open_maps_cta` — `Icons.map`, text `l10n.activeDeliveryQuickActionMaps`,
  Semantics label `l10n.activeDeliveryOpenMapsButton`;
- `mark_delivered_open_chat_cta` — `Icons.chat`, text `l10n.activeDeliveryQuickActionChat`,
  Semantics label `l10n.activeDeliveryOpenChatButton`;
- `mark_delivered_goods_cost_cta` — `Icons.receipt_long`, text
  `l10n.activeDeliveryQuickActionCosts`, Semantics label
  `l10n.activeDeliveryEnterGoodsCostButton`, **rendered only when `onEnterGoodsCost != null`**
  (exactly today's condition, `screen.dart:697`).
Keep each pill's `Semantics(identifier: …, container: true, button: true)` wrapper (`:586-590`
idiom) around the new button. Keep the `LayoutBuilder` stacking guard: retune
`_kInlineQuickActionsMinWidth` (`:20`) 448 → **320** (at 448 the row is unreachable on every
phone), and keep the `MediaQuery.textScalerOf(...)` half **verbatim** — it is what makes the 200%
golden stack the pills.

**T9 — `_CompletedPanel` token pass (`:481-520`), three lines:** `primaryContainer` →
`context.jeebRoles.successContainer`, `onPrimaryContainer` → `onSuccessContainer` (both verified
present on `JeebColorRoles`), title → `context.jeebText.cardTitle`. Identifier
`delivery_completed_state`, label, icon: unchanged. Nothing else — it is not on the board.

**T10 — Token sweep of what remains.** No `Color(0x…)`, no `Colors.*`, no `fontSize:`, no
`BorderRadius.circular(N)`, no `EdgeInsets.<m>(N` in the three feature files + the new one. All
paddings `EdgeInsetsDirectional` where asymmetric. `GpsPermissionBanner`: **zero edits** — its
copy/CTA branch is pinned by `background_location_permission_test.dart` and
`gps_permission_banner.dart:163` is a named pre-existing baseline analyze error.

**T11 — New tests (additive only), `test/features/active_delivery_jeeber/`:**
- `handoff_tiles_test.dart`: proof none/uploading/captured; note collapsed ↔ expanded with
  `mark_delivered_note_field` emitted in both; `mark_delivered_note_tile` tappable.
- Footer: 3 pills in a Row at 390pt/1.0 when `onEnterGoodsCost` passed, stacked at 2.0 scale,
  third pill absent when null.
- RTL smoke (`ar`): drop-off trailing circle at the start edge; code cells render LTR (through the
  kit's Directionality isolate).

**T12 — Gates.** `flutter analyze` (bar: no NEW issues over the 11/6 baseline),
`bash tool/check_design_tokens.sh`, `flutter test test/features/active_delivery_jeeber/`.
Goldens ×3 WILL fail locally — that is expected; they regenerate once, on the Mac Studio, in the
Wave-5 sweep. Do not regenerate them in this lane, do not delete them, do not mark them skipped.

---

## 3. Semantics freeze — every row must hold after the diff

| Identifier | Where it lands |
|---|---|
| `mark_delivered_root` | both shells, same node position (T4) |
| `delivery_completed_state`, `delivery_cancelled_state`, `delivery_expired_state`, `delivery_disputed_state` | unchanged |
| `active_delivery_stage_ordered/_picked/_intransit/_atdoor/_done` | the label row — all five (T2) |
| `mark_delivered_advance_cta` | stays in `DeliveryStatusStepper` (C1) |
| `active_delivery_gps_permission_banner`, `active_delivery_gps_permission_cta` | untouched |
| `mark_delivered_otp_input` (+ `_0.._3` via the kit's OmdsOtpInput), `mark_delivered_otp_submit` | code block in the accent card (T7) |
| `mark_delivered_proof_photo`, `mark_delivered_note_field` | the h86 tiles (T6) |
| `mark_delivered_cash_note` | the drop-off collect line (T5) — still emitted at InTransit for Maestro jm-051 (verified: the flow asserts it on a seeded InTransit delivery) |
| `mark_delivered_cta` | inTransit / atDoor-pre-code pill, unchanged Semantics |
| `mark_delivered_open_maps_cta`, `mark_delivered_open_chat_cta`, `mark_delivered_goods_cost_cta` | footer pills, goods-cost still conditional |
| NEW: `mark_delivered_back`, `mark_delivered_directions_cta`, `mark_delivered_note_tile` | T4 / T5 / T6 |

Frozen keys: `ValueKey('active_delivery_stage_<name>_<state>')` (re-homed to bar segments),
`Key('markDelivered.otpInput')`, `Key('markDelivered.otpSubmit')`, `GpsPermissionBanner.bannerKey`,
`ValueKey<String>(_identifier)` on the terminal `OmdsEmptyState`.

## 4. Test contract

Must pass **unedited**: `active_delivery_push_landing_test.dart` (the OTP two-phase guard),
`active_delivery_error_snackbar_test.dart`, `background_location_permission_test.dart` §4,
`active_delivery_lifecycle_test.dart`, `active_delivery_gps_upload_test.dart`,
`active_delivery_push_driven_test.dart`, `active_delivery_cubit_test.dart`, Maestro
`jm-051-mark-delivered.yaml`, and the advance-CTA block of the stepper test.
Legitimate edits: the two stepper-test families in T3, nothing else. Goldens: Wave 5.

## 5. Stop conditions

**Done means:** T1–T12 complete; the three feature dart files + `handoff_tiles.dart` are the whole
code diff; every §3 row holds; T12 gates green except the three goldens; wiring file written.

**Must NOT touch:** `app_router.dart`, `injection_container.dart`, `lib/core/theme/*`,
`lib/l10n/*.arb`, `pubspec.yaml`, `lib/core/widgets/jeeb/*` (requests only), any other feature dir
(including `goods_cost/` and `delivery_receipt/`), `gps_permission_banner.dart`,
`ActiveDeliveryCubit`/state/repository/`JeeberDelivery`, the committed goldens, any Maestro flow,
and the 6 pre-existing baseline analyze errors.

---

## 8. Wiring file — write EXACTLY this to `docs/redesign-2026-08/wiring/18-active-delivery-jeeber.md`

````markdown
# Wiring requests — 18 Active delivery (Jeeber)

### l10n
file: lib/l10n/app_en.arb (+ app_ar.arb — AR values below are drafts for reviewer sign-off)
need: nine new keys for the redesigned handoff surface, plus one value change.
exact change:
```json
"activeDeliveryHandoffTitle": "Complete the handoff",
"@activeDeliveryHandoffTitle": { "description": "Heading of the 18 handoff action card (inTransit + atDoor)." },
"activeDeliveryProofPhotoTile": "Proof photo",
"@activeDeliveryProofPhotoTile": { "description": "Label on the h86 proof-photo tile; the check is an icon, not text." },
"activeDeliveryDoorCodePrompt": "Ask the customer for their 4-digit door code:",
"@activeDeliveryDoorCodePrompt": { "description": "Single prompt line above the door-code cells; replaces title+instruction." },
"activeDeliveryCollectCash": "Collect {amount} cash on delivery",
"@activeDeliveryCollectCash": { "placeholders": { "amount": {} } },
"activeDeliveryCollectCashNoAmount": "Collect the order amount in cash on delivery",
"@activeDeliveryCollectCashNoAmount": { "description": "Run-22 P1-A degraded variant - never fabricate $0.00." },
"activeDeliveryDirectionsCta": "Directions",
"@activeDeliveryDirectionsCta": { "description": "A11y label for the drop-off card's directions circle." },
"activeDeliveryQuickActionMaps": "Maps",
"@activeDeliveryQuickActionMaps": { "description": "Footer pill; long form stays the Semantics label." },
"activeDeliveryQuickActionChat": "Chat",
"@activeDeliveryQuickActionChat": { "description": "Footer pill; long form stays the Semantics label." },
"activeDeliveryQuickActionCosts": "Costs",
"@activeDeliveryQuickActionCosts": { "description": "Footer pill; long form stays the Semantics label." }
```
VALUE CHANGE (verified: single consumer mark_delivered_panel.dart:191, no test/Maestro pin):
`"activeDeliveryOtpSubmit": "Complete Delivery"` → `"Verify code & complete"`.
AR drafts: handoff "أكمل التسليم"; proof "صورة الإثبات"; prompt "اطلب من العميل رمز الباب المكوَّن من 4 أرقام:";
collect "حصّل {amount} نقدًا عند التسليم"; collectNoAmount "حصّل قيمة الطلب نقدًا عند التسليم";
directions "الاتجاهات"; maps "الخرائط"; chat "الدردشة"; costs "التكاليف"; otpSubmit "تحقق من الرمز وأكمل".
NOTE: `activeDeliveryOtpTitle` / `activeDeliveryOtpInstruction` lose their last consumer — keys left in place, deletion is the integrator's call.
why: the handoff card heading, tiles, prompt, collect line, directions a11y, and footer pills are all new user-visible strings; the app is AR/EN.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_stepper.dart (kit item §5 #11)
need: a `bars` named constructor — 18's stepper has no nodes; §5 #11's 26px-node spec is screen 12 only.
exact change: `JeebStepper.bars({required int stepCount, required int currentIndex, List<Key>? segmentKeys})` — Row of `Expanded` segments h5, `OmdsBorderRadius.xSmall`, gap 6; passed `colorScheme.primary`, active `jeebRoles.accent` + kit-local `BoxShadow(color: Color.fromRGBO(215, 59, 0, 0.18), spreadRadius: 3)` (NOT `JeebShadows.stepGlow`, whose spread 5 is sized for 12's Ø26 node; NOT `focusRing`, wrong color), pending `colorScheme.surfaceContainerHighest`; `segmentKeys[i]` applied to segment i; bars wrapped in `ExcludeSemantics` (labels/semantics stay feature-side). Plain Row → RTL mirrors free.
why: 18 re-homes the frozen `ValueKey('active_delivery_stage_<name>_<state>')`s onto the segments; without `segmentKeys` the stepper test's byKey family breaks.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_code_cells.dart (kit item §5 #12)
need: `input52` must WRAP `OmdsOtpInput`, not re-implement it — the per-cell ids `<identifier>_0.._3` (omds_otp_input.dart:289-296) exist for Maestro RC-7 and must keep coming from OMDS.
exact change: `JeebCodeCells.input52({Key? key, required String identifier, bool hasError, ValueChanged<String>? onChanged, ValueChanged<String>? onCompleted})` internally: `Directionality(textDirection: TextDirection.ltr)` isolate; `TextSelectionTheme(cursorColor: jeebRoles.accent)`; `OmdsColorTokensProvider(tokens: context.omdsColorTokens.copyWith(inputBorderColor: colorScheme.surfaceContainerHigh))` to kill the resting hairline; `LayoutBuilder` → `OmdsOtpInput(length: 4, boxHeight: 52, boxWidth: (maxWidth - 3*9)/4, spacing: 9, fillColor: colorScheme.surfaceContainerHigh, focusedBorderColor: jeebRoles.accent, textStyle: <kit-local 22/w800/onSurface const — jeebText.codeInput is 29, sized for 03>, hasError, identifier, onChanged, onCompleted)`. Accepted divergences: OS caret (tinted accent) instead of the drawn 2×22 bar.
why: 18's door-code entry consumes this; re-implementing cells is pure identifier risk (RC-7) for zero gain.

### cross-feature
file: docs/redesign-2026-08/00-MIGRATION-PLAN.md (plan owner)
need: two consumer-list corrections. §5 #13 `JeebNumericKeypad` consumers "03 18" → "03" (18's render has no keypad; the lower 40% is the R1 spacer + footer). §5 #11 gains the `bars` form above (12 keeps nodes). §5 #2: 18 builds its 3-pill row screen-local; no `actionRow` footer form needed in the kit.
exact change: edit the two consumer cells + one sentence in #11's spec.
why: prevents the kit lane building a keypad for 18 and a one-consumer footer variant.

### owner-decision (NOT a request — do not action)
The board's third footer pill ("Costs") implies a `/jeeber/deliveries/:id/goods-cost` route, but `GoodsCostScreen` is a verified ORPHAN with a broken endpoint (goods_cost_screen.dart:25, JEBV4-227) and `app_router.dart:1482-1529` never passes `onEnterGoodsCost`. 18 keeps the pill conditional on the callback (renders in devtool/tests, hidden in production). Wiring a route is an owner call — the JEBV4-176 lesson says don't ship a redesigned pill over a guaranteed-failing flow.
````
