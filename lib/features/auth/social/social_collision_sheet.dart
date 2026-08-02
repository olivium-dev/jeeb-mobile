import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// 409 email_collision: second method BLOCKED. Sheet explains account exists.
Future<void> showSocialCollisionSheet(BuildContext context) {
  final scrim = Theme.of(context).colorScheme.onSecondaryContainer.withValues(
        alpha: UIConstants.opacityHigh,
      );
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Theme.of(context).colorScheme.surface,
    barrierColor: scrim,
    shape: const RoundedRectangleBorder(
      borderRadius: OmdsBorderRadius.topXLarge,
    ),
    builder: (sheetContext) => const SocialCollisionSheet(),
  );
}

class SocialCollisionSheet extends StatelessWidget {
  const SocialCollisionSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Semantics(
      identifier: 'social_collision_sheet',
      container: true,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(Spacing.large),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.person_off_outlined,
                size: Spacing.twoXLarge,
                color: theme.colorScheme.primary,
              ),
              const SizedBox(height: Spacing.medium),
              Text(
                l10n.registrationSocialCollisionTitle,
                style: theme.textTheme.titleLarge,
              ),
              const SizedBox(height: Spacing.small),
              Text(
                l10n.registrationSocialCollisionBody,
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: Spacing.large),
              SizedBox(
                width: double.infinity,
                child: Semantics(
                  identifier: 'social_collision_sheet_dismiss_cta',
                  button: true,
                  container: true,
                  child: OMDSOutlinedButton(
                    key: const Key('registration.socialCollisionDismiss'),
                    text: l10n.registrationSocialCollisionDismiss,
                    onTap: () => Navigator.of(context).pop(),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
