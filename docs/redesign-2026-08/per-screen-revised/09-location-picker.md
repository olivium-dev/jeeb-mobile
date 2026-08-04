# 09 · Location picker — REVISED instruction set (authoritative)

Verdict: **rebuild** of `/capture-location` + **restyle-with-structure** of `/client-location`.

Review status: every `file:line` in the original proposal was opened and checked. All of them are
accurate (a rare proposal). What changed here: three test paths corrected, two selected-state
regressions in the blanket token rules fixed, four scope-creep items cut (JeebInfoNote conversion,
"SAVED PLACES" label, JeebSectionLabel on the phone field, two back-semantic l10n keys), the
kit-chip wiring request dropped in favour of the shipped `quickReply` role, and the step-chip
alternative demoted from a wiring request to an owner option.

---

## 0. Target files — the prompt is wrong, the repo map wins

The task prompt points at `lib/features/location/presentation/location_picker_screen.dart`. It is
dead: tagged `// ORPHAN (JEBV4-227, verified 2026-07-12)` at line 15; `/location` mounts a 36-LOC
placeholder; its only importer is the devtool catalog. `screen-repo-map.md` (rows 16/32-34/58) and
`00-MIGRATION-PLAN.md` both correct this. Verified true.

Edit these:

| Route | File | Role |
|---|---|---|
| `/capture-location` (`app_router.dart:1135`) | `lib/features/location/presentation/capture_location_screen.dart` (143 LOC) | full-screen map pin picker — the board's map-first screen lands HERE |
| `/client-location` (`app_router.dart:1124`) | `lib/features/location/presentation/client_location_screen.dart` (1155 LOC) | content + location + phone + `POST /requests` — restyled to the same language, NOT merged |

Do **not** merge the two screens. Merging would delete the `POST /requests` gate, the G1
description contract and the OTP recipient-phone capture — none of which the board draws.
`screen-repo-map.md` calls this split "the only board change that alters navigation — the
highest-risk item on the board".

### Never touch
- `location_picker_screen.dart`, `location_search_bar.dart`, `widgets/saved_locations_chip_row.dart`,
  `cubit/location_picker_*.dart` — the orphan picker subtree.
- `lib/core/router/app_router.dart` (incl. `CaptureLocationRoute` at :123-152 — its
  pop-without-coordinate behaviour is pinned by `pin_location_coordinate_survives_b35_test.dart`),
  `lib/core/di/injection_container.dart`, `lib/core/theme/*`, `lib/l10n/*.arb`, `pubspec.yaml`.
- `lib/features/request_type/**` (incl. `selectable_radio_glyph.dart` — you stop importing it,
  you do not edit or delete it), `lib/features/request_summary/**` (`compose_request_controller.dart`
  stays exactly as is).
- `lib/features/location/presentation/widgets/delivery_create_layout.dart` — it is in our feature
  but screens 07/08 render through it; the gutter change goes through wiring (W3), not a direct edit.
- Any existing l10n key or its value ("Pin Location", "Confirm location", "Choose your location",
  "Current Location", "New Location" are all pinned by `find.text`).

---

## 1. Frozen contract — all verified in source

### Semantics identifiers (spelled identically, all must still be emitted)

`client_location_screen.dart`: `location_select_new_location_cta` (:415) ·
`location_select_saved_addresses_row` (:522) · `location_select_saved_address_${address.id}` (:579) ·
`location_select_saved_addresses_error` (:669) · `location_select_confirm_cta` (:727) ·
`compose_description_input` (:951) · `compose_description_mic` (:966) · `recipient_phone_input` (:1085)

