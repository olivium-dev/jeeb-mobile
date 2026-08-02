import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../../core/previews/jeeb_preview.dart';
import '../../../../devtool/catalog/fixtures/location_picker_placeholder_screen_fixtures.dart';

/// Placeholder restored under T-MOB-FIX-001 (AC1+AC4+AC5). Real implementation
/// arrives in the per-feature follow-up ticket. Do NOT add behavior here.
// ORPHAN (JEBV4-227, verified 2026-07-12): placeholder mounted at /location; zero callsites — see docs/project-understanding/reconciliation/orphans.md
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  static const _featureId = 'location-picker';

  @override
  void initState() {
    super.initState();
    debugPrint('[placeholder] $_featureId opened');
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      label: 'Location Picker coming soon. This screen is not yet available.',
      child: const OmdsEmptyStatePage(
        appBar: null,
        icon: Icons.construction_outlined,
        title: 'Location Picker coming soon',
        subtitle: 'This screen is not yet available.',
      ),
    );
  }
}

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/location/location_picker_screen_preview_test.dart
// ===========================================================================
//
// ## Which `LocationPickerScreen` is this?
//
// The one the app serves. Two classes carry this name:
//
//   * `presentation/location_picker_screen.dart` — 461 lines, a working
//     cubit-driven pickup→dropoff picker, imported by exactly one file in the
//     repo (`devtool/catalog/entries/batch_06_entries.dart`), and
//   * THIS file — 36 lines of "coming soon", imported by
//     `core/router/app_router.dart:76` and served at `/location`
//     (`name: 'location-picker'`, app_router.dart:968-970).
//
// So the designer-facing Screen Catalog renders a fully working Location Picker
// while the app routes to a dead end, and the catalog was the surface people
// were reviewing. `docs/previews/FINDING_location_picker_placeholder.md` has the
// history. This section exists so that opening the file the ROUTER imports
// shows the truth — which is the sharpest argument for co-locating previews
// there is, and the reason these cards are worth more than they look.
//
// ## Why there is no empty / loading / error triad
//
// That is a fact about the screen, not a gap in the previews. It takes no
// parameters, owns no cubit and reads no repository; `build` returns a `const
// OmdsEmptyStatePage` with two string literals. There is exactly ONE state, and
// nothing to seed it with, so [LocationPickerPlaceholderScreenFixtures] holds
// copy, boxes and captions rather than fakes. What varies — and what breaks —
// is the BOX the placeholder is handed and the ROUTE it is handed to, so the
// four cards are those two axes.
//
// ## What a reviewer should read off these cards
//
// Stated, not fixed: nothing above the banner may change.
//
//   * **The copy is hardcoded English.** `title`, `subtitle` and the
//     `Semantics.label` are literals, though `app_en.arb`/`app_ar.arb` ship 30+
//     `location*` keys (`locationPickerTitle` = "Choose location" among them)
//     and the 461-line sibling uses them throughout. The AR card of
//     [locationPickerScreenPlaceholderPhone] therefore mirrors the LAYOUT and
//     keeps the ENGLISH words. If that card ever renders Arabic, someone
//     localized the screen and these fixtures need updating.
//   * **It is a routed dead end.** `appBar: null`, so no app bar and no back
//     affordance, and `OmdsEmptyStatePage` is only given `title`/`subtitle` —
//     `buttonText`/`onButtonTap` are left null, so no action either. Unlike the
//     equivalent placeholder on `SavedAddressesScreen`, which is unrouted and
//     therefore unreachable, THIS one is live at `/location`: a user who arrives
//     can leave only by a system back gesture.
//     [locationPickerScreenPlaceholderDeadEnd] is that state — the screen pushed
//     on top of a route it CAN pop back to, drawing nothing that says so.
//     A screen reader gets no more: see below.
//   * **The copy is announced twice.** `Semantics(container: true, label: …)`
//     wraps a subtree that already publishes both sentences, and nothing
//     excludes it, so the merged node's label is the wrapper's line and THEN the
//     headline and the body again: "Location Picker coming soon. This screen is
//     not yet available.\nLocation Picker coming soon\nThis screen is not yet
//     available." One node, each sentence read twice, no children, no action,
//     and nothing to move focus to afterwards.
//   * **The headline is unclamped, and the narrow device is the ceiling.**
//     `OmdsEmptyState` passes the title no `maxLines` and no `overflow`. It wants
//     331 pt; the 390 pt phone gives it 342 and it stays on one line, the 320 pt
//     phone gives it 272 and it wraps to two. At 200% it wants 662 pt and wraps
//     to FOUR lines on the compact device — see
//     [locationPickerScreenPlaceholderCompact], which is matrixed for exactly
//     that card.
//   * **Nothing scrolls, and the margin is 36 pt.** `OmdsEmptyStatePage` is
//     `Scaffold` → `Center` → `OmdsEmptyState`, and `OmdsEmptyState` is a bare
//     `Column` (100 pt icon, 32 pt gap, headline, 16 pt gap, body, inside
//     `EdgeInsets.all(24)`) with no `SingleChildScrollView` above it, so a
//     viewport shorter than the content clips it with nothing to scroll to.
//     Measured in the real Inter face at each box: 248 pt of content on the
//     390x844 phone (468 at 200%), 248 on the 844x390 landscape box (300 at
//     200%), 280 on the 320x568 compact device — and **532 of 568** on that
//     compact device at 200%. Nothing overflows today; the narrowest supported
//     phone at the accessibility ceiling clears its viewport by 36 pt, with no
//     backstop if a word is added to either string.
//
// ## A warning about measuring this screen
//
// Those numbers are from the REAL font. The shared render harness does not load
// fonts, and Flutter's test face makes every glyph a 1-em square — Latin ~2x too
// wide — which for a centred, unclamped, non-scrolling `Column` inflates the
// height floor by an entire wrapped line at a time. Measured that way this
// screen appears to overflow the 844x390 landscape box at 200%; with Inter
// loaded it has 90 pt to spare there, and the box that is actually tight is the
// compact one. `SavedAddressesScreen`, the byte-identical placeholder in
// `features/settings/`, carries the phantom version of this finding in its own
// preview prose and render test. Do not re-derive any of it without
// `loadInterTestFont()`.
//
// ## Hosting
//
// The screen returns its OWN `Scaffold` (through `OmdsEmptyStatePage`) and
// `jeebPreviewHost` wraps every preview in another, so the canvas draws a
// Scaffold inside a Scaffold. It nests harmlessly here — the inner one has no
// app bar, no FAB and no bottom bar — and the shared host is left alone
// deliberately, because every preview in the tree uses it. The `size:` on each
// annotation is what makes the box real; the harness default (390x200) would
// judge a full-screen empty state in a 200 pt strip.
//
// Each card is captioned. The captions are dev chrome — LTR, unscaled, and
// OVERLAID rather than stacked above, so they cost the screen no height and each
// card stays a true device box. They exist because the render suite pins every
// preview by a string unique to it, and this screen renders the same two
// sentences in all four states: without captions, four previews wired to one
// fixture would all pass.

