// Shared dev-only fixtures for `ClientUnreachableScreen`.
//
// EXTRACTED from the Screen Catalog entry in
// `lib/devtool/catalog/entries/batch_02_entries.dart`
// (`_clientUnreachableScreenEntry`, state "Default"), which built the screen
// inline with a literal `deliveryId: 'delivery-demo-1'`. Both dev surfaces now
// read this file — the catalog entry and the JEEB PREVIEWS section at the bottom
// of `lib/features/client_unreachable/presentation/client_unreachable_screen.dart`
// — so the state a designer signs off against and the state an engineer reviews
// in the canvas cannot drift apart.
//
// ## Why the states here are WINDOWS and a NAVIGATION STACK, not data
//
// Most fixture sets in this directory are canned repositories, because most
// screens have a data axis to seed. This one has NONE, and that is itself the
// most useful thing to know about the screen:
//
//  * It builds no cubit, resolves nothing out of GetIt and takes no callbacks.
//  * Every string it renders is a hardcoded English literal in the shipped
//    source — there is no `AppLocalizations` lookup anywhere in the file, so
//    the copy is identical in every locale.
//  * Its one constructor parameter, `deliveryId`, is REQUIRED and never read.
//    Handing it a different id changes nothing on screen, which is why the two
//    ids below exist: to make that visible rather than to vary content.
//
// What is left that genuinely varies is the WINDOW (width + text scale, since
// the body is a non-scrolling `Column` with a `Spacer`) and the NAVIGATION
// STACK underneath it. `OMDSAppBar` is constructed with no `showBackButton`
// (which DEFAULTS TO FALSE) but passes `automaticallyImplyLeading: true`
// through to Material's `AppBar`, so whether there is a back arrow at all is
// decided by whether the enclosing route can be popped — and the screen's one
// live affordance is `Navigator.of(context).pop(true)`, which needs somewhere
// to pop TO.
//
// Being window/stack-only also makes both dev surfaces network-free by
// construction rather than by the guard that `jeebPreviewHost` and the catalog
// host install: there is no seam here through which a Dio-backed repository
// could be reached even by mistake.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:flutter/material.dart';

/// The delivery ids the two dev surfaces hand to `ClientUnreachableScreen`.
///
/// Separate constants rather than literals at the call sites — not because the
/// id changes what is drawn (it cannot; see [ClientUnreachableScreenFixtures]),
/// but because two DIFFERENT ids rendering byte-identical screens is the
/// cheapest possible proof that the required parameter is dead.
final class ClientUnreachableScreenDeliveryIds {
  ClientUnreachableScreenDeliveryIds._();

  /// The short, human-sized id the Screen Catalog has always shown.
  static const String catalog = 'delivery-demo-1';

  /// The shape a real delivery id has everywhere else in the app — the same
  /// 36-character form `DeliveryDetailScreen` and the live-tracking route carry.
  ///
  /// Nothing on screen changes when this is passed instead of [catalog]. That
  /// is the finding, and the render test pins it.
  static const String route = 'b7d1a4c8-2f60-4e5b-9a31-5c8e1f0d77ae';
}

