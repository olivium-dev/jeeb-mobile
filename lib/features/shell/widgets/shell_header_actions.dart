import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../l10n/app_localizations.dart';

/// Persistent header actions — the **wallet chip** + **notification bell** — that
/// the shell paints on the customer **Requests** and **Profile** headers
/// (JM-023 / JM-035; 50_EXECUTION_PLAN §"WAVE 1 (1) S3"; D33).
///
/// This is a SHARED, shell-owned widget (S3, the integrator's lane) so both
/// headers carry the identical affordance with the right per-screen Semantics
/// ids. The `idPrefix` scopes the ids to the host screen:
///   * Requests header → `orders_home_wallet_chip` / `orders_home_bell`
///   * Profile header  → `customer_profile_wallet_chip` / `customer_profile_bell`
///
/// Navigation targets (both registered → honest navigation, CTO brief §6.7):
///   * **wallet** route is registered (the `/wallet` stub, replaced by
///     `WalletHubScreen` in W2.5/JM-053), so the chip navigates via
///     `goNamed('wallet')`.
///   * **notifications** (`/notifications`, JM-057) landed in W4-INT, so the
///     bell now navigates via `goNamed('notifications')` — the W1/W2 coming-soon
///     guard is REMOVED (W3+W4 final-wave integrator). The bell ids
///     `orders_home_bell` / `delivery_tab_bell` / `customer_profile_bell` all
///     reach `notifications_root` (JM-057 deep-link dispatch follows from there,
///     D84).
class ShellHeaderActions extends StatelessWidget {
  const ShellHeaderActions({super.key, required this.idPrefix});

  /// Screen-scoped Semantics id prefix (`orders_home` | `customer_profile`).
  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Semantics(
          identifier: '${idPrefix}_search',
          button: true,
          container: true,
          label: l10n.shellSearchLabel,
          child: IconButton(
            tooltip: l10n.shellSearchLabel,
            icon: Icon(
              Icons.search,
              color: colorScheme.onSurface,
            ),
            // Sprint-5 Stream C: the search compose surface (`/search`,
            // `search_root`) IS registered — honest navigation.
            onPressed: () => context.goNamed('search'),
          ),
        ),
        Semantics(
          identifier: '${idPrefix}_wallet_chip',
          button: true,
          container: true,
          label: l10n.shellWalletChipLabel,
          child: IconButton(
            tooltip: l10n.shellWalletChipLabel,
            icon: Icon(
              Icons.account_balance_wallet_outlined,
              color: colorScheme.primary,
            ),
            // Wallet route IS registered (the `/wallet` stub, → WalletHubScreen
            // in W2.5/JM-053) — honest navigation.
            onPressed: () => context.goNamed('wallet'),
          ),
        ),
        Semantics(
          identifier: '${idPrefix}_bell',
          button: true,
          container: true,
          label: l10n.shellBellLabel,
          child: IconButton(
            tooltip: l10n.shellBellLabel,
            icon: Icon(
              Icons.notifications_none_outlined,
              color: colorScheme.onSurface,
            ),
            // notifications-list (JM-057) IS registered (`/notifications`,
            // W4-INT) — honest navigation. The bell routes to the real inbox
            // (`notifications_root`); the coming-soon guard was removed by the
            // final-wave integrator.
            onPressed: () => context.goNamed('notifications'),
          ),
        ),
      ],
    );
  }
}
