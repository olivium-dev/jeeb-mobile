// Shared dev-only fixtures for `RegistrationScreen` — the phone+OTP sign-up
// entry point (T-mobile-002 / JM-009, routed at `/register`).
//
// ONE source of truth for the two dev surfaces that mock this screen:
//
//   * the designer-facing Screen Catalog entry
//     (`lib/devtool/catalog/entries/batch_09_entries.dart`), and
//   * the engineer-facing preview section at the bottom of
//     `lib/features/registration/presentation/registration_screen.dart`.
//
// The catalog owned four private fixtures — `_FakeSocialAuthService`,
// `_FakeSocialAuthTokenStore`, `_fakeSocialAuthCubit()` and `_PendingOtpService`
// — plus three inline phone-number literals. All of them moved here unchanged
// (only renamed to the public, screen-prefixed spelling), so the two surfaces
// cannot drift: the catalog is what a designer signs off against, and a preview
// that quietly retyped `71234567` would be reviewing a different screen from
// the one that was approved.
//
// The sibling `OtpVerificationScreen` — the second step of the same flow, and
// the one this screen pushes — deliberately does NOT share these fixtures. It
// seeds through a different seam (it reads its `RegistrationCubit` from context
// and has no constructor seam of its own), and its catalog fixture
// (`_SeededRegistrationCubit`) stays in the batch file with it. Neither screen's
// designed states should be able to move when the other's are edited.
//
// Everything here is a LOCAL fake. `RegistrationScreen` already ships
// `cubit:` / `socialAuthCubit:` / `onVerified:` seams (built for exactly this
// kind of router-free preview), so with both cubits injected neither surface
// reaches `sl<OtpService>()`, `resolveGatewayDio()` or
// `SecureSocialAuthTokenStore()` — no Dio, no GetIt, no Keychain. Network-free
// by construction, not merely by the `CatalogNetworkGuard` both hosts install.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

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
// Social sign-in half. `SocialSignInSection` sits above the "or" divider on
// this screen and reads its `SocialAuthCubit` from context, so every mocked
// state has to supply one — otherwise the screen builds the REAL
// `DefaultSocialAuthService(dio: resolveGatewayDio())` and a
// `SecureSocialAuthTokenStore()` (Keychain).
// ─────────────────────────────────────────────────────────────────────────────

