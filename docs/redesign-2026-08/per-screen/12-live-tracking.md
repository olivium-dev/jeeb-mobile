# 12 · Live tracking — change proposal

Screen id: `12-live-tracking` · Verdict: **rebuild** (structure changes; the feature's cubit/domain
layer is untouched)
Target file: `lib/features/live_tracking/presentation/live_tracking_screen.dart` (677 LOC) + its
`presentation/widgets/` tree.
Sources read: `screens/12-live-tracking.png` (image), `.html`, `.note.md`, `00-MIGRATION-PLAN.md`,
`02-PLAN-ENHANCED.md`, the whole `live_tracking` feature, and the 12 test files that touch it.

---

## 0. What the board actually is

Measured off `12-live-tracking.html` (440×956 canvas). Six blocks, top-aligned, one `flex:1`
spacer, one docked split footer. Content ends at **y ≈ 1120 / 1912** in the 2× render — **41 % of
the screen below the door-code strip is plain white** (R1). That emptiness is the change, not a
by-product.

| # | Block | Geometry from the HTML |
|---|---|---|
| 1 | In-body top bar | pad `14/24/0`, gap 12. Ø40 `surface-high` circle + 20px navy back glyph · title 17/w700 navy 1-line ellipsis (`Medicine — Pharmacie du Musée`) · sub 12/w600 periwinkle (`⚡ Flash · $8 cash`) · Ø40 `surface-high` circle + 19px navy chat glyph |
| 2 | 4-node stepper | pad `18/24/0`. Nodes Ø26; connectors `flex:1 h3 r9`, `margin-top 12`. done = navy + 14px white check; **active = orange + Ø8 white core + `0 0 0 5 rgba(215,59,0,.18)`**; pending = `2px surface-highest` ring, no fill. Labels 10.5px, gap 5: done w700 navy · active **w800 orange** · pending w600 periwinkle |
| 3 | Map | margin `16/24/0`, **height 250 (fixed, not flex)**, r20, clipped. Floating ETA pill at `14/14`: pad `7/13`, r999, white, `0 6 16 rgba(11,19,81,.18)`, 12.5/w700 navy. Courier mark Ø34 orange + 19px white scooter, `0 0 0 6 rgba(215,59,0,.22)` + `0 8 18 rgba(215,59,0,.45)`. Destination pin `#E02020`. Route = navy dotted polyline, `stroke-width 5`, `dasharray 1 11`, round caps |
| 4 | Courier card | margin `14/24/0`, pad `13/16`, **r16, 1.5px brown outline, NO shadow**, gap 12. Ø42 navy disc + white 15/w800 initial · title 15/w700 navy · sub 12/w600 periwinkle `★ 4.9 · Scooter · $8 cash on delivery` · trailing Ø40 `surface-high` circle + 18px navy phone glyph |
| 5 | Door-code strip | margin `12/24/0`, pad `12/16`, r16, `surface-high`, gap 12. 19px navy key glyph · label 12/w600 periwinkle `Door code — share only at handoff` · trailing **20/w800 navy, letter-spacing 5** `2144` |
| 6 | Footer | pad `0/24/30`, gap 12, two `flex:1` items h50. Start = text `Report no-show` 14/w600 brown-subtitle. End = outline pill r999 `1.5px` brown outline, 14/w600 navy `Open dispute` |

**Not on the board and not to be built:** the 440×956 device frame, the `9:41` status row, the fake
`#EDEDF2` map tiles / white road bars / green blocks (real Google tiles are used).

**The designer note is three-quarters already shipped.** "Order context pinned up top", "4-step
stepper", "no-show / dispute one tap away" and "door code always visible from accept time" all exist
today — the last one was the 2026-07-31 P0 that made `_HandoverCodeRow` unconditional
(`live_tracking_screen.dart:366-390`). The only genuinely new things on this screen are the **ETA
pill**, the **pulsing active stepper node**, the **orange courier marker + dotted route**, and the
**shape/weight/density rebuild**.

---

## 1. Layout & structure

### 1.1 Target tree

```
LiveTrackingScreen  ── Semantics(identifier:'tracking_root', container, explicitChildNodes)
 └ Scaffold(backgroundColor: cs.surface)        ← appBar: null   (OMDSAppBar DELETED)
   └ SafeArea(top: true)
     └ _ResumeRefresh → BlocConsumer → _TrackingStateView → _TrackingBody
        Column(
          OrderSummaryPinnedHeader(info, onBack, onOpenChat),      // block 1  (restyled, ids kept)
          Padding(16/24/0)  OrderTrackingStepper(...),             // block 2
          Expanded(child: SingleChildScrollView(child: Column(     // ← R1 spacer lives here
            Padding(16/24/0)  _TrackingMapBlock(...),              // block 3, fixed h250, r20
            if (info.jeeber != null)
              Padding(12/24/0)  TrackingCourierCard(...),          // block 4  (NEW, screen-local)
            if (isAtDoor) OtpAtDoorCard(...)                       // at-door branch (unchanged gate)
            else Padding(12/24/0) _HandoverCodeRow(...),           // block 5
            Padding(12/24/0)  DeliveryTrackingPanel(info),         // meta strip (restyled, see 1.4)
          ))),
          _TrackingActionBar(info, deliveryId),                    // block 6, docked
        )
```

Everything above `Expanded` is pinned; the scroll view exists **only** so 200 % text scale cannot
overflow-crash (DoD). At 1.0 scale the content does not fill it — the white lower third is real.

### 1.2 Deleted

