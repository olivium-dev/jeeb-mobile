# Widget previews

A preview is a small function that renders one widget in one designed state, viewable
in a hot-reloading canvas without booting the app or signing in.

```bash
flutter widget-preview start        # opens the canvas in Chrome
```

**Previews live at the bottom of the widget's own source file**, below a banner. This
directory holds only the shared annotation (`jeeb_preview.dart`) and this document.

## Why previews live in the widget file

Because that is what the IDE panel keys on. `flutter widget-preview start` records a
`scriptUri` per preview — the file the function is *declared* in — and the IDE filters
the canvas to the file you have open. When previews lived in a parallel `lib/previews/`
tree, opening `chat_message_bubble.dart` showed you nothing: the previews for that
widget were attributed to `lib/previews/chat/chat_message_bubble_preview.dart`, a file
nobody was editing. You had to know the mirror path and open it by hand, which is
exactly the friction previews exist to remove.

Co-locating also collapses two failure modes into zero. The mirror layout could drift
(rename the widget, orphan the preview) and the coverage rule had to guess the mapping
from a file name — which was already wrong for `ActiveOrderCard` and
`ClientHomeTierBadge`, both of which live in `active_request_card.dart`.

The old arrangement was chosen to keep `lib/features/**` free of dev-only code. The
banner does that job better: it is a hard, greppable line, and
`test/previews/preview_structure_test.dart` asserts that nothing above it references
anything below it.

## Cost at runtime: none

A preview is an unreferenced top-level function. Nothing in the app calls one, so the
AOT compiler tree-shakes it out of release builds; the `@JeebPreview` annotation is a
`const` object that is never read at runtime.

The harness pulls `lib/devtool/catalog/catalog_network_guard.dart` into every feature
library that imports it, which pulls `dio` and the injection container. Both are
already in the transitive graph of every one of those libraries, so this adds nothing
new to the release binary.

## The layout inside a widget file

The section goes at the **very bottom**, after the last production declaration.
Nothing production may follow it.

```dart
// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/<area>/<snake>_preview_test.dart
// ===========================================================================
//
// Prose about what these previews are for goes here, in `//` — never `///`.
// A dangling doc comment silently re-attaches itself to the next declaration.

/// The canvas box for a home header: phone width, header height.
const Size _clientHomeGreetingHeaderBox = Size(390, 120);

Widget _clientHomeGreetingHosted(GreetingProfileState? profile) { … }

@JeebPreview(
  group: 'home_client',
  name: 'Named + avatar',
  size: _clientHomeGreetingHeaderBox,
)
Widget clientHomeGreetingNamed() => _clientHomeGreetingHosted(…);
```

Copy the banner bytes verbatim — the opening and closing rules are 78 characters and
the structure test matches on `^// =+ JEEB PREVIEWS =+$`. Exactly one banner per file,
even when a file holds several previewed widgets. Substitute the real test path on the
last line.

Order inside the section: banner → prose → size constants → private fixtures →
`@JeebPreview` functions.

The harness import goes at the **end** of the file's existing import block, under a
marker, so a reader can see what is preview-only. `directives_ordering` is not enabled,
so appending is legal; do not reorder the existing imports.

```dart
// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
```

## Naming — every top-level name below the banner is prefixed with the widget name

Mandatory, mechanical, no judgement calls. Some files hold previews for two or three
widgets, and before this rule 232 preview files each declared a `_hosted`.

| | |
|---|---|
| preview functions (public — the SDK requires it) | `clientHomeGreetingNamed` |
| private values / functions | `_clientHomeGreetingHosted` |
| private types | `_ClientHomeTierBadgeActiveHeader` |

Everything below the banner should be **private**. The exception is a fixture the
render test needs to reference — `notificationPermissionPromptTaps`,
`jeeberRequestUnavailableScreenBrowseTaps`. Those stay public, still prefixed, and the structure test requires
that every public non-preview name below a banner is actually used from `test/`.

The SDK constrains preview functions themselves (`_PreviewVisitor.visitFunctionDeclaration`):
top-level or `static`, **public**, explicit non-nullable return type, **no required
parameters**, under `lib/`.

## Writing one

**Always pass `group:`** — the feature area. The canvas renders one collapsible section
per group, which is what keeps ~730 previews navigable instead of one undifferentiated
wall. It is also the only reliable way to navigate: the canvas's own search box is
broken (see below).

By default each annotation renders **one** card: EN light. Pass `matrix: true` for the
full **EN light / AR RTL dark / EN 200% text** set side by side:

```dart
@JeebPreview(group: 'chat', name: 'Long note', matrix: true)
```

Use it where seeing them together is the point — a Row of text and actions, an
RTL-sensitive layout, copy whose length swings by locale. It is off by default because
all three for every widget is ~2200 cards and a slow first paint.

