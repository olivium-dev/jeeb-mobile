import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'social_auth_cubit.dart';
import 'social_auth_error.dart';
import 'social_auth_state.dart';
import 'social_collision_sheet.dart';
import 'social_provider.dart';
import 'social_sign_in_button.dart';

/// Renders the social sign-in row at the top of the registration screen:
/// [Apple button (iOS-only)] [Google button].
///
/// The "— or —" divider is owned by the registration screen layout
/// (`_PhoneEntryBody._OrDivider`, keyed `registration.orDivider`), NOT here —
/// rendering one in each place produced the duplicate divider QA flagged (D4).
///
/// Reads the [SocialAuthCubit] from the surrounding context. Surfaces
/// errors as a snackbar; lets the caller decide what to do on success
/// via [onAuthenticated].
class SocialSignInSection extends StatelessWidget {
  const SocialSignInSection({super.key, this.onAuthenticated});

  /// Invoked once the cubit reaches [SocialAuthStatus.authenticated]. The
  /// session is already persisted by the time this fires.
  final ValueChanged<SocialAuthState>? onAuthenticated;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<SocialAuthCubit, SocialAuthState>(
      listenWhen: (prev, curr) =>
          prev.status != curr.status || prev.error != curr.error,
      listener: (context, state) async {
        if (state.status == SocialAuthStatus.failed && state.error != null) {
          final message = _errorCopy(state.error!, l10n);
          // EXEMPT(omds-snackbar): OMDS ships `showOmdsErrorSnackbar` for
          // display but does not expose a hide-current helper. We dedupe
          // back-to-back failures here before delegating to OMDS for the
          // actual presentation. Tracked under JEEB-58.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showOmdsErrorSnackbar(context, message: message);
          context.read<SocialAuthCubit>().clearError();
        }
        if (state.status == SocialAuthStatus.collision) {
          // D22 (JM-019): the gateway returned 409 email_collision — the social
          // email is already registered another way. Block the second method
          // with an explicit prompt (identity linking is user-management's,
          // GR-2), then reset so the buttons are tappable and the sheet does
          // not re-fire on the next rebuild.
          final cubit = context.read<SocialAuthCubit>();
          await showSocialCollisionSheet(context);
          cubit.acknowledgeCollision();
        }
        if (state.status == SocialAuthStatus.authenticated) {
          onAuthenticated?.call(state);
        }
      },
      builder: (context, state) {
        final cubit = context.read<SocialAuthCubit>();
        final showApple = SocialSignInButton.isAppleAvailable();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (showApple) ...[
              SocialSignInButton(
                key: const Key('registration.appleSignIn'),
                provider: SocialProvider.apple,
                isBusy: state.isBusyFor(SocialProvider.apple),
                isEnabled: !state.isBusy,
                onTap: () => cubit.signInWith(SocialProvider.apple),
              ),
              const SizedBox(height: Spacing.small),
            ],
            SocialSignInButton(
              key: const Key('registration.googleSignIn'),
              provider: SocialProvider.google,
              isBusy: state.isBusyFor(SocialProvider.google),
              isEnabled: !state.isBusy,
              onTap: () => cubit.signInWith(SocialProvider.google),
            ),
          ],
        );
      },
    );
  }
}

String _errorCopy(SocialAuthError error, AppLocalizations l10n) {
  switch (error) {
    case SocialAuthError.network:
      return l10n.registrationSocialErrorNetwork;
    case SocialAuthError.invalidToken:
      return l10n.registrationSocialErrorInvalidToken;
    case SocialAuthError.accountDisabled:
      return l10n.registrationSocialErrorAccountDisabled;
    case SocialAuthError.collision:
    case SocialAuthError.cancelled:
    case SocialAuthError.unknown:
      return l10n.registrationSocialErrorGeneric;
  }
}
