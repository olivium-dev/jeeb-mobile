import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Centered helper note under the stacked offer cards in the broadcasting
/// chat (Figma node 56535:6659): "Accept only one offer".
///
/// Renders in the brand-accent (tertiary/orange) role to match the Figma
/// emphasis, with the copy resolved through [AppLocalizations].
class ChatOfferOnlyOneFooter extends StatelessWidget {
  const ChatOfferOnlyOneFooter({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'chat_detail_offer_only_one_note',
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Spacing.medium,
          vertical: Spacing.small,
        ),
        child: Center(
          child: Text(
            AppLocalizations.of(context).chatOfferAcceptOnlyOne,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelLarge?.copyWith(
              color: theme.colorScheme.tertiary,
            ),
          ),
        ),
      ),
    );
  }
}
