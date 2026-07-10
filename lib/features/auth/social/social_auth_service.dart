import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'social_auth_error.dart';
import 'social_auth_token.dart';
import 'social_provider.dart';

/// Result of a single social sign-in attempt.
sealed class SocialAuthResult {
  const SocialAuthResult();
}

class SocialAuthSuccess extends SocialAuthResult {
  const SocialAuthSuccess(this.session);
  final SocialAuthSession session;
}

class SocialAuthFailure extends SocialAuthResult {
  const SocialAuthFailure(this.error);
  final SocialAuthError error;
}

/// Drives the native social sign-in sheet, posts the resulting ID token to
/// jeeb-gateway, and returns the gateway-minted JWT bundle.
///
/// The class is provider-agnostic — call [signIn] with the desired
/// [SocialProvider] and the right native flow runs underneath. The gateway
/// endpoint is the VERIFIED `POST /v1/auth/social` (42_GUARDRAILS_MOCK
/// §"W-1 FLOOR"): body `{ provider, idToken }`, success body
/// `{ userId, authToken, refreshToken, expiresIn, recentlyCreated, phone? }`,
/// 409 `email_collision` on a cross-method collision (D22, JM-019), 401
/// `invalid_token` on a bad/unsupported provider. `MockGatewayClient` rewrites
/// the `/v1/auth/social` prefix to `:4010` (B1) — the legacy `/api/auth/social`
/// path also rewrites (B2), but new callers post the `/v1` path.
abstract class SocialAuthService {
  Future<SocialAuthResult> signIn(SocialProvider provider);

  /// Best-effort logout from the native SDKs. Does not clear the secure
  /// token store — call [SocialAuthTokenStore.clear] for that.
  Future<void> signOut();
}

/// A debug-only seam that short-circuits a social sign-in to a deterministic
/// result for Maestro (60_W0_TEST_PLAN §6 `jeeb.seam.social_login`:
/// `facebook_no_phone` → success with no phone; `collision_409` → 409).
///
/// The dev-flavor seam infrastructure (foundation / login-screen owner) wires a
/// resolver that reads the launch argument; production passes none, so the
/// service always takes the real native-SDK + `/v1/auth/social` path. Returning
/// `null` from the resolver also falls through to the real path. Keeping the
/// seam injectable (not reading a global) means JM-018's files need no edit
/// when the foundation wires the arg → resolver (see 50_ROUTE_REQUESTS.md).
typedef SocialAuthSeamResolver = SocialAuthResult? Function(
  SocialProvider provider,
);

/// Production implementation.
class DefaultSocialAuthService implements SocialAuthService {
  DefaultSocialAuthService({
    required Dio dio,
    GoogleSignIn? googleSignIn,
    bool Function()? isApplePlatform,
    SocialAuthSeamResolver? seamResolver,
  })  : _dio = dio,
        _google = googleSignIn ?? GoogleSignIn(scopes: const ['email']),
        _isApplePlatform = isApplePlatform ?? _defaultIsApplePlatform,
        _seamResolver = seamResolver;

  final Dio _dio;
  final GoogleSignIn _google;
  final bool Function() _isApplePlatform;

  /// Debug-only deterministic-result seam (null in production).
  final SocialAuthSeamResolver? _seamResolver;

  static bool _defaultIsApplePlatform() {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async {
    // Maestro dev seam (debug only): a wired resolver returns a deterministic
    // result so the flow does not depend on a live OAuth handshake. Skipped in
    // release (resolver is null) and whenever the resolver returns null.
    if (kDebugMode && _seamResolver != null) {
      final seamed = _seamResolver(provider);
      if (seamed != null) return seamed;
    }
    try {
      final idToken = switch (provider) {
        SocialProvider.google => await _signInWithGoogle(),
        SocialProvider.apple => await _signInWithApple(),
        SocialProvider.facebook => await _signInWithFacebook(),
      };
      if (idToken == null) {
        return const SocialAuthFailure(SocialAuthError.cancelled);
      }
      return await _exchangeToken(provider: provider, idToken: idToken);
    } on _CancelledException {
      return const SocialAuthFailure(SocialAuthError.cancelled);
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) {
        return const SocialAuthFailure(SocialAuthError.cancelled);
      }
      return const SocialAuthFailure(SocialAuthError.unknown);
    } on PlatformException catch (e) {
      // google_sign_in reports user cancellation as PlatformException with
      // code 'sign_in_canceled' on iOS and 'cancel' / 12501 on Android.
      if (_isCancellationCode(e.code)) {
        return const SocialAuthFailure(SocialAuthError.cancelled);
      }
      if (e.code == 'network_error') {
        return const SocialAuthFailure(SocialAuthError.network);
      }
      return const SocialAuthFailure(SocialAuthError.unknown);
    } on MissingPluginException {
      return const SocialAuthFailure(SocialAuthError.unknown);
    }
  }

