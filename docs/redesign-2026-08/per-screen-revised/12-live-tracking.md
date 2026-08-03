# 12 · Live tracking — REVISED instruction set (authoritative)

Screen id: `12-live-tracking` · Verdict: **rebuild** (presentation only; cubit/state/domain untouched)
Feature dir (the ONLY code you may edit): `lib/features/live_tracking/` + this screen's test files.

Review status: every `file:line` in the original proposal was opened and checked. Line citations
were accurate (±2). Four claims were corrected, three items were cut as scope creep, and the
back-navigation recipe was replaced with the repo's actual precedent. Everything below is verified
against the tree at review time.

---

## A. Reviewer verdicts (what changed vs the proposal)

**Cut (not evidenced by the board):**
1. `OtpAtDoorCard` restyle to `JeebAccentFrameCard(filled)` + its typography changes. The at-door
   state is not on the board, and the plan's `JeebAccentFrameCard` consumer list (§5 #5: 13 16 18
   20 24) does not include 12. **Do not touch `otp_at_door_card.dart` at all.** Its ids/keys
   (`tracking_otp_cta`, `tracking_at_door_code`, `Key('tracking.otpCta')`, `Key('tracking.atDoorCode')`)
   stay green for free (`qa_keys_batch_test.dart` B-6 pumps it standalone).
2. Lifecycle terminal bodies "restyle only: OmdsEmptyState + JeebCtaButton". Not on the board.
   Leave `_TrackingCancelledBody` / `_TrackingExpiredBody` / `_TrackingUnderReviewBody` /
   `_TrackingErrorBody` byte-identical **except** for the back-affordance fix in Task 4.
3. The "Show OTP" fallback ink change `colorScheme.primary → jeebRoles.accent` in the code row.
   The no-cached-code state is not drawn on the board; navy is the board's ink for that strip's
   trailing slot. Keep `colorScheme.primary`.

**Corrected:**
1. **Back recipe.** The proposal's "Navigator.maybePop, NEVER context.go('/')" is wrong on a
   deep-link root: `maybePop` no-ops there and leaves a dead button (`RootAwareBackScope` only
   intercepts SYSTEM back via `BackButtonListener` — `lib/core/router/root_aware_back_scope.dart:48`).
   The repo precedent for in-body back buttons (settings_screen.dart:121, client_offers_screen.dart:152,
   wallet ×3, jeeber_pending_offers:124) is:
   `context.canPop() ? context.pop() : context.go('/')` — and `'/'` is exactly
   `backFallbacks['live-tracking']`. Use that.
2. **Deleting the app bar deletes back from five view states.** `OrderSummaryPinnedHeader` mounts
   only when `info.hasSummary` (`price != null && jeeberName` non-empty —
   `delivery_tracking_info.dart:566`), and not at all in loading / error / cancelled / expired /
   under-review. A screen-local `_TrackingBackBar` (back circle only, same `tracking_back`
   identifier) must mount in every state where the header does not. Only one emitter of
   `tracking_back` is ever in the tree at once.
3. **The ETA pill must not vanish when `etaMinutes == null`.** Maestro
   `.maestro/flows/16-order-tracking.yaml:80` does `assertVisible id: "tracking_eta_label"` and the
   fixture's ETA cannot be guaranteed. The pill renders whenever `info != null`:
   known → `l10n.trackingArrivingIn(minutes)`, unknown → the existing pending copy
   (`LiveTrackingL10n.summaryEtaPending`). `liveRegion: true` preserved.
