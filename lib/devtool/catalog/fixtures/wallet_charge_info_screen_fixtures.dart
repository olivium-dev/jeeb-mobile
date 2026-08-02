// Shared dev-only fixtures for `WalletChargeInfoScreen`.

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Label of the stand-in that plays `wallet-hub` (JM-053) — where the back CTA
/// lands when there is nothing to pop.
const String walletChargeInfoScreenWalletHubLabel = 'wallet-hub · stand-in';

/// Label of the stand-in that plays a `+ Top up` caller (onboarding-funding
/// JM-041 / kyc-pending JM-042 / insufficient-balance JM-046) — where the back
const String walletChargeInfoScreenCallerLabel = '+ Top up caller · stand-in';

/// Which navigation stack the screen is mocked on.
/// This is the screen's only real state, and the two values are not
/// interchangeable: they send the same button to different destinations.
enum WalletChargeInfoScreenEntry {
  /// The PRODUCTION shape. `/wallet/charge-info` is declared FLAT — a
  /// top-level route beside `/wallet`, not a child of it — and all four
  standalone,

  /// The branch the screen's own doc comment describes ("when pushed from one
  /// of those callers it pops back to the caller"): the screen sits on top of
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
          textDirection: TextDirection.ltr,
          style: theme.textTheme.titleMedium,
        ),
      ),
    );
  }
}

/// Puts a real `Router` above [screen], on the stack named by [entry].
/// Stateful, and the [GoRouter] is built once and disposed with the host: a
/// router rebuilt on every frame would drop the stack the screen's `canPop()`
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
