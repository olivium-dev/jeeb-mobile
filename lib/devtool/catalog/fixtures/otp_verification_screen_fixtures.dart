// Shared dev-only fixtures for `OtpVerificationScreen`.
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_09_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/registration/presentation/otp_verification_screen.dart`.
//
// The catalog owned a private `_SeededRegistrationCubit` with three hand-rolled
// `seedX()` methods. Copying that into the preview section would have given the
// two surfaces two different notions of "the wrong-code state", free to drift —
// and the catalog is the one a designer signs off against. Both surfaces now
// import this file.
//
// ## Why the states are SEEDED rather than driven
//
// `OtpVerificationScreen` has no injectable seam of its own: it reads its
// `RegistrationCubit` off the ambient `BlocProvider` and renders whatever
// `RegistrationState` it finds. `RegistrationCubit` in turn takes an
// `otpService:` and nothing else — there is no `seed:` constructor — so the OTP
// step is reachable from outside only through the async `sendCode` round-trip,
// and most of the states worth looking at are not reachable at all:
//
//   * `isVerifying` exists only while a real `verifyCode` future is in flight;
//   * `otpError.expired` / `otpError.networkError` need a service rigged to
//     return that exact outcome at that exact moment;
//   * the 429 lockout (`OtpVerifyOutcome.rateLimited`) needs a THIRD outcome
//     again, and differs from the three-wrong-codes lockout only in a counter
//     nobody can see.
//
// [OtpVerificationScreenSeededCubit] is a DEV-ONLY subclass that emits one
// fixed state at construction, through the `emit` bloc marks `@protected` (i.e.
// visible to subclasses). It is not a production seam, nothing under
// `lib/features/**` may reach it, and it adds no seam to the screen: the screen
// still only ever sees a `RegistrationCubit` on the provider.
//
// ## Network-free, timer-free
//
// Every cubit here is built with a LOCAL [FakeOtpService] — no Dio, no GetIt,
// no gateway — so both surfaces are network-free by construction rather than
// merely by the `CatalogNetworkGuard` their hosts install.
//
// They also carry an INERT ticker. `RegistrationCubit`'s default
// `tickerFactory` is `Stream.periodic(1s)`, subscribed whenever a resend or
// lockout countdown starts; a designer tapping "Resend code" in the catalog, or
// nine preview cards sitting open in the canvas, would each spin up a live
// wall-clock timer that mutates the designed state out from under the person
// looking at it. `_otpVerificationScreenNoTicks` hands back an empty stream, so
// a seeded countdown stays on the number the fixture chose. Nothing in the
// state machine depends on the ticker: it only decrements.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/data/fake_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/registration_attempt_policy.dart';

/// The eight national digits every seeded state was sent a code for.
///
/// Parses (`LebanonPhone.tryParse`), which matters: the screen's subtitle is
/// `state.displayPhone`, and that getter falls back to the RAW `phoneInput`
/// when the number does not parse. A fixture with a junk number would render a
/// junk subtitle and prove nothing about the real step.
const String otpVerificationScreenPhoneInput = '71234567';

/// What [otpVerificationScreenPhoneInput] renders as in the OTP subtitle —
/// `LebanonPhone.displayWithPrefix`, i.e. dial code + a space + the digits.
///
/// Shared so the catalog, the previews and the render test all describe the
/// same number rather than three transcriptions of it.
const String otpVerificationScreenDisplayPhone = '+961 71234567';

/// The production attempt policy, named so a fixture can be read against it:
/// 3 attempts, a 60 s resend cooldown, a 60 s lockout.
const RegistrationAttemptPolicy otpVerificationScreenPolicy =
    RegistrationAttemptPolicy();

/// A ticker that never ticks — see the note at the top of this file.
Stream<DateTime> _otpVerificationScreenNoTicks() =>
    const Stream<DateTime>.empty();

/// A [RegistrationCubit] that starts in [seed] instead of the default
/// phone-entry state.
///
/// DEV-ONLY. The emit happens in the constructor, before any surface has
/// subscribed, so `OtpVerificationScreen`'s `BlocConsumer.listenWhen`
/// (`prev.step != curr.step`) never sees it as a step CHANGE. That is what
/// keeps a seeded state from firing the screen's `onVerified` / `Navigator.pop`
/// side effects the instant the widget mounts.
///
/// Everything else about the cubit is real: `verifyCode`, `resendCode` and
/// `changePhone` behave exactly as production against the local
/// [FakeOtpService] (whose only valid code is `1234`).
class OtpVerificationScreenSeededCubit extends RegistrationCubit {
  OtpVerificationScreenSeededCubit(RegistrationState seed)
      : super(
          otpService: const FakeOtpService(),
          policy: otpVerificationScreenPolicy,
          tickerFactory: _otpVerificationScreenNoTicks,
        ) {
    emit(seed);
  }
}

/// Base for every OTP-step fixture: the code is sent, nothing typed yet.
const RegistrationState _otpVerificationScreenOtpStep = RegistrationState(
  step: RegistrationStep.otp,
  phoneInput: otpVerificationScreenPhoneInput,
);

/// The state the user lands in the moment the code is sent: the four cells are
/// empty and the resend cooldown is at its full 60 s.
///
/// Also the catalog's `Code Entry — Ready`.
RegistrationCubit otpVerificationScreenCountingDownCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        resendSecondsRemaining: otpVerificationScreenPolicy
            .resendCooldown
            .inSeconds,
      ),
    );

/// The cooldown has run out and no code has arrived: the countdown label is
/// replaced by the tappable `phone_otp_resend_cta`.
///
/// The other half of `_ResendRow`'s if/else, and the only state in which the
/// screen offers a way to get a new code without going back to phone entry.
RegistrationCubit otpVerificationScreenResendReadyCubit() =>
    OtpVerificationScreenSeededCubit(_otpVerificationScreenOtpStep);

/// One wrong code entered, two attempts left.
///
/// Also the catalog's `Code Entry — Wrong Code`. The cubit zeroes nothing on a
/// wrong code, so this is exactly what `verifyCode` emits on the first
/// `OtpVerifyOutcome.invalidCode`: the inline error, the attempts counter, and
/// the resend row in whatever state it was already in.
RegistrationCubit otpVerificationScreenWrongCodeCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        failedAttempts: 1,
        otpError: RegistrationOtpError.invalid,
      ),
    );

/// Two wrong codes in: the next one locks the account out for a minute.
///
/// The state that renders `registrationOtpAttemptsRemaining(1)` — see the
/// preview note on what that string actually says.
RegistrationCubit otpVerificationScreenLastAttemptCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        failedAttempts: 2,
        otpError: RegistrationOtpError.invalid,
      ),
    );

/// The code timed out server-side (`OtpVerifyOutcome.expired`).
///
/// Costs no attempt — `failedAttempts` stays where it was — so this is the one
/// error state with no attempts counter under it. Paired with a spent cooldown
/// because its copy ("Tap resend to get a new one") is only actionable when the
/// resend button is actually mounted.
RegistrationCubit otpVerificationScreenExpiredCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        otpError: RegistrationOtpError.expired,
      ),
    );

/// The verify never reached the gateway (`OtpVerifyOutcome.networkError`).
///
/// Costs no attempt either. What it renders is the point — see the preview.
RegistrationCubit otpVerificationScreenNetworkErrorCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        otpError: RegistrationOtpError.networkError,
      ),
    );

/// `POST /v1/auth/otp/verify` in flight.
///
/// Unreachable without a real pending future: `verifyCode` sets `isVerifying`
/// and clears it the moment the future completes. Seeded here so the pending
/// CTA label can be looked at.
RegistrationCubit otpVerificationScreenVerifyingCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(isVerifying: true),
    );

/// Three wrong codes: the attempt budget is spent and the whole entry column is
/// replaced by `_LockoutBanner`.
///
/// Also the catalog's `Locked Out`. 45 s rather than the policy's full 60 s so
/// the banner shows a countdown mid-flight (`0:45`) rather than its first
/// frame.
RegistrationCubit otpVerificationScreenLockedOutCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        step: RegistrationStep.lockedOut,
        failedAttempts: otpVerificationScreenPolicy.maxAttempts,
        lockoutSecondsRemaining: 45,
      ),
    );

/// The gateway rate-limited the verify (HTTP 429).
///
/// `RegistrationCubit.verifyCode` treats a 429 as a cooldown "instead of
/// burning an attempt": same `lockedOut` step, same banner, full lockout
/// duration — but `failedAttempts` is still 0. Kept as its own fixture because
/// the two lockouts are indistinguishable on screen and reached by completely
/// different paths.
RegistrationCubit otpVerificationScreenRateLimitedCubit() =>
    OtpVerificationScreenSeededCubit(
      _otpVerificationScreenOtpStep.copyWith(
        step: RegistrationStep.lockedOut,
        lockoutSecondsRemaining:
            otpVerificationScreenPolicy.lockoutDuration.inSeconds,
      ),
    );
