import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

class ClientHomeEmptyView extends StatelessWidget {
  const ClientHomeEmptyView({super.key, this.onNewOrder});

  final VoidCallback? onNewOrder;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: '_request_empty_state_root',
      container: true,
      explicitChildNodes: true,
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
          horizontal: Spacing.medium,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            OmdsEmptyState(
              illustration: const _ApplicationIllustration(),
              title: AppLocalizations.of(context).homeEmptyTitle,
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
        borderRadius: OmdsBorderRadius.uiSmall,
        onTap: () => onPressed?.call(),
      ),
    );
  }
}