| What | Where today | Why |
|---|---|---|
| `OMDSAppBar(title: l10n.trackingTitle, centerTitle: true)` | `live_tracking_screen.dart:69-73` | The board has **no app bar** — a 40px circle back button + an in-body two-line title. `trackingTitle` becomes an unused ARB key: **leave it** (l10n parity gate; unused keys are safe, deleted ones are not). No test asserts it. |
| `DeliveryTrackingPanel`'s internal 3-step `OMDSLabeledStepperProgress` | `delivery_tracking_panel.dart:55-87` | It renders Ordered/Picked/In-transit — the **same fact** as the 4-step `tracking_stepper` directly above it. Two steppers on one screen is a visible defect. Its `tracking_progress_stepper` identifier survives (see 1.4). |
| `_TrackingJeeberSection` → `DeliveryJeeberCard` | `live_tracking_screen.dart:574-591` | `DeliveryJeeberCard` lives in `lib/features/delivery_status/` — **another lane's tree** (§7.4). It is an `OMDSSectionCard` with a "Your Jeeber" heading, a `primaryContainer` avatar and a `tertiaryContainer` rating chip; none of that is the board. Stop importing it here; build `TrackingCourierCard` screen-local. `delivery_status` keeps its copy untouched. |
| `Expanded(flex: isAtDoor ? 1 : 2)` around the map | `live_tracking_screen.dart:358-361` | The board fixes the map at **250 px** and gives the rest to the spacer. A flexing map is what makes today's screen feel dense. |

### 1.3 Added

* `TrackingCourierCard` — new file `lib/features/live_tracking/presentation/widgets/tracking_courier_card.dart`.
* `TrackingEtaPill` — private widget inside `tracking_map_surface.dart`, `PositionedDirectional`
  over the map.
* A destination marker + a dotted navy route polyline in `tracking_google_map.dart`.
* A pulse animation on the active stepper node (kit-side; see §4).

### 1.4 `DeliveryTrackingPanel` becomes the quiet meta strip (the one real IA conflict)

The board carries **no distance line and no deadline line**, but `deadline` is **Q-061 / D18 — a
locked product decision** ("the LOCKED absolute delivery deadline, frozen at order creation"),
and `distanceLabel` is a real gateway field. They cannot be dropped because a render omits them.

Rebuild the panel in place (it is this lane's file, and keeping the widget means
`semantics_identifier_surfacing_test.dart` B1 and `order_tracking_screen_test.dart`'s panel harness
still pump the same class):

```
Semantics(identifier:'tracking_status_panel', container: true, explicitChildNodes: true)
 └ Semantics(identifier:'tracking_progress_stepper', container: true,
             value: <current stage label>)          ← semantics-only compatibility node
   └ Wrap(spacing: Spacing.small, runSpacing: Spacing.twoXSmall)   // 12/w600, one line at 1.0×
       Semantics(id:'tracking_distance_label', liveRegion: true) Text('3 km away')
       Semantics(id:'tracking_deadline_label')     Text('Arrives by 3:45 PM')
```

* `FractionallySizedBox(widthFactor: 0.78)` is deleted — the strip is gutter-to-gutter like every
  other block (R1: nothing on this board is centre-inset).
* `tracking_progress_stepper` keeps **exactly its historical contract**: a queryable node whose
  `value` is the current stage label (`delivery_tracking_panel.dart:64-71` does the same today).
  This is the §7.5 "re-home value-identical" rule, and it is what lets the legacy Maestro flow
  `.maestro/flows/16-order-tracking.yaml` keep resolving while the screen shows one stepper.
* `tracking_eta_label` **moves out of the panel and onto the map ETA pill** — see §1.5. Maestro
  `16-order-tracking.yaml:80` asserts it by id only, so it stays green.

### 1.5 `OrderSummaryPinnedHeader` becomes the top bar (the second IA conflict)

The board folds the whole pinned summary into the top bar (`title` = item, `subtitle` = tier +
cash) and the courier card. But the header's six identifiers are frozen and asserted in three
places — `semantics_identifier_surfacing_test.dart` C1 (all five display leaves),
`tracking_header_overflow_test.dart` (the A33 "RIGHT OVERFLOWED BY 75 PIXELS" regression gate),
`tracking_open_chat_requestid_test.dart` (BUG-17), and Maestro `jm-031` AC4. Deleting the widget is
not available.

**Resolution — same shape as the plan's screen-21 C1 fix: restyle the container, keep every pinned
string inside it.** `OrderSummaryPinnedHeader` stops being a grey slab with a bottom radius and
becomes the board's in-body top bar:

```
Semantics(identifier:'order_summary_pinned', container: true, explicitChildNodes: true)
 └ JeebTopBar(
     leading: JeebTopBarLeading.back,  identifier: 'tracking_back',  onTap: <pop>,
     title:    info.itemSummary  (jeebText.titleProminent 17/w700, maxLines 1, ellipsis),
     subtitle: _MetaLine(...),                              ← the four pinned leaves
     trailing: JeebTopBarAction(icon: chat glyph 19px, identifier:'order_summary_open_chat',
                                onTap: onOpenChat),
   )
```

`_MetaLine` keeps the existing `Wrap` + `ConstrainedBox` construction verbatim (that IS the A33
overflow fix — see the 32-line doc comment at `order_summary_pinned_header.dart:167-201`; do not
turn it back into a `Row`), rendering four runs at `jeebText.bodySmall` in `mutedText`:

