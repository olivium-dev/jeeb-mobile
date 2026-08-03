# 18 · Active delivery — Jeeber — change proposal

Screen id: `18-active-delivery-jeeber`
Design: `screens/18-active-delivery-jeeber.{png,html,note.md}`
Target file: `lib/features/active_delivery_jeeber/presentation/active_delivery_jeeber_screen.dart`
(+ `presentation/widgets/{mark_delivered_panel,delivery_status_stepper,gps_permission_banner}.dart`)
Wave: 4 (sequence late — it owns 3 committed goldens; see §8)
Verdict: **rebuild** — Scaffold+ListView → Column + docked footer, the stepper changes form,
the at-door panel is recomposed, and two affordances (proof photo, note) change shape and
interaction. Not a restyle; not a new surface.

---

## 0. What the render actually is

The PNG is the **`AtDoor` + `otpRequired`** frame, not a generic frame. Reading it that way
resolves most of the apparent conflicts: the code cells and the `Verify code & complete` pill in
the render are today's `_DoorOtpEntry`, and the proof/note tiles above them are today's
`_ProofPhoto` + `_NoteField`. The designer note's "the shipped app scatters them" is about
**chrome**, not about state — today those four things are four sibling blocks in a plain
`ListView` under two `OMDSSectionCard`s; the design puts them inside one 2px-orange-framed card.

Measured from the HTML (all values design-exact):

| Block | Spec |
|---|---|
| Top bar | in-body row, pad `14/24/0`, gap 14; Ø40 circle `surface-high` + 20px navy back glyph; title 20/w700 navy |
| Stepper | 4 (→ 5, see §9-A) `flex:1` bars, h5, r9, gap 6; passed navy, active orange + `0 0 0 3 rgba(215,59,0,.18)`; labels row pad `7/24/0`, 10.5/w600 periwinkle, active 10.5/w800 orange |
| Drop-off card | margin `16/24/0`, pad `14/16`, r16, `1.5px #916F66`, gap 12; 20px pin; title 14.5/w700 navy 1-line ellipsis; sub 12/w500 periwinkle; trailing Ø38 circle `surface-high` + 17px navy directions glyph |
| Handoff panel | margin `14/24/0`, **2px orange**, r18, pad 16, **no shadow** |
| — heading | 15.5/w700 navy |
| — tile row | gap 10, both `flex:1` h86 r12; left = `surface-high` fill, 22px navy glyph + 11.5/w700 navy label; right = `1.5px dashed #916F66`, 18px periwinkle glyph + 11.5/w600 periwinkle label |
| — prompt | margin-top 12, 12/w600 periwinkle |
| — code cells | margin-top 9, gap 9, `flex:1` h52 r12 `surface-high`; digit 22/w800 navy; active cell `2px orange` + 2×22 orange caret; empty cells have **no** border |
| — CTA | margin-top 14, h54, r999, navy, white 15.5/w600, `0 10 24 rgba(11,19,81,.28)` |
| Spacer | `flex:1` — **~40% of the viewport is plain white** (R1) |
| Footer | pad `0/24/30`, gap 10, three `flex:1` h50 r999 `1.5px #916F66` pills, 16px navy glyph + 13.5/w600 navy label |

Mock chrome not to build: 440×956 frame, 40px frame radius, `scale(0.55)`, the `9:41` row.

---

## 1. Layout & structure

### 1.1 Page shell — `active_delivery_jeeber_screen.dart:225-235` (`_buildScaffold`)

**Delete** `appBar: OMDSAppBar(title: …, showBackButton: true)`. The design's bar is in-body.

```dart
Scaffold(
  body: SafeArea(
    child: Semantics(
      identifier: 'mark_delivered_root',      // UNCHANGED, same node position
      explicitChildNodes: true,
      child: _buildBody(context, state, l10n),
    ),
  ),
)
```

`_Unavailable` (`:144-153`) gets the same treatment so the two shells do not diverge; its
`mark_delivered_root` node is untouched.

### 1.2 Body becomes column + docked footer — `:352-412` (`_ReadyContent.build`)

The single largest structural change. `ListView(padding: EdgeInsets.all(Spacing.medium))` →

```dart
Column(
  children: [
    JeebTopBar(                                    // §5 #1, leading: back
      title: l10n.activeDeliveryTitle,
      identifier: 'mark_delivered_back',
      onBack: () => Navigator.of(context).maybePop(),
    ),
    if (!delivery.status.isUnsuccessfulTerminal)
      DeliveryStatusStepper(...),                  // directly under the bar, NO card
    Expanded(
      child: ListView(
        padding: const EdgeInsetsDirectional.fromSTEB(
          Spacing.xLarge, Spacing.medium, Spacing.xLarge, Spacing.medium),
        children: [ /* gps banner, completed panel, address card, action panel */ ],
      ),
    ),
    _QuickActionFooter(...),                        // docked, pad 0/24/32
  ],
)
```

R1 is the point: with `Expanded(child: ListView(...))` the content sits top-aligned and the lower
~40% stays white. **Never** `mainAxisAlignment: center`, never `Spacer()` between cards, never let
the list grow to fill.

### 1.3 Delete both `OMDSSectionCard` wrappers

- `:374-382` — the "Delivery progress" card around the stepper. The design has **no** card and no
  heading there. `l10n.activeDeliveryProgressTitle` is re-used as the heading of the ordered/picked
  action card (§1.5) so no ARB key is orphaned.
