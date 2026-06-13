import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../../l10n/app_localizations.dart';

/// Read-only notice displayed when the local Jeeber's offer was not accepted.
///
/// Shown in the `closed` phase when the conversation phase is resolved as
/// the Jeeber being the loser. The composer is hidden by [ChatState.isComposerVisible]
/// returning false when phase == closed. This banner provides additional
/// clarity by naming the reason: another Jeeber was picked.
///
/// Rendered above the (frozen) message list as a full-width warning strip.
class JeeberRemovedBanner extends StatelessWidget {
  const JeeberRemovedBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      key: const Key('jeeber-removed-banner'),
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: Spacing.medium,
        vertical: Spacing.small,
      ),
      color: colorScheme.errorContainer,
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            color: colorScheme.onErrorContainer,
            size: Sizes.large,
          ),
          const SizedBox(width: Spacing.small),
          Expanded(
            child: Text(
              l10n.chatJeeberRemovedMessage,
              style: textTheme.bodyMedium?.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
