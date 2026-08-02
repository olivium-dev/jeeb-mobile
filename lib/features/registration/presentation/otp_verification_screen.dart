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

import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/otp_verification_screen_fixtures.dart';

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
// ============================= JEEB PREVIEWS =============================
/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _otpVerificationScreenPhoneBox = Size(390, 844);

/// The caption each preview is pinned by.
final class OtpVerificationScreenCaptions {
  OtpVerificationScreenCaptions._();

  /// The code has just been sent; the resend cooldown is at its full 60 s.
  static const String countdownRunning = 'preview · code sent · resend locked';

  /// The cooldown is spent and `phone_otp_resend_cta` is mounted.
  static const String resendReady = 'preview · resend unlocked';

  /// One wrong code in, two attempts left.
  static const String wrongCode = 'preview · wrong code · first of three';

  /// Two wrong codes in — the next one locks out.
  static const String lastAttempt = 'preview · wrong code · last attempt';

  /// The code timed out server-side. Costs no attempt.
  static const String expired = 'preview · code expired';

  /// The verify never reached the gateway. Costs no attempt.
  static const String networkError = 'preview · verify never reached gateway';

  /// `POST /v1/auth/otp/verify` in flight.
  static const String verifying = 'preview · verify in flight';

  /// The attempt budget is spent.
  static const String lockedOut = 'preview · locked out · three wrong codes';

  /// The gateway rate-limited the verify (429) with no wrong code at all.
  static const String rateLimited = 'preview · locked out · gateway 429';
}

/// Puts an ambient [RegistrationCubit] above [OtpVerificationScreen] and
class _OtpVerificationScreenHost extends StatelessWidget {
  const _OtpVerificationScreenHost({
    required this.createCubit,
    required this.caption,
  });

  final RegistrationCubit Function() createCubit;

  /// The line painted above the device frame — see note 3 in the prose.
  final String caption;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Spacing.small,
            vertical: Spacing.xSmall,
          ),
          child: Text(
            caption,
            textDirection: TextDirection.ltr,
            textScaler: TextScaler.noScaling,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: BlocProvider<RegistrationCubit>(
            create: (_) => createCubit(),
            child: OtpVerificationScreen(onVerified: () {}),
          ),
        ),
      ],
    );
  }
}

Widget _otpVerificationScreenHosted(
  RegistrationCubit Function() createCubit,
  String caption,
) =>
    _OtpVerificationScreenHost(createCubit: createCubit, caption: caption);

/// The state every user lands in the instant the code is sent: four empty
@JeebPreview(
  group: 'registration',
  name: 'Code sent · countdown running',
  size: _otpVerificationScreenPhoneBox,
  matrix: true,
)
Widget otpVerificationScreenCountdownRunning() => _otpVerificationScreenHosted(
      otpVerificationScreenCountingDownCubit,
      OtpVerificationScreenCaptions.countdownRunning,
    );

/// The cooldown has run out: the countdown label is swapped for the tappable
@JeebPreview(
  group: 'registration',
  name: 'Resend unlocked',
  size: _otpVerificationScreenPhoneBox,
)
Widget otpVerificationScreenResendReady() => _otpVerificationScreenHosted(
      otpVerificationScreenResendReadyCubit,
      OtpVerificationScreenCaptions.resendReady,
    );

/// One wrong code: the inline error, the red cell borders, and the attempts
@JeebPreview(
  group: 'registration',
  name: 'Wrong code · first of three',
  size: _otpVerificationScreenPhoneBox,
)
Widget otpVerificationScreenWrongCode() => _otpVerificationScreenHosted(
      otpVerificationScreenWrongCodeCubit,
      OtpVerificationScreenCaptions.wrongCode,
    );

/// Two wrong codes in — the next one locks the account out for a minute.
@JeebPreview(
  group: 'registration',
  name: 'Wrong code · last attempt',
  size: _otpVerificationScreenPhoneBox,
)
Widget otpVerificationScreenLastAttempt() => _otpVerificationScreenHosted(
      otpVerificationScreenLastAttemptCubit,
      OtpVerificationScreenCaptions.lastAttempt,
    );

/// The code timed out server-side before it was submitted.
@JeebPreview(
  group: 'registration',
  name: 'Code expired',
  size: _otpVerificationScreenPhoneBox,
  matrix: true,
)
Widget otpVerificationScreenExpired() => _otpVerificationScreenHosted(
      otpVerificationScreenExpiredCubit,
      OtpVerificationScreenCaptions.expired,
    );

/// The verify never reached the gateway — and the screen says the code is
@JeebPreview(
  group: 'registration',
  name: 'Network failure shown as wrong code',
  size: _otpVerificationScreenPhoneBox,
)
Widget otpVerificationScreenNetworkError() => _otpVerificationScreenHosted(
      otpVerificationScreenNetworkErrorCubit,
      OtpVerificationScreenCaptions.networkError,
    );

/// `POST /v1/auth/otp/verify` is in flight.
@JeebPreview(
  group: 'registration',
  name: 'Verify in flight',
  size: _otpVerificationScreenPhoneBox,
)
Widget otpVerificationScreenVerifying() => _otpVerificationScreenHosted(
      otpVerificationScreenVerifyingCubit,
      OtpVerificationScreenCaptions.verifying,
    );

/// Three wrong codes: the attempt budget is spent and `_LockoutBanner` replaces
@JeebPreview(
  group: 'registration',
  name: 'Locked out · three wrong codes',
  size: _otpVerificationScreenPhoneBox,
)
Widget otpVerificationScreenLockedOut() => _otpVerificationScreenHosted(
      otpVerificationScreenLockedOutCubit,
      OtpVerificationScreenCaptions.lockedOut,
    );

/// The gateway rate-limited the verify (HTTP 429) — same banner, zero wrong
@JeebPreview(
  group: 'registration',
  name: 'Locked out · gateway 429',
  size: _otpVerificationScreenPhoneBox,
)
Widget otpVerificationScreenRateLimited() => _otpVerificationScreenHosted(
      otpVerificationScreenRateLimitedCubit,
      OtpVerificationScreenCaptions.rateLimited,
    );
