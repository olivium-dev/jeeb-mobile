# Wiring requests — 09 · Location picker

Source of truth: `docs/redesign-2026-08/per-screen-revised/09-location-picker.md` §6.
Screen code is written as if every request below has been granted.

Router: **no change**. DI: **no change**. Theme: **no change** (Wave-0 tokens already exist).

---

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
    "clientLocationGpsAccuracy": "GPS · دقة حتى ⁦{meters}⁩ م",
    "captureLocationPinCallout": "ثبّت هنا"
why: Task 6 renders the accuracy subtitle; task 3 renders the callout. No back-semantic keys are needed (MaterialLocalizations.backButtonTooltip is used instead).

### l10n
file: lib/l10n/app_localizations.dart
need: ADDENDUM (same finding the 07 lane recorded) — `AppLocalizations` in this repo is **hand-authored**, not `flutter gen-l10n` output, so adding the two ARB entries above is NOT sufficient: the typed members must be hand-added in the same commit or the app does not compile.
exact change: add alongside the existing `clientLocationGps*` / `captureLocation*` getters:
```dart
  String get captureLocationPinCallout => _get('captureLocationPinCallout');

  String clientLocationGpsAccuracy(int meters) =>
      _get('clientLocationGpsAccuracy').replaceAll('{meters}', '$meters');
```
why: `capture_location_pin.dart` and `current_location_status_card.dart` call both today. Until this lands, `dart analyze lib/features/location` reports exactly 3 errors (2 call sites of the getter, 1 of the method) and nothing else — that is the entire remaining delta for this screen.

### cross-feature
file: lib/core/widgets/jeeb/jeeb_top_bar.dart (kit owner, Wave-1 step 3)
need: A `floating` leading treatment — colorScheme.surface fill + JeebShadows.floatPill instead of surfaceContainerHigh — for a back circle floating over a map.
exact change: add `JeebTopBarLeadingTreatment.floating` (or equivalent flag) that renders the Ø40 back circle with `color: colorScheme.surface` and `boxShadow: JeebShadows.floatPill`; glyph unchanged (20px navy DirectionalIcons.back).
why: Screen 09's /capture-location back button floats over the map (render + HTML tpl 526: white fill, shadow rgba(11,19,81,.18) 0 6 16); screen 12 needs the same. Until granted, 09 ships a screen-local _MapBackButton with a TODO.

> **STATUS: ALREADY SATISFIED — integrator, no action.** The shipped kit defines
> `JeebTopBarLeadingTreatment.floating` (`jeeb_top_bar.dart:25-32`, painted at `_circle`) exactly as
> requested. `capture_location_screen.dart` therefore consumes `JeebTopBar.back(leadingTreatment:
> JeebTopBarLeadingTreatment.floating, identifier: 'capture_location_back')` and **no screen-local
> `_MapBackButton` was written** — the instruction set's fallback and its TODO are void, per the
> 00-MIGRATION-PLAN STOP block ("the kit EXISTS; import it, do not inline it").

### cross-feature
file: lib/features/location/presentation/widgets/delivery_create_layout.dart
need: Page gutter 20 → 24 to match the board-wide 24px gutter (HTML tpl 525/538).
exact change: in DeliveryCreateLayout.pagePadding, `Spacing.large` → `Spacing.xLarge` for the start/end insets (top/bottom unchanged).
why: The file lives in the location feature but request_type_screen.dart (screens 07/08) imports it — applying it via the integrator makes the 07/08 lane see the gutter change consciously instead of silently mid-flight. Screen 09 code is written against the 24px gutter.
