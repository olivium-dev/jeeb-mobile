import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/widgets/directional_icons.dart';
import '../../../l10n/app_localizations.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';
import '../domain/otp_service.dart';

class OtpVerificationScreen extends StatefulWidget {
  const OtpVerificationScreen({super.key, this.onVerified});

  final VoidCallback? onVerified;

  @override
  State<OtpVerificationScreen> createState() => _OtpVerificationScreenState();
}

class _OtpVerificationScreenState extends State<OtpVerificationScreen> {
  String _enteredCode = '';

  @override
  void initState() {
    super.initState();
    _maybeAutoSubmitSeamCode();
  }

  void _maybeAutoSubmitSeamCode() {
    if (!kDebugMode) return;
    final seamCode = DevSeam.current.otpCode;
    if (seamCode.isEmpty) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<RegistrationCubit>();
      if (cubit.state.step != RegistrationStep.otp) return;
      setState(() => _enteredCode = seamCode);
      cubit.verifyCode(seamCode);
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RegistrationCubit, RegistrationState>(
      listenWhen: (prev, curr) => prev.step != curr.step,
      listener: (context, state) {
        switch (state.step) {
          case RegistrationStep.phone:
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
          explicitChildNodes: true,
          child: Scaffold(
          appBar: OMDSAppBar(
            title: l10n.registrationOtpTitle,
            centerTitle: false,
            leading: Semantics(
              identifier: 'phone_otp_back_cta',
              button: true,
              container: true,
              child: IconButton(
              key: const Key('registration.otpBack'),
              icon: Icon(DirectionalIcons.back(context)),
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
                    Semantics(
                      identifier: 'phone_otp_change_phone_cta',
                      button: true,
                      container: true,
                      child: OmdsPrimaryButton(
                      key: const Key('registration.changePhone'),
                      text: l10n.registrationChangePhone,
                      variant: OmdsButtonVariant.text,
                      onTap: () =>
                          context.read<RegistrationCubit>().changePhone(),
                    ),
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

  static const int _kOtpLength = kCustomerOtpLength;

  final bool hasError;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onCompleted;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'phone_otp_input',
      container: true,
      child: Center(
        child: OmdsOtpInput(
          key: const Key('registration.otpField'),
          length: _kOtpLength,
          hasError: hasError,
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
