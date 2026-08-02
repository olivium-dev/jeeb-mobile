// Shared dev-only fixtures for `CustomerWalletStubScreen`.
//
// There is NO Screen Catalog entry for this screen today — `customer_wallet_stub`
// is not among the 67 entries in `lib/devtool/catalog/entries/batch_*.dart`. The
// fixtures are written here anyway, at the path the catalog's other fixture sets
// already use, so that whoever adds the entry seeds it from the same windows the
// preview section at the bottom of
// `lib/features/wallet/presentation/customer_wallet_stub_screen.dart` renders,
// instead of inventing a second set that is free to drift.
//
// ## Why these fixtures are WINDOWS and not fake repositories
//
// Every other fixture set in this directory is a canned repository, because
// every other screen has a data axis to seed. `CustomerWalletStubScreen` has
// none: it takes no arguments beyond `key`, resolves nothing out of GetIt,
// builds no cubit, and renders six fixed ARB strings. Its dartdoc is explicit —
// "It performs NO network calls". There is no empty / loading / error state to
// mock, and nothing for a fake to stand in for.
//
// What it DOES vary with is the window it is given: how wide, how tall, how much
// of it the system chrome has claimed, and how large the user has set their
// text. Those are the states, and they are what these fixtures describe.
//
// Being window-only also makes both dev surfaces network-free by construction
// rather than by the guard `jeebPreviewHost` / the catalog host installs: there
// is no seam here through which a Dio-backed repository could be reached even by
// mistake.
//
// ## Why the host owns a Router
//
// Both of the screen's exits — the app-bar back button and the
// `customer_wallet_stub_done` CTA — call `context.canPop()`, which is
// `GoRouter.of(context).canPop()` and throws when no `GoRouter` is in scope. The
// screen BUILDS fine without one (neither call happens during `build`), so a
// naive host looks correct in the canvas right up until someone taps it.
// [CustomerWalletStubScreenPreviewHost] supplies a real router, seeded to model
// production: the screen is the only page on the stack, because the wallet chip
// reaches it via stack-REPLACING `goNamed('customer-wallet')`. `canPop()` is
// therefore false and both exits take the `context.go('/')` fallback, which
// lands on [customerWalletStubScreenShellStandInLabel].
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// What the `context.go('/')` fallback lands on inside the fixture router.
///
/// Public so the render test can assert that the CTA has somewhere to go — an
/// exit that empties the Navigator is the black-screen failure mode
/// `OMDSAppBar._buildBackButton` documents at length.
const String customerWalletStubScreenShellStandInLabel =
    'app shell (preview stand-in)';