| Run | Identifier | Content | Notes |
|---|---|---|---|
| 1 | `order_summary_tier` | `⚡ Flash` | emoji from `JeebTierChip.emojiFor(tierId)` (kit-owned lexicon, §9-Q7) + `LiveTrackingL10n.tierName`. **Not a pill** — the board draws inline text here, see §3 |
| 2 | `order_summary_price` | `$8` | LTR-isolated (`MixedDirectionText`, already a dependency of this feature) |
| 3 | `order_summary_cash_label` | visible `cash`, `Semantics(label: l10n.summaryCashLabel)` | board's short word visually, the full D11 "Pay cash on delivery" to screen readers |
| 4 | `order_summary_eta` | `20 min` / `ETA pending` | see the divergence note below |

`order_summary_jeeber_name` moves to the **courier card's title** (`Karim is on the way`) — the
board's own placement, and C1's surfacing test pumps `OrderSummaryPinnedHeader` standalone and
expects the leaf inside it. ⚠ **That means the name leaf must stay in the header.** Keep it in the
header as the run that the board *does* draw there — it does not draw a name there at all. Concrete
answer: keep `order_summary_jeeber_name` in the header as a **zero-visual-cost fifth run only when
`info.jeeberName` is set and no courier card will mount** is dishonest; instead, keep the leaf on
the header's *title semantics* — `Semantics(identifier:'order_summary_jeeber_name', child: …)`
wrapping the courier name run appended to the meta line (`⚡ Flash · $8 cash · Karim · 20 min`)
would over-fill a 12px line. **Owner-visible decision (R-12-A):** the least-bad option is to keep
the jeeber-name leaf in the meta line and drop the ETA run, since the board draws neither and the
ETA has a real home on the map pill. Either choice edits exactly one test file. My recommendation:
**keep both leaves in the meta line at `bodySmall`, order `tier · price · cash · name · eta`, and
let the `Wrap` stack to a second run at large text scales** — zero test edits, one extra 12px line
the board does not draw. Flagged in §9 as divergence D-12-1.

`onTrack` stays `null` (self-navigation), the `hasSummary` gate stays, and the `OmdsPrimaryButton`
CTA row at `order_summary_pinned_header.dart:123-154` is deleted (the chat CTA is now the top-bar
circle, so `order_summary_open_chat` moves with it — `tracking_open_chat_requestid_test.dart` taps
it by identifier and stays green).

---

## 2. Tokens — every hardcoded value that must change

Wave 0 is landed: use `context.jeebText`, `JeebShadows`, `context.jeebRoles`,
`Theme.of(context).extension<JeebSemanticColors>()!`, `context.omdsColorTokens`. Do **not** create
new theme constants.

