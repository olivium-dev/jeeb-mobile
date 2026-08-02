// Shared dev-only fixtures for `ProfileUnavailableScreen`.
//
// There is NO Screen Catalog entry for this screen today — neither
// `profile_unavailable` nor `ProfileUnavailableScreen` appears anywhere in the
// 67 entries under `lib/devtool/catalog/entries/batch_*.dart`. The fixtures are
// written here anyway, at the path the catalog's other fixture sets already
// use, so whoever adds the entry seeds it from the same windows the preview
// section at the bottom of `lib/core/router/profile_unavailable_screen.dart`
// renders, instead of inventing a second set that is free to drift.
//
// ## Why these fixtures are WINDOWS and a NAVIGATOR, not a fake repository
//
// Most fixture sets in this directory are canned repositories, because most
// screens have a data axis to seed. `ProfileUnavailableScreen` has none: it
// takes nothing but a `key`, resolves nothing out of GetIt, builds no cubit and
// renders two fixed ARB strings under a fixed icon. It IS the error state — the
// release-safe fallback `app_router.dart` substitutes for `/profile/customer`
// and `/profile/delivery-man` when the typed `extra` is missing — so there is no
// empty / loading / error axis underneath it and nothing for a fake to stand in
// for.
//
// Two things DO vary, and they are the states:
//
//  1. **The window.** How wide, how tall, how much of the display the system
//     chrome has claimed, and how large the user has set their text. The body is
//     a `Center` around a NON-SCROLLING `Column`, so the window is what decides
//     whether the copy fits.
//  2. **The navigation stack underneath it.** The screen's only affordance is
//     `OMDSAppBar(showBackButton: true)`, whose default action is
//     `Navigator.of(context).maybePop()` — a no-op when the screen is the lone
//     page on the stack, which is exactly what `context.goNamed('customer-profile')`
//     leaves behind (`password_security_screen.dart:132`). One page or two is
//     therefore a real, reviewable state, not a test detail.
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

/// What the app-bar back button lands on when there IS something to pop.
///
/// Public so the render test can tell "the arrow popped to a real page" apart
/// from "the arrow did nothing" — the two outcomes look identical from inside
/// the screen, and only one of them is an exit.
const String profileUnavailableScreenParentStandInLabel =
    'profile route parent (preview stand-in)';

/// One simulated device window to render [ProfileUnavailableScreen] in.
///
/// The frame has to be pinned by the fixture rather than left to the canvas
/// `size:`, because the render tests in `test/previews/` pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test and every state would silently collapse into
/// the same widget.
@immutable
class ProfileUnavailableScreenWindow {
  const ProfileUnavailableScreenWindow({
    required this.label,
    required this.size,
    this.insets = EdgeInsets.zero,
    this.textScale,
  });

  /// Caption painted above the frame, and the string each preview is pinned by.
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

/// The named windows this screen is reviewed in.
final class ProfileUnavailableScreenWindows {
  ProfileUnavailableScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed.
  static const ProfileUnavailableScreenWindow phone =
      ProfileUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · 100% text',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st gen
  /// class). The body is a centred, non-scrolling `Column`, so this is the
  /// width at which the two strings first start costing lines.
  static const ProfileUnavailableScreenWindow compact =
      ProfileUnavailableScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// A notched phone in portrait: 59 pt status bar, 34 pt home indicator.
  ///
  /// The profile routes are bare top-level `GoRoute`s — no `ShellRoute`, no
  /// `SafeArea` — so whether the composition clears the system chrome is the
  /// screen's own problem.
  static const ProfileUnavailableScreenWindow notched =
      ProfileUnavailableScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const ProfileUnavailableScreenWindow phoneLargeText =
      ProfileUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. This is the window in which the un-scrollable body runs out of room.
  static const ProfileUnavailableScreenWindow compactLargeText =
      ProfileUnavailableScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// The ordinary phone again, but reviewed for its NAVIGATION state rather
  /// than its geometry: the screen as the lone page on the stack.
  ///
  /// Same pixels as [phone] — a distinct label so the two cannot be confused in
  /// the canvas or in the render test, where the caption is what each preview is
  /// pinned by.
  static const ProfileUnavailableScreenWindow phoneStackRoot =
      ProfileUnavailableScreenWindow(
    label: 'Phone · 390 × 844 · stack root (nothing to pop)',
    size: Size(390, 844),
  );
}

/// Hosts `ProfileUnavailableScreen` in one [ProfileUnavailableScreenWindow],
/// with a real [Navigator] above it so the app-bar back button resolves the way
/// it resolves in production.
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the router library, and
/// — the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget it is named after, so the
/// `const ProfileUnavailableScreen()` has to appear below the banner in the
/// screen's own file rather than in here.
///
/// [parentOnStack] models how the route was reached:
///
///  * `true` — a `context.push`-style arrival, a parent page still underneath.
///    `maybePop()` finds something to pop and the arrow is a working exit.
///  * `false` — a stack-REPLACING `context.goNamed('customer-profile')` (or a
///    deep link / notification tap). The Navigator holds one page, `maybePop()`
///    finds nothing, and the arrow does nothing at all.
///
/// Pass `window: null` to render at the ambient window with no caption and no
/// outline — that is the form a Screen Catalog entry would use, where the device
/// IS the frame.
class ProfileUnavailableScreenPreviewHost extends StatelessWidget {
  const ProfileUnavailableScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
    this.parentOnStack = true,
  });

  /// The screen under review — `const ProfileUnavailableScreen()`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final ProfileUnavailableScreenWindow? window;

  /// Whether a page sits beneath the screen on the fixture's Navigator.
  final bool parentOnStack;

  @override
  Widget build(BuildContext context) {
    // A LOCAL Navigator, not the canvas's. Inheriting the ambient one would
    // model the stack-root case by accident and make `parentOnStack: true`
    // silently a lie — the canvas and the render harness each mount the preview
    // as the lone page of their own Navigator.
    final Widget navigated = Navigator(
      onGenerateInitialRoutes: (NavigatorState navigator, String initialRoute) =>
          <Route<void>>[
        if (parentOnStack)
          MaterialPageRoute<void>(
            builder: (_) => const _ProfileUnavailableScreenParentStandIn(),
          ),
        MaterialPageRoute<void>(builder: (_) => screen),
      ],
      onGenerateRoute: (RouteSettings settings) =>
          MaterialPageRoute<void>(settings: settings, builder: (_) => screen),
    );

    final ProfileUnavailableScreenWindow? window = this.window;
    if (window == null) return navigated;

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
            child: SizedBox.fromSize(size: window.size, child: navigated),
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

/// The page beneath the screen when it was reached by a push — the profile
/// route's parent, stubbed.
///
/// It only has to exist and to be identifiable, so a tap on the back arrow can
/// be shown to reach a page rather than to do nothing.
class _ProfileUnavailableScreenParentStandIn extends StatelessWidget {
  const _ProfileUnavailableScreenParentStandIn();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            profileUnavailableScreenParentStandInLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
