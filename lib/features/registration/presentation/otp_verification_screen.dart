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

// Preview-only — see the JEEB PREVIEWS section at the end of this file.
import '../../../core/previews/jeeb_preview.dart';
import '../../../devtool/catalog/fixtures/otp_verification_screen_fixtures.dart';

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

  // Jeeb customer sign-in uses a 4-digit OTP code, matching the live gateway
  // contract (`/v1/auth/otp/verify` issues a 4-digit code, e.g. seed `1234`).
  // The length is sourced from [kCustomerOtpLength] (domain/otp_service.dart)
  // so the input width and the "code complete" gate stay in lockstep.
  static const int _kOtpLength = kCustomerOtpLength;

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

// ============================== JEEB PREVIEWS ==============================
// DEV-ONLY, NOT SHIPPED. Everything below this banner exists for
// `flutter widget-preview start` — open THIS file in the IDE to see its
// previews. Preview functions are never called by the app, so the AOT compiler
// tree-shakes them out of release builds. Nothing ABOVE this banner may
// reference anything BELOW it. Every fixture below is private to this library
// and prefixed with the widget name. Docs: lib/core/previews/README.md ·
// Render tests: test/previews/registration/otp_verification_screen_preview_test.dart
// ===========================================================================
//
// This is a SCREEN, so three things differ from a widget preview.
//
// 1. It owns its own `Scaffold` (OMDSAppBar + body) and [jeebPreviewHost] wraps
//    every child in one as well, so the canvas shows two nested Scaffolds. The
//    inner one is the real surface; the outer contributes only a background.
//    The canvas box is therefore a real device
//    ([_otpVerificationScreenPhoneBox], 390x844) rather than the harness's
//    default 390x200 — a scrolling column of title, subtitle, four OTP cells,
//    an inline error, an attempts counter and three CTAs cannot be judged in a
//    200 pt strip.
//
// 2. No `Router` is needed, and that is deliberate. Every preview passes
//    `onVerified: () {}`, which is the seam that stops the verified branch from
//    reaching `context.go('/')`; the only other navigation the screen performs
//    is `Navigator.pop` on a bounce back to phone entry, and that is already
//    guarded by `canPop()`. So the back arrow and "Change phone number" are
//    tappable in the canvas: they emit `RegistrationStep.phone` and the screen
//    simply stays put, which is exactly what it does when it is the root of a
//    stack in production.
//
// 3. Every state is pinned by a CAPTION rather than by screen copy
//    ([OtpVerificationScreenCaptions], the same device as
//    `MutualRatingScreenCaptions`). Copy alone cannot separate these states:
//    `Wrong code. Try again.` is what BOTH the invalid-code and the
//    network-failure states render, `Resend code` is mounted in four of them,
//    and the two lockouts differ only in a counter that is never drawn. The
//    render test asserts the real state behind each caption — which branch
//    built, whether the attempts counter is mounted, whether the CTA is enabled
//    — so the caption can never be the whole proof.
//
// State is driven the only way this screen allows: through the ambient
// [RegistrationCubit], with the seeded cubits shared verbatim with the Screen
// Catalog entry
// (`lib/devtool/catalog/fixtures/otp_verification_screen_fixtures.dart`). No
// preview builds a `DioOtpService` and nothing here resolves GetIt —
// network-free by construction rather than by the guard in [jeebPreviewHost].
// The fixtures also carry an inert ticker, so a seeded countdown stays on the
// number it was seeded with instead of nine canvas cards each running a live
// 1 s timer.
//
// One state is deliberately absent: `RegistrationStep.verified`. It renders
// nothing of its own — the step exists only to fire the listener — so it is a
// transition, not a picture.
//
// What these previews surfaced in the screen — see the notes on each:
//
//  * a NETWORK FAILURE is reported to the user as a wrong code. `_otpErrorCopy`
//    maps `RegistrationOtpError.networkError` onto `l10n.registrationOtpInvalid`
//    ("Wrong code. Try again."), and the OTP cells take the same error border,
//    so a user whose request never left the phone is told the four digits they
//    just read off an SMS are wrong. The attempts counter is the only tell, and
//    only by its absence — the network branch of `verifyCode` costs no attempt,
//    so nothing appears under the error. There is no `registrationOtpNetwork`
//    key in either ARB.
//  * the screen renders its title TWICE: `OMDSAppBar(title:)` and a
//    `headlineSmall` in the body are both `l10n.registrationOtpTitle`, so
//    "Enter the code" / "أدخل الرمز" is drawn once in the bar and again 16 pt
//    below it. Visible on every card.
//  * `registrationOtpAttemptsRemaining` is not pluralized in either locale, so
//    the last attempt before lockout reads "1 attempts remaining" in EN — see
//    `Wrong code · last attempt`. The ARB has one form and no `plural`
//    placeholder.
//  * the verify CTA can NEVER be enabled from cubit state. `isEnabled` reads
//    `_enteredCode`, which is `State`-local and starts empty, so every state
//    restored from the cubit — including `Verifying…`, which by definition has
//    a code in flight — draws a DISABLED button. Nothing is broken for a user
//    typing on a live screen; it means the button's enabled look is
//    un-previewable and un-restorable, and that a rebuilt screen (locale
//    change, hot reload) drops the typed code from the CTA's gate while the
//    four cells keep showing it.
//  * lockout is a one-way door with one exit, and it is not labelled as one.
//    The whole `if (state.step != RegistrationStep.lockedOut)` block — the
//    entry cells, the attempts counter, the verify CTA, the resend row and
//    "Change phone number" — is gone, leaving the banner and the app-bar back
//    arrow, whose only semantics id is `phone_otp_back_cta`. Tapping it calls
//    `changePhone()`, i.e. back OUT of the lockout, which is the opposite of
//    what a back arrow above a countdown implies.
//  * the two lockouts are the same picture. `Locked out · three wrong codes`
//    (`failedAttempts: 3`) and `Locked out · gateway 429` (`failedAttempts: 0`,
//    reached because `verifyCode` treats a 429 as a cooldown "instead of
//    burning an attempt") differ on screen only in the mm:ss the fixtures
//    happen to seed. A user who typed nothing wrong is shown the same "Too many
//    attempts" as one who burned the budget.
//  * the OTP cells are the only RTL-sensitive layout on the screen, which is
//    why `Code sent · countdown running` is matrixed: `OmdsOtpInput` lays its
//    four cells out in a plain `Row` with directional `EdgeInsets.only`
//    padding, so the AR card mirrors cell 0 to the right-hand edge while the
//    digits typed into it stay LTR.

