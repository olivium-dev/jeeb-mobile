// Shared dev-only fixtures for `JeeberRequestUnavailableScreen`.
//
// EXTRACTED from the Screen Catalog entry in
// `lib/devtool/catalog/entries/batch_05_entries.dart` (`_requestUnavailableEntry`,
// state "Request no longer available"), which built the screen inline with a
// literal `requestId: 'req-404'`. Both dev surfaces now read this file — the
// catalog entry and the JEEB PREVIEWS section at the bottom of
// `lib/features/jeeber_request_detail/presentation/jeeber_request_unavailable_screen.dart`
// — so the id a designer signs off against and the id an engineer reviews in the
// canvas cannot drift apart.
//
// ## Why the states here are ids, windows and a NAVIGATION STACK
//
// Most fixture sets in this directory are canned repositories, because most
// screens have a data axis to seed. This one has none: the screen takes a
// `String requestId` and a `VoidCallback onBack`, resolves nothing out of GetIt,
// builds no cubit, and renders three ARB strings under a fixed icon. It IS the
// terminal state — the graceful dead end `JeeberRequestDetailLoader` routes to
// when a request is cancelled, expired, or matched to another jeeber — so
// "empty / loading / error" has no answer here and has to be asked differently.
//
// Three things DO vary, and they are the states:
//
//  1. **The request id.** It is not decoration: it is interpolated straight into
//     the subtitle by `requestNoLongerAvailable`, so its LENGTH is the screen's
//     only content axis. The catalog's `req-404` is 7 characters; what the
//     shipped route actually hands over is a 36-character UUID
//     (`app_router.dart:1284` → `JeeberRequestDetailLoader.requestId`), and the
//     same builder's `?? ''` can hand over an empty string.
//  2. **The window.** The body is a `Center` around a NON-SCROLLING `Column`, so
//     width and text scale are what decide whether the composition fits.
//  3. **The navigation stack underneath it.** `OMDSAppBar` is constructed with
//     no `showBackButton` (it defaults to FALSE) but passes
//     `automaticallyImplyLeading: true` through to Material's `AppBar` — so
//     whether there is a back arrow at all is decided by whether the enclosing
//     route can be popped, not by this screen. A feed-row tap leaves a page
//     underneath; a cold push tap on a dead request does not.
//
// Being id/window/stack-only also makes both dev surfaces network-free by
// construction rather than by the guard `jeebPreviewHost` and the catalog host
// install: there is no seam here through which a Dio-backed repository could be
// reached even by mistake.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:flutter/material.dart';

/// The request ids the two dev surfaces render.
///
/// Separate constants rather than literals at the call sites, because the whole
/// point of three of the states below is that the SAME screen reads very
/// differently depending on which of these it is handed.
final class JeeberRequestUnavailableScreenIds {
  JeeberRequestUnavailableScreenIds._();

  /// The short, human-sized id the Screen Catalog has always shown.
  ///
  /// Nothing in the shipped app produces an id this shape — it is the friendly
  /// reading, kept because it is what the catalog state is signed off as and
  /// because it is the control the other two are read against.
  static const String catalog = 'req-404';

  /// What `/jeeber/requests/:id` actually puts on screen.
  ///
  /// The same id `jeeber_request_detail_loader_test.dart` and the loader's own
  /// previews use, so the canvas, the branch tests and the catalog all describe
  /// one request.
  static const String push = 'e30b7f2e-7914-402d-8dd3-e699e6775eae';

  /// The router's defensive fallback: `state.pathParameters['id'] ?? ''`
  /// (`app_router.dart:1284`).
  ///
  /// go_router will not match an empty path segment, so this is a defensive
  /// branch rather than a route a user can walk into today — but the `?? ''` is
  /// in shipped code, the id is interpolated into a sentence with no guard, and
  /// what that sentence becomes is worth being able to look at.
  static const String blank = '';
}

/// One simulated device window.
///
/// The frame has to be pinned by the fixture rather than left to the canvas
/// `size:`, because the render tests in `test/previews/` pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test and the small-window states would silently
/// become copies of the large ones.
@immutable
class JeeberRequestUnavailableScreenWindow {
  const JeeberRequestUnavailableScreenWindow({
    required this.label,
    required this.size,
    this.textScale,
  });

  /// Short name for the geometry, used in dartdoc and in debugging.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
  final double? textScale;
}

