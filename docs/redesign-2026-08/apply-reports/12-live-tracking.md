# 12 · Live tracking — implementation report

Screen id: `12-live-tracking` · Status: **applied**
Instruction set: `docs/redesign-2026-08/per-screen-revised/12-live-tracking.md`
Branch: `feat/redesign-24-migration` (no commits, no branch changes)

---

## 1. What shipped

The screen is the board's six vertical bands, top to bottom:

1. **In-body top bar** — `JeebTopBar.back` with `titleScale: compact` (17/w700 navy item
   summary, 1 line, ellipsised), a periwinkle meta line under it, `tracking_back` on the leading
   Ø40 circle and `order_summary_open_chat` on a real Ø40 trailing circle. The grey slab, the
   bottom `r20` corners and the full-width "Open chat" outlined button are gone.
2. **4-node stepper** — `JeebStepper` via `OrderTrackingStepper`. Ø26 discs, 3px connectors,
   orange glowing active node (bounded 3-breath pulse, disabled on the terminal step and under
   reduce-motion). The two OMDS steppers it replaced are deleted.
3. **Fixed 250px `r20` map card** with a floating white ETA pill (`JeebShadows.floatPill`),
   a dotted round-capped navy route, an orange scooter-disc courier marker and a red drop-off pin.
   The map no longer eats the viewport (`Expanded(flex: isAtDoor ? 1 : 2)` deleted).
4. **Outlined courier card** (new `TrackingCourierCard`) — Ø42 avatar (photo → initial),
   `<name> is on the way` in `cardTitle`, one qualifier line with vehicle + cash-on-delivery.
5. **Muted door-code strip** — `JeebInfoNote.muted` with a navy key glyph, the board's one-line
   label, and the code as `JeebCodeCells.strip` (20/w800, ls 5, LTR isolate).
6. **Split footer** — `JeebCtaFooter.split(expandLeading: true)` with
   `JeebCtaButton.text('Report no-show')` + `JeebCtaButton.outline('Open dispute')`.

