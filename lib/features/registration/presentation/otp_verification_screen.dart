import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';

/// `phone-otp-verification` — the phone-OTP verify step (JM-009).
///
/// **Re-parented behind sign-up / social (CTO-D1, G8).** In the email-first
/// funnel the user gives Name/Email/Password on `/sign-up` (JM-008) — or signs
/// in socially with no phone on file (JM-018) — and is then sent to this verify
/// step to confirm the phone with a 6-digit OTP before the account is active.
/// It is NOT a new route: it stays inside `/register` (the host
/// [RegistrationScreen] drives the phone-entry → send-code → this OTP entry
/// inside one [RegistrationCubit] scope), per 50_EXECUTION_PLAN §"Re-parent
/// (no new route)".
///
/// **Data wiring (42_GUARDRAILS_MOCK W-1 FLOOR):** the cubit talks to the
/// verified auth endpoints through [OtpService] / [DioOtpService]:
///   - `POST /v1/auth/otp/request` → `{ requestId, expiresInSeconds: 300 }`
///   - `POST /v1/auth/otp/verify`  → `{ accessToken, refreshToken, user{…} }`
/// The B1 rewrite carries these `/v1/auth/*` paths to `/auth-service/...` on
/// `:4010`; the mock dev code is the 6-digit `123456` (B4). The JWT pair +
/// `user.userId` are persisted by [DioOtpService] before verify returns.
///
/// **On verify success → Requests tab (JM-009 AC1).** The default [onVerified]
/// is `context.go('/')`, which resolves to the role-aware [ShellScreen]; for a
/// freshly-signed-up customer that is the Requests tab (the host
/// [RegistrationScreen]'s `_navigateHome` additionally marks onboarding
/// complete + refreshes the session so the router promotes `/` to the shell).
///
/// **D23 returning-user bypass (JM-009 AC3):** this screen is reached ONLY on a
/// fresh sign-up / first social link. A returning logged-in user with biometric
/// enrolled is routed by the splash gate (JM-006) to `/lock`
/// ([BiometricLockScreen], JM-005) and NEVER lands here — there is no per-login
/// OTP. The bypass therefore lives in the router redirect, not in this widget;
/// the OTP screen stays a pure sign-up-verify surface.
///
/// Semantics ids exposed (60_W0_TEST_PLAN §2.5):
///   `phone_otp_input` · `phone_otp_verify_cta` · `phone_otp_resend_cta`
///   (plus `phone_otp_root` for nav-honesty re-asserts, 41_GUARDRAILS §1.1).
/// Legacy `Key('registration.*')`s are kept alongside for the pre-build-out
/// widget tests (grandfathered, 41_GUARDRAILS §1.1).
///
/// Lives in the same [RegistrationCubit] scope as the phone screen; the
/// phone screen pushes this route with `BlocProvider.value` so the
/// countdown and attempt budget survive the navigation.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, this.onVerified});

  /// Called when the cubit reports a verified phone. Defaults to
  /// `context.go('/')` (the role-aware shell → Requests tab for a customer) in
  /// production; tests inject their own callback so the screen doesn't need a
  /// full GoRouter in scope.
  final VoidCallback? onVerified;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _enteredCode = '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RegistrationCubit, RegistrationState>(
      listenWhen: (prev, curr) => prev.step != curr.step,
      listener: (context, state) {
        switch (state.step) {
          case RegistrationStep.phone:
            // Cubit bounced us back to phone entry (lockout expired or the
            // user tapped "change phone"). Pop our route.
            if (Navigator.of(context).canPop()) Navigator.of(context).pop();
          case RegistrationStep.verified:
            final onVerified = widget.onVerified;
            if (onVerified != null) {
              onVerified();
            } else {
              context.go('/');
            }
          case RegistrationStep.otp:
          case RegistrationStep.lockedOut:
            break;
        }
      },
      builder: (context, state) {
        return Semantics(
          identifier: 'phone_otp_root',
          container: true,
          child: Scaffold(
          appBar: OMDSAppBar(
            title: l10n.registrationOtpTitle,
            centerTitle: false,
            leading: IconButton(
              key: const Key('registration.otpBack'),
              icon: const Icon(Icons.arrow_back),
              onPressed: () =>
                  context.read<RegistrationCubit>().changePhone(),
            ),
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(Spacing.medium),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    l10n.registrationOtpTitle,
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  const SizedBox(height: Spacing.xSmall),
                  Text(
                    l10n.registrationOtpSubtitle(state.displayPhone),
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: Spacing.large),
                  if (state.step == RegistrationStep.lockedOut)
                    _LockoutBanner(
                      remaining: state.lockoutSecondsRemaining,
                    )
                  else
                    _OtpEntry(
                      hasError: state.otpError != null,
                      onChanged: (code) =>
                          setState(() => _enteredCode = code),
                      onCompleted: (code) {
                        setState(() => _enteredCode = code);
                        context
                            .read<RegistrationCubit>()
                            .verifyCode(code);
                      },
                    ),
                  if (state.otpError != null) ...[
                    const SizedBox(height: Spacing.small),
                    Text(
                      _otpErrorCopy(state.otpError!, l10n),
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: Theme.of(context).colorScheme.error,
                          ),
                    ),
                  ],
                  if (state.step != RegistrationStep.lockedOut) ...[
                    const SizedBox(height: Spacing.small),
                    _AttemptsRemainingLabel(
                      attemptsUsed: state.failedAttempts,
                      maxAttempts: context
                          .read<RegistrationCubit>()
                          .policy
                          .maxAttempts,
                    ),
                    const SizedBox(height: Spacing.large),
                    // `phone_otp_verify_cta` (60_W0_TEST_PLAN §2.5): manual
                    // verify fallback (the OTP input also auto-submits on the
                    // 6th digit via `onCompleted`).
                    Semantics(
                      identifier: 'phone_otp_verify_cta',
                      button: true,
                      container: true,
                      child: OmdsPrimaryButton(
                        key: const Key('registration.verify'),
                        text: state.isVerifying
                            ? l10n.registrationOtpVerifying
                            : l10n.registrationOtpVerify,
                        isEnabled: !state.isVerifying &&
                            _enteredCode.length == _OtpEntry._kOtpLength,
                        onTap: () => context
                            .read<RegistrationCubit>()
                            .verifyCode(_enteredCode),
                      ),
                    ),
                    const SizedBox(height: Spacing.medium),
                    _ResendRow(
                      secondsRemaining: state.resendSecondsRemaining,
                    ),
                    const SizedBox(height: Spacing.small),
                    OmdsPrimaryButton(
                      key: const Key('registration.changePhone'),
                      text: l10n.registrationChangePhone,
                      variant: OmdsButtonVariant.text,
                      onTap: () =>
                          context.read<RegistrationCubit>().changePhone(),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ),
        );
      },
    );
  }
}

