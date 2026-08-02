# `lib/previews/` — widget previews

**Nothing in this folder ships to users, and nothing outside it may import from it.**

This folder holds Flutter widget previews: small functions that render one widget in
one designed state, viewable in a hot-reloading canvas without booting the app or
signing in.

```bash
flutter widget-preview start        # opens the canvas in Chrome
```

## Why previews live here and not next to the widget

They have to be under `lib/` — the preview scaffold `flutter_tools` generates imports
them as `package:` URIs, so a file in `test/` or a top-level `previews/` is invisible
to the tool.

Given that constraint, they are collected here rather than scattered through
`lib/features/**` so that a developer reading feature code sees production code only.
The mirror layout makes the mapping obvious in both directions:

```
lib/features/home_client/presentation/widgets/client_home_greeting.dart
lib/previews/home_client/client_home_greeting_preview.dart
```

```
lib/previews/
├── README.md
├── harness/          # the shared annotation + host wrapper (edit rarely)
├── fixtures/         # fakes shared across previews
├── core/             # previews for lib/core/**
└── <feature>/        # previews for lib/features/<feature>/**
```

## Cost at runtime: none

A preview is an unreferenced top-level function. Nothing in the app calls one, so the
AOT compiler tree-shakes them out of release builds. `test/previews/preview_structure_test.dart`
enforces the "nothing imports previews" half of that promise.

## Writing one

```dart
import '../harness/jeeb_preview.dart';

@JeebPreview(group: 'home_client', name: 'Empty', size: Size(390, 200))
Widget myWidgetEmpty() => const MyWidget(items: []);
```

**Always pass `group:`** — the feature area the widget lives in. The canvas renders
one collapsible section per group, which is what keeps ~700 previews navigable
instead of one undifferentiated wall. It is also the only reliable way to navigate:
the canvas's own search box is broken (see below).

By default each annotation renders **one** card: EN light. Pass `matrix: true` to get
the full **EN light / AR RTL dark / EN 200% text** set side by side:

```dart
@JeebPreview(group: 'chat', name: 'Long note', matrix: true)
```

Use it where seeing them together is the point — a Row of text and actions, an
RTL-sensitive layout, copy whose length swings by locale. It is off by default
because all three for every widget is ~750 cards and a slow first paint.

**This does not weaken the guarantee.** `testPreviewsRender()` pumps every preview in
**both** locales on every CI run, so AR stays asserted whether or not the canvas
draws it. The matrix flag controls what you *look at*, not what is *checked*.

Rules that keep previews honest:

- **No network.** Seed state through an inert cubit or a local fake — never a real
  repository. `jeebPreviewHost` additionally installs `CatalogNetworkGuard`, which
  rejects every non-GET verb, but that is a net, not the plan.
- **Cover the states that break**, not just the happy path: empty, loading, error,
  longest-plausible content, and any regression a bug report already produced.
- **Add a render test.** Nothing in CI opens the canvas, so an untested preview rots
  silently. See `test/previews/` — each asserts that each preview renders *its own*
  state, which is what distinguishes a real bug from a canvas display bug.

## Relationship to the Screen Catalog

`lib/devtool/catalog/` is the designer-facing, on-device browser of whole **screens**
(67 screens / 270 mocked states). This folder is the engineer-facing desktop loop for
individual **widgets**. Both share `CatalogNetworkGuard`. Screens are deliberately out
of scope here — `tool/preview_coverage.dart` skips any class ending in `Screen`.

## What is left

```bash
dart run tool/preview_coverage.dart            # summary by area
dart run tool/preview_coverage.dart --json     # machine-readable queue
dart run tool/preview_coverage.dart --area chat
```

## Known tooling bug (Flutter 3.44.2)

The canvas's **search box renders the wrong previews** — it filters the labels but
renders by unfiltered index, so searching can show a card labelled X containing
widget Y. Scroll instead of searching until this is fixed upstream.
