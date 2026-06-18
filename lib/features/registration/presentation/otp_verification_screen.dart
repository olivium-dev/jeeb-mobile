import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../l10n/app_localizations.dart';
import '../../../shared/first_run/first_run.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';

/// Step 2 of the phone+OTP registration flow.
///
/// Lives in the same [RegistrationCubit] scope as the phone screen; the
/// phone screen pushes this route with `BlocProvider.value` so the
/// countdown and attempt budget survive the navigation.
class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, this.onVerified});

  /// Called when the cubit reports a verified phone. Defaults to
  /// `context.go('/')` (home) in production; tests inject their own
  /// callback so the screen doesn't need a full GoRouter in scope.
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
        return FirstRunSemanticTarget(
          identifier: FirstRunSemanticsIds.otpScreen,
          explicitChildNodes: true,
          child: Scaffold(
            appBar: OMDSAppBar(
              title: l10n.registrationOtpTitle,
              centerTitle: false,
              leading: FirstRunSemanticTarget(
                identifier: FirstRunSemanticsIds.otpBackButton,
                label: l10n.registrationChangePhone,
                button: true,
                child: IconButton(
                  key: const Key('registration.otpBack'),
                  icon: const Icon(Icons.arrow_back),
                  onPressed: () =>
                      context.read<RegistrationCubit>().changePhone(),
                ),
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
                      _LockoutBanner(remaining: state.lockoutSecondsRemaining)
                    else
                      _OtpEntry(
                        hasError: state.otpError != null,
                        onChanged: (code) =>
                            setState(() => _enteredCode = code),
                        onCompleted: (code) =>
                            setState(() => _enteredCode = code),
                      ),
                    if (state.otpError != null) ...[
                      const SizedBox(height: Spacing.small),
                      _OtpErrorMessage(
                        message: _otpErrorCopy(state.otpError!, l10n),
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
                      FirstRunPrimaryButton(
                        buttonKey: const Key('registration.verify'),
                        identifier: FirstRunSemanticsIds.otpVerifyButton,
                        text: state.isVerifying
                            ? l10n.registrationOtpVerifying
                            : l10n.registrationOtpVerify,
                        isEnabled:
                            !state.isVerifying &&
                            _enteredCode.length == _OtpEntry._kOtpLength,
                        onTap: () => context
                            .read<RegistrationCubit>()
                            .verifyCode(_enteredCode),
                      ),
                      const SizedBox(height: Spacing.medium),
                      _ResendRow(
                        secondsRemaining: state.resendSecondsRemaining,
                      ),
                      const SizedBox(height: Spacing.small),
                      FirstRunPrimaryButton(
                        buttonKey: const Key('registration.changePhone'),
                        identifier: FirstRunSemanticsIds.otpChangePhoneButton,
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

class _OtpErrorMessage extends StatelessWidget {
  const _OtpErrorMessage({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return FirstRunSemanticTarget(
      identifier: FirstRunSemanticsIds.otpError,
      label: message,
      child: Text(
        message,
        key: const Key('registration.otpError'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.error,
        ),
      ),
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
    final l10n = AppLocalizations.of(context);
    return Center(
      child: FirstRunOtpInput(
        inputKey: const Key('registration.otpField'),
        identifier: FirstRunSemanticsIds.otpField,
        label: l10n.registrationOtpTitle,
        length: _kOtpLength,
        hasError: hasError,
        onChanged: onChanged,
        onCompleted: onCompleted,
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
    return FirstRunSemanticTarget(
      identifier: FirstRunSemanticsIds.otpAttemptsLeft,
      label: l10n.registrationOtpAttemptsRemaining(remaining),
      child: Text(
        l10n.registrationOtpAttemptsRemaining(remaining),
        key: const Key('registration.attemptsLeft'),
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
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
          FirstRunPrimaryButton(
            buttonKey: const Key('registration.resend'),
            identifier: FirstRunSemanticsIds.otpResendButton,
            text: l10n.registrationOtpResend,
            variant: OmdsButtonVariant.text,
            onTap: () => context.read<RegistrationCubit>().resendCode(),
          )
        else
          FirstRunSemanticTarget(
            identifier: FirstRunSemanticsIds.otpResendCountdown,
            label: l10n.registrationOtpResendIn(secondsRemaining),
            child: Text(
              l10n.registrationOtpResendIn(secondsRemaining),
              key: const Key('registration.resendCountdown'),
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
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
    return FirstRunSemanticTarget(
      identifier: FirstRunSemanticsIds.otpLockoutBanner,
      explicitChildNodes: true,
      child: Container(
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
