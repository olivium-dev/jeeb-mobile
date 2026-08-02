// Designed-state fixtures for the `LocationPickerScreen` PLACEHOLDER — the
// 36-line "coming soon" screen at
// `lib/features/location/presentation/screens/location_picker_screen.dart`,
// which is the class `app_router.dart` imports and serves at `/location`.
//
// ## Read this before you look for these in `location_picker_screen_fixtures.dart`
//
// TWO classes named `LocationPickerScreen` exist in this repo, and the
// obvious-looking fixtures file is the OTHER one's:
//
//   | file                                                          | what it is  |
//   |---------------------------------------------------------------|-------------|
//   | `features/location/presentation/location_picker_screen.dart`    | 461 lines, a full cubit-driven picker. Imported by NOTHING but `entries/batch_06_entries.dart`. |
//   | `features/location/presentation/screens/location_picker_screen.dart` | 36 lines, this placeholder. Imported by `core/router/app_router.dart` and served at `/location`. |
//
// `fixtures/location_picker_screen_fixtures.dart` holds the fakes and seeded
// cubits for the 461-line implementation. It is not wrong; it is about a screen
// no user can reach. This file is the one that describes what `/location`
// actually renders. See `docs/previews/FINDING_location_picker_placeholder.md`.
//
// ## ONE source of truth, and what "state" means for a screen with one
//
// The rule is that a previewed screen's designed states live here and BOTH dev
// surfaces read them, so the designer's on-device Screen Catalog and the
// engineer's `flutter widget-preview start` canvas cannot drift. This screen is
// the degenerate case of that rule and saying so is the point rather than an
// apology for a thin file.
//
// `LocationPickerScreen` (the placeholder) takes no parameters, owns no cubit
// and reads no repository — `build` returns a `const OmdsEmptyStatePage` with
// two literal English strings inside a `Semantics`. There is no fake repository
// to extract and no cubit to seed, because there is nothing to load: no empty /
// loading / error triad exists to cover. The single consumer today is the
// preview section at the bottom of the screen file. The Screen Catalog has NO
// entry for this screen at all — `batch_06_entries.dart` renders the 461-line
// sibling under the title "Location Picker (pickup/dropoff)", which is exactly
// how a designer ends up signing off a picker the app never shows.
//
// What IS worth single-sourcing is the part both surfaces and the render test
// would otherwise re-type out of the screen body: the COPY, the canvas BOXES,
// and the dev-chrome CAPTIONS that tell one card from another. The copy
// literals below are a DELIBERATE duplicate of the screen's, not a shared
// constant the screen reads — the screen is shipping code and may not import
// `lib/devtool/`, and pinning its strings from outside is precisely what lets
// the render test notice when they change.
//
// Everything here is inert by construction: no Dio, no GetIt, no platform
// channel, no timer. The `CatalogNetworkGuard` both hosts install has nothing
// to catch.

import 'package:flutter/widgets.dart';

import '../../../features/location/presentation/screens/location_picker_screen.dart';

/// The one designed state of the `/location` placeholder, the boxes it is
/// reviewed in, and the captions that label those boxes.
class LocationPickerPlaceholderScreenFixtures {
  const LocationPickerPlaceholderScreenFixtures._();

  // ── Copy ────────────────────────────────────────────────────────────────
  // All three strings are HARDCODED ENGLISH in the screen. `app_en.arb` and
  // `app_ar.arb` both ship 30+ `location*` keys — `locationPickerTitle`
  // ("Choose location") among them — and the 461-line sibling uses them
  // throughout. This screen uses none. Pinned here so the AR preview and the AR
  // half of the render suite can assert that an Arabic build still shows these
  // English words, instead of passing for the weaker reason that an
  // unlocalized screen always builds.

  /// The headline the placeholder renders.
  static const String title = 'Location Picker coming soon';

  /// The body copy under [title].
  static const String subtitle = 'This screen is not yet available.';

