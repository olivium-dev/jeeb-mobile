// Shared dev-only fixtures for `RegistrationScreen` — the phone+OTP sign-up

import 'dart:async';

import 'package:jeeb_mobile/features/auth/social/social_auth_cubit.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_error.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_service.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token_store.dart';
import 'package:jeeb_mobile/features/auth/social/social_provider.dart';
import 'package:jeeb_mobile/features/registration/application/registration_cubit.dart';
import 'package:jeeb_mobile/features/registration/application/registration_state.dart';
import 'package:jeeb_mobile/features/registration/data/fake_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';

// ─────────────────────────────────────────────────────────────────────────────

/// Canned [SocialAuthService]: every tap resolves to `cancelled`, the one
/// failure the cubit treats as a silent return to idle (no snackbar, no
/// collision sheet). A reviewer can therefore tap Google/Apple in either dev
class RegistrationScreenFakeSocialAuthService implements SocialAuthService {
  const RegistrationScreenFakeSocialAuthService();

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async =>
      const SocialAuthFailure(SocialAuthError.cancelled);

  @override
  Future<void> signOut() async {}
}

/// Forgetful [SocialAuthTokenStore] — never touches Keychain /
/// EncryptedSharedPreferences, which have no binding under `flutter test` and
/// no business being written from a design review.
class RegistrationScreenFakeSocialAuthTokenStore
    implements SocialAuthTokenStore {
  const RegistrationScreenFakeSocialAuthTokenStore();

  @override
  Future<void> save(SocialAuthSession session) async {}

  @override
  Future<SocialAuthSession?> read() async => null;

  @override
  Future<void> clear() async {}
}

/// The real [SocialAuthCubit] over the two inert collaborators above.
/// A function rather than a `const` value because [SocialAuthCubit] is a
SocialAuthCubit registrationScreenFakeSocialAuthCubit() => SocialAuthCubit(
      service: const RegistrationScreenFakeSocialAuthService(),
      tokenStore: const RegistrationScreenFakeSocialAuthTokenStore(),
    );

// ─────────────────────────────────────────────────────────────────────────────

/// Never resolves — keeps `RegistrationCubit.sendCode` pinned in-flight for a
/// stable "Sending…" state.
/// `sendCode` emits `isSendingCode: true` synchronously, before its first
class RegistrationScreenPendingOtpService implements OtpService {
  const RegistrationScreenPendingOtpService();

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) =>
      Completer<OtpSendOutcome>().future;

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) =>
      Completer<OtpVerifyOutcome>().future;
}

/// An [OtpService] whose send always resolves to [sendOutcome].
/// The two non-`sent` outcomes are the reason this exists.
/// `OtpSendOutcome.networkError` and `OtpSendOutcome.rateLimited` are the only
class RegistrationScreenCannedOtpService implements OtpService {
  const RegistrationScreenCannedOtpService(this.sendOutcome);

  /// What `POST /v1/auth/otp/request` is simulated as answering.
  final OtpSendOutcome sendOutcome;

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async => sendOutcome;

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async =>
      OtpVerifyOutcome.networkError;
}

/// Dev-only subclass that parks [RegistrationCubit] on a designed state.
/// [RegistrationCubit] exposes no seed seam, and every public mutator
/// normalises what it is given — `phoneChanged` and `sendCode` both run their
class RegistrationScreenSeededCubit extends RegistrationCubit {
  RegistrationScreenSeededCubit({
    required super.otpService,
    RegistrationState? seed,
  }) {
    if (seed != null) emit(seed);
  }
}

// ─────────────────────────────────────────────────────────────────────────────

/// Too short to parse (3 digits vs the 7-digit minimum) — the catalog's
/// "Phone Entry — Invalid Number", and the only error the screen's copy is
const String registrationScreenInvalidPhone = '123';

/// The number held on the never-landing send (catalog: "Phone Entry — Sending
/// Code").
const String registrationScreenSendingPhone = '71234567';

/// SIX digits — one short of the 7-digit minimum, and mid-typing rather than
/// submitted.
const String registrationScreenTypingPhone = '711234';

/// A valid 8-digit national number, ready to send. The same number the
/// Maestro P0 and BUG-1 regression tests use
const String registrationScreenReadyPhone = '71123456';

/// Valid number, unreachable gateway.
const String registrationScreenNetworkErrorPhone = '76001122';

/// Valid number, gateway answered 429.
const String registrationScreenRateLimitedPhone = '81445566';

/// A full international number as a user pastes it out of Contacts or a
/// WhatsApp message — the longest content the field can hold, and the state
const String registrationScreenPastedPhone = '+961 71 123 456';

// ─────────────────────────────────────────────────────────────────────────────

/// Cold entry: empty field, CTA disabled (catalog: "Phone Entry — Idle").
/// [FakeOtpService] answers `sent`, so a reviewer who types a number and taps
RegistrationCubit registrationScreenIdleCubit() =>
    RegistrationCubit(otpService: const FakeOtpService(latency: Duration.zero));

/// Mid-typing, one digit short of sendable: CTA disabled, and NO error line.
/// Driven through `phoneChanged`, which clears `phoneError` on every keystroke
RegistrationCubit registrationScreenTypingCubit() =>
    RegistrationCubit(otpService: const FakeOtpService(latency: Duration.zero))
      ..phoneChanged(registrationScreenTypingPhone);

/// A valid national number typed in full: CTA live, no error.
/// Driven through the production `phoneChanged`, i.e. the keystroke path.
RegistrationCubit registrationScreenReadyCubit() =>
    RegistrationCubit(otpService: const FakeOtpService(latency: Duration.zero))
      ..phoneChanged(registrationScreenReadyPhone);

/// Too-short number, rejected locally (catalog: "Phone Entry — Invalid
/// Number").
RegistrationCubit registrationScreenInvalidNumberCubit() =>
    RegistrationCubit(otpService: const FakeOtpService())
      ..sendCode(renderedPhone: registrationScreenInvalidPhone);

/// The send is in flight (catalog: "Phone Entry — Sending Code").
/// `sendCode` emits `isSendingCode: true` synchronously before its first
RegistrationCubit registrationScreenSendingCubit() => RegistrationCubit(
      otpService: const RegistrationScreenPendingOtpService(),
    )..sendCode(renderedPhone: registrationScreenSendingPhone);

/// A VALID number the gateway could not be asked about — `sendCode` came back
/// `networkError`.
RegistrationCubit registrationScreenNetworkErrorCubit() => RegistrationCubit(
      otpService: const RegistrationScreenCannedOtpService(
        OtpSendOutcome.networkError,
      ),
    )..sendCode(renderedPhone: registrationScreenNetworkErrorPhone);

/// A VALID number the gateway refused for now — `sendCode` came back
/// `rateLimited` (HTTP 429, "too many codes requested").
RegistrationCubit registrationScreenRateLimitedCubit() => RegistrationCubit(
      otpService: const RegistrationScreenCannedOtpService(
        OtpSendOutcome.rateLimited,
      ),
    )..sendCode(renderedPhone: registrationScreenRateLimitedPhone);

/// A full `+961 …` number pasted into the field.
/// Seeded rather than driven: every public mutator normalises its argument, so
RegistrationCubit registrationScreenPastedCubit() =>
    RegistrationScreenSeededCubit(
      otpService: const FakeOtpService(latency: Duration.zero),
      seed: const RegistrationState(phoneInput: registrationScreenPastedPhone),
    );
