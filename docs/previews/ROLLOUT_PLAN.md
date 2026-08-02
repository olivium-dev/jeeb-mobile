# Widget-preview rollout — plan

**Goal:** every public, non-screen widget in `lib/` has at least one `@JeebPreview`,
so any of them can be seen in EN / AR-RTL / 200%-text without booting the app.

**Scope:** 168 widgets (tier A — public, non-screen). Screens are excluded: the
on-device Screen Catalog already covers them with 270 mocked states. Private
`_`-prefixed widgets are exercised through their parent's preview.

**Status:** run `dart run tool/preview_coverage.dart`.

---

## 1. Where things live

```
lib/previews/               ← ALL preview code. Nothing outside imports it.
├── README.md               ← conventions (read before writing one)
├── harness/jeeb_preview.dart
├── fixtures/
├── core/
└── <feature>/

test/previews/
├── preview_test_harness.dart      ← testPreviewsRender()
├── preview_structure_test.dart    ← the two ratchets
└── <feature>/

tool/preview_coverage.dart         ← the work queue
tool/workflows/preview_rollout.js  ← one wave, fanned out
```

Previews **must** be under `lib/` — the generated preview scaffold imports them as
`package:` URIs. Collecting them in `lib/previews/` rather than beside each widget
is what keeps `lib/features/**` free of dev-only code.

## 2. The unit of work

One widget → two new files, never a production edit:

| | |
|---|---|
| `lib/previews/<area>/<widget>_preview.dart` | 3–6 `@JeebPreview` functions |
| `test/previews/<area>/<widget>_preview_test.dart` | `testPreviewsRender(...)` with `expectedText` |

`@JeebPreview` expands each function into **EN light / AR RTL dark / EN 200% text**.

A widget is **done** when `flutter analyze` and its render test are both clean.

## 3. How it runs

Three pieces, composed:

**`tool/preview_coverage.dart`** is the queue. It lists every uncovered widget with
its target paths, grouped by area, `--json` for automation. A widget counts as
covered when its class name appears anywhere under `lib/previews/`.

**`tool/workflows/preview_rollout.js`** is one wave. Given a batch of ~8 widgets it
runs one agent per widget in parallel — each reads the widget and its existing
tests, writes both files, and **runs analyze + test itself** before reporting.
Agents never share a file, so there is no write contention. A final integration
agent re-runs the whole preview suite, lowers the coverage floor, and spot-checks
two files against the README.

**The loop** repeats waves until the queue is empty:

```
/loop Run one wave of the widget-preview rollout in
  jeeb-mobile/.claude/worktrees/widget-previews-pilot:
  1. dart run tool/preview_coverage.dart --json
  2. take the next 8 uncovered widgets, finishing one area before starting another
  3. invoke tool/workflows/preview_rollout.js with that batch
  4. commit + push the wave
  5. if the queue is empty, stop the loop
```

At 8 per wave, 167 remaining is ~21 waves.

## 4. Order of areas

Highest-leverage and highest-churn first, so the shared surface stabilises before
the long tail.

| Wave group | Areas | Widgets |
|---|---|---|
| 1 | `chat` | 18 |
| 2 | `core` | 22 |
| 3 | `home_client`, `shell` | 20 |
| 4 | `live_tracking`, `delivery_status`, `active_delivery_jeeber` | 16 |
| 5 | `jeeber_*` (home, onboarding, request_feed, request_detail) | 24 |
| 6 | `location`, `kyc`, `customer_profile`, `delivery_man_profile` | 28 |
| 7 | everything else (26 areas at 1–4 each) | ~40 |

`chat` and `core` lead because July's push/Firestore migration churned chat hardest,
and `lib/core/widgets` is used by every other area.

## 5. What stops this from rotting

`test/previews/preview_structure_test.dart` holds two invariants on every CI run:

1. **Nothing outside `lib/previews/` imports it.** This is what makes "previews are
   tree-shaken out of release builds" true rather than aspirational.
2. **The uncovered count only goes down.** Each wave lowers `_coverageFloor`. A
   deleted or renamed preview fails CI instead of silently reducing coverage.

Neither the canvas nor `flutter widget-preview start` runs in CI, which is exactly
why every preview also carries a render test.

## 6. Known limits

- **The canvas search box is broken in Flutter 3.44.2** — it filters labels but
  renders by unfiltered index, so a card can be labelled X and contain widget Y.
  Scroll instead. This cost real debugging time once; do not re-derive it.
- **Not every widget is previewable.** Behavioural wrappers with no visual output of
  their own (`RouteResumeRefetch`, `PollingVisibilityGate`, `GestureLogListener`,
  `RouteVisibilityScope`) have nothing to show. Agents report these as
  `skipped-not-previewable` rather than inventing a fake state; they are then
  excluded from the floor rather than counted as debt.
- **Widgets with no injectable seam** cannot be previewed without a production
  change. Agents are instructed NOT to add the seam — they report what is missing so
  it can be decided deliberately, in its own PR.

## 7. Environment prerequisites

Two drifts must be fixed in any checkout doing this work (both are environment, not
code):

- `../omds-flutter` must be on `main` (2026-07-24 or later). The
  `iter5-flutter-blankscreen` branch predates the `identifier:` param mobile passes
  to OMDS buttons.
- `pubspec.lock` is gitignored, so a stale `.dart_tool` can pin **dio 5.9.2**, which
  lacks `DioExceptionType.transformTimeout`. A fresh `flutter pub get` resolves
  5.11.0.
