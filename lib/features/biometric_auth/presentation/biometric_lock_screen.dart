import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/biometric_lock_cubit.dart';
import '../application/biometric_lock_state.dart';

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/biometric_lock_screen_fixtures.dart';

/// `phase == locked`, see 40_GUARDRAILS_ARCH §5.5). They either
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
// ============================== JEEB PREVIEWS ==============================
const Size _biometricLockScreenPhoneCanvas = Size(402, 888);

/// The same, around the smallest display the app supports.
const Size _biometricLockScreenCompactCanvas = Size(332, 612);

/// Every state is one seeded [BiometricLockCubit] in one simula
Widget _biometricLockScreenHosted(
  BiometricLockCubit Function() create, {
  required BiometricLockScreenWindow window,
  required String caption,
}) =>
    BiometricLockScreenPreviewHost(
      key: ValueKey<String>(caption),
      create: create,
      window: window,
      caption: caption,
      screen: const BiometricLockScreen(),
    );

/// The reference reading: a returning enrolled user on an ordin
@JeebPreview(
  group: 'biometric_auth',
  name: 'Awaiting authentication',
  size: _biometricLockScreenPhoneCanvas,
  matrix: true,
)
Widget biometricLockScreenAwaiting() => _biometricLockScreenHosted(
      biometricLockScreenLockedCubit,
      window: BiometricLockScreenWindows.phone,
      caption: 'Awaiting authentication · Phone 390 × 844',
    );

/// The platform sheet is in flight (`prompt == prompting`). Unr
@JeebPreview(
  group: 'biometric_auth',
  name: 'Prompting',
  size: _biometricLockScreenPhoneCanvas,
)
Widget biometricLockScreenPrompting() => _biometricLockScreenHosted(
      biometricLockScreenPromptingCubit,
      window: BiometricLockScreenWindows.phone,
      caption: 'Prompting · Phone 390 × 844',
    );

/// The check was declined or failed. `phase` stays `locked`, so
@JeebPreview(
  group: 'biometric_auth',
  name: 'Failed attempt',
  size: _biometricLockScreenPhoneCanvas,
  matrix: true,
)
Widget biometricLockScreenFailed() => _biometricLockScreenHosted(
      biometricLockScreenFailedCubit,
      window: BiometricLockScreenWindows.phone,
      caption: 'Failed attempt · Phone 390 × 844',
    );

/// The smallest display the app supports, at default text size.
@JeebPreview(
  group: 'biometric_auth',
  name: 'Compact 320 × 568',
  size: _biometricLockScreenCompactCanvas,
)
Widget biometricLockScreenCompact() => _biometricLockScreenHosted(
      biometricLockScreenLockedCubit,
      window: BiometricLockScreenWindows.compact,
      caption: 'Awaiting authentication · Compact 320 × 568',
    );

/// The failure state on the smallest display, still at default 
@JeebPreview(
  group: 'biometric_auth',
  name: 'Failed · Compact 320 × 568',
  size: _biometricLockScreenCompactCanvas,
)
Widget biometricLockScreenFailedCompact() => _biometricLockScreenHosted(
      biometricLockScreenFailedCubit,
      window: BiometricLockScreenWindows.compact,
      caption: 'Failed attempt · Compact 320 × 568',
    );

/// The accessibility ceiling on an ORDINARY phone: 390 x 844 at
@JeebPreview(
  group: 'biometric_auth',
  name: 'Phone · 200% text',
  size: _biometricLockScreenPhoneCanvas,
)
Widget biometricLockScreenLargeText() => _biometricLockScreenHosted(
      biometricLockScreenLockedCubit,
      window: BiometricLockScreenWindows.phoneLargeText,
      caption: 'Awaiting authentication · Phone 390 × 844 · 200% text',
    );

/// The state a user with large text on a small phone actually A
@JeebPreview(
  group: 'biometric_auth',
  name: 'Compact · 200% text',
  size: _biometricLockScreenCompactCanvas,
)
Widget biometricLockScreenCompactLargeText() => _biometricLockScreenHosted(
      biometricLockScreenLockedCubit,
      window: BiometricLockScreenWindows.compactLargeText,
      caption: 'Awaiting authentication · Compact 320 × 568 · 200% text',
    );

/// The worst case the app supports, on the screen with the leas
@JeebPreview(
  group: 'biometric_auth',
  name: 'Failed · Compact · 200% text',
  size: _biometricLockScreenCompactCanvas,
)
Widget biometricLockScreenFailedCompactLargeText() =>
    _biometricLockScreenHosted(
      biometricLockScreenFailedCubit,
      window: BiometricLockScreenWindows.compactLargeText,
      caption: 'Failed attempt · Compact 320 × 568 · 200% text',
    );
