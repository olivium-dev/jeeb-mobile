# Widget-preview rollout — plan

**Goal:** every public, non-screen widget in `lib/` has at least one `@JeebPreview`,
so any of them can be seen in EN / AR-RTL / 200%-text without booting the app.

**Scope:** 150 widgets (tier A — public, non-screen). Screens are excluded: the
on-device Screen Catalog already covers them with 270 mocked states. Private
`_`-prefixed widgets are exercised through their parent's preview.

**Status:** 128/150 covered · 726 preview functions · 22 remaining. Run
`dart run tool/preview_coverage.dart`.

---

## 1. Where things live

Previews live at the **bottom of the widget's own source file**, below a
`// ===== JEEB PREVIEWS =====` banner.

```
lib/<anywhere>/some_widget.dart
├── production code
└── // ===== JEEB PREVIEWS =====   ← fixtures + @JeebPreview functions

lib/core/previews/
├── README.md                      ← conventions (read before writing one)
└── jeeb_preview.dart              ← the shared annotation + host wrapper

test/previews/
├── preview_test_harness.dart      ← testPreviewsRender()
├── preview_structure_test.dart    ← the seven invariants
└── <feature>/                     ← one render test per widget (unchanged)

tool/preview_inventory.dart        ← the detector, shared by the two below
tool/preview_coverage.dart         ← the work queue
tool/workflows/preview_rollout.js  ← one wave, fanned out
```

### Why they moved out of `lib/previews/`

`flutter widget-preview start` records a `scriptUri` per preview — **the file the
function is declared in** — and the IDE panel filters the canvas to the file you have
open. With previews in a parallel tree, opening `chat_message_bubble.dart` showed you
nothing; its previews were attributed to
`lib/previews/chat/chat_message_bubble_preview.dart`, a file nobody was editing. You
had to know the mirror path and open it by hand, which is exactly the friction previews
exist to remove.

Two other things went with it. The mirror layout could drift (rename the widget, orphan
the preview), and the coverage rule had to infer the mapping from a file name — already
wrong for `ActiveOrderCard` and `ClientHomeTierBadge`, both of which live in
`active_request_card.dart`.

Previews still **must** be under `lib/`: the generated preview scaffold imports them as
`package:` URIs, so a file in `test/` is invisible to the tool.

The old layout existed to keep `lib/features/**` free of dev-only code. The banner does
that job better — it is a hard, greppable line, and §5 asserts that nothing above it
references anything below it, which is a stronger statement than any import rule.

## 2. The unit of work

One widget → one file edited, one file written:

| | |
|---|---|
| a `JEEB PREVIEWS` section at the bottom of the widget's own source file | 3–6 `@JeebPreview` functions |
| `test/previews/<area>/<widget>_preview_test.dart` | `testPreviewsRender(...)` with `expectedText` |

Render tests stay in `test/previews/<area>/`. With `lib/previews/` gone that tree is
the only remaining index of what has previews, and `test/` root is already a flat pile
of ~200 widget tests.

`@JeebPreview` expands each function into **EN light / AR RTL dark / EN 200% text**.

Every top-level name in the section is prefixed with the widget's name
(`_clientHomeGreetingHosted`, not `_hosted`) so that a file holding previews for two or
three widgets cannot collide. See `lib/core/previews/README.md`.

A widget is **done** when `flutter analyze` and its render test are both clean.

## 3. How it runs

Three pieces, composed:

**`tool/preview_coverage.dart`** is the queue. It lists every uncovered widget with
its source file, grouped by area, `--json` for automation. A widget counts as covered
when its **own source file** declares a `@JeebPreview` function named after it AND the
section actually constructs it. Both, not either: construction alone lets a sibling's
fixture take the credit; the name alone lets a mis-typed fixture pass. One signal
without the other is reported as **MALFORMED** and fails CI. The detector itself lives
in `tool/preview_inventory.dart` and is shared with the structure test.

**`tool/workflows/preview_rollout.js`** is one wave. Given a batch of ~8 widgets it
runs one agent per widget in parallel — each reads the widget and its existing tests,
appends the preview section, writes the render test, and **runs analyze + test itself**
before reporting. Agents never share a file, so there is no write contention — but note
that co-location means the file an agent edits is now production code, so a half-written
section breaks the library and everything downstream of it. A final integration agent
re-runs the whole preview suite, lowers the coverage floor, and spot-checks two sections
against the README.

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

At 8 per wave, the 22 remaining is ~3 waves. The 22 are listed by
`dart run tool/preview_coverage.dart`; they are the long tail — one or two widgets
each across 20 small areas.

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

**All seven wave groups have landed** (waves 01–17, then the co-location migration).
What remains is the group-7 long tail — see the queue, not this table.

## 5. What stops this from rotting

Co-location removed the directory boundary that used to keep previews out of shipping
code, so `test/previews/preview_structure_test.dart` replaces it with seven invariants
that work on **references** rather than on file paths — strictly stronger, because a
fixture that leaks is caught even though it is one scroll away from the widget:

1. **`lib/previews/` does not exist.** The migration's completeness gate.
2. **The harness is imported only by files that have a preview section** — catches an
   import left behind after someone deletes previews.
3. **No `@JeebPreview` above a banner**, and at most one banner per file.
4. **Nothing above a banner references anything below it.** This is what makes
   "previews are tree-shaken out of release builds" true rather than aspirational.
5. **Nothing below a banner is referenced from another library under `lib/`.** Preview
   functions are public because the SDK requires it, so privacy does not protect them.
   `test/` is exempt — that is where they are legitimately called.
6. **Every name below a banner is widget-prefixed**, and public only when a test
   actually uses it.
7. **The uncovered count only goes down**, and no widget is MALFORMED. Each wave lowers
   `_coverageFloor`. A deleted or renamed preview fails CI instead of silently reducing
   coverage.

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
