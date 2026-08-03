import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';
import 'client_home_motion.dart';

/// Pending-list empty content for the client Requests screen.
///
/// The profile header, mic hero, filter chips, and bottom navigation remain
/// owned by the surrounding screen. This widget supplies only the branded Jeeb
/// empty-state mark, localized empty copy, and first-request CTA.
///
/// It deliberately carries **no title**: `homeEmptyTitle` ("What do you need?")
/// now belongs to the mic hero directly above it, and printing it twice on one
/// screen was the duplication this redesign removes.
///
/// The mark is [ClientHomeEmptyMark] (`empty-say-it.json`), not the pre-redesign
/// `empty_orders.png` shop illustration: motion spec §2.6 rules that this empty
/// state and "no orders yet" share one CTA — make your first request — so the
/// empty-state visual **is the mic**, matching the hero directly above.
class ClientHomeEmptyView extends StatelessWidget {
  const ClientHomeEmptyView({super.key, this.onNewOrder});

  /// Starts the new-order flow from the primary CTA.
  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: '_request_empty_state_root',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        // The redesign's screen gutter is 24; this view sits exactly where the
        // request cards would, so it must share their edge.
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.xLarge,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmdsEmptyState(
              illustration: const ClientHomeEmptyMark(),
              subtitle: AppLocalizations.of(context).homePendingEmpty,
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: Spacing.medium,
              ),
            ),
            _NewOrderButton(onPressed: onNewOrder),
          ],
        ),
      ),
    );
  }
}

class _NewOrderButton extends StatelessWidget {
  const _NewOrderButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: '_request_empty_state_new_order_button',
      button: true,
      child: OmdsPrimaryButton(
        text: l10n.homeEmptyCta,
        // Pill-dominant: the redesign has no 8px-cornered CTA anywhere.
        borderRadius: OmdsBorderRadius.pill,
        onTap: () => onPressed?.call(),
      ),
    );
  }
}
