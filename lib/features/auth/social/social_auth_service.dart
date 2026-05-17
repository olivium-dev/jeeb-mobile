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
/// endpoint is `POST /api/auth/social` per the T-mobile-003 contract.
abstract class SocialAuthService {
  Future<SocialAuthResult> signIn(SocialProvider provider);

  /// Best-effort logout from the native SDKs. Does not clear the secure
  /// token store — call [SocialAuthTokenStore.clear] for that.
  Future<void> signOut();
}

/// Production implementation.
class DefaultSocialAuthService implements SocialAuthService {
  DefaultSocialAuthService({
    required Dio dio,
    GoogleSignIn? googleSignIn,
    bool Function()? isApplePlatform,
  })  : _dio = dio,
        _google = googleSignIn ?? GoogleSignIn(scopes: const ['email']),
        _isApplePlatform = isApplePlatform ?? _defaultIsApplePlatform;

  final Dio _dio;
  final GoogleSignIn _google;
  final bool Function() _isApplePlatform;

  static bool _defaultIsApplePlatform() {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async {
    try {
      final idToken = switch (provider) {
        SocialProvider.google => await _signInWithGoogle(),
        SocialProvider.apple => await _signInWithApple(),
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

  Future<SocialAuthResult> _exchangeToken({
    required SocialProvider provider,
    required String idToken,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/api/auth/social',
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
    final userId = data['userId'] as String?;
    final authToken = data['authToken'] as String?;
    final refreshToken = data['refreshToken'] as String?;
    if (userId == null || authToken == null || refreshToken == null) {
      return null;
    }
    return SocialAuthSession(
      userId: userId,
      authToken: authToken,
      refreshToken: refreshToken,
      recentlyCreated: data['recentlyCreated'] as bool? ?? false,
    );
  }

  SocialAuthError _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return SocialAuthError.network;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
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