/// The dev-chrome line painted over the top edge of each device box.
class _LocationPickerScreenPlaceholderCaption extends StatelessWidget {
  const _LocationPickerScreenPlaceholderCaption({required this.caption});

  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.small,
        vertical: Spacing.xSmall,
      ),
      child: Text(
        caption,
        // LTR and unscaled: the AR card still reads this as one latin line, and
        // the 200% card does not spend a third of the device on a label.
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
        style: theme.textTheme.labelSmall?.copyWith(
          color: theme.colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Captions [child] without taking any of its height.
///
/// A `Column` would be simpler, but the caption would then cost the screen
/// ~32 pt and every geometry claim in the render test would be about a card
/// 32 pt shorter than the device it is named after — which matters, because the
/// tightest box here clears its viewport by 36 pt. Overlaying instead keeps each
/// card a true device box. The empty state is centred, so the caption sits on
/// background at every size but the 200% compact card, where it grazes the icon.
Widget _locationPickerScreenPlaceholderCaptioned(String caption, Widget child) {
  return Stack(
    fit: StackFit.expand,
    children: <Widget>[
      child,
      Positioned(
        top: 0,
        left: 0,
        right: 0,
        child: IgnorePointer(
          child: _LocationPickerScreenPlaceholderCaption(caption: caption),
        ),
      ),
    ],
  );
}

/// The single state, hosted for the canvas.
///
/// `const LocationPickerScreen()` is written out here rather than delegating to
/// [LocationPickerPlaceholderScreenFixtures.placeholder] because the coverage
/// detector (`tool/preview_inventory.dart` · `SourceFile.constructs`) looks for
/// the literal constructor call inside this section; a section that only calls a
/// factory is reported MALFORMED. The fixtures file still owns everything a
/// reader could get wrong — the copy, the boxes and the captions.
Widget _locationPickerScreenPlaceholderHosted(String caption) =>
    _locationPickerScreenPlaceholderCaptioned(
      caption,
      const LocationPickerScreen(),
    );

/// The reference rendering: a 390x844 phone.
///
/// `matrix: true` because the AR card is the whole point. The screen renders
/// string literals, so Arabic mirrors the LAYOUT and keeps the ENGLISH words —
/// the one defect a single EN card cannot show you. Read the 200% card as the
/// control for [locationPickerScreenPlaceholderCompact]: identical content at an
/// identical scale, with 376 pt to spare instead of 36, so what is tight there
/// is the DEVICE and not the text setting.
@JeebPreview(
  group: 'location',
  name: 'Placeholder · phone',
  size: LocationPickerPlaceholderScreenFixtures.phoneBox,
  matrix: true,
)
Widget locationPickerScreenPlaceholderPhone() =>
    _locationPickerScreenPlaceholderHosted(
      LocationPickerPlaceholderScreenFixtures.captionPhone,
    );

/// The narrowest viewport the app supports (320x568) — and the tight one.
///
/// `EdgeInsets.all(24)` leaves 272 pt of usable width, and the unclamped
/// headline wants 331, so it wraps to two lines here and the phone card is the
/// only one where it does not. `matrix: true` is for the third card: at 200%
/// the same headline wants 662 pt and wraps to FOUR lines, which takes the
/// centred non-scrolling column to 532 pt of a 568 pt viewport. Nothing
/// overflows — it clears by 36 pt — but that is the whole margin this screen
/// has, on the device that has the least of it, with no `SingleChildScrollView`
/// to fall back on if either string grows.
@JeebPreview(
  group: 'location',
  name: 'Placeholder · compact device',
  size: LocationPickerPlaceholderScreenFixtures.compactBox,
  matrix: true,
)
Widget locationPickerScreenPlaceholderCompact() =>
    _locationPickerScreenPlaceholderHosted(
      LocationPickerPlaceholderScreenFixtures.captionCompact,
    );

/// Landscape / split-screen (844x390) — the shortest viewport, and a card that
/// exists to be checked rather than to fail.
///
/// The obvious guess is that this is where the non-scrolling column runs out of
/// height: the icon alone is 100 pt and the gaps around it another 48 before a
/// word is drawn. Measured in the real font it is not — the extra width keeps
/// the headline on one line, so the content is 248 pt at 100% and 300 pt at
/// 200%, against 390 pt of viewport. Kept because "the short viewport is fine"
/// is a claim worth being able to see, and because measuring it under the
/// harness's 1-em test face says the opposite — see "A warning about measuring
/// this screen" in the section prose.
@JeebPreview(
  group: 'location',
  name: 'Placeholder · landscape, short viewport',
  size: LocationPickerPlaceholderScreenFixtures.landscapeBox,
)
Widget locationPickerScreenPlaceholderLandscape() =>
    _locationPickerScreenPlaceholderHosted(
      LocationPickerPlaceholderScreenFixtures.captionLandscape,
    );

/// The screen as `/location` actually delivers it: pushed on top of the screen
/// the user came from.
///
/// Every other card here shows the placeholder as a root surface, which flatters
/// it — a root surface is not expected to have a back button. This one puts a
/// route underneath, so the navigator CAN pop and the screen still draws
/// nothing that says so: `appBar: null` means no app bar and therefore no back
/// arrow, and `OmdsEmptyStatePage` is given no `buttonText`/`onButtonTap`, so
/// there is no action either. What is left is a full-screen dead end whose only
/// exit is a system gesture — and unlike the identical placeholder on
/// `SavedAddressesScreen`, which no route serves, this one is live.
@JeebPreview(
  group: 'location',
  name: 'Placeholder · pushed route, no way back',
  size: LocationPickerPlaceholderScreenFixtures.phoneBox,
)
Widget locationPickerScreenPlaceholderDeadEnd() =>
    _locationPickerScreenPlaceholderCaptioned(
      LocationPickerPlaceholderScreenFixtures.captionDeadEnd,
      Navigator(
        onGenerateInitialRoutes:
            (NavigatorState navigator, String initialRoute) => <Route<void>>[
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const Scaffold(
              body: Center(
                child: Text(
                  LocationPickerPlaceholderScreenFixtures.originRouteLabel,
                ),
              ),
            ),
          ),
          MaterialPageRoute<void>(
            builder: (BuildContext context) => const LocationPickerScreen(),
          ),
        ],
      ),
    );
