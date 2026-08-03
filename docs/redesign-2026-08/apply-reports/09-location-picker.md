# 09 · Location picker — apply report

**Status: APPLIED.** All 12 tasks of `per-screen-revised/09-location-picker.md` are done.
One dependency is outstanding and is the *only* thing not green: the two new l10n members, which
belong to the serialized integrator (`wiring/09-location-picker.md`).

---

## The §0 mapping, restated for the PR description

The prompt's `location_picker_screen.dart` is dead (ORPHAN tag, devtool-only importer). The board's
map-first screen landed on **`/capture-location`**; **`/client-location`** was restyled to the same
language and NOT merged into it — merging would have deleted the `POST /requests` gate, the G1
description contract and the OTP recipient-phone capture, none of which the board draws.

**`/client-location` therefore does not look like the PNG, and that is correct.** The PNG is the
capture surface.

## Files changed (all inside `lib/features/location/**` + this screen's own tests)

| file | what |
|---|---|
| `domain/current_location_resolver.dart` | `CurrentLocationResult.resolved` gains optional named `accuracyMeters`; lat/lng stay positional; `props` grows |
| `data/geolocator_current_location_resolver.dart` | threads `fix.accuracyMeters` (the gateway already carried it; it was dropped here) |
| `application/location_select_state.dart` | `gpsAccuracyMeters` field + `copyWith` (nulled by `clearGps`) + `props` |
| `application/location_select_cubit.dart` | threads `result.accuracyMeters` into the `resolved` emit |
| `presentation/capture_location_screen.dart` | **rebuilt** as a full-bleed `Stack`: map to every edge, floating back circle, docked sheet. `OMDSAppBar` and the `Column(Expanded, CTA)` body are gone. New optional `controller` param |
| `presentation/widgets/capture_picker_sheet.dart` | **new** — grab handle + pinned-point card + `JeebCtaFooter.single` CTA |
| `presentation/widgets/capture_location_pin.dart` | callout pill (own sibling Semantics node) + ground mark + `0 6 10 @.25` glyph shadow; tip re-anchored |
| `presentation/widgets/google_map_capture_view.dart` | `_CentreOnMeButton` is a Ø48 white disc + `floatPill`, no longer a FAB; new `bottomInset` so it clears the docked sheet |
| `presentation/widgets/capture_map_viewport.dart` | `Icons.map_outlined` → `Icons.map` (R10) |
| `presentation/widgets/current_location_status_card.dart` | accuracy subtitle; resolving/resolved move INTO the card's subtitle slot; `_Recovery` token pass |
| `presentation/widgets/client_location_option_card.dart` | the board's address card: red pin + `cardTitle` + subtitle slot; radio glyph deleted; selection = fill swap |
| `presentation/widgets/client_location_add_row.dart` | `JeebOutlinedCard` row; tap moved onto the card so the ripple is visible |
| `presentation/widgets/saved_address_pill_row.dart` | **new** — `JeebChipRow.scrollable` + `JeebSelectChip(role: quickReply)` + `MinTapTarget` |
| `presentation/client_location_screen.dart` | `JeebTopBar`, `client_location_root`, `h1` heading, R12 gaps, pill row replaces the stacked cards, `JeebCtaFooter` + `ctaNavy` footer, orange mic, token inks, pill phone field |
| `data/google_map_picker_launcher.dart` | passes the controller through to the sheet + the recentre clearance |
| `test/features/location/location_select_cubit_test.dart` | **ADD** 2 cases (accuracy threads; `clearGps` nulls it; null stays null) |
| `test/features/location/client_location_screen_test.dart` | **ADD** 2 cases (accuracy line renders; falls back when null) |

## Kit widgets consumed (no hand-rolled copies)

`JeebTopBar` (both screens) · `JeebOutlinedCard` (pinned-point card, add row) ·
`JeebCtaFooter.single` (both CTAs) · `JeebChipRow.scrollable` + `JeebSelectChip` (saved pills) ·
`JeebShadows.{ctaNavy, sheet, floatPill}` · `context.jeebText.*` · `context.jeebRoles.accent` ·
`MinTapTarget`.

**The instruction set's screen-local `_MapBackButton` fallback was NOT built.** It was written when
the kit was empty; `JeebTopBarLeadingTreatment.floating` ships today and does exactly what the
wiring block asked for, so `capture_location_screen.dart` consumes it and the block is marked
ALREADY SATISFIED. Its TODO is void — per the 00-MIGRATION-PLAN STOP block.

## Verification

| gate | result |
|---|---|
| `dart analyze lib/features/location` | **3 errors, all one cause**: `captureLocationPinCallout` ×2 + `clientLocationGpsAccuracy` ×1. Zero warnings, zero infos, nothing else. |
| same, with the wiring l10n applied locally | **`No issues found!`** |
| `flutter test` — `client_location_screen_test`, `location_select_cubit_test`, `capture_location_map_injection_test`, `google_map_picker_launcher_test`, `delivery_create_screens_test`, `map_capture_controller_test` (wiring applied locally) | **39/39 passed** |
| `bash tool/check_design_tokens.sh` | **exactly 8 violations** — unchanged baseline; mine is still only the pre-existing raw `TextField` at `client_location_screen.dart:1023` |
| identifier freeze | every §1 identifier still greps in `lib/features/location/`; all 7 new ids present; none renamed |