4. **Test-impact arithmetic.** `find.text('Delivery code')` appears on **4** lines of
   `live_tracking_handover_code_test.dart` (not 2), and in `order_tracking_screen_test.dart` the
   **RTL test also breaks** (it asserts `find.text('تم الطلب')`, which is the deleted 3-step
   stepper's first label) — so 4 of its 5 tests need rewriting, not 3.
5. **Meta-strip ink.** Distance + deadline are *facts*, not qualifiers (R4: navy/onSurfaceVariant =
   fact, periwinkle = qualifier), and `mutedText` (#777FC0) on white fails AA by the repo's own
   pinned guard. Render the strip lines in `colorScheme.onSurfaceVariant`, not `mutedText`.
6. **Plan-correction #3 (JeebTopBar title) softened.** The plan's own typography table already says
   `titleProminent` 17/w700 = "two-line bar titles" (00-MIGRATION-PLAN.md:215), so the kit's
   two-line variant should use it without any spec fight. It is a wiring note, not a plan defect.

**Confirmed and kept (the proposal was right, verified in code):**
- `_parseJeeber` passes `avatarUrl` through and never reads `phoneE164`/`rating`
  (`delivery_tracking_info.dart:423-440`); `delivery_tracking_jeeber_parse_test.dart:44-64` pins the
  withholding even when the wire leaks them. **Courier card ships with NO star and NO call button
  — this is a privacy contract, not a data gap. No TODO comment for it.**
- `order_tracking_jeeber_card_test.dart:88-91` asserts `find.byType(Image)` — the avatar must render
  the photo when a URL exists, initial disc as fallback.
- Screen 12 is **not** a `JeebTierChip` consumer: `12-live-tracking.html:19` draws `⚡ Flash · $8 cash`
  as plain 12/w600 periwinkle text. Only `JeebTierChip.emojiFor(tierId)` is needed (wiring).
- `markerIsLive` (`delivery_tracking_info.dart:521-524`) stays the only marker predicate.
- A bare `SizedBox(height: 250)` trips `tool/check_design_tokens.sh` ("SizedBox literal number");
  the named private const pattern is required.
- All 27 frozen identifiers and 11 widget Keys listed in §D below.
- D-12-1 default (keep `order_summary_jeeber_name` + `order_summary_eta` as extra meta-line runs,
  zero test edits) — `tracking_header_overflow_test.dart:141-162` requires tier/eta/price ids from
  the standalone header, including `order_summary_tier` **findsNothing when tier is null**, so the
  tier-run gate must stay.

---

## B. Preconditions (check before writing any code)

Wave 0 is landed (verified in tree: `context.jeebText` incl. `titleProminent/bodySmall/label/badge/button`,
`JeebShadows.floatPill/stepGlow`, `context.jeebRoles.accent`, `JeebSemanticColors.mutedText`).

Wave 1 is NOT verifiable from this review — **STOP and report if any of these kit widgets is missing
from `lib/core/widgets/jeeb/`:** `JeebTopBar`, `JeebStepper`, `JeebOutlinedCard`, `JeebAvatar`,
`JeebCtaButton`/`JeebCtaFooter`, `JeebInfoNote`, `JeebCodeCells`, `JeebTierChip` (for `emojiFor`).
Do not hand-roll a local copy of a kit widget; the screen waits on the kit lane.

---

## C. Tasks, dependency-ordered

### Task 1 — Write the wiring file
Create `docs/redesign-2026-08/wiring/12-live-tracking.md` with **exactly** the content of §G below.
Then write all screen code as if every request is granted (l10n getters exist, kit slots exist).
Until the ARB batch lands, the seven new strings live in `live_tracking_l10n.dart` (Task 2) so the
lane compiles standalone.

### Task 2 — `live_tracking_l10n.dart` (feature-owned stopgap)
- Change `disputeCta` → `_pick('Open dispute', 'فتح نزاع')` and `noShowCta` →
  `_pick('Report no-show', 'الإبلاغ عن عدم الحضور')` (board copy; verified no test asserts the old
  strings).
- Add stopgap getters: `arrivingIn(int minutes)`, `courierOnTheWay(String name)`,
  `cashOnDelivery(String amount)`, `doorCodeNote`, `cashShort` with the EN/AR pairs from §G.
- Extend the file's "Delete this file once the integrator adds:" doc list with the five new keys.

### Task 3 — `order_summary_pinned_header.dart` → the in-body top bar
Keep the widget, its name, its `hasSummary`-gated mount, `onTrack: null`, and **all six identifiers
inside it**. Replace the grey slab with:

```
Semantics(identifier: 'order_summary_pinned', container: true, explicitChildNodes: true)
 └ JeebTopBar(
     leading: back circle, identifier: 'tracking_back',
       onTap: () => context.canPop() ? context.pop() : context.go('/'),
     title: Text(info.itemSummary ?? l10n.trackingTitle,   // reuses the existing ARB key
                 style: context.jeebText.titleProminent, maxLines: 1, overflow: ellipsis),
     subtitle: _MetaLine(...),
     trailing: onOpenChat == null ? null :
       chat circle carrying Semantics(identifier: 'order_summary_open_chat', button: true),
   )
```

- Delete the `surfaceContainerHighest` fill + bottom `OMDSBorderRadius.lg` (:52-57) and the
  `OmdsPrimaryButton` CTA row (:123-154). `order_summary_open_chat` moves to the trailing circle —
  `tracking_open_chat_requestid_test.dart:105` taps by identifier and stays green.
- `_MetaLine` = the existing `_HeaderFactStrip` **construction verbatim** (LayoutBuilder +
  ConstrainedBox-per-run + Wrap; that IS the A33 overflow fix, doc comment :167-201 — never a Row),
  extended to five runs at `context.jeebText.bodySmall`, ink `JeebSemanticColors.mutedText`
  (qualifier ink, board-drawn):
  1. `order_summary_tier` — `JeebTierChip.emojiFor(tierId)` + `l10n.tierName(tier)`, **no
     "Tier:" prefix, not a pill**; run absent when tier null/empty (overflow test pins this).
  2. `order_summary_price` — keep `_formatPrice(price, currency)` unchanged, wrapped in
     `MixedDirectionText` (import from `../../../mixed_direction/presentation/mixed_direction_text.dart`
     — import only, no edit to that feature).
  3. `order_summary_cash_label` — `Semantics(identifier: ..., label: l10n.summaryCashLabel,
     excludeSemantics: true, child: Text(l10n.trackingCashShort))` — visible short word, full D11
     string to screen readers.
  4. `order_summary_jeeber_name` — `Text(info.jeeberName ?? '')` (D-12-1: pinned by C1, stays here).
  5. `order_summary_eta` — existing `ETA: … / ETA pending` composition unchanged (D-12-1/D-12-2).
- No visible `·` separators — Wrap spacing only (RTL-safe; minor divergence from the board, noted).

### Task 4 — `live_tracking_screen.dart` scaffold + body
1. `appBar:` deleted → `Scaffold(backgroundColor: colorScheme.surface, body: …)`. Leave
   `trackingTitle` in both ARBs (it is now the title fallback in Task 3, so it is not even unused).
2. New private `_TrackingBackBar`: `Padding(EdgeInsetsDirectional.fromSTEB(Spacing.xLarge,
   Spacing.small, Spacing.xLarge, 0))` → Ø40 `surfaceContainerHigh` circle, 20px
   `DirectionalIcons.back(context)` glyph in `colorScheme.primary`,
   `Semantics(identifier: 'tracking_back', button: true)`, same canPop-else-go tap. Mount it above
   the body in `loading`, `error`, `cancelled`, `expired`, `under-review` states and in
   `_TrackingBody` when `!info.hasSummary`. (Wrap each state body in a
   `Column[_TrackingBackBar, Expanded(existing body)]` at the `_TrackingStateView` level for the
   non-ready modes — the terminal bodies themselves stay untouched.)
3. `_TrackingBody` target tree:
   ```
   SafeArea(top: true)
    └ Column(
        info.hasSummary ? OrderSummaryPinnedHeader(...) : _TrackingBackBar(),
        Padding(STEB(xLarge, medium, xLarge, 0)) OrderTrackingStepper(...),
        Expanded(child: SingleChildScrollView(child: Column(
          Padding(STEB(xLarge, medium, xLarge, 0)) _TrackingMapBlock(...),   // Task 6
          if (info.jeeber != null)
            Padding(STEB(xLarge, small+2→Spacing.small, xLarge, 0)) TrackingCourierCard(...),
          if (isAtDoor) OtpAtDoorCard(...)                                    // UNCHANGED widget
          else ...[ _HandoverCodeRow(...),                                    // Task 5 restyle
                    _TrackingPanelSection(info) ],                            // Task 7 restyle
        ))),
        _TrackingActionBar(info, deliveryId),                                 // Task 8 restyle
      )
   ```
   The scroll view exists only so 200% text scale cannot overflow; at 1.0× the lower third is
   deliberately white (R1). Gutters: every `Spacing.medium` horizontal gutter in this file's
   sections (:342-347, :419-424, :494-500, :582-587, :601-604) becomes `Spacing.xLarge`.
4. Keep byte-identical: `_ResumeRefresh`, `BlocConsumer` wiring, `_onEvent` navigation, the
   BUG-17 `onOpenChat` requestId-precedence closure, the `isAtDoor` gate, and the **unconditional**
   `_HandoverCodeRow` mount (the 2026-07-31 P0 — do NOT re-gate it on `handoverCode != null`).

### Task 5 — `_HandoverCodeRow` restyle (same file)
`JeebInfoNote(tone: muted, onTap: → context.push('/orders/$deliveryId/otp'))` — fill
`surfaceContainerHigh`, r16 (`OmdsBorderRadius.medium`), pad 12/16, gap 12:
- Outer `Semantics` **contract unchanged**: `identifier: 'tracking_handover_code_row'`,
  `button: true`, `label: l10n.trackingCodeChipLabel`, `value:` code-split-or-CTA exactly as today
  (:501-507).
- Leading: `Icons.vpn_key_outlined`, `size: Sizes.large` (20 ≈ board 19), `color: colorScheme.primary`
  (board draws the key navy).
- Label: ONE line, `l10n.trackingDoorCodeNote` at `context.jeebText.bodySmall`, ink
  `colorScheme.onSurfaceVariant` (instruction copy — the board's periwinkle fails AA on
  `surface-high`; refusal stands, flag stays in §F).
- Trailing (must keep `Key('tracking.codeRowValue')` on the visible text in BOTH branches, and
  `find.text('1234')` must match one Text — no per-digit splitting):
  - code known → `JeebCodeCells.strip(code, key: Key('tracking.codeRowValue'))` (20/w800, ls 5,
    LTR isolate — kit contract, §G).
  - code null → `Text(l10n.trackingAtDoorCta, key: …)` in `colorScheme.primary` (ink unchanged — cut #3).
- Delete the two stacked label/hint lines (:528-545) and the `letterSpacing: Spacing.xSmall`
  token-misuse (:555).

### Task 6 — `tracking_map_surface.dart`: fixed map + ETA pill
1. In the screen: replace `Expanded(flex: isAtDoor ? 1 : 2)` (:358-361) with the padded block from
   Task 4.3. In the surface widget: `static const double _kMapHeight = 250.0;` (named const —
   token-gate requirement; precedent `delivery_tracking_panel.dart:53`) → `SizedBox(height:
   _kMapHeight)` → `ClipRRect(borderRadius: OmdsBorderRadius.large /*20*/)`. The
   `Semantics(identifier: 'tracking_map', image: true, label: l10n.trackingMapSemanticLabel)` and
   `TrackingMapSurface.rootKey` stay on the wrapper OUTSIDE the clip
   (`tracking_google_map_test.dart:157` + `order_tracking_screen_test` key probe).
2. `_MapBody` always stacks now. Add private `_TrackingEtaPill` rendered whenever `info != null`:
   `PositionedDirectional(start: Spacing.medium, top: Spacing.medium)` →
   `Semantics(identifier: 'tracking_eta_label', liveRegion: true)` → Container(pad
   `EdgeInsetsDirectional.symmetric(horizontal: Spacing.small, vertical: Spacing.twoXSmall+…)` ≈ 7/13
   → use `vertical: Spacing.xSmall`, `horizontal: Spacing.small`), `color: colorScheme.surface`,
   `borderRadius: OmdsBorderRadius.pill`, `boxShadow: JeebShadows.floatPill`, text
   `context.jeebText.bodySmall.copyWith(fontWeight: FontWeight.w700)` in `colorScheme.primary`.
   Copy: `etaMinutes != null ? l10n.arrivingIn(minutes) : l10n.summaryEtaPending` (correction #3).
3. `CourierPositionNotice` overlay stays bottom-anchored, untouched (:94-98 already
   `PositionedDirectional`).

### Task 7 — `delivery_tracking_panel.dart` → quiet meta strip
- Delete: `FractionallySizedBox` + `_panelWidthFactor` (:27-29, :53), the 3-step
  `OMDSLabeledStepperProgress` `_TrackingStepper` visual (:55-87 — incl. the banned
  `colorScheme.tertiary` at :76), and `_TrackingEtaLine` (:108-125; the id moves to the pill).
- New tree (rootKey `Key('tracking_status_panel')` moves to the new top-level child):
  ```
  Semantics(identifier: 'tracking_status_panel', container: true, explicitChildNodes: true)
   └ Semantics(identifier: 'tracking_progress_stepper', container: true,
               explicitChildNodes: true, value: <current stage label>)   // historical contract
     └ Wrap(spacing: Spacing.small, runSpacing: Spacing.twoXSmall)
         Semantics(id 'tracking_distance_label', liveRegion: true) MixedDirectionText(...)
         if (deadline != null) Semantics(id 'tracking_deadline_label', liveRegion: true) MixedDirectionText(...)
  ```
  `value:` keeps the 3-label vocabulary via the existing `_stepLabels` composition (same getters,
  same `trackingStepIndex` collapse) so the node's historical `value` contract is unchanged.
- Line style: `context.jeebText.bodySmall`, ink `colorScheme.onSurfaceVariant` (correction #5).
- Keep `DateFormat.jm(localeTag)` deadline formatting (:141) and both existing copy getters
  (`trackingDistanceAway/Unknown`, `trackingDeadlineLocked`). D-12-3 stands: the strip is not on
  the board but D18/Q-061 locks the deadline — it renders as the quietest line, below the door code.

### Task 8 — `_TrackingActionBar` → `JeebCtaFooter.split`
`JeebCtaFooter.split(leading: JeebCtaButton.text(l10n.noShowCta), trailing:
JeebCtaButton.outline(l10n.disputeCta))` — kit owns h50 / r999 / 1.5px `colorScheme.outline` /
gap 12 / pad `0/24/32`. Keep the existing `Semantics(identifier: 'tracking_noshow_cta' /
'tracking_dispute_cta', button: true)` wrappers and the exact callbacks (TrackingNoShowSheet.show
with reassign→`offer-review` / rebroadcast→`waiting-no-coverage`; dispute→`escalate`). The
requestId-fallback local stays `final`.

### Task 9 — `order_tracking_stepper.dart` → `JeebStepper` wrapper
Delete `OMDSStepperProgress` (:61-65) and `_StepNode` (:86-137). The widget becomes:
`Semantics(identifier: 'tracking_stepper', container: true, explicitChildNodes: true)` around
`JeebStepper(currentIndex: currentStep, labels: [stepOrdered, stepPicked, atDoor ? stepAtDoor :
stepInTransit, stepDelivered], stepIdentifiers: _stepIds, pulseActive: currentStep < 3)`.
Node/connector/label visuals are the KIT's job (§G request 3) — do not restyle locally. The
acceptance gate is `tracking_lifecycle_bodies_test.dart` d/e: per-node `Semantics(identifier:,
container: true, selected:, value: label)` must survive, with `node.value == 'At Door'` under the
P6/A5 relabel and identifier still `tracking_step_in_transit`. No fifth step, no reorder.
Padding moves to the call site (Task 4.3).

### Task 10 — new file `presentation/widgets/tracking_courier_card.dart`
`TrackingCourierCard({required JeeberSummary jeeber, double? price, String? currency})`:
```
Semantics(identifier: 'tracking_courier_card', container: true, explicitChildNodes: true)
 └ JeebOutlinedCard(r16, pad 13/16)   // white, 1.5px colorScheme.outline, NO shadow
     Row(gap 12):
       JeebAvatar(size Ø42, imageUrl: jeeber.avatarUrl, initialFrom: displayName)  // photo→initial fallback
       Column: Text(l10n.courierOnTheWay(displayName), context.jeebText.cardTitle, navy, 1-line ellipsis)
               MixedDirectionText('<vehicleLabel> · ' + l10n.cashOnDelivery(<formatted price>),
                                   context.jeebText.bodySmall, mutedText)   // qualifier ink, board-drawn
```
- Price formatting: the header's `_formatPrice` logic (extract it to a small shared helper inside
  this feature or duplicate the 3 lines — do not invent a `$`-symbol mapper).
- Price/currency null → subtitle degrades to vehicleLabel alone.
- **NO star, NO rating, NO call button, no TODO** (§A confirmed refusal).
- In the screen: `_TrackingJeeberSection` now builds this card; delete the
  `delivery_status/.../delivery_jeeber_card.dart` and `jeeber_summary.dart`… — keep the
  `JeeberSummary` import (domain type, read-only) and delete only the `DeliveryJeeberCard` import.
  `delivery_status` keeps its own copy untouched.

### Task 11 — `tracking_google_map.dart`: route + markers
1. `trackingPolylines(info, {Color? routeColor})` — optional named param (existing tests compile
   unchanged): `color: routeColor ?? <current default>`, `patterns: [PatternItem.dot,
   PatternItem.gap(11)]`, `startCap/endCap: Cap.roundCap`, `jointType: JointType.round`, keep
   `width: 5`, `geodesic: false`. The widget passes `routeColor:
   Theme.of(context).colorScheme.primary` (no color literal in this file — token gate).
2. `trackingMarkers(info, {BitmapDescriptor? courierIcon, BitmapDescriptor? destinationIcon})` —
   `markerIsLive` stays the ONLY courier-marker predicate (phantom-pin negative control is not
   negotiable). Destination pin: mount only when `info.polyline.length >= 2`, position
   `polyline.last`, icon `destinationIcon ?? BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueRed)`.
   (Risk stays open: `polyline.last == dropoff` is asserted only by the comment at :104-105 —
   confirm against one real gateway response before shipping; do not block on it.)
3. Courier icon: rasterise once in `_TrackingGoogleMapState` (lazy, cached) — Ø34 disc in
   `context.jeebRoles.accent` + white `Icons.two_wheeler` glyph via
   `ui.PictureRecorder`/`TextPainter` → `BitmapDescriptor.bytes(...)`
   (available in the pinned `google_maps_flutter 2.17.1` stack — no new dependency). Wrap
   generation in try/catch and **fall back to the default marker, never to no marker**. Colors come
   from the theme at build time and are passed into the pure function.
4. No cubit/state change anywhere. `tracking_pilot_fidelity_guard_test.dart` bans
   geolocator/background_gps/GeolocationService under this feature — the marker work touches
   `google_maps_flutter` only.

### Task 12 — tests
Edit (3 files, legitimately impacted):
1. `test/live_tracking_handover_code_test.dart` — the **4** `find.text('Delivery code')` probes →
   the new visible copy (`Door code — share only at handoff`). Everything else
   (`find.text('1234')`, `Show OTP`, all Keys, the AR at-door instruction :225-257) must pass
   UNEDITED.
2. `test/order_tracking_screen_test.dart` — rewrite 4 of 5 against the new strip: drop the 3-step
   label probes and `Estimated time:` probes; keep the `trackingStepIndex` domain assertions, the
   rootKey probe, the map-surface key test, and the RTL test's `Directionality.rtl` assertion with
   a new text probe (e.g. the distance line `'3 كم'…` — whatever `trackingDistanceAway` renders in AR).
3. `test/order_tracking_jeeber_card_test.dart` — re-point at `tracking_courier_card`; **keep** the
   `find.byType(Image)` assertion (avatar photo is real) and the ordering assertion against the
   new anchors (map above card, card above the code row).

Add (2 files):
4. `test/features/live_tracking/tracking_courier_card_test.dart` — no `★`, no phone glyph/call
   affordance, photo→initial fallback, AR mirroring.
5. An ETA-pill test — `tracking_eta_label` present on the map surface with `etaMinutes: 20` AND
   with `etaMinutes: null` (pending copy — this pins correction #3), `liveRegion` set.

Must stay green with ZERO edits: `tracking_lifecycle_bodies_test.dart` (5),
`semantics_identifier_surfacing_test.dart` B1+C1, `tracking_header_overflow_test.dart` (7),
`tracking_open_chat_requestid_test.dart`, `qa_keys_batch_test.dart` B-6,
`tracking_google_map_test.dart`, `tracking_live_position_overlay_test.dart`,
`tracking_position_status_test.dart`, `tracking_cancelled_state_test.dart`,
`tracking_not_found_state_test.dart`, `live_tracking_cubit_test.dart`,
`delivery_tracking_jeeber_parse_test.dart`, `tracking_pilot_fidelity_guard_test.dart`,
`test/core/router/back_nav_all_routes_test.dart`, `tracking_map_placeholder_route_test.dart`.

### Task 13 — verify
1. `flutter analyze` — no NEW errors/warnings (baseline: 11 issues / 6 errors pre-existing, all
   SDK-skew; do not fix, do not count).
2. `bash tool/check_design_tokens.sh` — zero violations in `lib/features/live_tracking/`.
3. Run every test file named in Task 12.
4. RTL smoke: pump `_TrackingBody` under `Locale('ar')` — top bar mirrors (back glyph via
   `DirectionalIcons.back`), pill pins to the START corner, stepper order mirrors (plain Row —
   no Stack offsets), digits stay LTR-isolated.

---

## D. Frozen surface — every identifier and Key, spelled exactly

Identifiers (27): `tracking_root` · `order_summary_pinned` · `order_summary_jeeber_name` ·
`order_summary_price` · `order_summary_tier` · `order_summary_eta` · `order_summary_cash_label` ·
`order_summary_open_chat` · `order_summary_track` (still absent/null here) · `tracking_stepper` ·
`tracking_step_ordered` · `tracking_step_picked` · `tracking_step_in_transit` (value+selected
contract) · `tracking_step_delivered` · `tracking_map` · `tracking_position_notice` ·
`tracking_status_panel` · `tracking_progress_stepper` (semantics-only, value = stage label) ·
`tracking_distance_label` · `tracking_eta_label` (→ map pill, liveRegion) ·
`tracking_deadline_label` · `tracking_handover_code_row` · `tracking_at_door_code` ·
`tracking_otp_cta` · `tracking_noshow_cta` · `tracking_dispute_cta` · `tracking_noshow_sheet` (+
`_reassign_cta`/`_rebroadcast_cta`/`_keep_cta`) · `tracking_cancelled_state`/`_home_cta` ·
`tracking_expired_state`/`_home_cta` · `tracking_under_review_state`.

New (2, convention `<screen>_<element>`): `tracking_back` (top-bar/back-bar circle) ·
`tracking_courier_card`. Deliberately NOT added: `tracking_courier_call_cta`.

Keys: `tracking_map` (TrackingMapSurface.rootKey) · `tracking_status_panel`
(DeliveryTrackingPanel.rootKey — re-homed inside the widget, same value) ·
`live-tracking-cancelled-state` · `live-tracking-expired-state` · `live-tracking-under-review-state` ·
`live-tracking-error-state` · `tracking-cancelled-home-cta` · `tracking-expired-home-cta` ·
`tracking.codeRowValue` (BOTH trailing branches) · `tracking.atDoorCode` · `tracking.otpCta`.

`DeliveryJeeberCard.rootKey` leaves this screen (it belongs to `delivery_status` and stays alive there).

---

## E. Stop conditions

**Done means:** the six board blocks render (in-body top bar, 4-node stepper with orange glowing
active node, fixed 250px r20 map with ETA pill + dotted navy route + orange courier marker,
outlined courier card without star/call, muted door-code strip with the w800 code, split text/outline
footer); every §D identifier/Key emits, spelled identically; Task 12's green list passes unedited;
the 3 edited + 2 new test files pass; analyze and the token gate are clean per Task 13; back works
by tap AND system gesture in all seven view states, LTR and RTL.

**Do NOT touch:** `otp_at_door_card.dart` · the four terminal/error body widgets (beyond the Task-4
back-bar mount around them) · `live_tracking_cubit.dart` / `live_tracking_state.dart` /
`delivery_tracking_info.dart` / anything in `data/` or `domain/` · `courier_position_notice.dart` ·
`tracking_noshow_sheet.dart` · `handover_code_display.dart` (otp_handover feature) ·
`delivery_status/**` (incl. `DeliveryJeeberCard`) · `lib/core/**` (router, DI, theme, kit widgets) ·
`lib/l10n/*.arb` · `pubspec.yaml` · any Maestro flow · `semantics_identifier_surfacing_test.dart`,
`tracking_header_overflow_test.dart`, `tracking_lifecycle_bodies_test.dart`,
`delivery_tracking_jeeber_parse_test.dart`, `qa_keys_batch_test.dart` (these encode the contracts —
if one goes red, the code is wrong, not the test). No new routes (`/orders/:id/tracking` +
`backFallbacks['live-tracking']` already exist and are untouched). No endpoint/field invention —
ETA, polyline, position, avatarUrl, handoverCode, deadline, distanceLabel all already exist in
`DeliveryTrackingInfo`.

---

## F. Open flags for the integrator (do not resolve locally)

1. Periwinkle-under-AA is refused locally three times on this screen (door-strip instruction, meta
   strip facts → `onSurfaceVariant`); the board uses it at every size. Needs ONE board-wide ruling.
2. `polyline.last == dropoff` is comment-asserted only — confirm against a live gateway response.
3. D-12-1/D-12-2: the meta line carries name + ETA runs the board does not draw (test-pinned);
   ETA appears twice (header + pill), as it already does today. Owner may later move either leaf
   at the cost of exactly one test-file edit each.
4. Maestro `16-order-tracking.yaml` is not in CI — re-run manually on the S22 after this lands
   (it is the only external consumer of the panel/strip identifiers).

---

## G. Wiring file content (paste verbatim into `docs/redesign-2026-08/wiring/12-live-tracking.md`)

```markdown
### l10n
file: lib/l10n/app_en.arb + lib/l10n/app_ar.arb (+ AppLocalizations getters)
need: Seven tracking-redesign strings; feature-local stopgap `live_tracking_l10n.dart` carries them until this lands, then the stopgap getters swap to these keys.
exact change:
  app_en.arb:
    "trackingArrivingIn": "Arriving in {minutes} min",
    "@trackingArrivingIn": {"description": "Floating ETA pill on the live-tracking map (screen 12).", "placeholders": {"minutes": {"type": "int"}}},
    "trackingCourierOnTheWay": "{name} is on the way",
    "@trackingCourierOnTheWay": {"description": "Courier-card title on live tracking.", "placeholders": {"name": {"type": "String"}}},
    "trackingCashOnDelivery": "{amount} cash on delivery",
    "@trackingCashOnDelivery": {"description": "Courier-card subtitle money qualifier (D11 — customer-facing, no commission).", "placeholders": {"amount": {"type": "String"}}},
    "trackingDoorCodeNote": "Door code — share only at handoff",
    "@trackingDoorCodeNote": {"description": "Door-code strip label on live tracking."},
    "trackingCashShort": "cash",
    "@trackingCashShort": {"description": "Short cash qualifier in the tracking top-bar meta line; screen readers get summaryCashLabel instead."},
    "trackingNoShowCta": "Report no-show",
    "@trackingNoShowCta": {"description": "Tracking footer start action (board copy)."},
    "trackingDisputeCta": "Open dispute",
    "@trackingDisputeCta": {"description": "Tracking footer end action (board copy)."}
  app_ar.arb:
    "trackingArrivingIn": "الوصول خلال {minutes} دقيقة",
    "trackingCourierOnTheWay": "{name} في الطريق",
    "trackingCashOnDelivery": "{amount} نقداً عند التسليم",
    "trackingDoorCodeNote": "رمز الباب — شاركه عند التسليم فقط",
    "trackingCashShort": "نقداً",
    "trackingNoShowCta": "الإبلاغ عن عدم الحضور",
    "trackingDisputeCta": "فتح نزاع"
why: Board copy for the pill, courier card, door-code strip and footer; screen 12 compiles today off the LiveTrackingL10n stopgap and swaps call-sites when these land.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_top_bar.dart
need: Screen 12 needs the two-line variant with (a) `identifier` params on leading AND trailing actions, (b) a `subtitle` WIDGET slot (its subtitle is four semantics leaves, not one Text), (c) the two-line title at `jeebText.titleProminent` 17/w700 per the plan's own typography table (00-MIGRATION-PLAN.md:215), not h2 scaled down.
exact change: `JeebTopBar({required JeebTopBarLeading leading, String? leadingIdentifier, VoidCallback? onLeadingTap, required Widget title, Widget? subtitle, JeebTopBarAction? trailing})` with `JeebTopBarAction({required Widget icon, required String identifier, required VoidCallback onTap})`.
why: 12's header carries `tracking_back` + `order_summary_open_chat` on the circles and five pinned semantics leaves in the subtitle line.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_stepper.dart
need: Per-node semantics contract + a pulse flag. Each node must emit `Semantics(identifier: stepIdentifiers[i], container: true, selected: isActive, value: labels[i])` — `tracking_lifecycle_bodies_test.dart` d/e reads `node.value` and `node.identifier` and is the acceptance gate. Active-node pulse (`pulseActive`) animates the `JeebShadows.stepGlow` spread only, must respect `MediaQuery.disableAnimationsOf(context)`, and callers disable it on the terminal step.
exact change: `JeebStepper({required int currentIndex, required List<String> labels, required List<String> stepIdentifiers, bool pulseActive = false})`; plain `Row` (auto-RTL), no Stack offsets.
why: Screen 12's `OrderTrackingStepper` becomes a thin wrapper; the four `tracking_step_*` ids and the P6/A5 At-Door relabel ride this contract.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_info_note.dart
need: `onTap` + a trailing WIDGET slot on the `muted` tone. 12's door-code strip is tappable (routes to `/orders/{id}/otp`) and its trailing is either `JeebCodeCells.strip` or a keyed CTA Text.
exact change: `JeebInfoNote({required JeebInfoNoteTone tone, required Widget leading, required Widget label, Widget? trailing, VoidCallback? onTap})` — when `onTap != null` wrap in Material/InkWell with the note's own radius.
why: The plan (§5 #22) already names 12 as the "trailing value: 2 1 4 4" consumer; without onTap the row loses its only unconditional route to the OTP screen (the 2026-07-31 P0).

### cross-feature
file: lib/core/widgets/jeeb/jeeb_code_cells.dart
need: The `strip` variant must render the code as ONE `Text` (no per-character widgets) inside an LTR isolate and forward a `key` to that Text.
exact change: `JeebCodeCells.strip(String code, {Key? textKey})` → one `Text(code, key: textKey)` at 20/w800/ls5.
why: `live_tracking_handover_code_test.dart:189/219` does `find.byKey(Key('tracking.codeRowValue'))` and `find.text('1234')` — per-digit splitting breaks both.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_tier_chip.dart
need: The tier→emoji lexicon exposed as a static so non-chip consumers stay centralised (§9-Q7). Screen 12 draws `⚡ Flash` as PLAIN TEXT (12-live-tracking.html:19), not a pill — it consumes only the emoji.
exact change: `static String emojiFor(String tierId)` (returns '' for unknown ids).
why: 12's top-bar meta line renders the emoji inline; duplicating the lexicon in the feature would fork it.
```

---

Task count: 13 (11 build + tests + verify). Wiring requests: 6 (1 l10n batch + 5 kit/cross-feature).
