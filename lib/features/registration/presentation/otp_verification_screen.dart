import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../../core/dev_seam/dev_seam.dart';
import '../../../core/theme/jeeb_color_roles.dart';
import '../../../core/theme/jeeb_text_styles.dart';
import '../../../core/widgets/jeeb/jeeb_code_cells.dart';
import '../../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../../core/widgets/jeeb/jeeb_numeric_keypad.dart';
import '../../../core/widgets/jeeb/jeeb_top_bar.dart';
import '../../../l10n/app_localizations.dart';
import '../application/registration_cubit.dart';
import '../application/registration_state.dart';
import '../domain/otp_service.dart';

/// U+2066 LEFT-TO-RIGHT ISOLATE / U+2069 POP DIRECTIONAL ISOLATE. A phone
/// number and an `m:ss` countdown are LTR tokens dropped into a paragraph that
/// is RTL under `ar`; without the isolate the bidi algorithm reorders them
/// (precedent: `core/formatting/money_format.dart`).
const String _lri = '\u2066';
const String _pdi = '\u2069';

/// `phone-otp-verification` — the phone-OTP verify step (JM-009).
///
/// **Re-parented behind sign-up / social (CTO-D1, G8).** In the email-first
/// funnel the user gives Name/Email/Password on `/sign-up` (JM-008) — or signs
/// in socially with no phone on file (JM-018) — and is then sent to this verify
/// step to confirm the phone with a 4-digit OTP before the account is active.
/// It is NOT a new route: it stays inside `/register` (the host
/// [RegistrationScreen] drives the phone-entry → send-code → this OTP entry
/// inside one [RegistrationCubit] scope), per 50_EXECUTION_PLAN §"Re-parent
/// (no new route)".
///
/// **Redesign 2026-08 (screen 03).** The OS keyboard used to cover the very
/// cells it was filling, so the code is now entered on an in-screen
/// [JeebNumericKeypad] and the cells ([JeebCodeCells.input74]) are
/// presentation-only — there is no `TextField` on this screen and no software
/// keyboard can open here. Entry auto-submits on the 4th digit.
///
/// **Data wiring (42_GUARDRAILS_MOCK W-1 FLOOR):** the cubit talks to the
/// verified auth endpoints through [OtpService] / [DioOtpService]:
///   - `POST /v1/auth/otp/request` → `{ requestId, expiresInSeconds: 300 }`
///   - `POST /v1/auth/otp/verify`  → `{ accessToken, refreshToken, user{…} }`
/// The B1 rewrite carries these `/v1/auth/*` paths to `/auth-service/...` on
/// `:4010`; the mock dev code is the 4-digit `1234` (B4). The JWT pair +
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
///   `phone_otp_input` (+ per-cell `phone_otp_input_0..3`) ·
///   `phone_otp_verify_cta` · `phone_otp_resend_cta` · `phone_otp_back_cta` ·
///   `phone_otp_change_phone_cta` · `phone_otp_resend_timer` ·
///   `phone_otp_keypad_0..9` / `phone_otp_keypad_backspace`
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
  void initState() {
    super.initState();
    _maybeAutoSubmitSeamCode();
  }

  /// DEBUG-ONLY OTP test-seam (62_SEAM_HARNESS.md `jeeb.seam.otp_code`).
  ///
  /// When an automated / on-device driver sets the `jeeb.seam.otp_code` seam
  /// (e.g. the run-branch's known code `1234`), this auto-submits it through
  /// the same [RegistrationCubit.verifyCode] path the user's keypad would
  /// drive — so a Maestro / integration test can advance past the phone-OTP
  /// verify step deterministically without typing into the per-cell input.
  ///
  /// Release-inert by construction: gated on [kDebugMode] AND a non-empty seam
  /// value, and [DevSeam.current] is always [DevSeamConfig.empty] in release
  /// (its `resolve` short-circuits when `!kDebugMode`). It therefore introduces
  /// NO production behaviour change — in a release build both guards are false
  /// and this is a no-op. It also stays inert in debug unless the seam is set,
  /// so the normal manual-entry flow (and the widget tests that drive
  /// `verifyCode` themselves) are untouched.
  void _maybeAutoSubmitSeamCode() {
    if (!kDebugMode) return;
    final seamCode = DevSeam.current.otpCode;
    if (seamCode.isEmpty) return;
    // Defer to the first frame: the cubit/state must be mounted before we
    // submit, and we only fire while the flow is genuinely on the OTP step.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final cubit = context.read<RegistrationCubit>();
      if (cubit.state.step != RegistrationStep.otp) return;
      setState(() => _enteredCode = seamCode);
      cubit.verifyCode(seamCode);
    });
  }

  /// Keypad digit tap. Auto-submits once the code is complete — the board
  /// draws no "verify" affordance and expects the 4th digit to fire it.
  void _appendDigit(String digit) {
    final cubit = context.read<RegistrationCubit>();
    // No racing input while a verify round-trip is in flight.
    if (cubit.state.isVerifying) return;
    if (_enteredCode.length >= kCustomerOtpLength) return;
    setState(() => _enteredCode += digit);
    if (_enteredCode.length == kCustomerOtpLength) {
      cubit.verifyCode(_enteredCode);
    }
  }

  void _deleteDigit() {
    if (_enteredCode.isEmpty) return;
    setState(
      () => _enteredCode = _enteredCode.substring(0, _enteredCode.length - 1),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return BlocConsumer<RegistrationCubit, RegistrationState>(
      listenWhen: (prev, curr) =>
          prev.step != curr.step || prev.otpError != curr.otpError,
      listener: (context, state) {
        // A rejected code would otherwise strand the caret past the last cell
        // with no way back except backspacing four times.
        if (state.otpError != null && _enteredCode.isNotEmpty) {
          setState(() => _enteredCode = '');
        }
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
        final colorScheme = Theme.of(context).colorScheme;
        final isLockedOut = state.step == RegistrationStep.lockedOut;
        return Semantics(
          identifier: 'phone_otp_root',
          container: true,
          explicitChildNodes: true,
          child: Scaffold(
            body: SafeArea(
              // Top-aligned column + a real empty band + a docked keypad. The
              // scroll view is what keeps that shape legal at 200% text scale.
              child: LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  child: ConstrainedBox(
                    constraints:
                        BoxConstraints(minHeight: constraints.maxHeight),
                    child: IntrinsicHeight(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          JeebTopBar.back(
                            key: const Key('registration.otpBack'),
                            identifier: 'phone_otp_back_cta',
                            onLeadingPressed: () =>
                                context.read<RegistrationCubit>().changePhone(),
                          ),
                          Padding(
                            padding: const EdgeInsetsDirectional.symmetric(
                              horizontal: Spacing.xLarge,
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                const SizedBox(height: Spacing.medium),
                                Text(
                                  l10n.registrationOtpHeadline,
                                  style: context.jeebText.h1
                                      .copyWith(color: colorScheme.primary),
                                ),
                                const SizedBox(height: Spacing.xSmall),
                                _SubtitleRow(displayPhone: state.displayPhone),
                                const SizedBox(height: Spacing.xLarge),
                                if (isLockedOut)
                                  _LockoutBanner(
                                    remaining: state.lockoutSecondsRemaining,
                                  )
                                else ...[
                                  Semantics(
                                    identifier: 'phone_otp_input',
                                    container: true,
                                    // Without it the per-cell ids are
                                    // swallowed.
                                    explicitChildNodes: true,
                                    // The cells are no longer TextFields,
                                    // so the value is spoken from here.
                                    value: _enteredCode.split('').join(' '),
                                    child: JeebCodeCells.input74(
                                      key: const Key('registration.otpField'),
                                      length: kCustomerOtpLength,
                                      value: _enteredCode,
                                      hasError: state.otpError != null,
                                      // Emits phone_otp_input_0..3 verbatim.
                                      cellIdentifier: 'phone_otp_input',
                                    ),
                                  ),
                                  const SizedBox(height: Spacing.small),
                                  _MetaRow(
                                    otpError: state.otpError,
                                    resendSecondsRemaining:
                                        state.resendSecondsRemaining,
                                    onResend: _handleResend,
                                  ),
                                  if (state.failedAttempts > 0) ...[
                                    const SizedBox(height: Spacing.small),
                                    _AttemptsRemainingLabel(
                                      attemptsUsed: state.failedAttempts,
                                      maxAttempts: context
                                          .read<RegistrationCubit>()
                                          .policy
                                          .maxAttempts,
                                    ),
                                  ],
                                ],
                              ],
                            ),
                          ),
                          // The board's empty band is real emptiness (R1).
                          const Spacer(),
                          if (!isLockedOut) ...[
                            Padding(
                              padding: const EdgeInsetsDirectional.symmetric(
                                horizontal: Spacing.xLarge,
                              ),
                              // `phone_otp_verify_cta` (60_W0_TEST_PLAN §2.5):
                              // manual fallback; the keypad auto-submits on the
                              // 4th digit.
                              child: JeebCtaButton.primary(
                                key: const Key('registration.verify'),
                                identifier: 'phone_otp_verify_cta',
                                label: state.isVerifying
                                    ? l10n.registrationOtpVerifying
                                    : l10n.registrationOtpVerify,
                                isEnabled: !state.isVerifying &&
                                    _enteredCode.length == kCustomerOtpLength,
                                onTap: () => context
                                    .read<RegistrationCubit>()
                                    .verifyCode(_enteredCode),
                              ),
                            ),
                            const SizedBox(height: Spacing.medium),
                            // Carries its own 0/20/30 gutter — mounts OUTSIDE
                            // the 24pt body padding.
                            JeebNumericKeypad(
                              identifierPrefix: 'phone_otp_keypad',
                              onDigit: _appendDigit,
                              onBackspace: _deleteDigit,
                              backspaceLabel:
                                  l10n.registrationOtpKeypadBackspaceA11y,
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _handleResend() {
    // A stale full code must not sit under a freshly sent SMS.
    setState(() => _enteredCode = '');
    context.read<RegistrationCubit>().resendCode();
  }
}

/// `Code sent to +961 71123456 · Edit` — three inks in one run
/// (`03 tpl 118`).
class _SubtitleRow extends StatelessWidget {
  const _SubtitleRow({required this.displayPhone});

  final String displayPhone;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final body = context.jeebText.body;
    // Wrap, not Row: it survives 200% text scale and mirrors for free.
    return Wrap(
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: Spacing.twoXSmall,
      children: [
        Text.rich(
          TextSpan(
            children: [
              TextSpan(
                text: '${l10n.registrationOtpSentToLabel} ',
                // AA-safe muted ink — periwinkle is never body text on white.
                style: body.copyWith(color: colorScheme.onSurfaceVariant),
              ),
              TextSpan(
                text: '$_lri$displayPhone$_pdi',
                style: body.copyWith(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        // Punctuation, not copy — l10n-exempt.
        Text('·', style: body.copyWith(color: colorScheme.onSurfaceVariant)),
        Semantics(
          identifier: 'phone_otp_change_phone_cta',
          button: true,
          container: true,
          child: InkWell(
            key: const Key('registration.changePhone'),
            onTap: () => context.read<RegistrationCubit>().changePhone(),
            child: Padding(
              // Lifts the inline link off a 17px tap strip without inflating
              // the subtitle run the way a 48px CTA pill would.
              padding: const EdgeInsetsDirectional.symmetric(
                vertical: Spacing.twoXSmall,
              ),
              child: Text(
                l10n.registrationOtpEditPhone,
                style: body.copyWith(
                  color: context.jeebRoles.accent,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// The row under the cells: the auto-verify hint (or the error) at the start,
/// the `m:ss` countdown — or the Resend CTA once it hits zero — at the end
/// (`03 tpl 127`).
class _MetaRow extends StatelessWidget {
  const _MetaRow({
    required this.otpError,
    required this.resendSecondsRemaining,
    required this.onResend,
  });

  final RegistrationOtpError? otpError;
  final int resendSecondsRemaining;
  final VoidCallback onResend;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final colorScheme = Theme.of(context).colorScheme;
    final small = context.jeebText.bodySmall;
    final error = otpError;
    return Row(
      children: [
        Expanded(
          // The error renders here and ONLY here — one node, one assertion.
          child: error != null
              ? Text(
                  _otpErrorCopy(error, l10n),
                  style: small.copyWith(color: colorScheme.error),
                )
              : Text(
                  l10n.registrationOtpAutoVerifyHint,
                  style: small.copyWith(color: colorScheme.onSurfaceVariant),
                ),
        ),
        if (resendSecondsRemaining > 0)
          Semantics(
            identifier: 'phone_otp_resend_timer',
            child: Text.rich(
              TextSpan(
                children: [
                  TextSpan(
                    text: '${l10n.registrationOtpResendInLabel} ',
                    style: small.copyWith(
                      color: colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(
                    text: '$_lri${_countdown(resendSecondsRemaining)}$_pdi',
                    style: small.copyWith(
                      color: colorScheme.primary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
              key: const Key('registration.resendCountdown'),
            ),
          )
        else
          // `phone_otp_resend_cta` (60_W0_TEST_PLAN §2.5): active only once
          // the countdown expires (JM-009 AC2). Tapping re-requests a code via
          // `RegistrationCubit.resendCode` → `POST /v1/auth/otp/request`; the
          // screen stays put. Orange marks the thing that decays (R5).
          JeebCtaButton.accentText(
            key: const Key('registration.resend'),
            identifier: 'phone_otp_resend_cta',
            label: l10n.registrationOtpResend,
            labelStyle: small.copyWith(fontWeight: FontWeight.w700),
            contentPadding: EdgeInsets.zero,
            onTap: onResend,
          ),
      ],
    );
  }

  /// `m:ss` — the board reads `0:42`, not `42s`.
  String _countdown(int seconds) {
    final minutes = seconds ~/ 60;
    final rest = (seconds % 60).toString().padLeft(2, '0');
    return '$minutes:$rest';
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
      style: context.jeebText.bodySmall.copyWith(
        color: Theme.of(context).colorScheme.onSurfaceVariant,
      ),
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
            style: context.jeebText.titleProminent.copyWith(
              color: colorScheme.onErrorContainer,
            ),
          ),
          const SizedBox(height: Spacing.xSmall),
          Text(
            l10n.registrationLockoutBody(minutes, seconds),
            style: context.jeebText.body.copyWith(
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