**How the l10n gate was verified without editing `lib/l10n/`.** The two members were applied
locally, the suites run, and then reverted **surgically** (only my own three insertions removed,
by exact-string match, asserted `count == 1` each). `lib/l10n/*.arb` parse as valid JSON and
`app_localizations.dart` analyzes clean; the concurrent lanes' large in-flight edits to those
files were left untouched. The revert script is
`<scratchpad>/s09_l10n.py` if the integrator wants to replay it.

**Five location tests could not be run at all**, and not because of this screen:
`location_confirm_creates_request_b11`, `location_confirm_double_submit_guard_b02`,
`location_confirm_enabled_when_saved_locations_unavailable`,
`location_confirm_route_current_guard_b02b`, `pin_location_coordinate_survives_b35`. They mount the
production `AppRouter`, which pulls in **nine other lanes** that have already shipped ungranted
l10n getters (`home_client`, `onboarding`, `registration`, `request_summary`, `transcription`,
`voice_request`, `delivery_receipt`, …). Nothing from `lib/features/location/` appears in that
compile-error list. They will run once the integrator lands the l10n batch.

## Refusals held (§3) — every one is absent from the shipped code

- **C1 step chips** (`Pickup set` / `2 · Drop-off`) — not built; `// TODO(redesign-24): step chips
  omitted — single-point leg; owner decision D-09a.` in `capture_picker_sheet.dart`.
- **C2 "Drop-off here"** — the callout renders `captureLocationPinCallout` = **"Pin here"**.
- **C3 "Rue Monot 42, Achrafieh"** — the pinned-point card shows the live coordinate to 4 dp with
  `// TODO(redesign-24): needs gateway reverse-geocode — omitted, not faked.`
- **C4 search field** — not built.
- **C5 live map** — `CaptureLocationRoute` untouched; the placeholder still pops without a
  coordinate; chrome-only restyle.
- **C6 periwinkle on white** — every real text ink is `onSurfaceVariant` (or `onPrimary` on navy).

## Deliberate deltas from the instruction set (each with its reason)

1. **`_MapBackButton` → `JeebTopBar` floating** — see above. The kit shipped the exact treatment.
2. **`_Resolved` lost its `Icons.my_location` glyph.** Task 6 said swap it to the filled variant.
   But task 10 moved that line INTO the card's subtitle slot, and the card already leads with
   `Icons.location_on`; the render's meta line ("GPS · accurate to 8 m") carries no glyph at all.
   The render wins.
3. **The three `_Recovery` glyphs also went filled** (`location_disabled`, `location_off`,
   `gps_off`). Task 6 only named `my_location_outlined`, but R10 is unambiguous and these sit in
   the same token pass. No identifier or copy moved.
4. **A `bottomInset` was added to `GoogleMapCaptureView`.** Task 4 said keep
   `PositionedDirectional(bottom, end)` — correct under the OLD layout, where the map ended above
   the CTA. Under the rebuilt full-bleed Stack the recentre control landed *behind* the sheet.
   The placement is still `PositionedDirectional`; only the clearance is now supplied
   (`CapturePickerSheet.dockedClearance` + the device safe-area, read at the button).
5. **The capture CTA got the same `ctaNavy` `DecoratedBox` as the client-location Confirm.** The
   task text specified the shadow wrap only for the latter; the render draws the same lifted navy
   pill on both, and both drop the shadow when disabled (kit §1.6).
6. **The AR accuracy string carries U+2066/U+2069 isolates around `{meters}`** (in the wiring
   request, not in Dart). §4 asked for the figure to be LTR-isolated; the isolate belongs in the
   translated value, not in a `Directionality` wrapper that would flip the Arabic around it. The
   coordinate label, where the reorder hazard is real (comma + two numbers), IS wrapped in
   `Directionality(ltr)` in `capture_picker_sheet.dart`.

## Owner decisions to log (not wiring)

- **D-09a** — the step-chip alternative ("✓ Tier / 2 · Location") needs `Tier? get tier` on
  `ComposeRequestController` + a kit chip tone + sign-off.
- **D-09b** — unblock the Maps API key (B-23) so `/capture-location` gets the live pin. Until then
  the new chrome renders over the grey placeholder viewport, which is correct, not a bug.
- **D-09c** — is a real drop-off leg in scope? The board draws one; the backend has none.

## Pre-existing rot, flagged not fixed

- Maestro `10-client-location.yaml` targets `client_location_add_new`, but the live screen overrides
  that row to `location_select_new_location_cta`. Both values left exactly as they were.
- `check_design_tokens.sh` baseline stays at 8, including the raw `TextField` in
  `_RecipientPhoneField`. Not fixed, not added to.
- `captureLocationTitle` ("Location") is now an orphan ARB key — the capture screen has no title
  bar in the redesign. Left in place; no gate checks for orphans and nothing else references it.
- No goldens exist for this feature.