/// One simulated device window.
///
/// The frame has to be pinned by the fixture rather than left to the canvas
/// `size:`, because the render tests in `test/previews/` pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test and the small-window states would silently
/// become copies of the large ones.
@immutable
class ClientUnreachableScreenWindow {
  const ClientUnreachableScreenWindow({
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
final class ClientUnreachableScreenWindows {
  ClientUnreachableScreenWindows._();

  /// The reference reading: an ordinary modern phone.
  static const ClientUnreachableScreenWindow phone =
      ClientUnreachableScreenWindow(
    label: 'Phone 390 × 844',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class). The notice card's paragraph is a centred `Text` with no line
  /// limit, so this is the width at which it first costs extra lines — and the
  /// `Spacer` below it is what pays for them.
  static const ClientUnreachableScreenWindow compact =
      ClientUnreachableScreenWindow(
    label: 'Compact 320 × 568',
    size: Size(320, 568),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const ClientUnreachableScreenWindow phoneLargeText =
      ClientUnreachableScreenWindow(
    label: 'Phone 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. This is the window in which the un-scrollable body runs out of room.
  static const ClientUnreachableScreenWindow compactLargeText =
      ClientUnreachableScreenWindow(
    label: 'Compact 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );
}

/// One designed state: an id, a window, and how the route was reached.
@immutable
class ClientUnreachableScreenFixture {
  const ClientUnreachableScreenFixture({
    required this.label,
    required this.deliveryId,
    this.window,
    this.parentOnStack,
  });

  /// Caption painted above the frame, and the string each preview is pinned by
  /// in the render test.
  ///
  /// Distinct per state on purpose, and here it is the ONLY thing that can be
  /// distinct: this screen renders the same title, the same icon, the same
  /// paragraph and the same three buttons in every state and in every locale.
  /// Nothing inside the frame tells two states apart.
  final String label;

  /// The id handed to `ClientUnreachableScreen.deliveryId`.
  ///
  /// Kept per-state even though the screen ignores it, so that "the id is not
  /// on screen" is a claim the render test can make about a value it chose.
  final String deliveryId;

  /// The simulated display, or `null` to render bare at the ambient window —
  /// the form the Screen Catalog uses, where the device IS the frame.
  final ClientUnreachableScreenWindow? window;

  /// Whether a page sits beneath the screen on a LOCAL navigator:
  ///
  ///  * `true` — the jeeber reached this from live tracking, so a page is still
  ///    underneath. `automaticallyImplyLeading` finds a poppable route, Material
  ///    draws the back arrow, and `pop(true)` has a caller to return `true` to.
  ///  * `false` — a stack-replacing arrival. One page, no implied leading, no
  ///    arrow, and nothing for the flag CTA's `pop(true)` to land on.
  ///  * `null` — mount no navigator of our own and inherit the ambient one.
  ///    This is what the catalog uses: it pushes the state as a real route and
  ///    overlays its own close button, and a local navigator would only get in
  ///    the way of both.
  final bool? parentOnStack;
}

/// The designed states, shared by the Screen Catalog and the previews.
final class ClientUnreachableScreenFixtures {
  ClientUnreachableScreenFixtures._();

  /// The catalog's long-standing state, unchanged: the short id, the real
  /// device as the frame, and the catalog's own route underneath it.
  static const ClientUnreachableScreenFixture catalogDefault =
      ClientUnreachableScreenFixture(
    label: 'Default',
    deliveryId: ClientUnreachableScreenDeliveryIds.catalog,
  );

  /// The reference reading, framed as a phone with live tracking underneath.
  static const ClientUnreachableScreenFixture phone =
      ClientUnreachableScreenFixture(
    label: 'Phone · reached from live tracking',
    deliveryId: ClientUnreachableScreenDeliveryIds.catalog,
    window: ClientUnreachableScreenWindows.phone,
    parentOnStack: true,
  );

  /// A stack-replacing arrival carrying a real-shaped delivery id: no back
  /// arrow, and nothing for `pop(true)` to return to.
  static const ClientUnreachableScreenFixture coldArrival =
      ClientUnreachableScreenFixture(
    label: 'Cold arrival · real id · nothing to pop',
    deliveryId: ClientUnreachableScreenDeliveryIds.route,
    window: ClientUnreachableScreenWindows.phone,
    parentOnStack: false,
  );

  /// The smallest display the app supports.
  static const ClientUnreachableScreenFixture compact =
      ClientUnreachableScreenFixture(
    label: 'Compact 320 × 568 · everything still fits',
    deliveryId: ClientUnreachableScreenDeliveryIds.catalog,
    window: ClientUnreachableScreenWindows.compact,
    parentOnStack: true,
  );

  /// The accessibility ceiling on a normal phone.
  static const ClientUnreachableScreenFixture phoneLargeText =
      ClientUnreachableScreenFixture(
    label: 'Phone · 200% text',
    deliveryId: ClientUnreachableScreenDeliveryIds.catalog,
    window: ClientUnreachableScreenWindows.phoneLargeText,
    parentOnStack: true,
  );

  /// Worst case: smallest display, largest text, and the cold-arrival stack
  /// that has no back arrow to fall back on.
  static const ClientUnreachableScreenFixture compactLargeText =
      ClientUnreachableScreenFixture(
    label: 'Compact · 200% text · nothing to pop',
    deliveryId: ClientUnreachableScreenDeliveryIds.route,
    window: ClientUnreachableScreenWindows.compactLargeText,
    parentOnStack: false,
  );
}

/// What the screen pops back to when there IS something underneath it.
///
/// Public so the render test can tell "the flag CTA returned to the caller"
/// apart from "the CTA emptied the navigator" — from inside the screen those
/// look the same, and only one of them is an exit.
const String clientUnreachableScreenParentLabel =
    'live tracking (preview stand-in)';

/// Every value `ClientUnreachableScreen` has popped with, newest last.
///
/// `Navigator.of(context).pop(true)` in the flag CTA is the screen's ENTIRE
/// output — it takes no callbacks, writes to no cubit and calls no repository,
/// so the boolean it hands back is the only thing a caller can observe. A
/// preview that could not see it would be reviewing three buttons, one of which
/// might as well be `onTap: () {}` like the other two.
final class ClientUnreachableScreenPopLog {
  ClientUnreachableScreenPopLog._();

  /// Pop results, in order. `true` is the flag confirmation; `null` is a
  /// system/back-arrow pop.
  static final List<Object?> results = <Object?>[];

  /// Clears [results]; the list is static, so one test's taps would otherwise
  /// leak into the next.
  static void reset() => results.clear();
}

/// Hosts `ClientUnreachableScreen` in one [ClientUnreachableScreenFixture].
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library, and
/// — the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget it is named after, so the
/// `ClientUnreachableScreen(...)` has to appear below the banner in the screen's
/// own file rather than in here.
class ClientUnreachableScreenPreviewHost extends StatelessWidget {
  const ClientUnreachableScreenPreviewHost({
    required this.fixture,
    required this.screen,
    super.key,
  });

  /// The state being rendered — id, window and navigation stack.
  final ClientUnreachableScreenFixture fixture;

  /// The screen under review, already built with [fixture]'s `deliveryId`.
  final Widget screen;

  /// The screen's own route, wired so its pop result lands in
  /// [ClientUnreachableScreenPopLog].
  Route<Object?> _screenRoute() {
    final MaterialPageRoute<Object?> route =
        MaterialPageRoute<Object?>(builder: (_) => screen);
    route.popped.then(ClientUnreachableScreenPopLog.results.add);
    return route;
  }

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
                (NavigatorState navigator, String initialRoute) =>
                    <Route<Object?>>[
              if (parentOnStack)
                MaterialPageRoute<Object?>(
                  builder: (_) => const _ClientUnreachableScreenParent(),
                ),
              _screenRoute(),
            ],
            onGenerateRoute: (RouteSettings settings) =>
                MaterialPageRoute<Object?>(
              settings: settings,
              builder: (_) => screen,
            ),
          );

    final ClientUnreachableScreenWindow? window = fixture.window;
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

/// The page beneath the screen when it was reached from live tracking.
///
/// It only has to exist and to be identifiable, so a pop can be shown to reach
/// a page rather than to empty the navigator.
class _ClientUnreachableScreenParent extends StatelessWidget {
  const _ClientUnreachableScreenParent();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            clientUnreachableScreenParentLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
