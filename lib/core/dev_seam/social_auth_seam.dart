import 'package:flutter/foundation.dart';

import '../../features/auth/social/social_auth_error.dart';
import '../../features/auth/social/social_auth_service.dart';
import '../../features/auth/social/social_auth_token.dart';
import '../../features/auth/social/social_provider.dart';
import 'dev_seam.dart';

/// DEBUG-ONLY social-login seam (62_SEAM_HARNESS.md, JM-018/JM-019).
///
/// Maps `jeeb.seam.social_login` to a deterministic [SocialAuthResult] so a
/// Maestro flow can drive the social funnel WITHOUT a live Google/Apple/Facebook
/// OAuth handshake (which an emulator + mock cannot satisfy) AND without
/// depending on the mock's `/auth/social` identity model. This is the resolver
/// the [DefaultSocialAuthService] doc comment anticipates — it is injected at
/// the three construction sites (`login_screen`, `sign_up_screen`,
/// `registration_screen`) under `kDebugMode` only.
///
/// Why a hard short-circuit (not a mock tweak): the mock's `POST /auth/social`
/// only accepts `provider ∈ {google, apple}` and returns 401 for `facebook`
/// (auth-service.ts), and it derives a *new* `recentlyCreated` identity per
/// idToken — so neither `facebook_no_phone` (needs a no-phone success on the
/// Facebook button) nor `collision_409` (needs a 409) is reachable through the
/// real path. The resolver gives both deterministic outcomes locally.
///
/// Values (60_W0_TEST_PLAN §6 `jeeb.seam.social_login`):
///   * `facebook_no_phone` → [SocialAuthSuccess] with NO phone on file
///     (`recentlyCreated: true`, `phone: null`) → `SocialAuthCubit` reports
///     `authenticated` + `requiresPhoneVerification` → host routes to the
///     phone-OTP step (`phone_otp_input`, JM-018 → JM-009).
///   * `collision_409` → [SocialAuthFailure] with [SocialAuthError.collision]
///     → `SocialAuthCubit` reports `collision` → host raises the
///     `social_collision_sheet` (JM-019).
///
/// Returns `null` (fall through to the real native + `/v1/auth/social` path)
/// when the seam is absent, unrecognised, or this is a release build.
class SocialAuthSeam {
  SocialAuthSeam._();

  /// Wire value for the no-phone success path (JM-018).
  static const String facebookNoPhone = 'facebook_no_phone';

  /// Wire value for the 409 email-collision path (JM-019).
  static const String collision409 = 'collision_409';

  /// The single resolver injected into [DefaultSocialAuthService.seamResolver]
  /// at every construction site. `const`-friendly (a tear-off of the static
  /// [_resolve]) so the call sites stay terse. No-op in release.
  static const SocialAuthSeamResolver resolver = _resolve;

  /// Synthetic userId for the seeded social success. Distinct from the seeded
  /// auth userIds so it is obviously a dev fixture; the mock never has to
  /// resolve it because the OTP step that follows mints the real session.
  static const String _seamUserId = 'user-social-seam';

  static SocialAuthResult? _resolve(SocialProvider provider) {
    if (!kDebugMode) return null;
    final variant = DevSeam.current.socialLogin;
    switch (variant) {
      case facebookNoPhone:
        // Authenticated but no phone on file → the G8 gate forces phone-OTP.
        return const SocialAuthSuccess(
          SocialAuthSession(
            userId: _seamUserId,
            authToken: 'mock-social-access-$_seamUserId',
            refreshToken: 'mock-social-refresh-$_seamUserId',
            recentlyCreated: true,
          ),
        );
      case collision409:
        // 409 email_collision → routed (NOT an error banner) to the sheet.
        return const SocialAuthFailure(SocialAuthError.collision);
      default:
        // Absent / unrecognised → take the real path.
        return null;
    }
  }
}
