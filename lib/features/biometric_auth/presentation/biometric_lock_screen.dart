import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/biometric_lock_cubit.dart';
import '../application/biometric_lock_state.dart';

/// `phase == locked`, see 40_GUARDRAILS_ARCH §5.5). They either:
class BiometricLockScreen extends StatelessWidget {
  const BiometricLockScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Semantics(
      identifier: 'biometric_unlock_prompt',
      container: true,
      explicitChildNodes: true,
      child: Scaffold(
        body: SafeArea(
          child: BlocBuilder<BiometricLockCubit, BiometricLockState>(
            builder: (context, state) {
              return Center(
                child: Padding(
                  padding: const EdgeInsetsDirectional.all(Spacing.large),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.fingerprint,
                        size: Sizes.fiveXLarge,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(height: Spacing.large),
                      Text(
                        l10n.biometricUnlockTitle,
                        style: Theme.of(context).textTheme.headlineSmall,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: Spacing.small),
                      Text(
                        l10n.biometricLockBody,
                        style: Theme.of(context).textTheme.bodyMedium,
                        textAlign: TextAlign.center,
                      ),
                      if (state.hasFailed) ...[
                        const SizedBox(height: Spacing.small),
                        Text(
                          l10n.biometricLockFailure,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color:
                                        Theme.of(context).colorScheme.error,
                                  ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                      const SizedBox(height: Spacing.xLarge),
                      Semantics(
                        identifier: 'biometric_unlock_authenticate_cta',
                        button: true,
                        enabled: !state.isPrompting,
                        child: OmdsPrimaryButton(
                          text: state.hasFailed
                              ? l10n.biometricLockRetry
                              : l10n.biometricUnlockAuthenticateCta,
                          isEnabled: !state.isPrompting,
                          onTap: () =>
                              context.read<BiometricLockCubit>().authenticate(),
                        ),
                      ),
                      const SizedBox(height: Spacing.small),
                      Semantics(
                        identifier: 'biometric_unlock_use_password_link',
                        button: true,
                        child: OmdsPrimaryButton(
                          text: l10n.biometricUnlockUsePasswordLink,
                          variant: OmdsButtonVariant.text,
                          onTap: () => _usePasswordFallback(context),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  void _usePasswordFallback(BuildContext context) {
    context.read<BiometricLockCubit>().usePasswordFallback();
    context.goNamed('register');
  }
}
