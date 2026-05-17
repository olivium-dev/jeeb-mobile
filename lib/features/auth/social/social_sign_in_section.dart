import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import 'social_auth_cubit.dart';
import 'social_auth_error.dart';
import 'social_auth_state.dart';
import 'social_provider.dart';
import 'social_sign_in_button.dart';

/// Renders the social sign-in row at the top of the registration screen:
/// [Apple button (iOS-only)] [Google button] [— or — divider].
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
      listener: (context, state) {
        if (state.status == SocialAuthStatus.failed && state.error != null) {
          final message = _errorCopy(state.error!, l10n);
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(message)));
          context.read<SocialAuthCubit>().clearError();
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
            const SizedBox(height: Spacing.medium),
            _OrDivider(label: l10n.registrationSocialDivider),
          ],
        );
      },
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider({required this.label});
  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
          color: colorScheme.onSurfaceVariant,
        );
    return Row(
      children: [
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: Spacing.medium),
          child: Text(label, style: style),
        ),
        Expanded(child: Divider(color: colorScheme.outlineVariant)),
      ],
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
    case SocialAuthError.cancelled:
    case SocialAuthError.unknown:
      return l10n.registrationSocialErrorGeneric;
  }
}
