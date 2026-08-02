import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../core/role/role_cubit.dart';
import '../../../core/role/user_role.dart';
import '../../../l10n/app_localizations.dart';

/// Persistent header actions — the **wallet chip** + **notification bell** — that
/// the shell paints on the customer **Requests** and **Profile** headers
class ShellHeaderActions extends StatelessWidget {
  const ShellHeaderActions({super.key, required this.idPrefix});

  final String idPrefix;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
            onPressed: () {
              final isJeeber =
                  context.read<RoleCubit?>()?.state == UserRole.jeeber;
              context.goNamed(isJeeber ? 'wallet' : 'customer-wallet');
            },
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
            onPressed: () => context.goNamed('notifications'),
          ),
        ),
      ],
    );
  }
}