/// The geometries this screen is reviewed in.
final class JeeberRequestUnavailableScreenWindows {
  JeeberRequestUnavailableScreenWindows._();

  /// The reference reading: an ordinary modern phone.
  static const JeeberRequestUnavailableScreenWindow phone =
      JeeberRequestUnavailableScreenWindow(
    label: 'Phone 390 × 844',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class). The subtitle is a centred, non-wrapping-limited `Text`, so
  /// this is the width at which a 36-character UUID first costs extra lines.
  static const JeeberRequestUnavailableScreenWindow compact =
      JeeberRequestUnavailableScreenWindow(
    label: 'Compact 320 × 568',
    size: Size(320, 568),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const JeeberRequestUnavailableScreenWindow phoneLargeText =
      JeeberRequestUnavailableScreenWindow(
    label: 'Phone 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. This is the window in which the un-scrollable body runs out of room.
  static const JeeberRequestUnavailableScreenWindow compactLargeText =
      JeeberRequestUnavailableScreenWindow(
    label: 'Compact 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );
}

/// One designed state: an id, a window, and how the route was reached.
@immutable
class JeeberRequestUnavailableScreenFixture {
  const JeeberRequestUnavailableScreenFixture({
    required this.label,
    required this.requestId,
    this.window,
    this.parentOnStack,
  });

  /// Caption painted above the frame, and the string each preview is pinned by
  /// in the render test.
  ///
  /// Distinct per state on purpose: this screen renders the same title, the
  /// same icon and the same CTA in every state, and two states share the phone
  /// window, so nothing else on screen reliably tells them apart.
  final String label;

  /// The id handed to `JeeberRequestUnavailableScreen.requestId`.
  final String requestId;

  /// The simulated display, or `null` to render bare at the ambient window —
  /// the form the Screen Catalog uses, where the device IS the frame.
  final JeeberRequestUnavailableScreenWindow? window;

  /// Whether a page sits beneath the screen on a LOCAL navigator:
  ///
  ///  * `true` — a feed-row tap, a parent page still underneath.
  ///    `automaticallyImplyLeading` finds a poppable route and Material draws
  ///    the back arrow.
  ///  * `false` — a cold push tap / deep link onto a dead request. One page,
  ///    no implied leading, no arrow.
  ///  * `null` — mount no navigator of our own and inherit the ambient one.
  ///    This is what the catalog uses: it pushes the state as a real route and
  ///    overlays its own close button, and a local navigator would only get in
  ///    the way of both.
  final bool? parentOnStack;
}

/// The designed states, shared by the Screen Catalog and the previews.
final class JeeberRequestUnavailableScreenFixtures {
  JeeberRequestUnavailableScreenFixtures._();

  /// The catalog's long-standing state, unchanged: a short id, the real device
  /// as the frame, and the catalog's own route underneath it.
  static const JeeberRequestUnavailableScreenFixture catalogDefault =
      JeeberRequestUnavailableScreenFixture(
    label: 'Request no longer available',
    requestId: JeeberRequestUnavailableScreenIds.catalog,
  );

  /// The same short id as the catalog, framed as a phone for the canvas.
  static const JeeberRequestUnavailableScreenFixture phoneShortId =
      JeeberRequestUnavailableScreenFixture(
    label: 'Phone · short id (req-404)',
    requestId: JeeberRequestUnavailableScreenIds.catalog,
    window: JeeberRequestUnavailableScreenWindows.phone,
    parentOnStack: true,
  );

  /// What a cold push tap on a dead request actually produces: the raw UUID in
  /// the sentence, and nothing underneath to pop back to.
  static const JeeberRequestUnavailableScreenFixture pushDeadEnd =
      JeeberRequestUnavailableScreenFixture(
    label: 'Cold push tap · raw UUID · nothing to pop',
    requestId: JeeberRequestUnavailableScreenIds.push,
    window: JeeberRequestUnavailableScreenWindows.phone,
    parentOnStack: false,
  );

  /// The smallest phone, carrying the id the shipped route hands over.
  static const JeeberRequestUnavailableScreenFixture compact =
      JeeberRequestUnavailableScreenFixture(
    label: 'Compact 320 × 568 · raw UUID',
    requestId: JeeberRequestUnavailableScreenIds.push,
    window: JeeberRequestUnavailableScreenWindows.compact,
    parentOnStack: true,
  );

  /// The accessibility ceiling on a normal phone.
  static const JeeberRequestUnavailableScreenFixture phoneLargeText =
      JeeberRequestUnavailableScreenFixture(
    label: 'Phone · 200% text · raw UUID',
    requestId: JeeberRequestUnavailableScreenIds.push,
    window: JeeberRequestUnavailableScreenWindows.phoneLargeText,
    parentOnStack: true,
  );

  /// Worst case: smallest display, largest text, and the cold-push stack that
  /// has no back arrow to fall back on.
  static const JeeberRequestUnavailableScreenFixture compactLargeText =
      JeeberRequestUnavailableScreenFixture(
    label: 'Compact · 200% text · nothing to pop',
    requestId: JeeberRequestUnavailableScreenIds.push,
    window: JeeberRequestUnavailableScreenWindows.compactLargeText,
    parentOnStack: false,
  );

  /// The router's `?? ''` fallback, rendered.
  static const JeeberRequestUnavailableScreenFixture blankId =
      JeeberRequestUnavailableScreenFixture(
    label: 'Phone · blank id from the router fallback',
    requestId: JeeberRequestUnavailableScreenIds.blank,
    window: JeeberRequestUnavailableScreenWindows.phone,
    parentOnStack: true,
  );
}

/// What the app-bar back arrow lands on when there IS something to pop.
///
/// Public so the render test can tell "the arrow popped to a real page" apart
/// from "there was no arrow at all" — from inside the screen those look the
/// same, and only one of them is an exit.
const String jeeberRequestUnavailableScreenParentLabel =
    'jeeber request feed (preview stand-in)';

/// Hosts `JeeberRequestUnavailableScreen` in one
/// [JeeberRequestUnavailableScreenFixture].
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library, and
/// — the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget it is named after, so the
/// `JeeberRequestUnavailableScreen(...)` has to appear below the banner in the
/// screen's own file rather than in here.
class JeeberRequestUnavailableScreenPreviewHost extends StatelessWidget {
  const JeeberRequestUnavailableScreenPreviewHost({
    required this.fixture,
    required this.screen,
    super.key,
  });

  /// The state being rendered — id, window and navigation stack.
  final JeeberRequestUnavailableScreenFixture fixture;

  /// The screen under review, already built with [fixture]'s `requestId`.
  final Widget screen;

  @override
  Widget build(BuildContext context) {
    final bool? parentOnStack = fixture.parentOnStack;

    // A LOCAL Navigator, not the canvas's. Inheriting the ambient one would
    // model the "one page, no back arrow" case by accident and make
    // `parentOnStack: true` silently a lie — the canvas and the render harness
    // each mount the preview as the lone page of their own Navigator.
    final Widget staged = parentOnStack == null
        ? screen
        : Navigator(
            onGenerateInitialRoutes:
                (NavigatorState navigator, String initialRoute) => <Route<void>>[
              if (parentOnStack)
                MaterialPageRoute<void>(
                  builder: (_) => const _JeeberRequestUnavailableScreenParent(),
                ),
              MaterialPageRoute<void>(builder: (_) => screen),
            ],
            onGenerateRoute: (RouteSettings settings) => MaterialPageRoute<void>(
              settings: settings,
              builder: (_) => screen,
            ),
          );

    final JeeberRequestUnavailableScreenWindow? window = fixture.window;
    if (window == null) return staged;

    final ThemeData theme = Theme.of(context);
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            fixture.label,
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border.all(color: theme.colorScheme.outlineVariant),
          ),
          child: MediaQuery(
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              // Null leaves the ambient scaler alone — see the field's dartdoc.
              textScaler: window.textScale == null
                  ? null
                  : TextScaler.linear(window.textScale!),
            ),
            child: SizedBox.fromSize(size: window.size, child: staged),
          ),
        ),
      ],
    );

    // Unbind both axes. The render tests pump onto 800 x 600 and the phone
    // frames are taller than that; an `Align` + `SizedBox` would pass the
    // host's constraints down and the frame would be silently clamped to
    // 600 pt — the exact measurement the "does the body still fit" assertions
    // depend on not being faked.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// The page beneath the screen when it was reached by an in-app feed tap.
///
/// It only has to exist and to be identifiable, so a tap on the back arrow can
/// be shown to reach a page rather than to do nothing.
class _JeeberRequestUnavailableScreenParent extends StatelessWidget {
  const _JeeberRequestUnavailableScreenParent();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            jeeberRequestUnavailableScreenParentLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
