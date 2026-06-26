import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/biometric_lock_cubit.dart';
import '../application/biometric_lock_state.dart';

/// `biometric-unlock` (JM-005, D23) — the real `/lock` gate screen.
///
/// A returning, biometric-enrolled user lands here on cold start (the
/// `app_router.dart` biometric gate holds them on `/lock` while the cubit
/// `phase == locked`, see 40_GUARDRAILS_ARCH §5.5). They either:
///
///   * tap `biometric_unlock_authenticate_cta` → the platform biometric dialog
///     (NO OTP, D23). On success the cubit flips `phase → unlocked`, which
///     releases the router gate → `/` (last-used tab, D75) [AC2]; or
///   * tap `biometric_unlock_use_password_link` → the cubit releases the gate
///     and the screen routes to `/login` [AC3].
///
/// The screen consumes the **app-level** [BiometricLockCubit] already provided
/// by `app.dart` (`BlocProvider.value`) — the SAME instance the router watches
/// in its `refreshListenable`. It must NOT spin up a fresh DI instance, or the
/// unlock would never reach the gate. Routing the success path through the
/// central redirect (not a screen-side `context.go`) honours the guardrail
/// "don't police a screen's reachability inside the screen" (§12).
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
          // Nav is NOT handled in a listener:
          //  * AC2 (success) — the router gate redirects `/lock` → `/` the
          //    instant the cubit reports `phase == unlocked`, so a screen-side
          //    `context.go` would only race the central gate (guardrail §12).
          //  * AC3 (password) — handled inline in the link's tap handler
          //    (`_usePasswordFallback`), where the release-then-`goNamed`
          //    ordering is guaranteed.
          // The builder exists only to disable the CTA while prompting and to
          // surface the failure hint.
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
                          // On success the cubit flips `phase → unlocked` and
                          // the central router gate lands the user on `/`
                          // (last-used tab, D75) [AC2]. No OTP (D23).
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
                          // AC3: release the routing gate FIRST (so the gate
                          // doesn't bounce us back to `/lock`), then route to
                          // `/login`. The emit is synchronous, the
                          // `refreshListenable` notify is async, so the
                          // synchronous `goNamed('login')` redirect already sees
                          // a released (non-locked) phase + a non-`/lock`
                          // location → login sticks.
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
    // EDGE: biometric-unlock → login (JM-005 AC3, 60_W0_TEST_PLAN §3).
    context.goNamed('login');
  }
}