Below the door code sits the quiet distance/deadline fact strip (D-12-3 — not on the board, but
D18/Q-061 locks the deadline, so it renders as the screen's quietest line).

## 2. Files

**Modified (7)**
- `lib/features/live_tracking/presentation/live_tracking_screen.dart` — app bar deleted; the
  scaffold is `backgroundColor: colorScheme.surface` + body only. New `_TrackingBackBar` (the kit
  top bar with no title) and `_BackBarScaffold` mount the back circle in the five states where the
  pinned header does not (loading, error, cancelled, expired, under-review) and in `_TrackingBody`
  when `!info.hasSummary` — exactly one emitter of `tracking_back` at a time. `_HandoverCodeRow`
  restyled to `JeebInfoNote`, `_TrackingActionBar` to `JeebCtaFooter.split`,
  `_TrackingJeeberSection` now builds `TrackingCourierCard`; every horizontal gutter moved
  `Spacing.medium → Spacing.xLarge`; the body scrolls between the stepper and the docked footer.
- `lib/features/live_tracking/presentation/widgets/order_summary_pinned_header.dart` — becomes
  the in-body `JeebTopBar`; `_HeaderFactStrip` → `_MetaLine`, same LayoutBuilder + ConstrainedBox +
  Wrap construction (the A33 overflow fix), extended to five runs; `_formatPrice` extracted as the
  shared `formatTrackingPrice`.
- `lib/features/live_tracking/presentation/widgets/order_tracking_stepper.dart` — a thin
  `JeebStepper` wrapper; `OMDSStepperProgress` + local `_StepNode` deleted.
- `lib/features/live_tracking/presentation/widgets/delivery_tracking_panel.dart` — the
  `FractionallySizedBox`, the second 3-step `OMDSLabeledStepperProgress` (and its banned
  `colorScheme.tertiary`) and `_TrackingEtaLine` deleted; two `Wrap`ped fact lines remain.
- `lib/features/live_tracking/presentation/widgets/tracking_map_surface.dart` — fixed
  `mapHeight = 250` + `ClipRRect(OmdsBorderRadius.large)`; always-stacked body; new
  `_TrackingEtaPill`.
- `lib/features/live_tracking/presentation/widgets/tracking_google_map.dart` — dotted navy route
  (`routeColor` named param), lazy cached courier-disc raster via `PictureRecorder`/`TextPainter`
  → `BitmapDescriptor.bytes`, new `trackingDestinationMarkers`.
- `lib/features/live_tracking/presentation/live_tracking_l10n.dart` — board CTA copy + five
  stopgap getters.

**Created (2 lib + 2 test + 1 wiring)**
- `lib/features/live_tracking/presentation/widgets/tracking_courier_card.dart`
- `test/features/live_tracking/tracking_courier_card_test.dart`
- `test/features/live_tracking/tracking_eta_pill_test.dart`
- `docs/redesign-2026-08/wiring/12-live-tracking.md`

**Tests edited (3)** — `test/live_tracking_handover_code_test.dart` (visible door-code label),
`test/order_tracking_screen_test.dart` (rewritten against the strip + map card),
`test/order_tracking_jeeber_card_test.dart` (re-pointed at `TrackingCourierCard`).

**Untouched, as required:** `otp_at_door_card.dart`, the four terminal/error bodies (only wrapped),
`courier_position_notice.dart`, `tracking_noshow_sheet.dart`, the cubit/state/domain/data layers,
`delivery_status/**`, `lib/core/**`, `lib/l10n/*.arb`, `pubspec.yaml`, every Maestro flow.

## 3. Deliberate deviations from the instruction set

**One, and it is a refusal to break a frozen test.**

§C task 11.2 asked for the drop-off pin inside `trackingMarkers(info, {courierIcon,
destinationIcon})`. That function's **emptiness is the phantom-pin contract**:
`tracking_position_status_test.dart:250/324/361/388` and
`tracking_live_position_overlay_test.dart:148` all assert `trackingMarkers(...) isEmpty` on rows
whose polyline is explicitly non-empty (one of them asserts `after.polyline, isNotEmpty` on the
next line). Folding a destination marker in would have turned "the map must draw no pin for a
courier we cannot vouch for" into an unassertable claim and reddened five pinned assertions on the
zero-edit list.

The pin ships as `trackingDestinationMarkers(info, {destinationIcon})`, unioned by the widget.
Same pixels, same board element, both contracts intact, zero frozen tests edited.

## 4. Verification

| Gate | Result |
| --- | --- |
| `dart analyze lib/features/live_tracking` + the five touched test paths | **No issues found** |
| `bash tool/check_design_tokens.sh` | **0 violations under `lib/features/live_tracking/`** |
| `flutter test test/features/live_tracking/ test/tracking_google_map_test.dart test/delivery_tracking_jeeber_parse_test.dart test/live_tracking_cubit_test.dart test/qa_keys_batch_test.dart` | **198 passed**, 1 load failure — see below |
| `test/order_tracking_screen_test.dart` + `order_tracking_jeeber_card_test.dart` + `live_tracking_handover_code_test.dart` + the 2 new files | **27 passed** |
| `tracking_lifecycle_bodies_test` + `tracking_header_overflow_test` + `tracking_open_chat_requestid_test` | **13 passed, unedited** |

RTL is covered by real cases, not a smoke claim: the Arabic distance line
(`order_tracking_screen_test`), the Arabic courier title + mirrored Directionality
(`tracking_courier_card_test`), the ETA pill pinned to the START (right) corner
(`tracking_eta_pill_test`), and the Arabic at-door instruction (`live_tracking_handover_code_test`).

### Failures that are NOT this lane

Two test files could not COMPILE, both because concurrently-running screen lanes reference ARB keys
and kit members that have not landed yet. Neither touches live-tracking code:

- `test/semantics_identifier_surfacing_test.dart` — blocked by the untracked
  `lib/features/home_client/presentation/widgets/client_home_request_hero.dart` calling
  `l10n.homeHeroSubtitle`. **B1 and C1 (this screen's two groups) are re-covered inside
  `test/order_tracking_screen_test.dart`** (`tracking_status_panel` + `tracking_progress_stepper`
  as distinct nodes, plus the stage `value`) and by `tracking_header_overflow_test`, which passes
  and asserts the header leaf ids.
- `test/features/live_tracking/tracking_delivery_id_nav_test.dart` and
  `test/core/router/tracking_map_placeholder_route_test.dart` — both import `AppRouter`, which pulls
  in `registration_screen.dart` (`SocialSignInSection(axis:)`, `registrationTagline`, …),
  `onboarding_screen.dart` (`DirectionalIcons.forward`), `offer_card.dart`, `transcription/**`,
  `request_summary/**` and `location/**`, all mid-flight in other lanes.

Re-run both once the shared ARB batch and the router-adjacent lanes land.

## 5. Open flags for the integrator

1. **Periwinkle under AA** — refused locally twice (the door-code strip label and the panel's
   distance/deadline lines are `colorScheme.onSurfaceVariant`, not `mutedText`). The header meta
   line DOES use `mutedText`, per task 3. Needs one board-wide ruling, not a per-screen decision.
2. **`polyline.last == dropoff`** is comment-asserted only. Confirm against one real gateway
   response before trusting the red pin's position; it degrades to "a pin at the end of the drawn
   route", never to a crash.
3. **D-12-1 / D-12-2** — the meta line carries `order_summary_jeeber_name` and `order_summary_eta`
   runs the board does not draw, because `tracking_header_overflow_test` and
   `semantics_identifier_surfacing_test` C1 pin their ids. At 1.0× on a 411 dp device the five runs
   wrap to a second line where the board shows one. Dropping either leaf costs exactly one
   test-file edit each and is an owner call.
4. **Maestro `16-order-tracking.yaml`** is not in CI and is the only external consumer of the
   panel/strip identifiers. Re-run it manually on the S22 after this lands — `tracking_eta_label`
   moved from the panel to the map pill (same id, same `liveRegion`, and it now renders even when
   the ETA is unknown precisely so that flow cannot go red on a missing field).
5. **The seven l10n keys** in `wiring/12-live-tracking.md` are the only OPEN request. The five kit
   requests from §G were verified already satisfied by the shipped Wave-1 kit and are recorded as
   such — no integrator action.