widgets: `client_location_option_current` (`client_location_option_card.dart:29`) ·
`client_location_add_new` (`client_location_add_row.dart:15` — the **default param value**; Maestro
flow 10 lines 107/124/134/138 target it; keep the default AND the screen's override) ·
`current_location_gps_recovery` (×3 — `current_location_status_card.dart:68/79/90`) ·
`current_location_gps_resolving` (:110) · `current_location_gps_resolved` (:152) ·
`current_location_gps_primary_cta` (:245) · `current_location_gps_retry_cta` (:256)

capture: `capture_location_pin_cta` (`capture_location_screen.dart:99`) ·
`capture_location_map` (:134) · `capture_location_pin` (`capture_location_pin.dart:20`) ·
`capture_location_my_location` (`google_map_capture_view.dart:108`)

Widget keys: `clientLocation.descriptionField`, `clientLocation.descriptionMic`,
`clientLocation.recipientPhoneField`.

### Type/behaviour freezes (tests read these — do not "fix" the tests)
- The Confirm CTA stays an **`OmdsLoadingButton`** — `test/features/location/client_location_screen_test.dart`
  (~:210-217) resolves `tester.widget<OmdsLoadingButton>` under `location_select_confirm_cta`.
  Style by wrapping in a `DecoratedBox`, never by substituting `JeebCtaButton`.
- **`ClientLocationAddRow`** stays a public type — `location_confirm_route_current_guard_b02b_test.dart`
  (~:205-230) finds it by type under an `IgnorePointer(ignoring: true)`. `_SubmitLock`
  (`client_location_screen.dart:489-508`) is untouched.
- `CaptureMapViewport` and `CaptureLocationPin` types stay —
  `test/capture_location_map_injection_test.dart` (:31-44) asserts both.
- The Pin CTA keeps `l10n.captureLocationPinCta` ("Pin Location") — `find.text('Pin Location')` in
  `test/delivery_create_screens_test.dart:244`, `test/capture_location_map_injection_test.dart` and
  `test/google_map_picker_launcher_test.dart` (×2). (Note: these three test files live at `test/`
  root — the original proposal's `test/features/...` paths were wrong.)
- Constructor seams stay source-compatible: `CaptureLocationScreen(onPinned, mapBuilder, isConfirming)`
  all keep their names/defaults; new params are optional-named only.
- `CurrentLocationResult.resolved(lat, lng)` stays callable positionally —
  `test/features/location/location_select_cubit_test.dart:57` constructs it that way.

### New identifiers (ADDs, `<screen>_<element>` convention — all verified absent today)
`client_location_root` · `client_location_back` · `client_location_saved_places_row` ·
`capture_location_root` · `capture_location_back` (Maestro flow 11 selector-note (c) documents
"no `capture_location_back` id" — this is an ADD, not a rename) · `capture_location_pin_callout`
(`image: true` + label, non-interactive) · `capture_location_address_card` (only when a controller
is injected).

---

## 2. Task list — dependency-ordered, execute top to bottom

Wave-0 theme tokens (`context.jeebText`, `JeebShadows`, `context.jeebRoles.accent`) already exist on
this branch — verified in `lib/core/theme/`. `lib/core/widgets/jeeb/` does **not** exist yet; tasks
7–11 are blocked on Wave-1 kit steps 1 (`JeebOutlinedCard`), 3 (`JeebTopBar`), 4 (`JeebCtaFooter`),
5 (`JeebSelectChip`/`JeebChipRow`). Tasks 1–6 have no kit dependency — start there.

**Phase A — not kit-blocked**

1. **Thread GPS accuracy (D1) — data layer.** Verified buildable: `GpsSample.accuracyMeters` exists
   (`background_gps/domain/gps_sample.dart:21-23`), the gateway fills it
   (`geolocator_geocapture_gateway.dart`, `_toSample`), and it is dropped at
   `data/geolocator_current_location_resolver.dart:32`.
   - `domain/current_location_resolver.dart` (:29-54): add optional named `{double? accuracyMeters}`
     to `CurrentLocationResult.resolved`, a `final double? accuracyMeters`, add it to `props`.
   - `data/geolocator_current_location_resolver.dart:32`: pass `accuracyMeters: fix.accuracyMeters`.
   - `application/location_select_state.dart`: `final double? gpsAccuracyMeters` — ctor, `copyWith`
     (nulled by the existing `clearGps` flag exactly like `gpsLat`/`gpsLng`), `props`.
   - `application/location_select_cubit.dart` (:121-126): thread `result.accuracyMeters` into the
     `resolved` emit.
   This is a device sensor value — no endpoint, no backend field. Note `props` grows: re-run
   `compose_request_controller_test.dart` and any suite constructing `LocationSelectState` literals.

2. **Cubit test (ADD-only).** In `test/features/location/location_select_cubit_test.dart`: one case
   proving `accuracyMeters` threads resolver → state and that `clearGps` nulls it.

3. **`widgets/capture_location_pin.dart` — callout + ground mark + shadow.** Restructure to an
   `IgnorePointer(child: Column(mainAxisSize: min, children: [callout, pinGlyph, groundMark]))`:
   - Callout pill: its **own sibling** `Semantics(identifier: 'capture_location_pin_callout',
     image: true, label: <text>)` — do NOT nest it inside the existing `capture_location_pin` node
     (it would be swallowed). Pad `6/12`, `OmdsBorderRadius.pill`, `colorScheme.primary` fill,
     `colorScheme.onPrimary` ink at `context.jeebText.bodySmall`, `JeebShadows.ctaNavy` (design
     `0 8 18 rgba(11,19,81,.30)`, tpl 530 — `ctaNavy` is the sanctioned nearest; add no const).
     Copy: `l10n.captureLocationPinCallout` ("Pin here") — **NOT** "Drop-off here" (refusal C2, §3).
   - Keep the existing `Semantics(identifier: 'capture_location_pin', image: true, ...)` wrapping the
     glyph (+ mark). Keep the tip-anchored translate so the TIP stays at the viewport centre.
   - Ground mark: 10×4, r999, `rgba` via `Colors.black.withValues(alpha: 0.25)`… no — use
     `scheme.shadow.withValues(alpha: 0.25)`, sized `10×4`, under the tip (tpl 533).
   - Pin shadow: `blurRadius: 10, offset: Offset(0, 6)` (tpl 531 `drop-shadow(0 6px 10px …)`),
     replacing the current `Spacing.xSmall / Sizes.threeXSmall` values.
   - The callout is centred over the pin by the Column — direction-neutral; never `left:`-offset it.

4. **`widgets/google_map_capture_view.dart` — restyle `_CentreOnMeButton` in place (:96-118).**
   Replace `FloatingActionButton.small` with a Ø48 circle: `Container(width/height 48,
   BoxDecoration(shape: circle, color: colorScheme.surface, boxShadow: JeebShadows.floatPill))` +
   `Material(transparent) > InkWell(customBorder: CircleBorder)` + `Icons.my_location` 22px
   `colorScheme.primary` (tpl 534/535). KEEP: the `Semantics(identifier:
   'capture_location_my_location', button: true, label: ...)` wrapper, the
   `PositionedDirectional(bottom, end)` placement, and the `if (widget.gateway != null)` guard —
   no recentre button over the grey placeholder. The FAB's `heroTag` disappears with the FAB; fine.

5. **`widgets/capture_map_viewport.dart:43`:** `Icons.map_outlined` → `Icons.map` (R10). Nothing
   else — the grey `surfaceContainerHighest` placeholder is deliberate (never bundle the Figma map
   raster); the render's `#EDEDF2` fake streets are NOT tokenized.

6. **`widgets/current_location_status_card.dart` — token pass + accuracy subtitle.**
   - Add optional named `this.accuracyMeters` (`double?`, default null) to
     `CurrentLocationStatusCard` — call sites and tests keep compiling.
   - `_Resolved` renders `l10n.clientLocationGpsAccuracy(meters.round())` when `accuracyMeters` is
     non-null, else the existing `l10n.clientLocationGpsResolved`. The numeric string must be
     LTR-isolated for AR (wrap the value span, see §4).
   - Keep `_Resolving`/`_Resolved`/`_Recovery` **as widgets** with their five Semantics identifiers
     — the JeebInfoNote conversion is CUT (see appendix). Token-only restyle of `_Recovery`:
     `OmdsBorderRadius.uiLarge` → `OmdsBorderRadius.medium` (:215), border →
     `Border.all(color: scheme.outline, width: 1.5)` (:216), title `theme.textTheme.titleSmall…`
     → `context.jeebText.cardTitle` (:228), messages `bodyMedium` → `context.jeebText.body`
     (:131, :169, :239), `Icons.my_location_outlined` → `Icons.my_location` (:161). Both
     `OmdsPrimaryButton` CTAs and their identifiers unchanged.

**Phase B — blocked on Wave-1 kit (steps 1/3/4/5)**

7. **Rebuild `capture_location_screen.dart` as a full-bleed Stack.** Delete the `OMDSAppBar`
   (:42-46) and the `Column(Expanded(_MapStack), _PinCta)` body (:71-78). Become:
   ```
   Scaffold(
     backgroundColor: colorScheme.surface,
     body: Semantics(identifier: 'capture_location_root', container: true, explicitChildNodes: true,
       child: Stack(fit: StackFit.expand, children: [
         _MapStack(...),                                      // unchanged Semantics + pin
         PositionedDirectional(start: Spacing.xLarge, top: topPad + 14, child: _MapBackButton()),
         PositionedDirectional(start: 0, end: 0, bottom: 0, child: _PickerSheet(...)),
       ])))
   ```
   where `topPad = MediaQuery.viewPaddingOf(context).top` (no SafeArea around the map — the map
   runs to the top edge, per the render).
   - `_MapBackButton` (screen-local): Ø40 `colorScheme.surface` circle + `JeebShadows.floatPill` +
     `DirectionalIcons.back(context)` 20px `colorScheme.primary` (tpl 526-528).
     `Semantics(identifier: 'capture_location_back', button: true,
     label: MaterialLocalizations.of(context).backButtonTooltip)` — no new l10n key needed.
     Tap: `Navigator.of(context).maybePop()`. Must be `PositionedDirectional(start:)`, never `left:`.
     Add `// TODO(redesign-24): swap to JeebTopBar floating treatment when the kit ships it (W2).`
   - `_PickerSheet` (extract to `widgets/capture_picker_sheet.dart` — the screen file stays small):
     `colorScheme.surface`, `OmdsBorderRadius.topXLarge` (24 — design 28, nearest feature-level
     token per §4.4), `JeebShadows.sheet`, padding
     `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.small, Spacing.xLarge, Spacing.twoXLarge)`
     with `SafeArea(top: false)` inside. Contents top→bottom (tpl 538/539):
     44×5 r999 `surfaceContainerHighest` grab handle, centred → address card (task 8, only when a
     controller is injected) → `JeebCtaFooter.single` wrapping the **existing** `OmdsPrimaryButton`
     with `capture_location_pin_cta` + `l10n.captureLocationPinCta`, `isEnabled: !isConfirming`,
     same `_onPin` fallback-to-pop behaviour.
   - NOT built: the step chips, the search field, saved-place pills on this surface (§3).
   - Add optional named `MapCaptureController? controller` to `CaptureLocationScreen` (D4). The
     router's placeholder path passes none → no address card → correct, not a regression.
     `GoogleMapPickerLauncher.pickOnMap` (`data/google_map_picker_launcher.dart:37-52`) already owns
     a controller; pass it through there (that file is in this lane).

8. **Capture-sheet address card (new, inside `capture_picker_sheet.dart`).** Rendered only when
   `controller != null`, wrapped `Semantics(identifier: 'capture_location_address_card',
   container: true, explicitChildNodes: true)`. `JeebOutlinedCard` (white, 1.5px
   `colorScheme.outline`, `OmdsBorderRadius.medium`, pad h `Spacing.medium` / v `Spacing.small` —
   tpl 549). Row: `Icons.location_on` 19px `colorScheme.error` + title
   `context.jeebText.cardTitle` navy, ellipsized. Title = the coordinate label formatted to 4 dp
   (same format as `ComposeRequestController._currentLocationLabel` — reimplement the tiny string
   locally, do NOT import the controller), live via `ListenableBuilder(listenable: controller)`
   (`MapCaptureController` is a `ChangeNotifier` — verified). No street address:
   `// TODO(redesign-24): needs gateway reverse-geocode — omitted, not faked.` No accuracy line here
   (the controller has no accuracy). Digits LTR-isolated (§4).

9. **`client_location_screen.dart` restyle.** In order through the file:
   - Scaffold: wrap body content root in `Semantics(identifier: 'client_location_root',
     container: true, explicitChildNodes: true)`.
   - `OMDSAppBar` (:280-284) → in-body `JeebTopBar(leading: back, title: l10n.clientLocationTitle)`;
     back keeps `Navigator.of(context).maybePop()` and gets identifier `client_location_back`
     (if `JeebTopBar` doesn't take an identifier param, wrap per the kit's documented idiom).
   - `_Heading` (:1139-1155): `theme.textTheme.headlineSmall…w800` → `context.jeebText.h1` +
     `colorScheme.primary`. Strings unchanged.
   - Section gaps (:361, :363, :386, :395, :403, :406, :421): 24/20 → `Spacing.small`(12)–
     `Spacing.medium`(16) per R12 (board: 9–12 card gaps, 14–20 section gaps).
   - Saved addresses: replace the `_SavedAddressCard` column (:394-405, class :562-656) with a
     horizontal pill row — new file `widgets/saved_address_pill_row.dart` (do NOT name it
     `saved_locations_chip_row.dart`; that name is taken by the orphan subtree). Container:
     `Semantics(identifier: 'client_location_saved_places_row', container: true,
     explicitChildNodes: true)` over a **non-lazy `Row` inside
     `SingleChildScrollView(scrollDirection: Axis.horizontal)`** (a lazy ListView hides off-screen
     pills from `find.bySemanticsIdentifier` — real risk, keep non-lazy), gap `Spacing.xSmall`,
     `EdgeInsetsDirectional` padding. Each pill: the EXACT existing Semantics wrapper
     (`location_select_saved_address_${address.id}`, `inMutuallyExclusiveGroup: true`,
     `checked:`, `button: true`, same label composition `'${label}, $subtitle'`) around
     `ExcludeSemantics(child: JeebSelectChip(role: quickReply, selected: …))` with a leading 14px
     filled category icon (`Icons.home / Icons.work / Icons.place` — move `_iconFor` here, filled
     variants per R10). Each pill wrapped in a `ConstrainedBox(constraints:
     BoxConstraints(minHeight: 48))` or equivalent — the 8/14-padded pill alone is ~34px and fails
     the 48dp tap minimum (real a11y regression risk). Tap → `cubit.selectSaved(id)` unchanged.
     Row placement: directly under the GPS card (board order); the manage row moves below the pills.
     NO "SAVED PLACES" section label — the board draws none (cut, see appendix).
   - `_SavedAddressesRow` (:512-557): KEEP structure, Semantics id, `ExcludeSemantics`, `InkWell`,
     `DirectionalIcons.disclosure` (Maestro jm-049 + tests). Restyle in place: label
     `context.jeebText.body` w600 `colorScheme.onSurfaceVariant`, `Icons.bookmark_outline` (:535) →
     `Icons.bookmark` sized down to `Sizes.medium`, ink `onSurfaceVariant`. Do NOT convert to
     `JeebCtaButton.text` (semantics-wrapper churn for zero design payoff).
   - `ClientLocationAddRow` (:412-420, widget file): keep the type, both identifiers (default at
     :15 + the screen's override), the `ExcludeSemantics`/`InkWell` shell. Restyle `_RowContent` as
     an outlined-card row: wrap in `JeebOutlinedCard` (r16, 1.5px `colorScheme.outline`), label
     `context.jeebText.cardTitle`, keep the trailing Ø40 `colorScheme.primary` circle +
     `Icons.add` 20px `onPrimary`. No leading map icon (cut — the board draws no such row at all;
     minimum restyle only). `OmdsBorderRadius.uiMedium` (:36) → `OmdsBorderRadius.medium`.
   - `_RecipientPhoneField` (:1008-1137): label Text (:1076-1082) → `context.jeebText.cardTitle` +
     `colorScheme.primary` (NOT JeebSectionLabel — cut); field border radius (:1121)
     `OmdsBorderRadius.medium` → `OmdsBorderRadius.pill`; `fillColor` (:1104)
     `surfaceContainerHighest` → `surfaceContainerHigh` (tpl 545); helper (:1130) →
     `context.jeebText.bodySmall` + `onSurfaceVariant`. KEEP the raw `TextField` — it is the
     pre-existing `check_design_tokens.sh` violation at :1088 (gate baseline: 8; do not fix, do
     not add a ninth). `EdgeInsets.symmetric` at :1106 → `EdgeInsetsDirectional.symmetric`.
   - `_ConfirmFooter` (build at :714-749): wrap the padding in `JeebCtaFooter.single` (pad
     `0/24/32`) and the **existing `OmdsLoadingButton`** in
     `DecoratedBox(decoration: BoxDecoration(borderRadius: OmdsBorderRadius.pill,
     boxShadow: JeebShadows.ctaNavy))`. Semantics `location_select_confirm_cta` stays where it is.
     Footer stays in `bottomNavigationBar`; body stays a `ListView` — this screen legitimately
     carries more than one viewport; do not vertically centre, do not add a `flex:1` spacer.
   - Description mic (:971): `Icons.mic_none_outlined` → `Icons.mic`, ink
     `context.jeebRoles.accent` (R5 sanctions the mic as an orange mark; 4.65:1 on white; B04's
     `Icons.mic_none` assertion is scoped to `test/features/chat/` — verified no conflict).
   - Subtitle/body inks: `:982`, `:1130` → `context.jeebText.bodySmall` (already
     `onSurfaceVariant` — style swap only).

10. **`widgets/client_location_option_card.dart` — address-card restyle.**
    - Delete the `SelectableRadioGlyph` import/usage (R8: selection is a fill swap, never a radio).
      Do not touch the glyph's own file (request_type feature).
    - Body becomes the address-card row: `Icons.location_on` 19px — ink `colorScheme.error` when
      unselected, `onPrimary` when selected — + label `context.jeebText.cardTitle` in the existing
      `foreground` colour + a subtitle SLOT (the `CurrentLocationStatusCard` passes the
      resolving/resolved widget into it, keeping their own Semantics nodes; the card's outer
      `Semantics` gets `container: true, explicitChildNodes: true` so
      `current_location_gps_resolving`/`_resolved` are not swallowed — canonical idiom in
      `active_request_card.dart`).
    - Border (**corrected rule** — the proposal's blanket "1.5px `colorScheme.outline`" would paint
      a brown ring on the selected navy fill): `selected ? scheme.primary : scheme.outline`,
      `width: 1.5`. Same correction applies to `_SavedAddressCard`'s old rule if any of it is
      reused: subtitle ink stays `selected ? onPrimary : onSurfaceVariant` — keep the UX-AUDIT §T3
      owner comment (:626-635) in compressed form; `color_role_contrast_test` pins that periwinkle
      fails AA on white (C6, §3).
    - Radii: `OmdsBorderRadius.uiLarge` → `OmdsBorderRadius.medium` (:37, :38, :56 — same 16px,
      correct token name). Padding v `Spacing.large` → `Spacing.small` (board card pad 13/16).
    - The recovery/resolving/resolved detail stays hosted by `CurrentLocationStatusCard` exactly as
      today, rendered into the card's subtitle slot for `resolving`/`resolved`, and BELOW the card
      for `_Recovery` (a multi-CTA panel does not fit inside the card).

11. **Widget tests (ADD-only).** In `test/features/location/client_location_screen_test.dart`:
    the address card shows the accuracy line when the fake resolver returns
    `CurrentLocationResult.resolved(lat, lng, accuracyMeters: 8)` and falls back to
    `clientLocationGpsResolved` when accuracy is null.

12. **Full verification pass.** Run, in order:
    - `flutter analyze` — no NEW issues over the 11-issue/6-error baseline;
    - `bash tool/check_design_tokens.sh` — still exactly 8 violations;
    - `flutter test test/features/location test/delivery_create_screens_test.dart
      test/capture_location_map_injection_test.dart test/google_map_picker_launcher_test.dart
      test/core/router/dev_seam_route_pin_test.dart` (+ the compose_request_controller suite for
      the `props` growth);
    - identifier freeze check: every string in §1 still greps in `lib/features/location/`.

---

## 3. Refusals — final, with verified evidence (do not relitigate)

- **C1 — "Pickup set / 2 · Drop-off" chips + "Confirm drop-off" CTA: REFUSED.** The location leg is
  single-point: `compose_request_controller.dart` writes the ONE confirmed coordinate to both legs
  ("Single confirmed point in this step… no dropoff picker in this leg" — verified). Drawing
  pickup→drop-off progress fabricates a second-leg state (the JEBV4-176 class of lie). Keep
  "Confirm location" and "Pin Location". Omit the chip row; add
  `// TODO(redesign-24): step chips omitted — single-point leg; owner decision D-09a.` A real
  drop-off leg is a product change. (The proposal's "✓ Tier / 2 · Location" alternative needs a
  cross-feature getter + a kit tone + owner sign-off — dropped from default scope; recorded as
  owner option D-09a below.)
- **C2 — "Drop-off here" callout: REFUSED** (same root cause). Ship neutral
  `captureLocationPinCallout` = "Pin here".
- **C3 — "Rue Monot 42, Achrafieh": REFUSED as drawn.** No reverse-geocode source exists:
  `LocationRepository` is not DI-registered, and `InMemoryLocationRepository.reverseGeocode`
  (verified) snaps to a hardcoded 5-entry Beirut catalogue — calling it IS the JEBV4-176
  fabrication. Coordinate label + TODO.
- **C4 — Search field: REFUSED.** `LocationSelectRepository` exposes only `fetchSavedAddresses`;
  the only `searchAddress` impl is the same fabricated catalogue; no geocoding dep exists and
  none may be added. Also a second raw-TextField gate violation.
- **C5 — Live draggable map: REFUSED to wire.** `CaptureLocationRoute` deliberately injects no
  `mapBuilder` and pops without a coordinate (B-23, Maps key owner-gated);
  `pin_location_coordinate_survives_b35_test.dart` drives the production router and asserts
  `submitCount == 0`. Restyle the chrome only.
- **C6 — Periwinkle subtitles on white: REFUSED.** Owner-reported AA defect, pinned by
  `color_role_contrast_test`. Real text ink = `onSurfaceVariant`.
- `decision_violations_test.dart` covers D56/D52/D20/earnings-framing only — verified none touch
  this screen. B04 is chat-scoped.

**Owner decisions to log (not wiring):** D-09a step-chip alternative (needs `Tier? get tier` on
`ComposeRequestController` + a kit chip tone); D-09b unblock the Maps API key (B-23) so
`/capture-location` gets the live pin; D-09c is a real drop-off leg in scope?

---

## 4. RTL checklist

- Floating back + sheet: `PositionedDirectional(start:)` / `EdgeInsetsDirectional` only. The
  recentre button is already `PositionedDirectional(bottom, end)` — keep.
- Back glyph via `DirectionalIcons.back(context)`; disclosure at :548 already correct.
- Pill row: non-lazy `Row` in a horizontal `SingleChildScrollView` (mirrors correctly; keeps all
  pills in the element tree for finders).
- Digits LTR-isolated: the accuracy figure and the coordinate label both reorder inside an RTL
  paragraph — wrap the value in `Directionality(textDirection: TextDirection.ltr, child: Text(…))`
  or U+2066…U+2069 isolates.
- The callout is centred by construction — no directional offset.
- The AR test (`client_location_screen_test.dart:315-333`) pins `ما الذي تحتاجه؟` and RTL layout of
  the description field — both must stay green.

---

## 5. Known pre-existing rot — flag, do not fix

- Maestro `10-client-location.yaml` targets `client_location_add_new` but the live screen overrides
  that row to `location_select_new_location_cta` — the flow cannot pass today. Maestro is not in
  CI; reconciling either way breaks widget tests or jm-024. Leave both values exactly as they are.
- `check_design_tokens.sh` baseline is 8 violations incl. `client_location_screen.dart:1088`
  (raw TextField). Leave at 8.
- No goldens exist for this feature.

---

## 6. Wiring requests — write this file verbatim

Create `docs/redesign-2026-08/wiring/09-location-picker.md` with exactly these three blocks, and
write screen code as if all are already granted:

```
### l10n
file: lib/l10n/app_en.arb (+ mirrored key in lib/l10n/app_ar.arb)
need: Two new keys for screen 09 — the GPS-accuracy subtitle and the neutral pin callout.
exact change:
  app_en.arb:
    "clientLocationGpsAccuracy": "GPS · accurate to {meters} m",
    "@clientLocationGpsAccuracy": {
      "description": "Address-card subtitle on /client-location when the device fix carries an accuracy radius; meters is a rounded whole number.",
      "placeholders": { "meters": { "type": "int" } }
    },
    "captureLocationPinCallout": "Pin here",
    "@captureLocationPinCallout": {
      "description": "Non-interactive callout pill above the fixed map pin on /capture-location. Deliberately NOT 'Drop-off here' — the create leg is single-point (per-screen-revised/09 §3 C2)."
    }
  app_ar.arb:
    "clientLocationGpsAccuracy": "GPS · دقة حتى {meters} م",
    "captureLocationPinCallout": "ثبّت هنا"
why: Task 6 renders the accuracy subtitle; task 3 renders the callout. No back-semantic keys are needed (MaterialLocalizations.backButtonTooltip is used instead).
```

```
### cross-feature
file: lib/core/widgets/jeeb/jeeb_top_bar.dart (kit owner, Wave-1 step 3)
need: A `floating` leading treatment — colorScheme.surface fill + JeebShadows.floatPill instead of surfaceContainerHigh — for a back circle floating over a map.
exact change: add `JeebTopBarLeadingTreatment.floating` (or equivalent flag) that renders the Ø40 back circle with `color: colorScheme.surface` and `boxShadow: JeebShadows.floatPill`; glyph unchanged (20px navy DirectionalIcons.back).
why: Screen 09's /capture-location back button floats over the map (render + HTML tpl 526: white fill, shadow rgba(11,19,81,.18) 0 6 16); screen 12 needs the same. Until granted, 09 ships a screen-local _MapBackButton with a TODO.
```

```
### cross-feature
file: lib/features/location/presentation/widgets/delivery_create_layout.dart
need: Page gutter 20 → 24 to match the board-wide 24px gutter (HTML tpl 525/538).
exact change: in DeliveryCreateLayout.pagePadding, `Spacing.large` → `Spacing.xLarge` for the start/end insets (top/bottom unchanged).
why: The file lives in the location feature but request_type_screen.dart (screens 07/08) imports it — applying it via the integrator makes the 07/08 lane see the gutter change consciously instead of silently mid-flight. Screen 09 code is written against the 24px gutter.
```

Router: **no change**. DI: **no change**. Theme: **no change** (Wave-0 tokens already exist).

---

## 7. Stop conditions — what "done" means

DONE when all of:
1. Tasks 1–12 complete; tasks 7–11 only after the Wave-1 kit widgets exist.
2. Every §1 identifier greps unchanged; the 7 new identifiers exist; no identifier renamed.
3. `flutter analyze` shows no NEW errors/warnings over the 11-issue baseline;
   `check_design_tokens.sh` still reports exactly 8; every test suite in task 12 is green with only
   the two sanctioned ADD-only test changes.
4. The Confirm CTA is still an `OmdsLoadingButton`; `ClientLocationAddRow`, `CaptureMapViewport`,
   `CaptureLocationPin` still exist as types; `CaptureLocationRoute` behaviour untouched.
5. `docs/redesign-2026-08/wiring/09-location-picker.md` contains exactly the §6 blocks.
6. No edit outside `lib/features/location/**` and `test/**` (location-scope tests only) except the
   wiring file. `delivery_create_layout.dart` NOT edited directly (wiring block 3 covers it).
7. Every refused element (§3) is absent from the shipped code; the three TODOs
   (`reverse-geocode` ×2 surfaces, `step chips`) are present, one line each.

Accept as CORRECT, not failures: `/capture-location` renders the new chrome over the grey
placeholder viewport (no Maps key — R1); `/client-location` does not look like the PNG (the PNG is
the capture surface — carry the §0 mapping in the PR description).

---

## Appendix — deltas from the original proposal

**Cut (scope creep / misfit):**
1. `_Recovery` → `JeebInfoNote`: 09 is not an InfoNote consumer in either plan doc; the panel has
   two CTAs (InfoNote's trailing slot is meter/value/link only) and isn't drawn on the board.
   Token-level restyle instead — also removes all risk to the 5 `current_location_gps_*` ids.
2. "SAVED PLACES" `JeebSectionLabel` + `clientLocationSavedPlacesLabel` key: the board draws no
   label above the Home/Work/Mama's pills.
3. `JeebSectionLabel` on the recipient-phone label: the field isn't on the board; `cardTitle`
   restyle only. (§5 #10 lists consumers 05/15/17/19/20/23 — not 09.)
4. `clientLocationBackSemantic`/`captureLocationBackSemantic` keys: `MaterialLocalizations
   .backButtonTooltip` is already localized.
5. W3 (kit chip-role confirmation): the measured deltas vs `quickReply` (1px pad, 0.5px font) are
   sub-token noise and the plan forbids lane-local sizes. Use `role: quickReply` as shipped.
6. W4 (`Tier? get tier`): owner-gated alternative only → logged as decision D-09a, not pre-wired.
7. `_SavedAddressesRow` → `JeebCtaButton.text`: in-place restyle instead (keeps the Semantics shell
   and disclosure untouched).
8. Leading `Icons.map` on `ClientLocationAddRow`: not evidenced anywhere.

**Corrected:**
1. Test paths: `delivery_create_screens_test.dart`, `capture_location_map_injection_test.dart`,
   `google_map_picker_launcher_test.dart` are at `test/` root.
2. Selected-state regressions in the blanket token rules: border and subtitle ink keep their
   `selected ?` branches (`primary` border / `onPrimary` ink on the navy fill) — only the
   UNSELECTED branch moves to `outline` 1.5px / `onSurfaceVariant`.
3. `_ConfirmFooter` build is :714-749 (widget :685, state :705); `pickOnMap` is :37-52; the Maestro
   flow-11 back note is selector-note (c) (~:68).
4. "Icons.location_on_outlined in client_location_screen.dart" — no such occurrence exists; the
   filled pin applies to the NEW card only.
5. The proposal's single merged "address card title = saved label else coordinate" conflated two
   surfaces — split: client-location card = "Current Location" + GPS subtitle; capture card =
   live coordinate label from the controller.

**Confirmed against the proposal's own doubts:** D1 (GPS accuracy) is genuinely buildable today —
every file:line in its 4-step chain verified; it stays in scope as the screen's one functional gain.