/// One simulated device window to render [CustomerWalletStubScreen] in.
///
/// The frame has to be pinned by the fixture rather than left to the canvas
/// `size:`, because the render tests in `test/previews/` pump onto a fixed
/// 800 x 600 surface: a state that merely ASKED for a 320 x 568 canvas would be
/// measured at 800 x 600 under test and every state would silently collapse into
/// the same widget.
@immutable
class CustomerWalletStubScreenWindow {
  const CustomerWalletStubScreenWindow({
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
final class CustomerWalletStubScreenWindows {
  CustomerWalletStubScreenWindows._();

  /// The reference reading: an ordinary modern phone, no system chrome claimed.
  static const CustomerWalletStubScreenWindow phone =
      CustomerWalletStubScreenWindow(
    label: 'Phone · 390 × 844 · 100% text',
    size: Size(390, 844),
  );

  /// The smallest display the app still has to look right on (iPhone SE 1st
  /// gen class). This screen's content is a fixed-height column inside a
  /// `ListView`, so this is where it first stops fitting.
  static const CustomerWalletStubScreenWindow compact =
      CustomerWalletStubScreenWindow(
    label: 'Compact · 320 × 568 · 100% text',
    size: Size(320, 568),
  );

  /// A notched phone in portrait: 59 pt status bar, 34 pt home indicator.
  ///
  /// The screen is mounted as a bare top-level `GoRoute` — `app_router.dart`
  /// wraps it in no `ShellRoute` and no `SafeArea` — so the bottom inset is
  /// real and nothing but the `ListView`'s own 24 pt bottom padding stands
  /// between the CTA and the home indicator.
  static const CustomerWalletStubScreenWindow notched =
      CustomerWalletStubScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
  );

  /// The accessibility ceiling on an ordinary phone.
  static const CustomerWalletStubScreenWindow phoneLargeText =
      CustomerWalletStubScreenWindow(
    label: 'Phone · 390 × 844 · 200% text',
    size: Size(390, 844),
    textScale: 2,
  );

  /// The worst case the app supports: the smallest display AND the largest
  /// text. Both of this screen's paragraphs are long, so this is the state that
  /// decides whether the only action on the screen is reachable.
  static const CustomerWalletStubScreenWindow compactLargeText =
      CustomerWalletStubScreenWindow(
    label: 'Compact · 320 × 568 · 200% text',
    size: Size(320, 568),
    textScale: 2,
  );

  /// The notched phone at the accessibility ceiling — the one combination in
  /// which the body actually SCROLLS on a device that has a home indicator, and
  /// therefore the only window in which the missing bottom inset is visible
  /// rather than merely latent.
  static const CustomerWalletStubScreenWindow notchedLargeText =
      CustomerWalletStubScreenWindow(
    label: 'Notched · 393 × 852 · inset 59/34 · 200% text',
    size: Size(393, 852),
    insets: EdgeInsets.only(top: 59, bottom: 34),
    textScale: 2,
  );
}

/// Hosts `CustomerWalletStubScreen` in one [CustomerWalletStubScreenWindow],
/// with a real `Router` above it so both of its exits work.
///
/// The screen is passed IN rather than constructed here, for two reasons. It
/// keeps this file free of a circular import back into the feature library, and
/// — the load-bearing one — `tool/preview_coverage.dart` only credits a preview
/// section that literally CONSTRUCTS the widget it is named after, so the
/// `const CustomerWalletStubScreen()` has to appear below the banner in the
/// screen's own file rather than in here.
///
/// Pass `window: null` to render at the ambient window with no caption and no
/// outline — that is the form a Screen Catalog entry would use, where the
/// device IS the frame.
///
/// Stateful, and the router is built once and disposed with the host: a
/// [GoRouter] rebuilt every frame would drop the navigation state `canPop()`
/// reads.
class CustomerWalletStubScreenPreviewHost extends StatefulWidget {
  const CustomerWalletStubScreenPreviewHost({
    required this.screen,
    super.key,
    this.window,
  });

  /// The screen under review — `const CustomerWalletStubScreen()`.
  final Widget screen;

  /// The simulated display, or `null` to use the real one.
  final CustomerWalletStubScreenWindow? window;

  @override
  State<CustomerWalletStubScreenPreviewHost> createState() =>
      _CustomerWalletStubScreenPreviewHostState();
}

class _CustomerWalletStubScreenPreviewHostState
    extends State<CustomerWalletStubScreenPreviewHost> {
  late final GoRouter _router = GoRouter(
    // The wallet chip reaches this screen with a stack-REPLACING
    // `goNamed('customer-wallet')`, so in production it is the only page on the
    // stack. Starting deep here reproduces that: `canPop()` is false and both
    // exits take the `context.go('/')` fallback.
    initialLocation: '/wallet/customer',
    routes: <RouteBase>[
      GoRoute(
        path: '/',
        builder: (_, _) => const _CustomerWalletStubScreenShellStandIn(),
      ),
      GoRoute(
        path: '/wallet/customer',
        name: 'customer-wallet',
        builder: (_, _) => widget.screen,
      ),
    ],
  );

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final Widget routed = Router.withConfig(config: _router);
    final CustomerWalletStubScreenWindow? window = widget.window;
    if (window == null) return routed;

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
            child: SizedBox.fromSize(size: window.size, child: routed),
          ),
        ),
      ],
    );

    // Unbound both axes. The render tests pump onto 800 x 600 and every frame
    // here is taller than that; an `Align` + `SizedBox` would pass the host's
    // constraints down and the frame would be silently clamped to 600 pt, which
    // is exactly the measurement the "is the CTA below the fold" tests depend
    // on not being faked.
    return SingleChildScrollView(
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: framed,
      ),
    );
  }
}

/// Where `context.go('/')` lands — the app shell, stubbed.
///
/// It only has to exist and to be identifiable, so that a tap on the back
/// button or on `customer_wallet_stub_done` demonstrably reaches a page rather
/// than emptying the Navigator.
class _CustomerWalletStubScreenShellStandIn extends StatelessWidget {
  const _CustomerWalletStubScreenShellStandIn();

  @override
  Widget build(BuildContext context) => Scaffold(
        body: Center(
          child: Text(
            // Forced LTR: a diagnostic string, not shipped copy.
            customerWalletStubScreenShellStandInLabel,
            textDirection: TextDirection.ltr,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
        ),
      );
}