  /// The `Semantics.label` the screen wraps itself in.
  ///
  /// NOT what a screen reader announces. `container: true` over a subtree that
  /// already publishes both sentences, with nothing excluding it, merges into a
  /// single node labelled `'$semanticsLabel\n$title\n$subtitle'` — the copy read
  /// twice over, in one node, with no focusable control to move to next. The
  /// render test pins that concatenation; this constant is only the first third
  /// of it.
  static const String semanticsLabel =
      'Location Picker coming soon. This screen is not yet available.';

  // ── Boxes ───────────────────────────────────────────────────────────────
  // The screen has one state, so the BOX is the only thing about it that can
  // break, and these three are the shapes the app ships into. Every height
  // below was measured with the REAL Inter face loaded — under Flutter's 1-em
  // test face the same content is an entire wrapped line taller per box, which
  // is enough to invert which box is the tight one.

  /// The reference device: a 390x844 phone.
  ///
  /// 342 pt of usable width, so [title] stays on ONE line — the only box where
  /// it does. Content height 248 pt, or 468 at the 200% text ceiling.
  static const Size phoneBox = Size(390, 844);

  /// The narrowest viewport the app supports (320x568), and the tight one.
  ///
  /// 272 pt of usable width once `OmdsEmptyState`'s `EdgeInsets.all(24)` is off
  /// both sides, against an unclamped headline that wants 331 — so [title] wraps
  /// to two lines here, and to FOUR at 200%, where the content reaches **532 pt
  /// of the 568 pt viewport**. That 36 pt is the entire margin this screen has,
  /// on the device that has the least of it, with nothing scrollable underneath.
  static const Size compactBox = Size(320, 568);

  /// A 844x390 landscape / split-screen viewport — the SHORTEST one, and not
  /// the one that breaks.
  ///
  /// `OmdsEmptyStatePage` centres a NON-scrolling `Column` (100 pt icon, 32 pt
  /// gap, headline, 16 pt gap, body, inside `EdgeInsets.all(24)`), so the
  /// content has a hard height floor that grows with the text scale and nowhere
  /// to go when the viewport is shorter than it — which makes this box look like
  /// the ceiling. It is not: the extra width keeps [title] on one line, so the
  /// content is 248 pt at 100% and 300 pt at 200%, against 390 pt of viewport.
  static const Size landscapeBox = Size(844, 390);

  // ── Captions ────────────────────────────────────────────────────────────
  // Dev chrome painted above each card, never shipped copy. They exist because
  // the render suite pins each preview by a string that is UNIQUE to it, and
  // this screen renders the same two sentences in every state — without a
  // caption, four previews wired to the same fixture would all pass.

  /// The reference reading at [phoneBox].
  static const String captionPhone =
      'preview · what /location actually serves · 390x844';

  /// [compactBox] — the width floor.
  static const String captionCompact =
      'preview · narrowest supported device · 320x568';

  /// [landscapeBox] — the height ceiling.
  static const String captionLandscape =
      'preview · short viewport, nothing scrolls · 844x390';

  /// The placeholder pushed onto a route the user can pop back out of.
  static const String captionDeadEnd =
      'preview · pushed route · no back affordance is drawn';

  /// Stands in for the screen the user tapped through from, one route below the
  /// placeholder. Never asserted; it exists so the pushed card has something to
  /// be pushed on top of.
  static const String originRouteLabel =
      'preview · the screen the user came from';

  // ── The single designed state ───────────────────────────────────────────

  /// The one state, built the same way for every consumer.
  ///
  /// The preview section deliberately writes `const LocationPickerScreen()` out
  /// again rather than calling this — the coverage detector
  /// (`tool/preview_inventory.dart` · `SourceFile.constructs`) looks for the
  /// literal constructor call inside the section and reports a section that only
  /// calls a factory as MALFORMED.
  static Widget placeholder() => const LocationPickerScreen();
}