| File:line | Today | Becomes |
|---|---|---|
| `live_tracking_screen.dart:69` | `OMDSAppBar(...)` | deleted → `JeebTopBar` inside the header widget |
| `:342-347`, `:419-424`, `:494-500`, `:582-587`, `:601-604` | `Spacing.medium` (16) horizontal gutters | `Spacing.xLarge` (24) — §4.3 `--screen-gutter` |
| `:509` | `theme.colorScheme.surfaceContainerHighest` (code-row fill) | `colorScheme.surfaceContainerHigh` — board `--jeeb-surface-high` `#EAE7EB` |
| `:510`, `:512` | `OmdsBorderRadius.medium` | keep (16 ✓, board r16) — delegated to `JeebInfoNote` |
| `:522-524` | `Icon(Icons.key_outlined, size: Sizes.medium, color: onSurfaceVariant)` | `Icons.vpn_key_outlined`, `size: Sizes.large` (20 ≈ board 19), `color: colorScheme.primary` (board draws it **navy**, not brown) |
| `:533-535`, `:539-541` | `labelMedium` / `bodySmall` `.copyWith(onSurfaceVariant)`, two stacked lines | one line, `context.jeebText.bodySmall` (12/w600), ink `colorScheme.onSurfaceVariant` — see the AA note in §7 |
| `:550-559` | `titleLarge`/`titleSmall` `.copyWith(FontWeight.bold, letterSpacing: Spacing.xSmall /*8*/)` | `JeebCodeCells.strip` (kit: 20/w800, ls **5**, LTR isolate). The `letterSpacing: Spacing.xSmall` is a spacing token used as a type metric — a token-misuse to delete. |
| `:557` | `theme.colorScheme.primary` for the "Show OTP" fallback ink | `context.jeebRoles.accent` (the CTA-ish decaying affordance) |
| `:431-447`, `:455-465` | `OmdsPrimaryButton(variant: text / outlined)` | `JeebCtaFooter.split(leading: JeebCtaButton.text, trailing: JeebCtaButton.outline)` — h50, r999, `1.5px colorScheme.outline`, `jeebText.button.copyWith(fontSize)`→ kit-internal 14/w600 |
| `:450` | `SizedBox(width: Spacing.small)` between CTAs | `JeebCtaFooter` owns the 12px gap |
| `order_summary_pinned_header.dart:53-56` | `surfaceContainerHighest` fill + bottom `OMDSBorderRadius.lg` | **no fill, no radius** — the board's top bar sits on `colorScheme.surface` |
| `:70-71`, `:84-85` | `titleMedium.copyWith(w700)` ×2 | title → `context.jeebText.titleProminent`; price run → `context.jeebText.bodySmall` |
| `:107-108`, `:117-120`, `:213` | `bodySmall` / `labelMedium.copyWith(primary, w600)` | `context.jeebText.bodySmall`, ink `JeebSemanticColors.mutedText` |
| `order_tracking_stepper.dart:61-65` | `OMDSStepperProgress(progressColor: primary)` | deleted — the connectors are part of `JeebStepper` |
| `:113-121` | `Icon(check_circle / radio_button_checked / radio_button_unchecked, size: Sizes.large, color: primary|onSurfaceVariant)` | `JeebStepper` nodes: Ø26 navy+white check / Ø26 `jeebRoles.accent` + Ø8 white core + `JeebShadows.stepGlow` / Ø26 ring `2px surfaceContainerHighest` |
| `:128-131` | `bodySmall.copyWith(color, w600|w400)` | `context.jeebText.label` (10.5/w700) done-navy · `jeebText.badge` (10.5/w800) active-`jeebRoles.accent` · `label.copyWith(w600)` pending-`mutedText` |
| `delivery_tracking_panel.dart:53` | `_panelWidthFactor = 0.78` + `FractionallySizedBox` | deleted |
| `:76` | `progressColor: colorScheme.tertiary` | deleted with the 3-step stepper (and `.tertiary` is the banned spelling anyway — `jeebRoles.accent` is the sanctioned orange) |
| `:163-166` | `labelLarge.copyWith(onSecondaryContainer, w600)` | `context.jeebText.bodySmall`, ink `JeebSemanticColors.mutedText` |
| `tracking_map_surface.dart:82-88` | `Container(color: surfaceContainerHighest)`, full-bleed | `ClipRRect(borderRadius: OmdsBorderRadius.large /*20*/)` over a `SizedBox(height: _kMapHeight)`; `_kMapHeight = 250.0` as a named private const (a bare `SizedBox(height: 250)` trips `tool/check_design_tokens.sh`; `delivery_tracking_panel.dart:53` is the existing precedent for a named const) |
| `:110-111` | `onSurfaceVariant.withValues(alpha: UIConstants.opacityMedium)` placeholder glyph | keep |
| `otp_at_door_card.dart:50-62` | `surface` + hand-rolled `BoxShadow(shadow, .12, blur Sizes.small, offset (0,-2))` + `BorderRadius.vertical(top: Sizes.large)` | `JeebAccentFrameCard(filled: true)` — accent fill + `JeebShadows.accentBanner` (§5 #5, the 13 arrival-banner treatment) |
| `:70`, `:77` | `titleMedium` / `bodyMedium` | `context.jeebText.cardTitle` / `context.jeebText.body` |
| `tracking_google_map.dart:114` | `Polyline(width: 5)`, default blue | `color: <navy passed in>`, `patterns: [PatternItem.dot, PatternItem.gap(11)]`, `startCap/endCap: Cap.roundCap`, `jointType: JointType.round` |

**No `Color(0x…)` / `Colors.*` / `fontSize:` / `BorderRadius.circular(N)` may appear in any of
these files** — `tool/check_design_tokens.sh` scans `lib/features`, and `tracking_google_map.dart`
is inside it, so the polyline/marker colors must be **passed in from the widget** as parameters
(`trackingPolylines(info, {Color? routeColor})`, `trackingMarkers(info, {BitmapDescriptor?
courierIcon, BitmapDescriptor? destinationIcon})`). Optional named params keep
`tracking_google_map_test.dart` and `tracking_live_position_overlay_test.dart` compiling unchanged.

---

## 3. Shared components this screen consumes

| Kit widget (§5) | Used for | Notes / what this lane needs from it |
|---|---|---|
| **#1 `JeebTopBar`** | block 1 | `leading: back` + **real `trailing` slot** (the chat glyph). Must accept `identifier` on both leading and trailing, plus a `subtitle` **widget** slot (not a String) — this screen's subtitle is four semantics leaves, not one `Text`. |
| **#11 `JeebStepper`** | block 2 | The whole of `OrderTrackingStepper` becomes a wrapper. **Hard requirements:** per-node `Semantics(identifier:, container: true, selected: isActive, value: label)` — `tracking_lifecycle_bodies_test.dart` d/e read `node.value` and `node.identifier`. Also needs a `pulse` flag on the active node (§4). |
| **#22 `JeebInfoNote`** *(tone `muted`, trailing `value`)* | block 5, door code | The plan already names 12 as a consumer with "value: 12's `2 1 4 4`". Needs `onTap` (the row routes to `/orders/{id}/otp`) and a `trailing` **widget** slot. |
| **#12 `JeebCodeCells`** *(variant `strip`)* | the `2144` | 20/w800, ls 5, **one `Text`, LTR isolate**. Must forward a `key` (or be wrapped in `KeyedSubtree`) — `live_tracking_handover_code_test.dart:189/219` does `find.byKey(Key('tracking.codeRowValue'))`, and `find.text('1234')` must still match, so the strip may **not** split digits into per-character widgets. |
| **#3 `JeebOutlinedCard`** | block 4 | white, `1.5px colorScheme.outline`, **r16**, **no shadow**, pad `13/16`. |
| **#9 `JeebAvatar`** *(Ø42)* | block 4 | navy fill, white 15/w800 initial, **`imageUrl` fallback to initial**. See §5 — the avatar URL **is** available; the plan says otherwise and is wrong. No presence/unread dot on this screen. |
| **#2 `JeebCtaFooter.split` + `JeebCtaButton`** | block 6 | `text` variant (`onSurfaceVariant` 14/w600) + `outline` variant (h50 pill, `1.5px outline`, navy 14/w600), both `Expanded`, gap 12, pad `0/24/32`. |
| **#5 `JeebAccentFrameCard(filled)`** | at-door branch | replaces `OtpAtDoorCard`'s hand-rolled top-radius + shadow. |
| **#7 `JeebTierChip`** | ❌ **not used** | The plan lists 12 as a `JeebTierChip` consumer. **Measured, it is not:** `12-live-tracking.html:19` renders `⚡ Flash · $8 cash` as plain 12/w600 periwinkle text — there is no pill on this screen. This lane needs only `JeebTierChip.emojiFor(tierId)` exposed as a static so the emoji lexicon (§9-Q7) stays centralised. |

Nothing else. `JeebMeter`, `JeebSelectChip`, `JeebWaveform`, `JeebMicHero` do not appear on 12.

---

## 4. New functionality (and what it needs from the cubit/state)

| Behaviour | Data source | Verdict |
|---|---|---|
| **ETA pill on the map** — `Arriving in 20 mins` | `DeliveryTrackingInfo.etaMinutes` (exists; parsed in all three factories) | **Buildable today, no cubit change.** Hidden entirely when `etaMinutes == null` (nothing to say) — the header's ETA run keeps the honest `ETA pending` form. |
| **Pulsing active stepper node** | none | **Buildable, kit-side.** A `TweenAnimationBuilder`/`AnimationController` scaling the `JeebShadows.stepGlow` spread. Must respect `MediaQuery.disableAnimationsOf(context)` (DS: "functional and gentle — no bounce, no decorative loops"), and must **not** animate on `TrackingStage.delivered`. Cheap, but it is the only continuously-running animation on the screen — do not attach it to a rebuild-heavy subtree. |
| **Orange courier marker** | `info.jeeberPosition` + `markerIsLive` (exist) | **Buildable, no new deps.** Rasterise a Ø34 accent disc + white scooter glyph once via `ui.PictureRecorder` → `BitmapDescriptor.bytes(...)` (present in `google_maps_flutter_platform_interface` 2.16.0, shipped under the pinned `google_maps_flutter: 2.17.1`). Generate lazily, cache in `_TrackingGoogleMapState`, and **fall back to the current default marker if generation throws** — a marker that fails to draw must not remove the pin. The `markerIsLive` gate (`delivery_tracking_info.dart:521-524`) stays the only predicate that decides whether a marker exists at all: the phantom-pin negative control is not negotiable. |
| **Dotted navy route** | `info.polyline` (exists) | **Buildable.** `PatternItem.dot` + `PatternItem.gap(11)` matches the HTML `stroke-dasharray="1 11"` exactly. |
| **Destination pin** | derived: `info.polyline.last` when `polyline.length >= 2` | **Derivation of existing fields** (§7.6 allows it). Gate strictly on length ≥ 2 and use `BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)` (no color literal). ⚠ The polyline's semantics — pickup→dropoff — is asserted only in a code comment (`tracking_google_map.dart:102-105`). If the gateway ever returns a courier-trail polyline instead, `.last` is the courier, not the door. **Risk, not a blocker;** listed in §9. |
| **`★ 4.9` on the courier card** | `JeeberSummary.rating` | ❌ **REFUSED — see §8/C3.** |
| **Call button on the courier card** | `JeeberSummary.phoneE164` | ❌ **REFUSED — see §8/C3.** |
| Door code "always visible from accept time" (the note's headline claim) | `LiveTrackingState.handoverCode` | **Already shipped.** `live_tracking_screen.dart:366-390` made the row unconditional on 2026-07-31 after the hardware dead-end. No work; do not re-gate it on `handoverCode != null` while restyling — that regression is what the P0 fixed. |

**No cubit or state change is required by this screen.** `LiveTrackingCubit`, `LiveTrackingState`
and `DeliveryTrackingInfo` are untouched. The Q-061 pilot-fidelity grep
(`tracking_pilot_fidelity_guard_test.dart`) bans `geolocator` / `background_gps` /
`GeolocationService` anywhere under `lib/features/live_tracking/` — the marker work touches
`google_maps_flutter` only, which is already there.

---

## 5. Corrections to the plan (verified in code, not inferred)

1. **`avatarUrl` is NOT destroyed by the parser.** `00-MIGRATION-PLAN.md` §6-W4 and
   `02-PLAN-ENHANCED.md` C3 both state that `fromTrackingJson` "nulls `phoneE164`, `rating` AND
   `avatarUrl`". `_parseJeeber` (`delivery_tracking_info.dart:434-439`) **reads `avatarUrl` and
   passes it through**; the doc comment at `:419-420` lists only phone and rating as withheld.
   `delivery_tracking_jeeber_parse_test.dart:63` expects null only because that fixture *sends*
   null, and `:26-29` proves the opposite when a URL is present. **So `JeebAvatar` on this screen
   should render the photo when there is one**, with the initial disc as the fallback — which is
   also what `order_tracking_jeeber_card_test.dart:88-91` asserts today (`find.byType(Image)`).
   Building "initial disc only" would break a green test for no reason.
2. **12 is not a `JeebTierChip` consumer** (§3 above).
3. **The plan's §5 #1 `JeebTopBar` title spec (`jeebText.h2`, 20px) is wrong for this screen** — 12's
   title is 17/w700 = `titleProminent`, because it is the two-line variant. The kit must expose the
   two-line form with a 17px title, not scale `h2` down.

---

## 6. New routes

**None.** `/orders/:id/tracking` (name `live-tracking`) already exists at
`app_router.dart:1339-1401`, keeps its `?deliveryId=` precedence
(`resolveTrackingDeliveryId`), its `useLiveMap: true`, its `RefreshTopic.order` push wiring, its
`HandoverCodeStore` hydration and its `backFallbacks['live-tracking'] = '/'` entry
(`back_nav_all_routes_test.dart:105` pins it as a must-wrap deep-link target).

⚠ The new in-body back circle must pop through the **same** path the deleted `OMDSAppBar` used, i.e.
`Navigator.maybePop` / the ambient `RootAwareBackScope`, **not** a hardcoded `context.go('/')` —
otherwise the wrapped-route contract silently degrades for the push/deep-link entry.

---

## 7. Semantics identifiers

### 7.1 Frozen — every one must still be emitted (27 on this surface)

| Identifier | Today | After |
|---|---|---|
| `tracking_root` | screen root | unchanged |
| `order_summary_pinned` | pinned header root | header root (now the top bar) |
| `order_summary_jeeber_name` | header row 1 | header meta line (see D-12-1) |
| `order_summary_price` | header row 1 | header meta line, run 2 |
| `order_summary_tier` | header fact strip | header meta line, run 1 |
| `order_summary_eta` | header fact strip | header meta line, run 4 |
| `order_summary_cash_label` | header | header meta line, run 3 (visible `cash`, `label:` = full D11 string) |
| `order_summary_open_chat` | header CTA row | **top-bar trailing Ø40 circle** |
| `order_summary_track` | header (null on this surface) | unchanged — still null here |
| `tracking_stepper` | `OrderTrackingStepper` root | unchanged |
| `tracking_step_ordered` / `_picked` / `_in_transit` / `_delivered` | per-step nodes | unchanged, **`value` + `selected` preserved** |
| `tracking_map` | map surface wrapper | unchanged (now inside the `ClipRRect`) |
| `tracking_position_notice` | `CourierPositionNotice` | unchanged, still bottom-anchored on the map |
| `tracking_status_panel` | panel root | meta-strip root |
| `tracking_progress_stepper` | 3-step OMDS stepper | semantics-only node, `value` = stage label (§1.4) |
| `tracking_distance_label` | panel | meta strip |
| `tracking_eta_label` | panel | **map ETA pill** (`liveRegion: true` preserved) |
| `tracking_deadline_label` | panel | meta strip |
| `tracking_handover_code_row` | code row | the `JeebInfoNote` door-code strip |
| `tracking_at_door_code` | `HandoverCodeDisplay` in the at-door card | unchanged |
| `tracking_otp_cta` | at-door CTA | unchanged (`qa_keys_batch_test.dart:266`) |
| `tracking_noshow_cta` / `tracking_dispute_cta` | action bar | footer, unchanged |
| `tracking_noshow_sheet` / `_reassign_cta` / `_rebroadcast_cta` / `_keep_cta` | sheet | untouched |
| `tracking_cancelled_state` / `_home_cta`, `tracking_expired_state` / `_home_cta`, `tracking_under_review_state` | lifecycle bodies | untouched (restyle only: `OmdsEmptyState` + `JeebCtaButton`) |

Widget `Key`s that must survive: `tracking_map` (`TrackingMapSurface.rootKey`),
`tracking_status_panel` (`DeliveryTrackingPanel.rootKey`), `live-tracking-cancelled-state`,
`live-tracking-expired-state`, `live-tracking-under-review-state`, `live-tracking-error-state`,
`tracking-cancelled-home-cta`, `tracking-expired-home-cta`, `tracking.codeRowValue`,
`tracking.atDoorCode`, `tracking.otpCta`.

`DeliveryJeeberCard.rootKey` (`delivery-status-jeeber-card`) **leaves this screen** — it belongs to
`delivery_status` and stays alive there. See §8.

### 7.2 New identifiers

| Identifier | Element | Convention |
|---|---|---|
| `tracking_back` | top-bar Ø40 back circle | `<screen>_back` (§5 #1 owns this contract) |
| `tracking_courier_card` | `TrackingCourierCard` root (`container: true`, `explicitChildNodes: true`) | `<screen>_<element>` |

Deliberately **not** added: `tracking_courier_call_cta` (refused, §8).

---

## 8. Conflicts — refused, with reasons

**C3 (refused): the courier card's `★ 4.9` and its Ø40 call button.**
`DeliveryTrackingInfo._parseJeeber` never reads `phoneE164` or `rating`
(`delivery_tracking_info.dart:423-440`), and `delivery_tracking_jeeber_parse_test.dart:44-64`
asserts both stay null *even when the wire leaks them* — an explicit blind-reveal / privacy guard,
not a data gap. Ship the card as **avatar (photo or initial) + `Karim is on the way` + `Scooter ·
$8 cash on delivery`**, with **no star and no call button**. Do not add
`// TODO(redesign-24): needs gateway rating` — the field is refused, not missing. If the owner wants
a call affordance on tracking it must route through the existing gate
(`DeliveryStatusCubit.requestContactNumber()` → `DeliveryStatusError.contactUnavailable`,
`delivery_status_cubit.dart:105-111`), which is a cross-feature change outside this lane.
**Owner decision, unchanged from the plan.**

**Refused: the board's periwinkle instruction copy on the door-code strip.** `--jeeb-periwinkle`
`#777FC0` on `--jeeb-surface-high` `#EAE7EB` is ≈ 3.6:1 — below AA, and
`color_role_contrast_test.dart` already pins "periwinkle fails on white" as a guard the migration
keeps. `Door code — share only at handoff` is an **instruction**, not a qualifier, so it renders in
`colorScheme.onSurfaceVariant` (`#5C4038`, ≈ 7.3:1 on that fill). Purely-qualifying runs (tier /
price / vehicle) keep `mutedText` per R4. Raised globally in §9.

**Not a conflict (checked, so no lane refuses it by mistake):** the four stepper labels map onto the
existing `TrackingStage` enum through `LiveTrackingL10n.stepOrdered/_picked/_inTransit/_delivered`
and the at-door relabel (P6/A5) — no fifth stage, no reorder (C10 satisfied). The screen shows no
commission/fee line, so D41/D44 do not apply. There is no cancel affordance here, so the
"no pre-accept cancel endpoint" rule is not touched.

---

## 9. Divergences from the board (deliberate, listed for review)

* **D-12-1 — the meta line carries two runs the board does not draw** (`Karim` and `20 min`), because
  `order_summary_jeeber_name` and `order_summary_eta` are pinned by
  `semantics_identifier_surfacing_test.dart` C1 and `tracking_header_overflow_test.dart` and must
  surface from inside `OrderSummaryPinnedHeader`. Cost: one extra 12px line's worth of text.
  Alternative (owner call): move either leaf to its board-drawn home (name → courier card, ETA →
  map pill) and edit the two test files. Zero-risk either way; I default to no test edits.
* **D-12-2 — ETA appears twice** (meta run + map pill) as a consequence of D-12-1. Today it also
  appears twice (header `ETA: 20 min` + panel `Estimated time: 20 min`), so this is not a regression.
* **D-12-3 — the meta strip (distance + locked deadline) is not on the board.** Q-061/D18 makes the
  deadline a locked product fact; dropping it because a render omits it would be a silent product
  change. It renders as the quietest line on the screen, below the door code, above the spacer.
* **D-12-4 — one stepper, two identifiers.** The board has one stepper; the app has two
  (`tracking_stepper` 4-step, `tracking_progress_stepper` 3-step). The visual duplicate is deleted;
  the identifier is kept as a semantics node with its historical `value` contract.
* **D-12-5 — map fill.** The board's `#EDEDF2` tiles are mock chrome; real Google tiles ship. Only
  the r20 clip, the 250px height, the ETA pill, the dotted navy route and the orange marker are real.

**Risks:**
1. Wave 1 has not landed — `lib/core/widgets/jeeb/` does not exist yet. This screen consumes eight
   kit widgets and **cannot start** before build-order steps 1–4, 6 and 9 (§5.1). `JeebStepper` is
   step 9 and is the long pole.
2. The custom courier `BitmapDescriptor` is the only genuinely new engineering here. If rasterising
   proves flaky on the S22, fall back to the default marker — never to no marker.
3. `polyline.last == destination` is asserted only in a comment. Gate the destination pin on
   `length >= 2` and confirm against a real gateway response before shipping it.
4. Periwinkle-on-white / periwinkle-on-grey is under AA at every size the board uses it. This screen
   makes a local call (§8); the integrator should rule on it once, board-wide.

---

## 10. Test impact

| Test | Effect | Legitimate? |
|---|---|---|
| `test/features/live_tracking/tracking_lifecycle_bodies_test.dart` (5) | **Must stay green as-is.** `tracking_stepper` present/absent, `tracking_step_in_transit` `node.value` = `At Door` / `In transit`. This is the acceptance gate on `JeebStepper`'s semantics contract. | n/a |
| `test/live_tracking_handover_code_test.dart` (7) | `find.text('Delivery code')` ×2 → the strip's visible copy becomes `Door code — share only at handoff`. `find.text('1234')`, `Key('tracking.codeRowValue')`, `Key('tracking.atDoorCode')`, `Key('tracking.otpCta')`, `Show OTP`, the AR at-door string all stay green. | **Yes** — copy genuinely changed; discoverability (the P0 the test guards) is unchanged. |
| `test/order_tracking_screen_test.dart` (5) | 3 panel tests break: `find.text('Ordered'/'Picked'/'In transit')` (3-step stepper deleted) and `find.text('Estimated time: 20 min')` (ETA moved to the pill). `Distance updating…`, the RTL test and the map-surface key test stay green. | **Yes** — the duplicated stepper is a design defect the board removes. Rewrite against the new strip; keep the AR mirroring assertion. |
| `test/order_tracking_jeeber_card_test.dart` (2) | Breaks: asserts `DeliveryJeeberCard.rootKey` on this screen and that it sits above `DeliveryTrackingPanel.rootKey`. | **Yes** — the card is replaced by `TrackingCourierCard` and the order changes (map → courier → code → strip). Re-point at `tracking_courier_card`; **keep** the `find.byType(Image)` assertion (the avatar URL is real, §5-1) and the ordering assertion against the new anchors. |
| `test/semantics_identifier_surfacing_test.dart` B1 + C1 | Green **if** the panel keeps `tracking_status_panel` + `tracking_progress_stepper` and the header keeps all five leaves — which is exactly why §1.4/§1.5 are written the way they are. | n/a |
| `test/features/live_tracking/tracking_header_overflow_test.dart` (7) | Must stay green. The `Wrap` + `ConstrainedBox` construction is the fix under test — **do not** revert it to a `Row` while restyling. Re-run at A33 geometry, AR, 200 %, unmapped tier, 7-figure price. | n/a |
| `test/features/live_tracking/tracking_open_chat_requestid_test.dart` | Green — taps `order_summary_open_chat` by identifier; it just lives on the top-bar circle now. | n/a |
| `test/qa_keys_batch_test.dart` B-6 | Green — `tracking_otp_cta` + `Key('tracking.otpCta')` survive the `JeebAccentFrameCard` restyle. | n/a |
| `test/tracking_google_map_test.dart`, `tracking_live_position_overlay_test.dart`, `tracking_position_status_test.dart`, `tracking_cancelled_state_test.dart`, `tracking_not_found_state_test.dart`, `live_tracking_cubit_test.dart`, `delivery_tracking_jeeber_parse_test.dart` | Green — pure domain/cubit, or identifier-based. Keep `trackingMarkers`/`trackingPolylines` params **optional named** so these compile unchanged. | n/a |
| `test/features/live_tracking/tracking_pilot_fidelity_guard_test.dart` | Green — no banned dependency added. | n/a |
| `test/core/router/*` (`back_nav_all_routes_test`, `tracking_map_placeholder_route_test`) | Green — route, `useLiveMap: true` and `backFallbacks` unchanged. **Only if** the new back circle pops rather than `go`s. | n/a |
| Maestro `jm-032-order-tracking.yaml`, `jm-031-order-summary-pinned.yaml`, `16-order-tracking.yaml` | All ids preserved → green. **Not in CI** — re-run `16-order-tracking.yaml` manually on the S22, it is the only consumer of `tracking_progress_stepper` / `tracking_status_panel` / `tracking_distance_label` / `tracking_eta_label`. | n/a |

Net: **3 test files edited, 0 identifiers renamed, 0 gates weakened.**

New tests to add: `tracking_courier_card_test.dart` (no star, no call button, avatar photo →
initial fallback, AR mirroring) and an ETA-pill test (`tracking_eta_label` on the map, absent when
`etaMinutes == null`).

---

## 11. RTL

| Item | Hazard | Build it as |
|---|---|---|
| Top-bar back glyph | `Icons.arrow_back` points the wrong way in AR | `DirectionalIcons.back(context)` (`lib/core/widgets/directional_icons.dart:16`) |
| Top bar leading/trailing | fixed left/right | `Row` + `EdgeInsetsDirectional`; the kit owns it |
| Stepper | node/connector order | plain `Row` — auto-mirrors; connector "passed" state is index-based and mirrors with it. Do **not** use `Positioned` or `Stack` offsets. |
| ETA pill on the map | `Positioned(left: 14)` pins it to the wrong corner in AR | `PositionedDirectional(start: Spacing.medium, top: Spacing.medium)` |
| `CourierPositionNotice` overlay | already `PositionedDirectional` (`tracking_map_surface.dart:94-98`) | unchanged |
| Door code `2144` | Arabic-Indic digit shaping / bidi reordering | `JeebCodeCells` wraps digits in an LTR isolate (kit contract) |
| `$8` / `$8 cash on delivery` | currency symbol jumps in RTL | `MixedDirectionText` (already imported by `delivery_tracking_panel.dart:6`) or a `⁦…⁩` isolate |
| `Arrives by 3:45 PM` | already locale-formatted via `DateFormat.jm(localeTag)` (`delivery_tracking_panel.dart:141`) | keep — it renders `٣:٤٥ م` in AR |
| Meta line | `Wrap` run direction | `Wrap` follows ambient `Directionality`; keep it, do not set `textDirection` |
| Footer | text button start / pill end | plain `Row` of two `Expanded` — auto-mirrors |
| Google map | tiles + markers are not mirrored | correct and intentional; only the pill and the notice mirror |

The existing AR assertions to keep passing: `order_tracking_screen_test.dart:75-89` (`تم الطلب`,
`Directionality.rtl`), `live_tracking_handover_code_test.dart:225-257`
(`شارك هذا الرمز مع جيبرك عند وصوله`), `tracking_header_overflow_test.dart` (AR at 200 %).

---

## 12. l10n

Integrator-owned batch (§7.4, 4-edit recipe: EN key + `@description` → real AR → `_get` getter →
call site). New keys:

| Key | EN | AR |
|---|---|---|
| `trackingArrivingIn` | `Arriving in {minutes} min` | `الوصول خلال {minutes} دقيقة` |
| `trackingCourierOnTheWay` | `{name} is on the way` | `{name} في الطريق` |
| `trackingCashOnDelivery` | `{amount} cash on delivery` | `{amount} نقداً عند التسليم` |
| `trackingDoorCodeNote` | `Door code — share only at handoff` | `رمز الباب — شاركه عند التسليم فقط` |
| `trackingCashShort` | `cash` | `نقداً` |
| `trackingNoShowCta` | `Report no-show` | `الإبلاغ عن عدم الحضور` |
| `trackingDisputeCta` | `Open dispute` | `فتح نزاع` |

The last two currently live in the feature-local stopgap `live_tracking_l10n.dart:57-59`, whose own
doc comment lists them as awaiting the integrator. Until the batch lands, update the stopgap strings
in place (this lane owns that file); no test asserts the old copy. Reuse without change:
`trackingCodeChipLabel` (Semantics label), `trackingAtDoorCta` (`Show OTP` fallback),
`trackingStepOrdered/_Picked/_InTransit/_Completed`, `activeDeliveryStatusAtDoor`,
`summaryCashLabel`, `trackingDistanceAway`, `trackingDistanceUnknown`, `trackingDeadlineLocked`,
`trackingMapSemanticLabel`. `trackingTitle` becomes unused — **leave it in both ARBs**.