class _OtpEntry extends StatelessWidget {
  const _OtpEntry({
    required this.hasError,
    required this.onChanged,
    required this.onCompleted,
  });

  // Jeeb sign-in uses a 6-digit OTP code. Reconciled from 4 → 6 (P0-3 /
  // defect D1) to match the live gateway contract: `DioOtpService` is the
  // DI-default `OtpService`, the dev `FakeOtpService.validCode` is `'123456'`
  // (6 digits), and both `registrationPhoneSubtitle` / `registrationOtpSubtitle`
  // ARB copies (en + ar) already say "6-digit". The old 4-box input made the
  // canonical 6-digit code physically un-enterable. FLAG: confirm against the
  // running `/v1/auth/otp/verify` before release — if the live service truly
  // emits a different length, that is an owner-gated SHARED change to
  // `one-time-password` (non-breaking-extension-protocol), not a UI edit.
  static const int _kOtpLength = 6;

  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    // `phone_otp_input` (60_W0_TEST_PLAN §2.5): the 6-digit OTP widget. The
    // container node carries the id Maestro taps/asserts; each inner per-digit
    // cell also gets an addressable id `phone_otp_input_0..5` (RC-7) because a
    // single `inputText` on the container does NOT distribute the 6 digits
    // across the N separate TextFields — the driver must type one digit per
    // cell. On completion it auto-submits via `onCompleted` (B4 contract:
    // code = `123456`).
    return Semantics(
      // Container id kept for back-compat (assertions/visibility).
      identifier: 'phone_otp_input',
      container: true,
      child: Center(
        child: OmdsOtpInput(
          key: const Key('registration.otpField'),
          length: _kOtpLength,
          hasError: hasError,
          // RC-7: per-cell ids phone_otp_input_0..5 for digit-by-digit entry.
          identifier: 'phone_otp_input',
          onChanged: onChanged,
          onCompleted: onCompleted,
        ),
      ),
    );
  }
}

class _AttemptsRemainingLabel extends StatelessWidget {
  const _AttemptsRemainingLabel({
    required this.attemptsUsed,
    required this.maxAttempts,
  });

  final int attemptsUsed;
  final int maxAttempts;

  @override
  Widget build(BuildContext context) {
    final remaining = (maxAttempts - attemptsUsed).clamp(0, maxAttempts);
    if (attemptsUsed == 0) return const SizedBox.shrink();
    final l10n = AppLocalizations.of(context);
    return Text(
      l10n.registrationOtpAttemptsRemaining(remaining),
      key: const Key('registration.attemptsLeft'),
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
    );
  }
}

class _ResendRow extends StatelessWidget {
  const _ResendRow({required this.secondsRemaining});

  final int secondsRemaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canResend = secondsRemaining <= 0;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (canResend)
          // `phone_otp_resend_cta` (60_W0_TEST_PLAN §2.5): active only after the
          // countdown expires (JM-009 AC2). Tapping re-requests a code via
          // `RegistrationCubit.resendCode` → `POST /v1/auth/otp/request`; the
          // screen stays put (the OTP input remains visible).
          Semantics(
            identifier: 'phone_otp_resend_cta',
            button: true,
            container: true,
            child: OmdsPrimaryButton(
              key: const Key('registration.resend'),
              text: l10n.registrationOtpResend,
              variant: OmdsButtonVariant.text,
              onTap: () => context.read<RegistrationCubit>().resendCode(),
            ),
          )
        else
          Text(
            l10n.registrationOtpResendIn(secondsRemaining),
            key: const Key('registration.resendCountdown'),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
      ],
    );
  }
}

class _LockoutBanner extends StatelessWidget {
  const _LockoutBanner({required this.remaining});

  final int remaining;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final minutes = (remaining ~/ 60).toString();
    final seconds = (remaining % 60).toString().padLeft(2, '0');
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      key: const Key('registration.lockoutBanner'),
      padding: const EdgeInsets.all(Spacing.medium),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: OmdsBorderRadius.medium,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            l10n.registrationLockoutTitle,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            l10n.registrationLockoutBody(minutes, seconds),
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onErrorContainer,
                ),
          ),
        ],
      ),
    );
  }
}

String _otpErrorCopy(RegistrationOtpError error, AppLocalizations l10n) {
  switch (error) {
    case RegistrationOtpError.invalid:
      return l10n.registrationOtpInvalid;
    case RegistrationOtpError.expired:
      return l10n.registrationOtpExpired;
    case RegistrationOtpError.networkError:
      return l10n.registrationOtpInvalid;
  }
}
