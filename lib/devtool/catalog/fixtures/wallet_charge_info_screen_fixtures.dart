// Shared dev-only fixtures for `WalletChargeInfoScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_11_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/wallet/presentation/wallet_charge_info_screen.dart`.
//
// There is no fake repository here, and that is not an omission. JM-054 is a
// STATIC instructional screen: no constructor parameters, no cubit, no network
// call by design ("No network call. Mock: —"). The catalog entry therefore had
// no fake to extract — it built `const WalletChargeInfoScreen()` and nothing
// else.
//
// What the screen DOES read from outside itself is its navigation context. Both
// back affordances (the app bar arrow and `charge_info_back_cta`) branch on
// `context.canPop()` and fall through to `context.goNamed('wallet')`, so the
// fixture that actually matters is a ROUTER — and which of the two stacks the
// screen is sitting on is the only real state this screen has. Hosting it is
// also what makes the surfaces safe to tap: with no local router the catalog's
// back CTA drives the REAL app router and teleports the reviewer out of the
// catalog, and the preview canvas (which has no `Router` at all) throws.
//
// Everything here is local: a [GoRouter] built in memory over two stand-in
// destinations. No DI, no Dio, no GetIt — network-free by construction, not
// merely by the guard the two hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Label of the stand-in that plays `wallet-hub` (JM-053) — where the back CTA
/// lands when there is nothing to pop.
const String walletChargeInfoScreenWalletHubLabel = 'wallet-hub · stand-in';

/// Label of the stand-in that plays a `+ Top up` caller (onboarding-funding
/// JM-041 / kyc-pending JM-042 / insufficient-balance JM-046) — where the back
/// CTA lands when the screen was pushed ON TOP of one of them.
const String walletChargeInfoScreenCallerLabel = '+ Top up caller · stand-in';

/// Which navigation stack the screen is mocked on.
///
/// This is the screen's only real state, and the two values are not
/// interchangeable: they send the same button to different destinations.
enum WalletChargeInfoScreenEntry {
  /// The PRODUCTION shape. `/wallet/charge-info` is declared FLAT — a
  /// top-level route beside `/wallet`, not a child of it — and all four
  /// `+ Top up` CTAs reach it with `goNamed`, which REPLACES the stack. The
  /// screen is therefore the only page on it, `context.canPop()` is false, and
  /// both back affordances take the `goNamed('wallet')` branch.
  standalone,

  /// The branch the screen's own doc comment describes ("when pushed from one
  /// of those callers it pops back to the caller"): the screen sits on top of
  /// the caller, `context.canPop()` is true, and back POPS to it — while the
  /// CTA still reads "Back to wallet".
  ///
  /// Kept because it is the other half of the screen's written contract and it
  /// is one `pushNamed` away from being live; note that no caller in the app
  /// pushes today (see the preview section for the full reading).
  pushedOnCaller,
}

/// A minimal, obviously-fake destination so a tap on a back affordance lands
/// somewhere legible instead of throwing or escaping into the real app.
class WalletChargeInfoScreenStandIn extends StatelessWidget {
  const WalletChargeInfoScreenStandIn({required this.label, super.key});

  /// What this stand-in is playing — read by the render tests to tell the two
  /// back destinations apart.
  final String label;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.colorScheme.surfaceContainerHighest,
      body: Center(
        child: Text(
          label,
          // Forced LTR: a diagnostic, not shipped copy, and a latin route name
          // reorders visually inside an RTL paragraph.
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [screen], on the stack named by [entry].
///
/// Stateful, and the [GoRouter] is built once and disposed with the host: a
/// router rebuilt on every frame would drop the stack the screen's `canPop()`
/// call reads. `Router.withConfig` is exactly what `MaterialApp.router` does
/// internally, so this adds a Router and nothing else — the ambient theme,
/// locale and text scale still come from the host above it.
///
/// The screen is INJECTED rather than constructed here so that both dev
/// surfaces keep building the real `WalletChargeInfoScreen()` in their own
/// source: the catalog's convention is that every entry visibly renders the
/// real screen, and `tool/preview_inventory.dart` credits a preview section
/// only when the section itself constructs the widget it is named after.
class WalletChargeInfoScreenHost extends StatefulWidget {
  const WalletChargeInfoScreenHost({
    required this.screen,
    super.key,
    this.entry = WalletChargeInfoScreenEntry.standalone,
  });

  /// The real `WalletChargeInfoScreen`, built by the caller.
  final Widget screen;

  final WalletChargeInfoScreenEntry entry;

  @override
  State<WalletChargeInfoScreenHost> createState() =>
      _WalletChargeInfoScreenHostState();
}

class _WalletChargeInfoScreenHostState
    extends State<WalletChargeInfoScreenHost> {
  late final GoRouter _router = _buildRouter();

  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Router.withConfig(config: _router);

  /// Mirrors the two stacks exactly, because the difference between them IS the
  /// state:
  ///
  ///  * [WalletChargeInfoScreenEntry.standalone] declares charge-info FLAT, the
  ///    way `app_router.dart` does, and starts there — one page, `canPop()`
  ///    false;
  ///  * [WalletChargeInfoScreenEntry.pushedOnCaller] declares it as a CHILD of
  ///    the caller and starts at the child, so go_router materializes both
  ///    pages — `canPop()` true.
  GoRouter _buildRouter() {
    final GoRoute walletHub = GoRoute(
      path: '/wallet',
      // The name the screen itself reaches for: `context.goNamed('wallet')`.
      name: 'wallet',
      builder: (_, _) => const WalletChargeInfoScreenStandIn(
        label: walletChargeInfoScreenWalletHubLabel,
      ),
    );
    switch (widget.entry) {
      case WalletChargeInfoScreenEntry.standalone:
        return GoRouter(
          initialLocation: '/wallet/charge-info',
          routes: <RouteBase>[
            walletHub,
            GoRoute(
              path: '/wallet/charge-info',
              builder: (_, _) => widget.screen,
            ),
          ],
        );
      case WalletChargeInfoScreenEntry.pushedOnCaller:
        return GoRouter(
          initialLocation: '/top-up-caller/charge-info',
          routes: <RouteBase>[
            walletHub,
            GoRoute(
              path: '/top-up-caller',
              builder: (_, _) => const WalletChargeInfoScreenStandIn(
                label: walletChargeInfoScreenCallerLabel,
              ),
              routes: <RouteBase>[
                GoRoute(
                  path: 'charge-info',
                  builder: (_, _) => widget.screen,
                ),
              ],
            ),
          ],
        );
    }
  }
}