/// The canvas box for a whole screen: a real phone, not the harness default.
const Size _otpVerificationScreenPhoneBox = Size(390, 844);

/// The caption each preview is pinned by.
///
/// Public because the render test's `expectedText` map is the reason they
/// exist — see note 3 in the section prose. Dev chrome, never shipped copy, so
/// they are deliberately un-localized and rendered LTR at a fixed text scale.
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
/// captions the state.
///
/// The cubit is built inside `BlocProvider.create`, so each mount gets its own
/// and the provider closes it on dispose — a `BlocProvider.value` here would
/// leak one cubit per canvas rebuild.
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
            // Dev chrome: LTR and unscaled, so the AR card still reads it as
            // one latin line and the 200% card does not spend a third of the
            // device on a label.
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
            // `onVerified` is the seam that keeps `context.go('/')` — and
            // therefore a GoRouter — out of these previews.
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
/// cells, no error, and 60 s before a resend is allowed.
///
/// This is the screen's EMPTY state, and the one where the verify CTA's gate is
/// doing its job — `_enteredCode` is `''`, so `registration.verify` is
/// disabled. Note that it stays disabled in every OTHER preview too, for the
/// same reason: the gate reads widget state, never the cubit.
///
/// Matrixed because the four OTP cells are the only RTL-sensitive layout here.
/// `OmdsOtpInput` centres a plain `Row` and pads each cell with directional
/// `EdgeInsets.only(left:/right:)`, so the AR RTL card puts cell 0 — the one
/// that autofocuses and takes the first digit — against the right-hand edge.
/// The EN 200% card is where the rest of the column is under pressure: the
/// title is drawn twice (bar + body), and everything below the cells has to
/// share what is left of 844 pt with a 56 pt-tall input row that does not
/// scale.
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
/// `phone_otp_resend_cta`.
///
/// The other half of `_ResendRow`'s if/else, and the only affordance on the
/// screen for getting a fresh code without abandoning the step. Read it next to
/// `Code sent · countdown running`: those two are the same screen 60 s apart,
/// and the swap is the entire visible difference.
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
/// counter appearing for the first time.
///
/// `_AttemptsRemainingLabel` renders nothing at `failedAttempts == 0`, so this
/// is the first state in which the user learns there is a budget at all — after
/// a third of it is already gone.
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
///
/// The reason this state has its own card: `registrationOtpAttemptsRemaining`
/// is a plain placeholder string with no `plural` form in either ARB, so the
/// most consequential moment on the screen reads "1 attempts remaining". The
/// Arabic is the same shape ("{remaining} محاولات متبقية"), which is wrong for
/// 1 and 2 in a language with a dual.
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
///
/// Costs no attempt, so there is no counter under the error — the copy
/// ("The code expired. Tap resend to get a new one.") has to carry the whole
/// explanation, and it points at a button that is only mounted once the
/// cooldown is spent. The fixture pairs the two so the instruction is
/// actionable; if the code expires while the cooldown is still running, this
/// screen tells the user to tap something that is not on it.
///
/// Matrixed because this is the longest copy the screen can hold — the longest
/// inline error in either locale, stacked under the doubled title and the
/// subtitle — so the EN 200% card is the accessibility ceiling for the whole
/// column, and the AR RTL card is where the error text's alignment under a
/// centred input row is decided.
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
/// wrong.
///
/// `_otpErrorCopy` collapses `RegistrationOtpError.networkError` onto
/// `l10n.registrationOtpInvalid`, and `_OtpEntry` takes `hasError` from
/// `otpError != null`, so an offline device produces the identical frame to
/// `Wrong code · first of three` minus the attempts counter. Nothing tells the
/// user to check their connection, and nothing distinguishes "we could not
/// ask" from "we asked and you were wrong". Compare the two cards side by side
/// in the canvas: the only pixels that differ are the missing counter line.
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
///
/// The only in-flight signal is the CTA's label flipping to "Verifying…" — no
/// spinner, no dimmed cells, and the four cells stay editable, so a user can
/// keep typing into a code that is already being checked. The button under that
/// label is DISABLED, and not because it is busy: `isEnabled` is
/// `!isVerifying && _enteredCode.length == 4`, and `_enteredCode` is
/// `State`-local, so a state restored from the cubit can never satisfy the
/// second half.
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
/// the entire entry column.
///
/// What goes with it: the cells, the attempts counter, the verify CTA, the
/// resend row AND "Change phone number". What is left is the banner and the
/// app-bar back arrow — which calls `changePhone()`, i.e. it is the way OUT of
/// the lockout, not a way back to it. The countdown is frozen here (the
/// fixtures use an inert ticker); on a live screen it ticks to zero and the
/// cubit bounces the user back to phone entry with a fresh budget.
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
/// codes.
///
/// `verifyCode` routes `OtpVerifyOutcome.rateLimited` into the lockout step
/// "instead of burning an attempt", so `failedAttempts` is still 0 and the user
/// has not typed anything wrong. They are told "Too many attempts" anyway.
/// Read this card next to `Locked out · three wrong codes`: the two are the
/// same picture apart from the mm:ss, which is the point.
@JeebPreview(
  group: 'registration',
  name: 'Locked out · gateway 429',
  size: _otpVerificationScreenPhoneBox,
)
Widget otpVerificationScreenRateLimited() => _otpVerificationScreenHosted(
      otpVerificationScreenRateLimitedCubit,
      OtpVerificationScreenCaptions.rateLimited,
    );
