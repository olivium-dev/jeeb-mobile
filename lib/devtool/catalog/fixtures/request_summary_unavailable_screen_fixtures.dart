// Shared dev-only fixtures for `RequestSummaryUnavailableScreen`.
//
// EXTRACTED from the Screen Catalog entry in
// `lib/devtool/catalog/entries/batch_10_entries.dart` (feature `request_summary`,
// state "Unavailable"), which built the screen inline as a bare
// `const RequestSummaryUnavailableScreen()`. Both dev surfaces now read this
// file — that catalog entry and the JEEB PREVIEWS section at the bottom of
// `lib/features/request_summary/presentation/request_summary_unavailable_screen.dart`
// — so the state a designer signs off against and the states an engineer reviews
// in the canvas cannot drift apart.
//
// ## Why the states here are WINDOWS and a NAVIGATOR, not a fake repository
//
// Most fixture sets in this directory are canned repositories, because most
// screens have a data axis to seed. `RequestSummaryUnavailableScreen` has none:
// it takes nothing but a `key`, resolves nothing out of GetIt, builds no cubit,
// and renders one ARB title plus one ARB sentence under a fixed icon. It IS the
// empty state — the fallback `app_router.dart:1329` substitutes for
// `/request-summary` when `state.extra` is not a `RequestDraft` — so the usual
// "empty / loading / error" axis has no answer here and has to be asked
// differently.
//
// Two things DO vary, and they are the states:
//
//  1. **The window.** How wide, how tall, how much of the display the system
//     chrome has claimed, and how large the user has set their text. The body is
//     a `Center` around a NON-SCROLLING `Column` (`OmdsErrorState`), so the
//     window is what decides whether the copy fits.
//  2. **The navigation stack underneath it.** The screen's only affordance is
//     `OMDSAppBar(showBackButton: true)` with no `onBackPressed`, so the default
//     action is `Navigator.of(context).maybePop()` — a no-op when this screen is
//     the lone page on the stack. Both stacks are reachable in the shipped app,
//     for different reasons, so one page or two is a real reviewable state:
//
//       * **Two pages.** Every in-app edge into this route is a `context.push`
//         WITH a draft (`app_router.dart:1105`, `:1120`, `:1160`), so a parent
//         is still underneath. Those pushes normally land on
//         `RequestSummaryScreen`; they land HERE when the `extra` did not
//         survive — go_router's `extra` is not serializable, so an Android
//         process-death restore rebuilds the same route with `extra == null`.
//       * **One page.** A cold deep link straight to `/request-summary`
//         (`request_summary_route_test.dart` Test 2) has no draft and nothing
//         underneath. `maybePop()` then finds nothing and the arrow is inert.
//
// Being window-only also makes both dev surfaces network-free by construction
// rather than by the guard `jeebPreviewHost` / the catalog host installs: there
// is no seam here through which a Dio-backed repository could be reached even by
// mistake.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:flutter/material.dart';

/// The Screen Catalog's long-standing label for this screen's single state.
///
/// Pinned here rather than left as a literal in the entry, because it is the
/// string a designer has already signed the state off under and the render test
/// asserts the catalog form still renders the same screen.
const String requestSummaryUnavailableScreenCatalogStateLabel = 'Unavailable';

/// What the app-bar back arrow lands on when there IS something to pop.
///
/// Public so the render test can tell "the arrow popped to a real page" apart
/// from "the arrow did nothing" — the two outcomes look identical from inside
/// the screen, and only one of them is an exit.
const String requestSummaryUnavailableScreenParentStandInLabel =
    'create-request step (preview stand-in)';

/// One simulated device window to render `RequestSummaryUnavailableScreen` in.
///
/// The frame has to be pinned by the fixture rather than left to the canvas
/// `size:`, because the render tests in `test/previews/` pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test and every state would silently collapse into
/// the same widget.
@immutable
class RequestSummaryUnavailableScreenWindow {
  const RequestSummaryUnavailableScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Caption painted above the frame, and the string each preview is pinned by
  /// in the render test.
  ///
  /// Distinct per state on purpose: this screen renders the same title, the same
  /// icon and the same sentence in every state, and two windows are the same
  /// pixels, so nothing else on screen reliably tells them apart.
  final String label;

  /// Logical size of the simulated display.
  final Size size;

  /// System-chrome insets (`MediaQuery.padding`) — status bar, home indicator.
  final EdgeInsets insets;

  /// `MediaQuery.textScaler` multiplier, or `null` to INHERIT the ambient one.
  ///
  /// Null is load-bearing, not laziness: `JeebPreview(matrix: true)` renders a
  /// third card at `textScaleFactor: 2.0`, and a window that pinned 1.0 would
  /// silently overwrite it and show a 100% rendering under a "200% text" label.
  /// Only the windows that exist FOR a text scale set one.
  final double? textScale;
}