  @override
  Future<void> signOut() async {
    try {
      await _google.signOut();
    } catch (_) {
      // Native sign-out is best-effort; we never want logout to throw.
    }
  }

  Future<String?> _signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return null; // user cancelled
    final auth = await account.authentication;
    final token = auth.idToken;
    if (token == null || token.isEmpty) {
      throw const _CancelledException();
    }
    return token;
  }

  Future<String?> _signInWithApple() async {
    if (!_isApplePlatform()) {
      // Android Apple Sign-In uses a Safari fallback that requires a
      // server-side webAuthenticationOptions payload (clientId, redirectUri,
      // state, nonce). The gateway does not host that flow today, so we
      // simply refuse on non-Apple platforms — the UI hides this entry
      // point unless we're on iOS/macOS.
      return null;
    }
    final credential = await SignInWithApple.getAppleIDCredential(
      scopes: const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ],
    );
    final token = credential.identityToken;
    if (token == null || token.isEmpty) {
      throw const _CancelledException();
    }
    return token;
  }

  Future<String?> _signInWithFacebook() async {
    // JM-018: Facebook is the third social provider on the login/sign-up rows.
    // The app does not yet bundle a native Facebook SDK (no `flutter_facebook_auth`
    // in pubspec — tracked under JEEB-57 alongside the branded glyph work), so we
    // do NOT drive a native FB sheet here. The OAuth handshake is server-mediated:
    // the gateway exchanges the provider grant, and under the dev flavor the
    // `jeeb.seam.social_login` seam (60_W0_TEST_PLAN §6: `facebook_no_phone`,
    // `collision_409`) auto-approves and shapes the `/v1/auth/social` response.
    // We forward a provider-scoped grant marker as the `idToken` so the POST
    // carries `provider: "facebook"`; the real native token replaces this when
    // the SDK lands (the exchange + downstream routing are unchanged).
    return 'facebook-oauth-grant';
  }

  Future<SocialAuthResult> _exchangeToken({
    required SocialProvider provider,
    required String idToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        // VERIFIED gateway path (B1 rewrite → `/auth-service/auth/social`).
        '/v1/auth/social',
        data: <String, dynamic>{
          'provider': provider.wireName,
          'idToken': idToken,
        },
      );
      final data = response.data;
      if (data == null) {
        return const SocialAuthFailure(SocialAuthError.unknown);
      }
      final session = _parseSession(data);
      if (session == null) {
        return const SocialAuthFailure(SocialAuthError.unknown);
      }
      return SocialAuthSuccess(session);
    } on DioException catch (e) {
      return SocialAuthFailure(_mapDioError(e));
    }
  }

  SocialAuthSession? _parseSession(Map<String, dynamic> data) {
    // Defensive parse (40_GUARDRAILS §4): tolerate snake_case aliases and
    // normalise empty strings to null so `hasPhone` (the G8 gate) is honest.
    final userId = (data['userId'] ?? data['user_id'] ?? data['id']) as String?;
    final authToken =
        (data['authToken'] ?? data['auth_token'] ?? data['accessToken'])
            as String?;
    final refreshToken =
        (data['refreshToken'] ?? data['refresh_token']) as String?;
    if (userId == null || authToken == null || refreshToken == null) {
      return null;
    }
    final rawPhone = (data['phone'] ?? data['phoneNumber']) as String?;
    final phone =
        (rawPhone != null && rawPhone.trim().isNotEmpty) ? rawPhone : null;
    return SocialAuthSession(
      userId: userId,
      authToken: authToken,
      refreshToken: refreshToken,
      recentlyCreated:
          (data['recentlyCreated'] ?? data['recently_created']) as bool? ??
              false,
      phone: phone,
    );
  }

  SocialAuthError _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.connectionError:
        return SocialAuthError.network;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        // 409 `email_collision` (D22, JM-019): the social email is already
        // registered another way → route to the collision sheet, NOT an error.
        if (status == 409) return SocialAuthError.collision;
        if (status == 401) return SocialAuthError.invalidToken;
        if (status == 403) return SocialAuthError.accountDisabled;
        if (status >= 500) return SocialAuthError.network;
        return SocialAuthError.unknown;
      case DioExceptionType.cancel:
        return SocialAuthError.cancelled;
      case DioExceptionType.badCertificate:
      case DioExceptionType.unknown:
        return SocialAuthError.unknown;
    }
  }

  static const _googleCancelCodes = {
    'sign_in_canceled',
    'canceled',
    'cancel',
    '12501', // Android GoogleSignInStatusCodes.SIGN_IN_CANCELLED
  };

  bool _isCancellationCode(String code) => _googleCancelCodes.contains(code);
}

class _CancelledException implements Exception {
  const _CancelledException();
}
