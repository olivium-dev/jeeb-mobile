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

class SocialSignInSection extends StatelessWidget {
  const SocialSignInSection({super.key, this.onAuthenticated});

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
          // EXEMPT: OMDS shows error but no hide-current helper; dedupe back-to-back.
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          showOmdsErrorSnackbar(context, message: message);
          context.read<SocialAuthCubit>().clearError();
        }
        if (state.status == SocialAuthStatus.collision) {
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
                identifier: 'login_social_apple',
                provider: SocialProvider.apple,
                isBusy: state.isBusyFor(SocialProvider.apple),
                isEnabled: !state.isBusy,
                onTap: () => cubit.signInWith(SocialProvider.apple),
              ),
              const SizedBox(height: Spacing.small),
            ],
            SocialSignInButton(
              key: const Key('registration.googleSignIn'),
              identifier: 'login_social_google',
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