/// The geometries this screen is reviewed in.
final class RequestSummaryUnavailableScreenWindows {
  RequestSummaryUnavailableScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed.
  static const RequestSummaryUnavailableScreenWindow phone =
      RequestSummaryUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · 100% text',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st gen
  /// class). The body is a centred, non-scrolling `Column`, so this is the width
  /// at which the one sentence first starts costing lines.
  static const RequestSummaryUnavailableScreenWindow compact =
      RequestSummaryUnavailableScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// A notched phone in portrait: 59 pt status bar, 34 pt home indicator.
  ///
  /// `/request-summary` is a bare top-level `GoRoute` — no `ShellRoute`, no
  /// `SafeArea` anywhere in `app_router.dart` — so whether the composition
  /// clears the system chrome is the screen's own problem.
  static const RequestSummaryUnavailableScreenWindow notched =
      RequestSummaryUnavailableScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const RequestSummaryUnavailableScreenWindow phoneLargeText =
      RequestSummaryUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest text.
  /// This is the window in which the un-scrollable body runs out of room.
  static const RequestSummaryUnavailableScreenWindow compactLargeText =
      RequestSummaryUnavailableScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// The ordinary phone again, but reviewed for its NAVIGATION state rather than
  /// its geometry: the screen as the lone page on the stack, which is what a
  /// cold deep link to `/request-summary` produces.
  ///
  /// Same pixels as [phone] — a distinct label so the two cannot be confused in
  /// the canvas or in the render test, where the caption is what each preview is
  /// pinned by.
  static const RequestSummaryUnavailableScreenWindow phoneDeepLink =
      RequestSummaryUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · cold deep link (nothing to pop)',
    size: Size(390, 844),
  );
}

/// Hosts `RequestSummaryUnavailableScreen` in one
/// [RequestSummaryUnavailableScreenWindow], with a real [Navigator] above it so
/// the app-bar back arrow resolves the way it resolves in production.
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library, and
/// — the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget it is named after, so the
/// `const RequestSummaryUnavailableScreen()` has to appear below the banner in
/// the screen's own file rather than in here.
///
/// [parentOnStack] models how the route was reached:
///
///  * `true` — a `context.push('/request-summary', extra: draft)` whose draft
///    did not survive (go_router's `extra` is not serializable, so an Android
///    process-death restore rebuilds the route with `extra == null`). A parent
///    page is still underneath, `maybePop()` finds it, and the arrow is a
///    working exit.
///  * `false` — a cold deep link straight to `/request-summary`. The Navigator
///    holds one page, `maybePop()` finds nothing, and the arrow does nothing.
///  * `null` — mount no Navigator of our own and inherit the ambient one. This
///    is what the Screen Catalog uses: it pushes each state as a real route and
///    overlays its own close button (`catalog_screen.dart:80`), and a local
///    Navigator would only get in the way of both.
///
/// Pass `window: null` to render at the ambient window with no caption and no
/// outline — again the catalog's form, where the device IS the frame.
class RequestSummaryUnavailableScreenPreviewHost extends StatelessWidget {
  const RequestSummaryUnavailableScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
    this.parentOnStack,
  });

  /// The screen under review — `const RequestSummaryUnavailableScreen()`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final RequestSummaryUnavailableScreenWindow? window;

  /// Whether a page sits beneath the screen on a LOCAL navigator, or `null` to
  /// mount no navigator at all.
  final bool? parentOnStack;

  @override
  Widget build(BuildContext context) {
    final bool? parentOnStack = this.parentOnStack;

    // A LOCAL Navigator, not the canvas's. Inheriting the ambient one would
    // model the deep-link case by accident and make `parentOnStack: true`
    // silently a lie — the canvas and the render harness each mount the preview
    // as the lone page of their own Navigator.
    final Widget staged = parentOnStack == null
        ? screen
        : Navigator(
            onGenerateInitialRoutes:
                (NavigatorState navigator, String initialRoute) => <Route<void>>[
              if (parentOnStack)
                MaterialPageRoute<void>(
                  builder: (_) =>
                      const _RequestSummaryUnavailableScreenParentStandIn(),
                ),
              MaterialPageRoute<void>(builder: (_) => screen),
            ],
            onGenerateRoute: (RouteSettings settings) =>
                MaterialPageRoute<void>(settings: settings, builder: (_) => screen),
          );

    final RequestSummaryUnavailableScreenWindow? window = this.window;
    if (window == null) return staged;

    final ThemeData theme = Theme.of(context);
    final Widget framed = Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 4, 8),
          child: Text(
            window.label,
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
            // `jeebPreviewHost` wraps every preview in a `SafeArea`, which
            // ZEROES `padding` for everything below it. Restoring it here is
            // what makes the notched window mean anything at all.
            data: MediaQuery.of(context).copyWith(
              size: window.size,
              padding: window.insets,
              viewPadding: window.insets,
              viewInsets: EdgeInsets.zero,
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

    // Unbind both axes. The render tests pump onto 800 x 600 and every frame
    // here is taller than that; an `Align` + `SizedBox` would pass the host's
    // constraints down and the frame would be silently clamped to 600 pt — the
    // exact measurement the "does the body still fit" assertions depend on not
    // being faked.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// The page beneath the screen when the route was reached by an in-app push.
///
/// It only has to exist and to be identifiable, so a tap on the back arrow can
/// be shown to reach a page rather than to do nothing.
class _RequestSummaryUnavailableScreenParentStandIn extends StatelessWidget {
  const _RequestSummaryUnavailableScreenParentStandIn();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            requestSummaryUnavailableScreenParentStandInLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