**This does not weaken the guarantee.** `testPreviewsRender()` pumps every preview in
**both** locales on every CI run, so AR stays asserted whether or not the canvas draws
it. The matrix flag controls what you *look at*, not what is *checked*.

Rules that keep previews honest:

- **No network.** Seed state through an inert cubit or a local fake — never a real
  repository. `jeebPreviewHost` additionally installs `CatalogNetworkGuard`, which
  rejects every non-GET verb, but that is a net, not the plan.
- **Cover the states that break**, not just the happy path: empty, loading, error,
  longest-plausible content, and any regression a bug report already produced.
- **Add a render test** at `test/previews/<area>/<snake>_preview_test.dart`. Nothing in
  CI opens the canvas, so an untested preview rots silently. Each asserts that each
  preview renders *its own* state, which is what distinguishes a real bug from a canvas
  display bug.
- **Never leave a widget file half-edited.** A broken fixture now marks the whole
  library — and every library that imports it — as errored, in the canvas
  (`PreviewDetector._propagateErrors`), in `flutter analyze`, and in `flutter build`.
  This is the one real cost of co-location.
- **No file-level `// ignore_for_file:`.** It would silently weaken analysis of the
  shipping code above the banner. Use a line-level `// ignore:` inside the section.

## What the structure test enforces

`test/previews/preview_structure_test.dart` (detector shared with
`tool/preview_coverage.dart` via `tool/preview_inventory.dart`):

1. `lib/previews/` does not exist.
2. The harness is imported only by files that have a preview section.
3. No `@JeebPreview` above a banner; at most one banner per file.
4. Nothing above a banner references anything below it.
5. Nothing below a banner is referenced from another library under `lib/`.
6. Every name below a banner is widget-prefixed; every public one is a preview function
   or is used from `test/`.
7. The coverage ratchet — the uncovered count never rises.

## Coverage

A widget is **covered** when its own source file declares at least one `@JeebPreview`
function named after it **and** the section actually constructs it. Both, not either:
construction alone lets a sibling's fixture take the credit, and the name alone lets a
mis-typed fixture pass. A widget with one signal and not the other is reported as
**MALFORMED** — almost always a half-finished edit.

```bash
dart run tool/preview_coverage.dart            # summary by area
dart run tool/preview_coverage.dart --json     # machine-readable queue
dart run tool/preview_coverage.dart --area chat
```

Deliberate exclusions live in `tool/preview_exclusions.txt`. Whole trees that are out
of scope (`lib/devtool/`, `lib/l10n/`, `lib/core/observability/`) are listed in
`tool/preview_inventory.dart`. Note that `lib/core/observability/` is excluded from the
*count* but `ObsOverlayBubble` and `ObsOverlayPanelHeader` do carry previews — they
just do not score.

## Relationship to the Screen Catalog

`lib/devtool/catalog/` is the designer-facing, on-device browser of whole **screens**
(89 screens / 282 mocked states). Previews are the engineer-facing desktop loop for
individual **widgets**. Both share `CatalogNetworkGuard`.

Screens are **in** scope for coverage. `tool/preview_coverage.dart` used to skip any
class ending in `Screen` on the grounds that the catalog covered them; it covers ~56 of
82, from inside the app rather than the IDE, and no screen had a preview — so the tool
reported 100% while 80 screens showed nothing when opened. The exclusion is gone, which
is why the ratchet in `preview_structure_test.dart` sits above zero: the widget queue
is empty and the remainder is screens.

When a screen is previewed, extract the catalog entry's fixtures into
`lib/devtool/catalog/fixtures/<snake>_fixtures.dart` and point BOTH surfaces at it —
never copy them into the preview section. Two copies of the same "designed state" drift,
and the catalog is the one a designer signs off against.

## Known tooling bug (Flutter 3.44.2)

The canvas's **search box renders the wrong previews** — it filters the labels but
renders by unfiltered index, so searching can show a card labelled X containing
widget Y. Scroll instead of searching until this is fixed upstream.

## Canvas performance — one SDK-level patch

Groups render **collapsed by default**. That is NOT configurable from this repo:
`initiallyExpanded: true` is hardcoded in Flutter's scaffold template at

```
$(dirname $(readlink -f $(which flutter)))/../packages/flutter_tools/templates/
  widget_preview_scaffold/lib/src/widget_preview_rendering.dart.tmpl:283
```

It has been flipped to `false` on this machine. Consequences worth knowing:

- The change is **global to this Flutter install**, not to this project.
- **`flutter upgrade` or a channel switch will revert it**, and the canvas will go
  back to expanding all ~20 groups at once — which is what made scrolling slow.
- To restore stock behaviour, set that line back to `true`.

With every group expanded the canvas builds every card on the page; collapsed, it
builds only what you open. Nothing in this repo depends on the patch — it only
affects how the canvas opens.
