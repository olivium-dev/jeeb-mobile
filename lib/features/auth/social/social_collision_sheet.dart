import 'package:flutter/material.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';

/// `social-collision-prompt` (D22, JM-019) — the block-second-method sheet.
///
/// The gateway returns `409 email_collision` when the email behind a social
/// identity is already registered another way (phone-OTP, email/password, or a
/// different provider). Per D22 (Q-045 STANDS) a *second* sign-in method on an
/// existing identity is **blocked**, NOT silently merged — identity linking is
/// owned by the untouchable user-management service (GR-2) and is out of scope
/// for the client. This sheet is the user-facing outcome of that block: it
/// explains that the account already exists and asks the user to sign in the
/// way they did before.
///
/// It is a **sheet, not a route** (40_GUARDRAILS_ARCH §5 — transient prompts
/// use `showModalBottomSheet`, not `GoRoute`s; mirrors `OfferAcceptSheet`). The
/// caller (`SocialSignInSection`) awaits it and then calls
/// [SocialAuthCubit.acknowledgeCollision] so the buttons are tappable again and
/// the listener does not re-fire on the next rebuild.
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

/// The block-second-method (D22) prompt body. Provider-agnostic copy — the
/// block is identical whichever social provider triggered the 409, so no ICU
/// placeholder is needed.
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
                child: OMDSOutlinedButton(
                  key: const Key('registration.socialCollisionDismiss'),
                  text: l10n.registrationSocialCollisionDismiss,
                  onTap: () => Navigator.of(context).pop(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