- `:532-534` (`_AddressCard`) — the "Drop-off address" titled section card becomes a bare
  `JeebOutlinedCard`. `l10n.activeDeliveryDropOffLabel` survives as the card's Semantics label.

### 1.4 Drop-off card — `:522-568` (`_AddressCard`)

Rebuild as `JeebOutlinedCard` (§5 #3, r16, `1.5px colorScheme.outline`, **no shadow**, pad
`14/16`) containing a `Row(gap: Spacing.small)`:

1. 20px `Icons.location_on` filled (design uses a filled pin, not `_outlined`), ink
   `context.jeebRoles.accent` — see §9-F for why not `#E02020`.
2. `Expanded(Column(crossAxisAlignment: start))`:
   - `delivery.dropOff.label`, `context.jeebText.titleProminent.copyWith(fontSize: …)` → use
     `cardTitle` (15.5/w700; design 14.5 — nearest ramp entry, do not add a field), `maxLines: 1`,
     `overflow: TextOverflow.ellipsis`, ink `colorScheme.onSurface`.
   - the **collect line** — `dropOff.detail` and the cash reminder joined by `·`, `jeebText.bodySmall`,
     ink `JeebSemanticColors.mutedText`. This node carries `mark_delivered_cash_note` (§1.7).
3. Trailing Ø38 circle, `colorScheme.surfaceContainerHigh`, `OmdsBorderRadius.pill`, 17px navy
   `Icons.directions`, `onTap: onOpenMaps` — new id `mark_delivered_directions_cta`.

### 1.5 The action panel — `mark_delivered_panel.dart:72-111`

One card slot, three stage-driven contents. **Only the at-door state is orange** (R5: orange marks
what is decaying — the customer is standing there):