/// Canned [SocialAuthService]: every tap resolves to `cancelled`, the one
/// failure the cubit treats as a silent return to idle (no snackbar, no
/// collision sheet). A reviewer can therefore tap Google/Apple in either dev
/// surface and land back where they started instead of on an error they did not
/// ask to review — `SocialSignInSection`'s own preview section owns those.
///
/// Reaches no native SDK and no Dio.
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
///
/// A function rather than a `const` value because [SocialAuthCubit] is a
/// `Cubit` — one instance per mocked state, so a tap in one card cannot leave
/// another card's buttons stuck in `inProgress`.
SocialAuthCubit registrationScreenFakeSocialAuthCubit() => SocialAuthCubit(
      service: const RegistrationScreenFakeSocialAuthService(),
      tokenStore: const RegistrationScreenFakeSocialAuthTokenStore(),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Phone+OTP half.
// ─────────────────────────────────────────────────────────────────────────────

/// Never resolves — keeps `RegistrationCubit.sendCode` pinned in-flight for a
/// stable "Sending…" state.
///
/// `sendCode` emits `isSendingCode: true` synchronously, before its first
/// `await`, so pairing it with a send that never lands is the only way to hold
/// the CTA on its spinner: every real outcome resolves on the next microtask
/// and the state is gone before a reviewer sees it. Holds no timer and no
/// subscription — it simply never settles.
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
///
/// The two non-`sent` outcomes are the reason this exists.
/// `OtpSendOutcome.networkError` and `OtpSendOutcome.rateLimited` are the only
/// way to reach `RegistrationPhoneError.networkError` / `.rateLimited`, and
/// those two states are not reachable at all through [FakeOtpService] (which
/// answers `sent` unconditionally) — so before this fixture existed, two of the
/// screen's three inline error states could not be mocked on either surface.
///
/// `verifyCode` is unreachable from this screen (only the pushed
/// `OtpVerificationScreen` calls it) and answers `networkError` rather than
/// pretending to verify, so a future caller cannot get a false green here.
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
///
/// [RegistrationCubit] exposes no seed seam, and every public mutator
/// normalises what it is given — `phoneChanged` and `sendCode` both run their
/// argument through `LebanonPhone.normalise` before it reaches `phoneInput`.
/// That makes one real, shipped state unreachable through the public API: the
/// one where the FIELD holds what the user actually pasted or typed
/// (`+961 71 123 456`, `03 554477`) while the cubit holds the normalised
/// digits. Emitting once from the constructor is the whole implementation.
///
/// The seeded state is emitted BEFORE the screen's `BlocConsumer` subscribes,
/// so it is the *initial* state as far as the listener is concerned and no
/// navigation fires. Nothing is overridden: tapping "Send code" in a canvas
/// still runs the production `sendCode`.
///
/// Rendering note: seeding `phoneInput` with un-normalised text is faithful to
/// what the screen DRAWS, which is all either dev surface can show. The screen
/// reads `phoneInput` exactly once — `initState` copies it into the
/// [TextEditingController] — and from then on renders the controller, the
/// `phoneError`, and a CTA whose enablement runs the controller text back
/// through `LebanonPhone.tryParse`. All three are identical whether the cubit
/// holds `+961 71 123 456` or the `71123456` production would have normalised
/// it to.
class RegistrationScreenSeededCubit extends RegistrationCubit {
  RegistrationScreenSeededCubit({
    required super.otpService,
    RegistrationState? seed,
  }) {
    if (seed != null) emit(seed);
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// The numbers each mocked state carries.
//
// Every state gets a DISTINCT one. These previews differ only in the digits in
// one text field and an optional line of error copy, so without a distinct
// number a render test could not tell one state from another and would pass
// with every card wired to the same fixture.
// ─────────────────────────────────────────────────────────────────────────────

/// Too short to parse (3 digits vs the 7-digit minimum) — the catalog's
/// "Phone Entry — Invalid Number", and the only error the screen's copy is
/// actually written for.
const String registrationScreenInvalidPhone = '123';

/// The number held on the never-landing send (catalog: "Phone Entry — Sending
/// Code").
const String registrationScreenSendingPhone = '71234567';

/// SIX digits — one short of the 7-digit minimum, and mid-typing rather than
/// submitted.
///
/// The distinction from [registrationScreenInvalidPhone] is the whole point:
/// both are unparseable, but this one has NOT been through `sendCode`, so the
/// CTA is disabled and there is deliberately no error line — the cubit's
/// `phoneChanged` clears `phoneError` on every keystroke so the user "isn't
/// yelled at while typing". It is also the exact value the Maestro P0
/// regression test erases down to before re-typing the 8th digit
/// (`test/registration_screen_test.dart`, step 2), i.e. the state that used to
/// be unrecoverable when the cubit mirrored its normalised value back into the
/// field.
const String registrationScreenTypingPhone = '711234';

/// A valid 8-digit national number, ready to send. The same number the
/// Maestro P0 and BUG-1 regression tests use
/// (`test/registration_screen_test.dart`).
const String registrationScreenReadyPhone = '71123456';

/// Valid number, unreachable gateway.
const String registrationScreenNetworkErrorPhone = '76001122';

/// Valid number, gateway answered 429.
const String registrationScreenRateLimitedPhone = '81445566';

/// A full international number as a user pastes it out of Contacts or a
/// WhatsApp message — the longest content the field can hold, and the state
/// `_PhoneField`'s own comment says it must not truncate ("No max-length here
/// so a pasted +961 block isn't truncated at the wrong end").
///
/// `LebanonPhone.normalise` reduces this to [registrationScreenReadyPhone], but
/// the FIELD keeps it verbatim: PR #45 removed the per-keystroke mirror-back of
/// the normalised value because it corrupted live editing (Maestro P0), and
/// `_syncControllerText` now runs only on a step transition.
const String registrationScreenPastedPhone = '+961 71 123 456';

// ─────────────────────────────────────────────────────────────────────────────
// One factory per designed state.
//
// A function, never a shared value: a `Cubit` is mutable, and a catalog state
// or a canvas card that mutated a shared instance would change what every other
// surface renders. Each call returns a fresh cubit over an inert service.
//
// Where a state is reached by CALLING the production API (`phoneChanged`,
// `sendCode`) it is reached that way, so the fixture cannot drift from the
// state machine. [RegistrationScreenSeededCubit] is used only where the public
// API cannot express the state at all.
// ─────────────────────────────────────────────────────────────────────────────

/// Cold entry: empty field, CTA disabled (catalog: "Phone Entry — Idle").
///
/// [FakeOtpService] answers `sent`, so a reviewer who types a number and taps
/// "Send code" in either surface walks on to the real `OtpVerificationScreen`
/// exactly as the app does.
RegistrationCubit registrationScreenIdleCubit() =>
    RegistrationCubit(otpService: const FakeOtpService(latency: Duration.zero));

/// Mid-typing, one digit short of sendable: CTA disabled, and NO error line.
///
/// Driven through `phoneChanged`, which clears `phoneError` on every keystroke
/// — so this is the state that proves the screen distinguishes "not finished"
/// from "wrong", and the one a regression that validated per-keystroke would
/// break first.
RegistrationCubit registrationScreenTypingCubit() =>
    RegistrationCubit(otpService: const FakeOtpService(latency: Duration.zero))
      ..phoneChanged(registrationScreenTypingPhone);

/// A valid national number typed in full: CTA live, no error.
///
/// Driven through the production `phoneChanged`, i.e. the keystroke path.
RegistrationCubit registrationScreenReadyCubit() =>
    RegistrationCubit(otpService: const FakeOtpService(latency: Duration.zero))
      ..phoneChanged(registrationScreenReadyPhone);

/// Too-short number, rejected locally (catalog: "Phone Entry — Invalid
/// Number").
///
/// `sendCode` validates and emits `phoneError` synchronously — before any
/// `await`, and without touching the service — when the number does not parse,
/// so this settles instantly and never reaches the network at all.
RegistrationCubit registrationScreenInvalidNumberCubit() =>
    RegistrationCubit(otpService: const FakeOtpService())
      ..sendCode(renderedPhone: registrationScreenInvalidPhone);

/// The send is in flight (catalog: "Phone Entry — Sending Code").
///
/// `sendCode` emits `isSendingCode: true` synchronously before its first
/// `await`; pairing that with a send that never lands pins the CTA on its
/// spinner and the field on `enabled: false`.
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
///
/// Seeded rather than driven: every public mutator normalises its argument, so
/// the state where the FIELD holds the raw paste is not expressible through
/// `phoneChanged`/`sendCode` — see [RegistrationScreenSeededCubit].
RegistrationCubit registrationScreenPastedCubit() =>
    RegistrationScreenSeededCubit(
      otpService: const FakeOtpService(latency: Duration.zero),
      seed: const RegistrationState(phoneInput: registrationScreenPastedPhone),
    );
