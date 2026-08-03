import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Pending-list empty content for the client Requests screen.
///
/// The profile header, mic hero, filter chips, and bottom navigation remain
/// owned by the surrounding screen. This widget supplies only the branded Jeeb
/// application illustration, localized empty copy, and first-request CTA.
///
/// It deliberately carries **no title**: `homeEmptyTitle` ("What do you need?")
/// now belongs to the mic hero directly above it, and printing it twice on one
/// screen was the duplication this redesign removes.
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
              illustration: const _ApplicationIllustration(),
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

/// Decorative Jeeb application illustration. Screen readers use the localized
/// title and subtitle instead of receiving an unhelpful image announcement.
class _ApplicationIllustration extends StatelessWidget {
  const _ApplicationIllustration();

  @override
  Widget build(BuildContext context) {
    return ExcludeSemantics(
      child: Image.asset(
        'assets/illustrations/empty_orders.png',
        width: Sizes.twoHundredLarge,
        height: Sizes.twoHundredLarge,
        fit: BoxFit.contain,
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