| Stage | Card | Contents |
|---|---|---|
| `ordered`, `picked` | `JeebOutlinedCard` | heading `activeDeliveryProgressTitle` + `mark_delivered_advance_cta` as a navy `JeebCtaButton.primary` (h54, `JeebShadows.ctaNavy`) |
| `inTransit` | `JeebOutlinedCard` | heading `activeDeliveryHandoffTitle` + tile row + `mark_delivered_cta` |
| `atDoor`, `!otpRequired` | **`JeebAccentFrameCard`** (§5 #5, 2px accent, r18) | heading + tile row + `mark_delivered_cta` |
| `atDoor`, `otpRequired` | **`JeebAccentFrameCard`** | heading + tile row + prompt + code cells + `mark_delivered_otp_submit` — **this is the render** |

The `mark_delivered_advance_cta` moves out of `delivery_status_stepper.dart:213-239` and into this
card so the screen has exactly one framed action surface at every stage. Its identifier, label
switch and `isLoading` behaviour are copied verbatim — see §6.

**Deleted:** `mark_delivered_panel.dart:77-80`, the panel title `Text(l10n.activeDeliveryStatusDone)`
("Done" as a heading is a copy bug that predates the redesign), and `:152-162`, the
`_DoorOtpEntry` title + long instruction, replaced by the design's single prompt line.

### 1.6 Proof + note tile row — replaces `_ProofPhoto` (`:204-288`) and `_NoteField` (`:291-312`)

A screen-local `presentation/widgets/handoff_tiles.dart` (this pattern repeats nowhere else on the
board, so it does **not** go in `lib/core/widgets/jeeb/`). `Row(gap 10)` of two `Expanded` h86 r12
tiles:

**Proof tile** — `mark_delivered_proof_photo` (identifier, `button: true`, `image: true`,
`label: l10n.receiptProofPhotoLabel`, `enabled: !uploading` — all four preserved verbatim from
`:230-236`).
- none → `surfaceContainerHigh` fill, 22px navy `Icons.photo_camera`, label
  `activeDeliveryProofPhotoTile` 11.5/w700 navy.
- uploading → same tile, `OmdsLoadingState` in place of the glyph.
- captured → `Image.memory(bytes)` / `OmdsCachedImage(url)` at `BoxFit.cover` behind an r12 clip,
  with a 14px `Icons.check` after the label. **Do not delete the thumbnail** — JEBV4-200 exists
  precisely so the jeeber sees the frame they took; the design simply does not draw the captured
  state.
- The 180px full-width placeholder (`:242-244`) goes away.

**Note tile** — the whole cell is wrapped in
`Semantics(identifier: 'mark_delivered_note_field', container: true, explicitChildNodes: true)` so
that identifier is **always emitted**, collapsed or not.
- collapsed → `1.5px dashed colorScheme.outline` (a `CustomPainter` dash — no new dep), 18px
  periwinkle `Icons.notes`, label `offerSubmissionNoteLabel` ("Note (optional)" — already the exact
  design string, no new key). Tap target id `mark_delivered_note_tile` (new).
- expanded → the tile becomes filled `surfaceContainerHigh` (mirroring the proof tile's "done"
  treatment) and an `OmdsTextField(maxLines: 3, maxLength: 280, onChanged: onNoteChanged)` renders
  **below the tile row**, inside the same `mark_delivered_note_field` node. Same callback, same
  limits.

### 1.7 Cash note re-homed — `_CashNote` (`:315-358`) is deleted as a block

`mark_delivered_cash_note` moves onto the drop-off card's second line (§1.4). Three reasons:
the note says "the drop-off card states what to collect"; the render has no cash slab; and moving
it up makes it visible at **every** live stage instead of only inTransit/atDoor, which is strictly
more available for the Maestro `assertVisible`.

The `primaryContainer` slab, the `Icons.payments_outlined` and the
`receiptCashToJeeber(amount, party)` call all go. Copy becomes:

```dart
final amount = delivery.amountText;
final cash = amount == null || amount.isEmpty
    ? l10n.activeDeliveryCollectCashNoAmount            // NEW — run-22 P1-A rule
    : l10n.activeDeliveryCollectCash(amount);           // NEW
final detail = delivery.dropOff.detail;
final line = detail == null ? cash : '$detail · $cash';
```

This fixes two live copy defects on the way: `:328` renders `"Pay  cash to X"` when `amountText`
is null (`?? ''` fabricates an empty amount — the exact thing `receiptCashToJeeberNoAmount` was
added to prevent), and `:329` falls back to `activeDeliveryDropOffLabel` as the *party*, producing
"Pay $8 cash to Drop-off address".

### 1.8 Docked footer — replaces `_ActionButtons`/`_QuickActions`/`_GoodsCostAction` (`:600-704`)

`Row` of `Expanded` `JeebCtaButton.outline` pills (h50, r999, `1.5px colorScheme.outline`, 16px
navy leading glyph, `jeebText` 13.5/w600 navy), gap `Spacing.small` (10 ≈ 12), padding
`EdgeInsetsDirectional.fromSTEB(24, 0, 24, 32)` (§3.2 of `02-PLAN-ENHANCED.md`: pick 32).

- `mark_delivered_open_maps_cta` — `Icons.map`, label `activeDeliveryQuickActionMaps` ("Maps"),
  Semantics label `activeDeliveryOpenMapsButton`.
- `mark_delivered_open_chat_cta` — `Icons.chat`, label `activeDeliveryQuickActionChat` ("Chat"),
  Semantics label `activeDeliveryOpenChatButton`.
- `mark_delivered_goods_cost_cta` — `Icons.receipt_long`, label `activeDeliveryQuickActionCosts`
  ("Costs"), Semantics label `activeDeliveryEnterGoodsCostButton`. **Stays conditional on
  `onEnterGoodsCost != null`** — see §9-E.

`_QuickAction`'s `Semantics(identifier:…, container: true, button: true)` wrapper (`:586-590`) is
kept exactly; only the button it wraps changes.

**`_kInlineQuickActionsMinWidth` (`:20`) must be retuned from 448 → 320.** At 448 the guard fires on
*every* phone (390pt wide), so today's two actions are always stacked — the design's row is
currently unreachable. Measured for the new labels: 3 × ~58pt + 2 × 10 gap + 48 gutter = 242pt, so
320 gives comfortable headroom. **Keep the `MediaQuery.textScalerOf` half of the guard verbatim** —
it is what makes the 200% golden survive; at that scale the three pills stack into a Column and the
`Expanded` list above simply gets shorter.

### 1.9 `_CompletedPanel` (`:481-520`)

Not in the render (it is a terminal state). Minimal token pass only: `primaryContainer` →
`context.jeebRoles.successContainer` / `onSuccessContainer` (a delivered banner is a success, not a
brand fill), radius `OmdsBorderRadius.medium`, title `context.jeebText.cardTitle`. Identifier,
label and `Icons.check_circle` unchanged.

### 1.10 `GpsPermissionBanner`

Stays first in the scroll area, unchanged in copy and CTA logic (its three strings are pinned by
`background_location_permission_test.dart` §4). Wave 0 already re-tinted `errorContainer` from the
`#B00020` slab to `#FFDAD6`, which is the whole visual fix. Optional: radius already
`OmdsBorderRadius.medium`. **Do not touch `gps_permission_banner.dart:163`** — that OMDS
`identifier:` param is the named pre-existing baseline issue.

---

## 2. Tokens — every hardcoded value that must move

| Where (file:line) | Today | Becomes |
|---|---|---|
| `screen.dart:353` | `EdgeInsets.all(Spacing.medium)` (16) | `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, …)` — 24pt gutter (§4.3) |
| `screen.dart:226,145` | `OMDSAppBar` | `JeebTopBar` + `context.jeebText.h2` |
| `screen.dart:510` | `theme.textTheme.titleMedium` | `context.jeebText.cardTitle` |
| `screen.dart:496` | `colorScheme.primaryContainer` | `context.jeebRoles.successContainer` |
| `screen.dart:503` | `colorScheme.onPrimaryContainer` | `context.jeebRoles.onSuccessContainer` |
| `screen.dart:540,542` | `colorScheme.primary` + `Sizes.xLarge` pin | `context.jeebRoles.accent`, 20pt (§9-F) |
| `screen.dart:550` | `theme.textTheme.titleMedium` | `context.jeebText.cardTitle` |
| `screen.dart:556-557` | `bodyMedium` + `onSurfaceVariant` | `context.jeebText.bodySmall` + `JeebSemanticColors.mutedText` |
| `screen.dart:590-594` | `OmdsPrimaryButton(variant: outlined)` | `JeebCtaButton.outline` (h50, r999, `1.5px colorScheme.outline`) |
| `screen.dart:20` | `448` | `320` (measured, §1.8) |
| `panel.dart:79` | `theme.textTheme.titleMedium` | `context.jeebText.cardTitle` (15.5/w700 — the design's heading size exactly) |
| `panel.dart:159-161` | `bodyMedium` + `onSurfaceVariant` | `context.jeebText.bodySmall` + `mutedText` |
| `panel.dart:180-182` | `bodySmall` + `colorScheme.error` | `context.jeebText.caption` + `colorScheme.error` (Wave 0 set `error` explicitly) |
| `panel.dart:241` | `OmdsBorderRadius.medium` on a 180px box | `OmdsBorderRadius.small` (12) on the h86 tile |
| `panel.dart:250-251,255-256` | `height: 180` | h86 tile |
| `panel.dart:260` | `surfaceContainerHighest` | `surfaceContainerHigh` (`#EAE7EB` — the design's cell/field fill; `Highest` is the *empty* fill) |
| `panel.dart:269` | `Sizes.twoXLarge` glyph | 22pt (design), 18pt on the note tile |
| `panel.dart:334-337` | `primaryContainer` slab | deleted (§1.7) |
| `panel.dart:386-391` | `OmdsLoadingButton` | `JeebCtaButton.primary` h54 + `JeebShadows.ctaNavy` + `context.jeebText.button` |
| `stepper.dart:78` | `colors.tertiary` | `context.jeebRoles.accent` — the *only* sanctioned orange accessor (§4.6) |
| `stepper.dart:79` | `colors.surfaceContainerHighest` | unchanged — correct for the pending bar |
| `stepper.dart:81-82` | `Sizes.threeXLarge` / `Sizes.threeXSmall` | bar h5 / r9 (`OmdsBorderRadius.xSmall`) inside the kit widget |
| `stepper.dart:197-208` | `labelSmall` + `copyWith(fontWeight)` | `context.jeebText.label` (10.5/w700), active `.copyWith(fontWeight: w800)` |
| `stepper.dart:144-148` | icon ink switch | deleted with `_StageIcon` (§4) |

**Gate note:** this feature is **not** in `no_raw_semantic_colors_test.dart`'s 18-file list, but it
**is** under `tool/check_design_tokens.sh` (`lib/features`). So: no `Color(0x…)`, no `Colors.*`,
no `fontSize:`, no `BorderRadius.circular(N)`, no `EdgeInsets.<x>(<number>)`, no
`SizedBox(width|height: <number>)` in any of these three files. Every design-exact px (86, 52, 54,
50, 5, 9) must live **inside** the `lib/core/widgets/jeeb/` kit widgets, which the script does not
scan. The one screen-local exception, `handoff_tiles.dart`, must therefore express 86/12/22 through
`Sizes`/`Spacing`/`OmdsBorderRadius` tokens (`Sizes` has the needed rungs) or move into the kit.

---

## 3. Shared components this screen consumes

| Kit widget (§5) | Used for | Notes |
|---|---|---|
| #1 `JeebTopBar` | the in-body bar | `leading: back`, `identifier: 'mark_delivered_back'`, title `activeDeliveryTitle` |
| #2 `JeebCtaButton` | advance / complete / verify pills (`primary`) and the 3 footer pills (`outline`) | — |
| #2 `JeebCtaFooter` | the docked footer | **needs a fourth form — see §3.1** |
| #3 `JeebOutlinedCard` | drop-off card; action panel at ordered/picked/inTransit | r16, `1.5px outline`, no shadow |
| #5 `JeebAccentFrameCard` | the at-door handoff panel | 2px `jeebRoles.accent`, r18, **no shadow**, pad 16 |
| #11 `JeebStepper` | the progress bar | **needs a `bars` variant — see §3.2** |
| #12 `JeebCodeCells` | the 4 door-code cells | `input52`, **must wrap `OmdsOtpInput` — see §3.3** |

**Not consumed, deliberately:**

- **#13 `JeebNumericKeypad`.** The plan (§5 #13) lists 18 as a consumer. **The render has no
  keypad** — the bottom 40% is empty white and the only chrome down there is the 3-pill footer.
  Building one here would fill the R1 spacer and directly contradict the image. Refused; the plan's
  consumer list should read "03" only.
- **#22 `JeebInfoNote`.** No info note on this screen.
- **#10 `JeebSectionLabel`.** No uppercase section label on this screen.

### 3.1 Correction to §5 #2 — `JeebCtaFooter` needs an `actionRow` form

The plan enumerates three realized footer forms (`single`, `split`, `textStack`). 18's footer is a
fourth: **N equal-`flex` outline pills** (`actionRow`), pad `0/24/32`, gap 10, each h50 r999
`1.5px outline` with a 16px leading glyph. It must accept 2 or 3 children (the third is conditional,
§9-E) and must fall back to a stacked `Column` under the text-scale guard. This is 18-only today,
so if the kit owner prefers, it can ship as a screen-local `_QuickActionFooter` — but the padding
and pill metrics must come from the kit's constants either way.

### 3.2 Correction to §5 #11 — `JeebStepper` has two forms, not one

§5 #11 specs "Nodes 26px … connectors h3 r8" for **both** 12 and 18. That is screen 12's stepper.
**Screen 18 has no nodes at all** — it is four `flex:1` bars, h5, r9, gap 6, with the labels in a
separate row beneath. Add a named constructor:

```dart
JeebStepper.bars({
  required int stepCount,
  required int currentIndex,
  required List<String> labels,
  List<String>? semanticsLabels,
  List<Key>? segmentKeys,
})
```

- passed segment: `colorScheme.primary`
- active segment: `jeebRoles.accent` + `BoxShadow(color: accent@.18, spreadRadius: 3)` — the kit's
  `JeebShadows.stepGlow` is spread **5** (sized for 12's Ø26 node); 18's bar measures spread **3**,
  so `bars` carries its own const rather than reusing the wrong one.
- pending segment: `colorScheme.surfaceContainerHighest`
- labels: `jeebText.label`; active `.copyWith(fontWeight: FontWeight.w800)` ink `jeebRoles.accent`;
  **all others `JeebSemanticColors.mutedText`** — the render draws "Ordered", "Picked" and
  "In transit" in the *same* periwinkle, so completed and upcoming are not distinguished by ink
  (the bar carries that, and the Semantics label carries it for a11y).
- `segmentKeys` exists so `DeliveryStatusStepper` can re-home the frozen
  `active_delivery_stage_<name>_<state>` `ValueKey`s onto the bars (§6).

Plain `Row` of `Expanded` → mirrors for free under RTL.

### 3.3 Correction to §5 #12 — `JeebCodeCells.input52` must wrap `OmdsOtpInput`, not replace it

`OmdsOtpInput(identifier: 'mark_delivered_otp_input')` emits per-cell ids
`mark_delivered_otp_input_0 … _3` (`omds_otp_input.dart:274-293`), which exist specifically because
Maestro cannot distribute a 4-digit string across N `TextField`s through one container node (RC-7).
Re-implementing that from scratch is pure identifier risk for zero gain, because OMDS already
exposes every knob the design needs:

```dart
LayoutBuilder(builder: (context, c) => OmdsOtpInput(
  key: const Key('markDelivered.otpInput'),
  length: 4,
  identifier: 'mark_delivered_otp_input',
  boxHeight: 52,                                        // design
  boxWidth: (c.maxWidth - 3 * 9) / 4,                   // emulates flex:1
  spacing: 9,
  fillColor: colorScheme.surfaceContainerHigh,
  focusedBorderColor: context.jeebRoles.accent,         // 2px, already the OMDS focus width
  textStyle: /* 22 / w800 / onSurface — kit-local const */,
  hasError: hasError,
  onChanged: …, onCompleted: …,
))
```

`OmdsBorderRadius.small` is 12 — the design radius exactly. Two divergences to accept and state:
(a) the resting cell keeps OMDS's `inputBorderColor` hairline where the design draws none — kill it
by scoping an `OmdsColorTokensProvider(tokens: …copyWith(inputBorderColor: surfaceContainerHigh))`
around the cells (the same technique `app.dart` uses for the star color); (b) the caret is the OS
caret, not the design's 2×22 orange bar — tint it via a local
`TextSelectionTheme(cursorColor: jeebRoles.accent)`. Both are theme-side, neither edits OMDS.

Keep `autoFocus` and the existing `onCompleted: (_) => _submit()` — **auto-verify on the 4th digit
already ships** (`panel.dart:173`); it is not new work.

---

## 4. New functionality — and what it needs from the state layer

**Nothing on this screen needs a new field, a new endpoint, or a cubit change.** Enumerated:

| Design item | Status |
|---|---|
| Unified at-door panel | pure presentation over existing `otpRequired` / `proofPhotoStatus` / `status` |
| Auto-verify on the 4th digit | **already ships** — `panel.dart:173` `onCompleted: (_) => _submit()` |
| Directions circle in the drop-off card | reuses `_launchMaps(delivery)` (`screen.dart:281-290`) and `delivery.dropOff.{lat,lng}` |
| "collect $8 + $6.50 goods" | **partially blocked.** `delivery.amountText` exists; there is **no** goods-cost field on `JeeberDelivery` (`jeeber_delivery.dart:70-86`) and no gateway read for one. Render `Collect {amount} cash on delivery` and leave `// TODO(redesign-24): needs gateway goods-cost on the delivery snapshot — omitted, not faked.` **Do not** invent a split |
| "Costs" third pill | the callback exists (`onEnterGoodsCost`) but is never passed by the router; `GoodsCostScreen` is a documented ORPHAN with a broken endpoint (`goods_cost_screen.dart:25`, JEBV4-227). See §9-E |
| Note-tile expand/collapse | new local `StatefulWidget` state only; `onNoteChanged` unchanged |
| Proof-tile capture states | new local rendering of the existing `ProofPhotoStatus` enum |

The `ActiveDeliveryCubit`, `ActiveDeliveryState`, `ActiveDeliveryRepository` and `JeeberDelivery`
are **untouched by this proposal**. That is deliberate — see §9-C.

---

## 5. New routes

**None.** `/jeeber/deliveries/:id/active` (name `jeeber-active-delivery`,
`app_router.dart:1482-1529`) is unchanged, keeps all six injected seams
(`repository`, `photoPicker`, `gpsUploader`, `onOpenChat`, `onMarkedDelivered`, `mapsUrlBuilder`)
and stays out of `backFallbacks`.

A `/jeeber/deliveries/:id/goods-cost` route is *implied* by the design's third pill but is
**deliberately not proposed** — see §9-E. It belongs in the integrator's route-request queue as an
owner decision, not in this lane's diff.

---

## 6. Semantics identifiers

### 6.1 Existing — every one of these must still be emitted (frozen)

| Identifier | Today | After |
|---|---|---|
| `mark_delivered_root` | `screen.dart:149` (`_Unavailable`), `:230` (`_buildScaffold`) | same two nodes, inside `SafeArea` |
| `delivery_completed_state` | `:490` | unchanged |
| `delivery_cancelled_state` / `_expired_state` / `_disputed_state` | `:449-454` via `_identifier` | unchanged |
| `mark_delivered_open_maps_cta` | `:614` | footer pill 1 |
| `mark_delivered_open_chat_cta` | `:620` | footer pill 2 |
| `mark_delivered_goods_cost_cta` | `:662` | footer pill 3 (still conditional) |
| `active_delivery_stage_ordered` / `_picked` / `_intransit` / `_atdoor` / `_done` | `stepper.dart:174` | the label row beneath the bars — **all five** |
| `mark_delivered_advance_cta` | `stepper.dart:230` | moves into the action card (§1.5) |
| `active_delivery_gps_permission_banner` | `gps_permission_banner.dart:67` | unchanged |
| `active_delivery_gps_permission_cta` | `gps_permission_banner.dart:163` | unchanged (do not touch — baseline issue) |
| `mark_delivered_otp_input` (+ `_0.._3`) | `panel.dart:165,170` | the code-cell row inside the accent panel |
| `mark_delivered_otp_submit` | `panel.dart:187` | the at-door verify pill |
| `mark_delivered_proof_photo` | `panel.dart:231` | the h86 proof tile |
| `mark_delivered_note_field` | `panel.dart:302` | wraps the whole note cell (always emitted) |
| `mark_delivered_cash_note` | `panel.dart:331` | the drop-off card's collect line |
| `mark_delivered_cta` | `panel.dart:379` | the inTransit / at-door-pre-code pill |

Also frozen (keys, not identifiers): `ValueKey('active_delivery_stage_<name>_<state>')`
(`stepper.dart:150-152`) → re-home onto the bar segments via `segmentKeys`;
`Key('markDelivered.otpInput')`, `Key('markDelivered.otpSubmit')`,
`GpsPermissionBanner.bannerKey`, `ValueKey<String>(_identifier)` on the `OmdsEmptyState`
(`screen.dart:440`).

### 6.2 New

| Identifier | Element |
|---|---|
| `mark_delivered_back` | `JeebTopBar` back circle (`<screen>_back` convention) |
| `mark_delivered_directions_cta` | Ø38 directions circle in the drop-off card |
| `mark_delivered_note_tile` | the collapsed note tile's tap target (inside `mark_delivered_note_field`) |

Every parent that wraps children keeps `container: true` + `explicitChildNodes: true`
(the `active_request_card.dart` idiom), and every wrapper is an explicit `Semantics(...)` — the
`OmdsOtpInput(identifier:)` param at `panel.dart:170` is the one pre-existing exception and it
stays (it is what produces the per-cell ids).

---

## 7. RTL

| Item | Risk | Build rule |
|---|---|---|
| Stepper bars + labels | progress direction | plain `Row` of `Expanded` — mirrors correctly; AR progress reads right→left, which is right |
| **Code cells** | **real bug, present today** | `OmdsOtpInput` is a `Row`, so under `ar` cell 0 lands at the *right* and the code the recipient reads out is entered visually reversed. Wrap the cells in `Directionality(textDirection: TextDirection.ltr)`. This changes the AR golden — intentionally |
| Money in the collect line | bidi reordering of `$8.00 USD` | wrap `amountText` in `⁦…⁩` (FSI/PDI) or a `Directionality.ltr` span |
| Top bar back glyph | fixed arrow | `DirectionalIcons.back` (`lib/core/widgets/directional_icons.dart`) |
| Drop-off trailing circle | fixed side | `Row` + `EdgeInsetsDirectional`; never `EdgeInsets.only(left:)` |
| Tile row / footer row | fixed order | plain `Row` of `Expanded`; gaps via `SizedBox` (direction-neutral) |
| Body padding | fixed gutter | `EdgeInsetsDirectional.fromSTEB` |
| Card outlines / dashed border | none | symmetric |
| `Collect … · Ring twice` join | separator placement | build with `'$detail · $cash'` in the string, not with a hardcoded leading/trailing glyph |

The golden suite already asserts `Directionality.of(...) == rtl` for the `ar` scenario
(`golden_test.dart:110-115`) — that assertion must keep passing untouched.

---

## 8. Test impact

### Legitimately updated (the design genuinely changed)

1. **`test/features/active_delivery_jeeber/goldens/*.png` ×3** — `active_delivery_english_phone`,
   `active_delivery_arabic_rtl_phone`, `active_delivery_english_200_percent_text`. All three
   regenerate. Per plan risk #10, regenerate **once, on the Mac Studio, in Wave 5**; expect a red
   golden locally until then. `active_delivery_jeeber_golden_test.dart` itself needs **no** code
   change (it seeds `status: picked`, so it exercises the top bar + bar stepper + address card +
   ordered/picked action card + footer).
2. **`test/features/active_delivery_jeeber/delivery_status_stepper_test.dart`** — exactly two
   assertion families die with the icon-circle stepper:
   - `:52` and `:123` `find.byType(OmdsStepIndicator)` → replace with the bar-segment finder.
   - `:69` `find.byIcon(_icons[stage]!)` and the `_icons` map at `:18-24` → delete; the design has
     no stage icons, and `JeeberDeliveryStatus.stepIcon` (`stepper.dart:261-279`) becomes dead code
     and should be deleted with it.

   **Everything else in that file must keep passing verbatim** — `find.text(_labels[stage])`,
   `find.bySemanticsIdentifier('active_delivery_stage_*')`,
   `find.bySemanticsLabel('<Label>, <State>')`, `find.byKey(ValueKey('..._<state>'))`, and the whole
   `mark_delivered_advance_cta` block including the tap + label assertions ("Mark as Picked" /
   "Mark as In Transit"). **If any of those need editing, this proposal is wrong** — the advance CTA
   moving into the action card must not change its identifier, its label switch, or its callback.

### Must keep passing unchanged (they are the guardrail)

3. **`active_delivery_push_landing_test.dart`** — the strongest constraint on this screen.
   `:266` expects `mark_delivered_cta` **present** at `atDoor`; `:282` expects it **absent** after
   the tap; `:285-289` expects `delivery_completed_state` absent throughout. This is exactly why
   §9-C refuses to collapse the two-phase OTP gate. Also `:201` `OmdsStepIndicator findsNothing` on
   unsuccessful terminals still passes trivially, and `:203` `active_delivery_stage_done findsNothing`
   passes because `_UnsuccessfulTerminalContent` short-circuits before the stepper.
4. **`active_delivery_error_snackbar_test.dart`** — text + `Directionality` only; unaffected.
5. **`background_location_permission_test.dart` §4 (4 cases)** — `GpsPermissionBanner.bannerKey`
   plus the literal strings "Live tracking is off" / "Open settings" / "Allow location" and the AR
   variant. Do not touch the banner's copy or CTA branch.
6. **`active_delivery_lifecycle_test.dart` (AC13/AC14/AC15/N6)**, `active_delivery_gps_upload_test.dart`,
   `active_delivery_push_driven_test.dart`, `active_delivery_cubit_test.dart`,
   `delivery_otp_handover_path_test.dart`, `v3_final_state_mapping_test.dart` — all cubit/repository
   level. Unaffected, because §4 changes no state.
7. **Maestro `.maestro/flows/jm-051-mark-delivered.yaml`** — untouched. It lands on a seeded
   `InTransit` delivery and asserts `mark_delivered_root`, `mark_delivered_proof_photo`,
   `mark_delivered_cash_note`, `mark_delivered_cta`, then taps through to `rating_submit_cta`.
   All four are still emitted at `InTransit` after this change (the cash note moves *up* to the
   address card, which renders at every live stage).
8. **`tool/check_design_tokens.sh`** — must stay clean; see the gate note in §2.

### New tests to add (ADD only, never weaken)

- `handoff_tiles` widget test: none / uploading / captured proof states; note collapsed ↔ expanded
  with `mark_delivered_note_field` emitted in both.
- RTL smoke: `ar` locale, assert the code cells render LTR and that the drop-off trailing circle is
  at the start edge.
- Footer test: 3 pills in a `Row` at 390pt / 1.0 scale, stacked at 2.0 scale, third pill absent when
  `onEnterGoodsCost == null`.

---

## 9. Conflicts and refusals

**A — The 4-node stepper is refused; ship 5 segments.**
The board draws four steps (Ordered / Picked / In transit / At door). The app's stage vocabulary is
five (`jeeberDeliveryProgressStages`, `jeeber_delivery_status.dart:20-26`) and the fifth carries the
frozen identifier `active_delivery_stage_done` plus its `ValueKey`s, asserted in
`delivery_status_stepper_test.dart:53-79` and (negatively) in `push_landing_test.dart:203`.
Dropping it would delete a frozen identifier — §7.1-2. Render **five** `flex:1` bars; at `atDoor`
that is 3 navy + 1 accent + 1 pending, which is visually within a hair of the render. This is the
18 analogue of C10 (12's stepper must resolve through the existing stage enum).

**B — `JeebNumericKeypad` is refused on this screen.**
Plan §5 #13 lists consumers "03 18". The 18 render has **no keypad**; the lower 40% is empty white
(R1) and the only bottom chrome is the 3-pill footer. Building one would fill the spacer and
contradict the image. Correct the plan's consumer list to "03".

**C — The board's "code entry + CTA always together" is honoured as a *layout*, refused as a
*state change*.**
The render is the `otpRequired == true` frame. Auto-raising `otpRequired` at `AtDoor` on load (so
the cells appear without the intermediate `mark_delivered_cta` tap) would be a cubit change that
breaks `push_landing_test.dart:266/282` and would remove the only surface that distinguishes
"walked to the door" from "asking for the code". The frozen SM (`DeliverySm.cs:53-62` — `AtDoor` has
exactly three exits, all OTP/escalation) is what that two-phase gate encodes. **Keep both phases;
the design's visual unification is achieved by putting both phases inside the same
`JeebAccentFrameCard`.** If the owner wants the tap removed, that is a one-line cubit change plus a
deliberate edit to two assertions in `push_landing_test.dart` — an owner call, not this lane's.

**D — "collect $8 + $6.50 goods" cannot be split.**
`JeeberDelivery` carries `amountText` only. There is no goods-cost field on the delivery snapshot
and no gateway read for one. Render `Collect {amount} cash on delivery` (with the
`…NoAmount` degraded variant — never fabricate `$0.00`, run-22 P1-A) and leave the TODO from §4.
Do not compose a number from anything.

**E — The "Costs" pill must not get a route.**
`GoodsCostScreen` exists but is marked `// ORPHAN (JEBV4-227, verified 2026-07-12): zero external
refs; its backend endpoint is also broken` (`goods_cost_screen.dart:25`), it has no `GoRoute`, and
`onEnterGoodsCost` is never passed by `app_router.dart:1482-1529`. Wiring it would ship a
guaranteed-failing flow behind a redesigned pill — the JEBV4-176 lesson. **Keep
`mark_delivered_goods_cost_cta` conditional exactly as it is today** (so the devtool/tests that pass
the callback still render it, and production still shows two pills), and raise the route as an owner
decision. The 2-pill row still matches the design's shape.

**F — `#E02020` is not available as a token.**
Plan §4.1 excludes the destination-pin red as "existing marker assets" — but on 18 it is an inline
20px glyph in a card, not a map marker, and a raw `Color(0xFFE02020)` in `lib/features` fails
`check_design_tokens.sh`. `colorScheme.error` (`#B00020` after Wave 0) is semantically wrong for a
destination. **Use `context.jeebRoles.accent` (`#D73B00`)** — the sanctioned "happening right now"
ink, which reads as red-orange. Divergence: the pin is warmer than the board's. Stated, not hidden.

**G — Two live copy defects fixed on the way (not design changes, but do not re-introduce them).**
`panel.dart:328` renders `"Pay  cash to X"` when `amountText` is null (`?? ''`), and `:329` uses
`activeDeliveryDropOffLabel` as the *party*, producing "Pay $8 cash to Drop-off address". Both die
with the re-homed collect line (§1.7).

**H — No conflict with `decision_violations_test.dart`.** This screen carries no commission/fee
copy (D41/D44), no rating skip (D56), no chat composer (B04), no KYC resubmit (D52), no vehicle
labels (D20), and no pre-accept cancel. The only locked contract it touches is the frozen delivery
SM, which §9-C preserves.

---

## 10. l10n (integrator batch — 4-edit recipe each, EN + real AR)

| Key | EN | Why |
|---|---|---|
| `activeDeliveryHandoffTitle` | "Complete the handoff" | design heading; replaces the `activeDeliveryStatusDone` ("Done") mis-use at `panel.dart:79` |
| `activeDeliveryProofPhotoTile` | "Proof photo" | h86 tile label (the ✓ is an `Icons.check`, not part of the string — AR/RTL safe) |
| `activeDeliveryDoorCodePrompt` | "Ask the customer for their 4-digit door code" | design's compact prompt; replaces the two-line title + instruction |
| `activeDeliveryCollectCash` | "Collect {amount} cash on delivery" | the re-homed `mark_delivered_cash_note` |
| `activeDeliveryCollectCashNoAmount` | "Collect the order amount in cash on delivery" | degraded variant — never fabricate `$0.00` |
| `activeDeliveryDirectionsCta` | "Directions" | a11y label for the Ø38 circle |
| `activeDeliveryQuickActionMaps` | "Maps" | footer pill label (long form kept as the Semantics label) |
| `activeDeliveryQuickActionChat` | "Chat" | ditto |
| `activeDeliveryQuickActionCosts` | "Costs" | ditto |

**One value change** (not an append): `activeDeliveryOtpSubmit` "Complete Delivery" →
"Verify code & complete", EN + AR. Verified no test and no Maestro flow pins that string; its only
consumer is `panel.dart:191`. If the integrator prefers append-only, add
`activeDeliveryVerifyAndComplete` instead and leave the old key.

**Reused, no new key:** `offerSubmissionNoteLabel` is already exactly "Note (optional)";
`activeDeliveryProgressTitle` becomes the ordered/picked action-card heading;
`activeDeliveryDropOffLabel`, `activeDeliveryOpenMapsButton`, `activeDeliveryOpenChatButton`,
`activeDeliveryEnterGoodsCostButton` survive as Semantics labels.

---

## 11. Build order for this lane

1. Wait on kit steps 1 (`JeebOutlinedCard`/`JeebNavySurfaceCard`), 3 (`JeebTopBar`), 4
   (`JeebCtaButton`/`JeebCtaFooter` + the new `actionRow` form), 9 (`JeebStepper` + the new `bars`
   variant), 12 (`JeebAccentFrameCard`, `JeebCodeCells`).
2. Land the l10n batch (§10) through the integrator.
3. `delivery_status_stepper.dart` → bars (+ the two test edits in §8.2).
4. `active_delivery_jeeber_screen.dart` → column shell, top bar, drop-off card, docked footer,
   `_kInlineQuickActionsMinWidth` 448→320.
5. `mark_delivered_panel.dart` → accent frame card, tile row, code cells, CTA.
6. `handoff_tiles.dart` (new, screen-local) + its widget/RTL tests.
7. `dart analyze --fatal-infos .` (bar: zero new issues) + `tool/check_design_tokens.sh` +
   `flutter test test/features/active_delivery_jeeber/`.
8. Goldens ×3 regenerated in the Wave-5 sweep on the Mac Studio only.
