# 09 · Location picker — implementation proposal

Board screen: `docs/redesign-2026-08/screens/09-location-picker.{png,html,note.md}`
Designer note (verbatim): *"map-first with a draggable pin (the shipped picker is a form with the
map behind a button), pickup→drop-off progress as chips, GPS accuracy stated on the address card,
saved places (Home/Work/Mama's) one tap away."*

**Verdict: rebuild** (of `/capture-location`) **+ restyle-with-structure** (of `/client-location`).

---

## 0. Which files — the prompt is wrong, the repo map wins

The task prompt points at `lib/features/location/presentation/location_picker_screen.dart`. That
file is **dead**: it is tagged `// ORPHAN (JEBV4-227, verified 2026-07-12)` at line 15, the `/location`
route mounts a 36-LOC "coming soon" placeholder instead, and its only importer is the devtool
catalog. `00-MIGRATION-PLAN.md` §STOP-1 and `screen-repo-map.md` both correct it. The two live files
are:

| Route | File | LOC | Role today |
|---|---|---|---|
| `/client-location` (`app_router.dart:1124`) | `lib/features/location/presentation/client_location_screen.dart` | 1155 | the create-flow **location + content** step: "What do you need?", Current-Location GPS card, saved addresses, "New Location" → map, recipient phone, Confirm → `POST /requests` |
| `/capture-location` (`app_router.dart:1135`) | `lib/features/location/presentation/capture_location_screen.dart` | 142 | full-screen map pin picker (placeholder viewport in the live router) |

**Do not touch `location_picker_screen.dart`, `location_search_bar.dart`, `saved_locations_chip_row.dart`
or `cubit/location_picker_*.dart`** — that whole sub-tree is the orphan picker.

The board draws **one** map-first screen. The app splits it in two. `screen-repo-map.md` calls this
"the only board change that alters navigation — the highest-risk item on the board". This proposal
does **not** merge them: the board's map-first sheet lands on `/capture-location`, and
`/client-location` keeps its distinct job (compose content + phone + create) restyled to the same
visual language. Merging would delete the `POST /requests` gate, the G1 description contract and the
OTP recipient-phone capture, none of which the board draws.

---

## 1. Layout & structure

### 1A. `capture_location_screen.dart` — map-first rebuild

**Delete** `appBar: OMDSAppBar(...)` (`capture_location_screen.dart:42-46`) and the
`Column(Expanded(map), _PinCta)` body (`:71-78`). **Become** a full-bleed `Stack`:

```
Scaffold(
  backgroundColor: colorScheme.surface,
  body: Stack(fit: StackFit.expand, children: [
    _MapStack(...),                    // unchanged Semantics + CaptureLocationPin
    _PinCallout(),                     // NEW — navy pill above the pin tip
    PositionedDirectional(start: 24, top: safeTop + 14, child: <floating back>),
    PositionedDirectional(start: 0, end: 0, bottom: 0, child: _PickerSheet(...)),
  ]),
)
```

- **Floating back circle** (HTML tpl 526): Ø40 white, glyph 20px navy `DirectionalIcons.back`,
  `JeebShadows.floatPill`. The render has **no app bar and no title** — the map runs to the top edge.
  Consume `JeebTopBar(leading: back)` **only if** the kit ships the `floating` treatment (white fill
  instead of `surfaceContainerHigh` + `floatPill`); see wiring request W2. Otherwise a screen-local
  `_MapBackButton` is correct — this is the only floating back on this screen.
- **Pin callout** (HTML tpl 530-533): pill pad `6/12`, `OmdsBorderRadius.pill`,
  `colorScheme.primary` fill, `onPrimary` ink at `context.jeebText.bodySmall`, `JeebShadows.ctaNavy`
  (the HTML's `0 8 18 rgba(11,19,81,.30)` — `ctaNavy` is the sanctioned nearest; do not add a const).
  Plus the Ø10×4 `r999 rgba(0,0,0,.25)` ground mark under the tip (tpl 533) — build that inside
  `CaptureLocationPin` so the tip/shadow relationship stays in one widget.
  **Copy is refused as drawn** — see §9-C1.
- **Recentre FAB** (HTML tpl 534, Ø48 white + `Icons.my_location` 22px navy): this already exists as
  `_CentreOnMeButton` (`widgets/google_map_capture_view.dart:96-118`) and already sits at
  `PositionedDirectional(bottom, end)`. **Restyle it in place** — swap `FloatingActionButton.small`
  (Ø40, theme FAB colors) for a Ø48 `colorScheme.surface` circle + `JeebShadows.floatPill`. Do not
  move it: it owns the `GeolocatorGeocaptureGateway` and only renders when a live map is injected,
  which is correct — no recentre button over a grey placeholder.
- **Bottom sheet** replacing `_PinCta` (`:82-118`): `colorScheme.surface`,
  `OmdsBorderRadius.topXLarge` (24; design 28 — nearest token, §4.4), `JeebShadows.sheet`,
  padding `EdgeInsetsDirectional.fromSTEB(Spacing.xLarge, Spacing.small, Spacing.xLarge, Spacing.twoXLarge)`.
  Contents top→bottom: grab handle (44×5 `r999 surfaceContainerHighest`, centred — tpl 539) →
  address card (only when a `MapCaptureController` is injected, §4-D2) → `JeebCtaFooter.single`
  wrapping the **existing** `OmdsPrimaryButton` with `capture_location_pin_cta`.
- **Not built here**: the step chips (§9-C1), the search field (§9-C4), the saved-place pills
  (they belong on `/client-location`, which is the surface that already loads
  `LocationSelectState.savedAddresses`).

### 1B. `client_location_screen.dart` — restyle + restructure

| What | Where | Becomes |
|---|---|---|
| `OMDSAppBar` | `:280-284` | in-body `JeebTopBar(leading: back, title: l10n.clientLocationTitle)`; keep `Navigator.maybePop` |
| page padding | `:350`, `:725` via `DeliveryCreateLayout.pagePadding` | gutter 20 → **24** (`Spacing.xLarge`). ⚠ `DeliveryCreateLayout` is shared with `request_type_screen.dart:138,219` (screens 07/08) — see wiring request W6 |
| `_Heading` | `:1139-1155` | `context.jeebText.h1` + `colorScheme.primary`; **keep the string** (`find.text('Choose your location')` is pinned) |
| `CurrentLocationStatusCard` + `ClientLocationOptionCard` | `widgets/current_location_status_card.dart:45-56`, `widgets/client_location_option_card.dart` | one **address card**: `JeebOutlinedCard`, r16, `1.5px colorScheme.outline`, pad `12/16`, row = 19px `Icons.location_on` (`colorScheme.error`) + Column[title `jeebText.cardTitle` navy, subtitle line]. **Delete `SelectableRadioGlyph`** — R8: selection is a fill swap (navy fill + white ink), never a radio |
| `_Resolved` / `_Resolving` detail rows | `current_location_status_card.dart:101-179` | fold **into** the card as its subtitle line (render's second line), keeping their `Semantics` wrappers (§6) |
| `_Recovery` panel | `current_location_status_card.dart:183-270` | `JeebInfoNote` tone `muted`, r16 pad `12/16` gap 10, leading 17px glyph `colorScheme.error`; CTAs unchanged |
| `_SavedAddressCard` list | `:394-405`, `:562-656` | **saved-place pill row** — `JeebChipRow` of `JeebSelectChip(role: quickReply)`, non-lazy `Row` inside a horizontal `SingleChildScrollView`, gap `Spacing.xSmall`. This is the render's `⌂ Home / Work / Mama's` |
| `_SavedAddressesRow` | `:512-557` | keep (Maestro `jm-049` + widget tests). Demote from a bold navy row to a `JeebCtaButton.text` inline action, 13/w600 `onSurfaceVariant`, `DirectionalIcons.disclosure` unchanged |
| `ClientLocationAddRow` | `:412-420`, `widgets/client_location_add_row.dart` | keep the **type** (`find.byType(ClientLocationAddRow)` is pinned) and both identifiers. Restyle as a `JeebOutlinedCard` row: 20px `Icons.map` navy + label `jeebText.cardTitle` + Ø40 `colorScheme.primary` circle with `Icons.add` 20px `onPrimary` |
| `_RecipientPhoneField` | `:1008-1137` | label → `JeebSectionLabel`; field h52 `surfaceContainerHigh` fill at `OmdsBorderRadius.pill`, no border, start pad 18 (HTML tpl 545); helper `jeebText.bodySmall`. **Keep the raw `TextField`** — it is already a `check_design_tokens.sh` violation (see §8) and adding a second one is worse than leaving one |
| `_ConfirmFooter` | `:705-749` | `JeebCtaFooter.single` padding `0/24/32`, and wrap the **existing `OmdsLoadingButton`** in `DecoratedBox(BoxDecoration(borderRadius: OmdsBorderRadius.pill, boxShadow: JeebShadows.ctaNavy))`. ⚠ **do not swap it for `JeebCtaButton`** — `client_location_screen_test.dart:210-216` reads `tester.widget<OmdsLoadingButton>` under the CTA identifier |
| `_SubmitLock` | `:489-508` | **unchanged** — the `IgnorePointer(ignoring:true)` ancestor is asserted by `location_confirm_route_current_guard_b02b_test.dart:213-226` |
| section gaps | `:361,363,386,395,403,406,421` | 24/20 → **12–16** (`Spacing.small` / `Spacing.medium`); R12 measures the board at 9–12px card gaps, 14–20px section gaps. Nothing on this board is spaced at 24 between cards |

**Density (R1).** `/client-location` legitimately carries more than one viewport (description + GPS
card + saved places + map row + phone), so the `ListView` stays and the footer stays docked in
`bottomNavigationBar`. Do **not** vertically centre and do **not** let the saved-address list expand
— collapsing those cards into pills is the density win this screen can actually deliver.

---

## 2. Tokens — every value that should change

The two files carry **zero hex literals** (token-clean). What is wrong is the *role* and the *shape*.

| Current | Where | Becomes |
|---|---|---|
| `textTheme.headlineSmall?.copyWith(fontWeight: w800)` | `client_location_screen.dart:1149` | `context.jeebText.h1` |
| `textTheme.labelLarge?.copyWith(fontWeight: w700)` ×3 | `:541`, `:615`, `:1078` | `context.jeebText.cardTitle` (`:541`, `:615`) / `JeebSectionLabel` (`:1078`) |
| `textTheme.bodyLarge` | `client_location_add_row.dart:55` | `context.jeebText.cardTitle` |
| `textTheme.labelLarge?.copyWith(w700)` | `client_location_option_card.dart:82` | `context.jeebText.cardTitle` |
| `textTheme.bodySmall` ×3 | `:625`, `:982`, `:1130` | `context.jeebText.bodySmall`, ink **`colorScheme.onSurfaceVariant`** — *not* periwinkle, see §9-C6 |
| `textTheme.bodyMedium` ×3 | `current_location_status_card.dart:131,169,239` | `context.jeebText.body` |
| `textTheme.titleSmall?.copyWith(w700)` | `current_location_status_card.dart:228` | `context.jeebText.cardTitle` |
| `Border.all(color: scheme.outlineVariant)` (1px) | `:599`, `client_location_option_card.dart:58`, `current_location_status_card.dart:216` | `Border.all(color: colorScheme.outline, width: 1.5)` — R7, the warm brown `#916F66` **is** the card outline |
| `OmdsBorderRadius.uiLarge` (16) on cards | `:587,588,597`, `client_location_option_card.dart:37,38,56`, `current_location_status_card.dart:215` | `OmdsBorderRadius.medium` (16 — same value, correct name) |
| `OmdsBorderRadius.uiMedium` (12) on rows | `:527`, `client_location_add_row.dart:36` | `OmdsBorderRadius.medium` (16) |
| `OmdsBorderRadius.medium` on the phone field | `:1121` | `OmdsBorderRadius.pill` (the board's fields are h52 full pills) |
| `Icons.location_on_outlined` | `client_location_screen.dart` (orphan-shared idiom) / new card | `Icons.location_on` |
| `Icons.bookmark_outline` | `:535` | `Icons.bookmark` |
| `Icons.my_location_outlined` | `current_location_status_card.dart:161` | `Icons.my_location` |
| `Icons.mic_none_outlined` | `:971` | `Icons.mic`, ink `context.jeebRoles.accent` (R5 — the mic is a sanctioned orange mark; 4.65:1 on white). Safe: B04's `Icons.mic_none` assertion is scoped to `test/features/chat/` |
| `Icons.home_outlined / work_outline / place_outlined` | `:652-654` | `Icons.home / work / place` (R10: filled, single-colour, no outline variants anywhere on the board) |
| `Icons.map_outlined` | `capture_map_viewport.dart:43` | `Icons.map` |
| no shadow on the CTA | `:734` | `JeebShadows.ctaNavy` behind the pill |
| `FloatingActionButton.small` | `google_map_capture_view.dart:111-115` | Ø48 `colorScheme.surface` circle + `JeebShadows.floatPill` |
| pin shadow `blurRadius: Spacing.xSmall, offset: (0, Sizes.threeXSmall)` | `capture_location_pin.dart:44-48` | `blurRadius: 10, offset: Offset(0, 6)` (HTML tpl 531 `drop-shadow(0 6px 10px rgba(0,0,0,.25))`) |

**Explicitly do NOT tokenize:** the render's map fill `#EDEDF2` and its fake streets — §4.1 says the
map is real tiles, and `CaptureMapViewport` is a deliberate neutral placeholder
(`capture_map_viewport.dart:9-12`, "the Figma map raster is a mock and is never bundled"). Leave its
`surfaceContainerHighest`. The `#E02020` pin stays `colorScheme.error`.

---

## 3. Shared components consumed

| Kit widget (§5) | Replaces | Where |
|---|---|---|
| **#1 `JeebTopBar`** (`back`) | `OMDSAppBar` | `client_location_screen.dart:280`; and the floating variant over the map on `capture_location_screen.dart` (needs W2) |
| **#2 `JeebCtaButton` / `JeebCtaFooter.single`** | `_PinCta`'s `Padding` (`capture:91-107`) and `_ConfirmFooter`'s `Padding` (`:723-748`) | both screens — **footer wrapper only**; the inner `OmdsLoadingButton` / `OmdsPrimaryButton` stay (test + Maestro contracts) |
| **#3 `JeebOutlinedCard`** | `ClientLocationOptionCard._body`, `_SavedAddressCard`'s `Container`, the new pin address card | both |
| **#6 `JeebSelectChip` + `JeebChipRow`** (`role: quickReply`) | `_SavedAddressCard` list | `client_location_screen.dart:394-405` |
| **#10 `JeebSectionLabel`** | `_RecipientPhoneField`'s label `Text` (`:1076-1082`) and a new `SAVED PLACES` label | `client_location_screen.dart` |
| **#22 `JeebInfoNote`** (tone `muted`) | `_Recovery` (`current_location_status_card.dart:183-270`) | `client_location_screen.dart` body |

`lib/core/widgets/jeeb/` **does not exist yet** — this lane is blocked on Wave 1 steps 1–5.

Not consumed: `JeebNavySurfaceCard` (no navy hero here), `JeebStepper` (see §9-C1), `JeebMeter`,
`JeebAvatar`.

---

## 4. New functionality — what the notes describe and what the app can actually do

**D1 — GPS accuracy on the address card: BUILDABLE TODAY. This corrects the plan.**
`00-MIGRATION-PLAN.md` §7.6 lists "GPS accuracy meters (09)" as *still genuinely suspect*. It is not.
`GeolocatorGeocaptureGateway.currentFix()` already returns a `GpsSample` carrying
`accuracyMeters: position.accuracy` (`geolocator_geocapture_gateway.dart:236`, field documented at
`gps_sample.dart:21-23`). The value is **thrown away at the port boundary** —
`geolocator_current_location_resolver.dart:32` calls `CurrentLocationResult.resolved(fix.latitude, fix.longitude)`
and drops the third number. Four small edits, all inside `lib/features/location/` (this lane's tree):

1. `domain/current_location_resolver.dart:32-37` — add `{double? accuracyMeters}` to
   `CurrentLocationResult.resolved`, a `final double? accuracyMeters`, and it into `props`.
   Optional-named ⇒ `FakeCurrentLocationResolver` (`test/support/`) and
   `location_select_cubit_test.dart:57` keep compiling unchanged.
2. `data/geolocator_current_location_resolver.dart:32` — pass `accuracyMeters: fix.accuracyMeters`.
3. `application/location_select_state.dart` — `final double? gpsAccuracyMeters`, into the ctor,
   `copyWith` (cleared by the existing `clearGps` flag) and `props`.
4. `application/location_select_cubit.dart:121-126` — thread `result.accuracyMeters`.

UI: render `l10n.clientLocationGpsAccuracy(metres)` as the address card's subtitle **only when
non-null**; fall back to the existing `clientLocationGpsResolved` ("Using your current location")
otherwise. This is a real device value, not a backend field — no endpoint is invented.

**D2 — Street address ("Rue Monot 42, Achrafieh"): NOT BUILDABLE.** There is no `geocoding`
dependency in `pubspec.yaml`, no gateway reverse-geocode route, and `LocationRepository` is **not
registered in DI** (`injection_container.dart` registers only `SavedLocationRepository` and
`CurrentLocationResolver`). Its only implementation, `InMemoryLocationRepository.reverseGeocode`
(`data/location_repository.dart:164-183`), snaps to a hardcoded five-entry Beirut catalogue — calling
it is *literally* the JEBV4-176 fabrication. `compose_request_controller.dart:213-217` already
documents the gap and ships `Current location (33.8959, 35.4797)` as the honest label.

→ Card title = a **saved address's real `label`/`address`** when one is selected (that data is real,
from `GET /users/me/saved-locations`), else the coordinate label. Leave
`// TODO(redesign-24): needs gateway reverse-geocode — omitted, not faked.`

**D3 — Draggable pin / live map on `/capture-location`: DO NOT WIRE.** All the machinery exists
(`GoogleMapCaptureView`, `MapCaptureController`, `GoogleMapPickerLauncher`), but
`CaptureLocationRoute` (`app_router.dart:123-152`) deliberately injects no `mapBuilder` and pops
**without** a coordinate — B-23, Maps API key owner-gated. §9-C5.

**D4 — Address card on `/capture-location` needs the map centre.** Add an optional
`MapCaptureController? controller` to `CaptureLocationScreen` (source-compatible constructor seam,
§7.4 "preserve every constructor seam" — this only adds one) and render the card **only when it is
non-null**. `GoogleMapPickerLauncher.pickOnMap` (`data/google_map_picker_launcher.dart:38-49`)
already owns a controller and can pass it. On the router's placeholder path there is no controller
and therefore no address card — correct, not a regression.

**D5 — Cubit/state summary of what this lane needs:** exactly one new state field
(`gpsAccuracyMeters`) and one new screen param (`controller`). No new cubit, no new repository, no
new route, no new endpoint.

---

## 5. New routes

**None.** Both surfaces exist (`/client-location` `app_router.dart:1124`, `/capture-location` `:1135`)
and both are already in `backFallbacks` (`:483-484`). `app_router.dart` is **not edited by this lane**.

Explicitly not proposed: resurrecting `/location` onto the orphan `LocationPickerScreen`.

---

## 6. Semantics identifiers

### Frozen — every one must still be emitted after the restyle

`client_location_screen.dart`
`location_select_new_location_cta` (:415) · `location_select_saved_addresses_row` (:522) ·
`location_select_saved_address_${address.id}` (:579) · `location_select_saved_addresses_error` (:669) ·
`location_select_confirm_cta` (:727) · `compose_description_input` (:951) ·
`compose_description_mic` (:966) · `recipient_phone_input` (:1085)

widgets
`client_location_option_current` (`client_location_option_card.dart:29`) ·
`client_location_add_new` (`client_location_add_row.dart:15` — the **default param value**; Maestro
flow 10 targets it, keep the default) · `current_location_gps_recovery` (×3, `:68/79/90`) ·
`current_location_gps_resolving` (:110) · `current_location_gps_resolved` (:152) ·
`current_location_gps_primary_cta` (:245) · `current_location_gps_retry_cta` (:256)

`capture_location_screen.dart` / widgets
`capture_location_pin_cta` (:99) · `capture_location_map` (:134) ·
`capture_location_pin` (`capture_location_pin.dart:20`) ·
`capture_location_my_location` (`google_map_capture_view.dart:108`)

Widget keys (also asserted): `clientLocation.descriptionField`, `clientLocation.descriptionMic`,
`clientLocation.recipientPhoneField`.

**Re-homing rule for the merged card:** `current_location_gps_resolving` / `_resolved` move from
sibling rows into the card's subtitle slot. The card's outer `Semantics` must carry
`container: true, explicitChildNodes: true` or it swallows them (§7.5, canonical idiom in
`active_request_card.dart`). Same for the saved-place `JeebChipRow`.

### New (ADD only, `<screen>_<element>` convention)

| Identifier | On |
|---|---|
| `client_location_root` | `/client-location` screen root (none today; §7.5 wants one per surface) |
| `client_location_back` | the new in-body back circle |
| `client_location_saved_places_row` | the pill row container (`container: true, explicitChildNodes: true`) |
| `capture_location_root` | `/capture-location` screen root |
| `capture_location_back` | the floating back circle (flow 11 notes "no `capture_location_back` id" — this adds it) |
| `capture_location_pin_callout` | the "Pin here" pill (`image: true` + label, non-interactive) |
| `capture_location_address_card` | the sheet address card (only when a controller is injected) |

---

## 7. RTL

- Floating back → `PositionedDirectional(start:)`. Recentre FAB is already
  `PositionedDirectional(bottom, end)` (`google_map_capture_view.dart:104-106`) ✔ — keep `end`.
- Saved-place pills: a non-lazy `Row` inside `SingleChildScrollView(scrollDirection: Axis.horizontal)`
  with `EdgeInsetsDirectional` padding. Flutter mirrors the scroll origin under RTL; a lazy
  `ListView` would additionally hide off-screen pills from `find.bySemanticsIdentifier` (see §10-R4).
- **Digits must be LTR-isolated**: the accuracy figure (`8 m`) and the coordinate fallback
  (`33.8959, 35.4797`) both reorder badly inside an RTL paragraph. Wrap in
  `Directionality(textDirection: TextDirection.ltr, …)` or `⁦…⁩`.
- The pin callout is centred over the pin — direction-neutral by construction; do **not** offset it
  with `left:`.
- `EdgeInsets.symmetric` at `:1106` is direction-safe but switch to `EdgeInsetsDirectional` for
  consistency with the rest of the file.
- `DirectionalIcons.disclosure(context)` at `:548` already correct; the new back glyph must use
  `DirectionalIcons.back`.
- The existing AR test (`client_location_screen_test.dart:315-333`) pins the Arabic heading
  `ما الذي تحتاجه؟` and `Directionality.of(field) == rtl` — both survive.

---

## 8. Test impact

**Green by construction (no test change needed):**

| Test | What it pins | Why it survives |
|---|---|---|
| `delivery_create_screens_test.dart:186-188` | `find.text('Choose your location' / 'Current Location' / 'New Location')` | all three l10n keys are kept verbatim |
| `delivery_create_screens_test.dart:244`, `capture_location_map_injection_test.dart:60`, `google_map_picker_launcher_test.dart:40,72` | `find.text('Pin Location')` | `captureLocationPinCta` unchanged — §9-C1 refuses "Confirm drop-off" |
| `capture_location_map_injection_test.dart:31-44` | `CaptureMapViewport` absent when a builder is injected; `CaptureLocationPin` always present | both widget types and the Stack overlay are kept |
| `location_confirm_route_current_guard_b02b_test.dart:213-226` | `find.byType(ClientLocationAddRow)` under an `IgnorePointer(ignoring:true)` | type + `_SubmitLock` untouched |
| `pin_location_coordinate_survives_b35_test.dart` | drives the **real** router; `submitCount == 0` after a placeholder pin | no `mapBuilder` is wired (§9-C5) |
| `client_location_screen_test.dart` (6 cases), `client_location_401_test`, `location_confirm_creates_request_b11_test`, `location_confirm_double_submit_guard_b02_test`, `location_confirm_enabled_when_saved_locations_unavailable_test` | identifiers + description key + `canConfirm` gating | untouched |
| `core/router/dev_seam_route_pin_test.dart`, `core/router/fr_gating_first_run_test.dart` | `find.byType(ClientLocationScreen / CaptureLocationScreen)` | class names unchanged |
| `location_select_cubit_test.dart:57` | `CurrentLocationResult.resolved(lat, lng)` positional | new param is optional-named |

**Constrains the design — do not "fix" by changing the test:**

- `client_location_screen_test.dart:210-216` resolves `tester.widget<OmdsLoadingButton>` inside the
  `location_select_confirm_cta` node and reads `.isEnabled`. **The Confirm CTA must remain an
  `OmdsLoadingButton`.** Style it by wrapping, never by substituting `JeebCtaButton`. If a later
  reviewer sees `JeebCtaButton` there, the proposal was implemented wrong.

**Legitimate ADD-only test work (2 items):**

1. `location_select_cubit_test.dart` — a case proving `accuracyMeters` threads
   resolver → state, and that `clearGps` nulls it.
2. `client_location_screen_test.dart` — the address card shows the accuracy line when the fake
   resolves with an accuracy and falls back to `clientLocationGpsResolved` when it does not.

**Known pre-existing rot, do not "fix":** Maestro `10-client-location.yaml:107,124,134` targets
`client_location_add_new`, but the live screen overrides that row's identifier to
`location_select_new_location_cta` (`client_location_screen.dart:415`). That flow cannot pass today.
Maestro is not in CI; renaming either value to reconcile them would break the widget tests and
`jm-024`. Flag it, leave it.

**Gate baseline:** `tool/check_design_tokens.sh` is already red — 8 violations, one of which is
`client_location_screen.dart:1088` (raw `TextField` in `_RecipientPhoneField`). Pre-existing; do not
fix it and do not add a ninth (this is a second reason the board's search field is refused).

**No goldens exist for this feature** (goldens are screens 18 + the 24-sheet).

---

## 9. Conflicts — refused, with reasons

**C1 — "2 · Drop-off" progress chips and the "Confirm drop-off" CTA. REFUSED.**
The app's location leg is **single-point**. `compose_request_controller.dart:195-201` writes the one
confirmed coordinate to *both* legs, with the comment *"Single confirmed point in this step… no
dropoff picker in this leg."* Drawing a pickup→drop-off stepper and a "Confirm drop-off" button
would tell the customer a second leg exists and is set, when the draft is sending the same
coordinate twice. That is exactly the class of lie JEBV4-176 removed.
→ Keep `l10n.locationConfirm` ("Confirm location") and `l10n.captureLocationPinCta` ("Pin Location").
→ *Honest alternative if the owner wants the chip row's shape:* bind it to the create flow the app
really has — `✓ <Tier>` (done) + `2 · Location` (active) — which needs a public `Tier? get tier` on
`ComposeRequestController` (wiring request W4). If that is refused, omit the row with a TODO.
**A real drop-off leg is a product change, not a restyle. Owner decision.**

**C2 — "Drop-off here" pin callout. REFUSED (same root cause).** Render a neutral
`captureLocationPinCallout` ("Pin here" / AR equivalent).

**C3 — "Rue Monot 42, Achrafieh". REFUSED as drawn.** No reverse-geocode source exists (§4-D2).
Render the saved address's real label when one is selected, else the coordinate label the create
already ships. Do **not** call `InMemoryLocationRepository.reverseGeocode` — it returns a fabricated
Beirut catalogue entry.

**C4 — "Search street, building…" field. REFUSED.** `LocationSelectRepository` has no search
(`domain/location_select_repository.dart` exposes only `fetchSavedAddresses`); the only
`searchAddress` implementation is the same fabricated in-memory catalogue
(`data/location_repository.dart:154-162`), and no Places/geocoding client or dependency exists.
Adding it would also add a raw-`TextField` gate violation. **This is a data-source refusal, not the
"deleted client-side search" decision** — do not mis-cite C8 here.

**C5 — Live draggable map on `/capture-location`. REFUSED to wire.**
`app_router.dart:123-152` documents the deliberate refusal ("no live draggable map injected yet
(B-23, Maps SDK key owner-gated)… now 'Pin Location' pops with NO coordinate"), and
`pin_location_coordinate_survives_b35_test.dart` drives the **production** router and asserts
`submitCount == 0`. Restyle the chrome; leave `CaptureLocationRoute` behaviourally identical.
**Owner decision** (unblocking the Maps key).

**C6 — Periwinkle subtitles under the address title. PARTIALLY REFUSED.**
The board sets the address card's second line to `--jeeb-periwinkle #777FC0` (HTML tpl 554).
`client_location_screen.dart:626-635` carries an explicit owner-reported fix — *"the unselected row
sits on the white surface, so the subtitle must use `onSurfaceVariant` (AA 9.35:1), NOT periwinkle
(the ~2.2:1 light-purple-on-white the owner reported)"* — and `color_role_contrast_test` pins that
periwinkle fails AA on white. `JeebSemanticColors.mutedText` is declared decorative-only in §4.6.
→ Real subtitle/body ink stays `colorScheme.onSurfaceVariant`. `mutedText` appears only inside kit
widgets that already own it (`JeebSectionLabel`, `JeebInfoNote`).

**No `decision_violations_test.dart` decision touches this screen** (it covers D56, D52, D20 and the
earnings framing). B04 is chat-only. D41/D44 and `kJeebCommissionRate` do not appear here.

---

## 10. Risks

1. **R1 — The board's screen lands on a placeholder.** The most visible part of the redesign (map +
   draggable pin + address card) ships as chrome over `CaptureMapViewport`'s grey box until the Maps
   key is unblocked. A screenshot review of `/capture-location` will not look like the PNG, and that
   is correct behaviour, not a lane failure.
2. **R2 — "Screen 09 done" is ambiguous.** A reviewer comparing the PNG against `/client-location`
   will conclude the lane skipped the design. The mapping in §0 must travel with the PR.
3. **R3 — Pill tap targets.** `pad 8/14` + 12.5px text ≈ 34px tall; below the 48dp minimum the
   current full-width cards satisfy today. `JeebSelectChip` must guarantee a 48dp hit area (or wrap
   each pill in a `ConstrainedBox`). Real a11y regression risk in the collapse.
4. **R4 — Horizontally scrolled saved places vs. `find.bySemanticsIdentifier`.** A lazy `ListView`
   builds no element for off-screen pills, so `location_select_saved_address_<id>` for the second or
   third address becomes unfindable. Use a non-lazy `Row` in a `SingleChildScrollView`.
5. **R5 — `LocationSelectState.props` grows.** Adding `gpsAccuracyMeters` changes state equality;
   any whole-state literal comparison in a `bloc_test` `expect` list needs a look
   (`compose_request_controller_test.dart` constructs `LocationSelectState(...)` literals — those
   still compile, but re-run the suite).
6. **R6 — Fully blocked on Wave 1.** `lib/core/widgets/jeeb/` does not exist yet; this lane needs
   build-order steps 1 (`JeebOutlinedCard`), 2 (`JeebInfoNote`), 3 (`JeebTopBar`), 4 (`JeebCtaFooter`)
   and 5 (`JeebSelectChip`) before a single line lands.
7. **R7 — `/client-location` cannot reach the board's emptiness.** Description + GPS card + saved
   places + map row + phone is genuinely more than one viewport. Tighten the gaps, keep the scroll,
   do not force a `flex:1` spacer that would push the phone field off-screen.
8. **R8 — Cross-lane file.** `DeliveryCreateLayout.pagePadding` is shared with
   `request_type_screen.dart:138,219` (screens 07/08). Changing 20 → 24 silently restyles their
   gutters too; coordinate or add a second constant.

---

## 11. Wiring requests (outside this lane)

- **W1 — l10n integrator (append-only batch, EN + real AR + `@key` + `_get` getter):**
  `clientLocationGpsAccuracy` (takes a `{meters}` number placeholder),
  `captureLocationPinCallout` ("Pin here"),
  `clientLocationSavedPlacesLabel` ("SAVED PLACES", uppercased by `JeebSectionLabel`),
  `clientLocationBackSemantic` / `captureLocationBackSemantic`.
- **W2 — kit owner, `JeebTopBar` (§5 #1):** add a `floating` treatment — `colorScheme.surface` fill +
  `JeebShadows.floatPill` instead of `surfaceContainerHigh` — for a back circle over a map.
  Screens 09 and 12 both need it.
- **W3 — kit owner, `JeebSelectChip` (§5 #6):** confirm 09's saved-place pill (`pad 8/14`,
  `12.5/w600`, **navy** ink, `1.5px outline`) maps to `role: quickReply`, and expose a filled
  unselected tone (`surfaceContainerHigh` + navy w700 — R2's "meta chip" row) which 09's step chips
  would need if C1's alternative is taken. **Do not let this lane invent a local padding.**
- **W4 — `request_summary` lane:** a public `Tier? get tier` on `ComposeRequestController`, *only if*
  the owner accepts the C1 alternative (create-flow step chips). Otherwise no change.
- **W5 — owner decisions:** (a) is a real drop-off leg in scope? (b) unblock the Maps API key so
  `/capture-location` gets a live draggable pin (B-23)?
- **W6 — screens 07/08 lane:** agree the `DeliveryCreateLayout.pagePadding` gutter change 20 → 24, or
  this lane adds a separate constant.
- **Router: no change requested.** **DI: no change requested.**
