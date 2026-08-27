import 'dart:io' show Platform;

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../../../core/monitoring/crash_reporter.dart';
import 'social_auth_error.dart';
import 'social_auth_token.dart';
import 'social_provider.dart';

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

abstract class SocialAuthService {
  Future<SocialAuthResult> signIn(SocialProvider provider);

  Future<void> signOut();
}

typedef SocialAuthSeamResolver = SocialAuthResult? Function(
  SocialProvider provider,
);

class DefaultSocialAuthService implements SocialAuthService {
  DefaultSocialAuthService({
    required Dio dio,
    GoogleSignIn? googleSignIn,
    FirebaseAuth? firebaseAuth,
    Future<void> Function()? firebaseInitializer,
    bool Function()? isApplePlatform,
    SocialAuthSeamResolver? seamResolver,
  })  : _dio = dio,
        _google = googleSignIn ?? GoogleSignIn(scopes: const ['email']),
        _firebaseAuth = firebaseAuth,
        _firebaseInitializer =
            firebaseInitializer ?? _defaultFirebaseInitializer,
        _isApplePlatform = isApplePlatform ?? _defaultIsApplePlatform,
        _seamResolver = seamResolver;

  final Dio _dio;
  final GoogleSignIn _google;
  final FirebaseAuth? _firebaseAuth;
  final Future<void> Function() _firebaseInitializer;
  final bool Function() _isApplePlatform;

  final SocialAuthSeamResolver? _seamResolver;

  static bool _defaultIsApplePlatform() {
    if (kIsWeb) return false;
    return Platform.isIOS || Platform.isMacOS;
  }

  @override
  Future<SocialAuthResult> signIn(SocialProvider provider) async {
    if (kDebugMode && _seamResolver != null) {
      final seamed = _seamResolver(provider);
      if (seamed != null) return seamed;
    }
    try {
      final credential = switch (provider) {
        SocialProvider.google => await _signInWithGoogle(),
        SocialProvider.apple => await _signInWithApple(),
        SocialProvider.facebook => await _signInWithFacebook(),
      };
      if (credential == null) {
        return const SocialAuthFailure(SocialAuthError.cancelled);
      }
      return await _exchangeToken(provider: provider, credential: credential);
    } on _InvalidTokenException {
      return const SocialAuthFailure(SocialAuthError.invalidToken);
    } on SignInWithAppleAuthorizationException catch (e) {
      switch (e.code) {
        case AuthorizationErrorCode.canceled:
          return const SocialAuthFailure(SocialAuthError.cancelled);
        case AuthorizationErrorCode.failed:
          CrashReporter.log(
            '[apple-signin] authorization failed: '
            'code=${e.code} message=${e.message}',
          );
          return const SocialAuthFailure(SocialAuthError.unknown);
        case AuthorizationErrorCode.invalidResponse:
          CrashReporter.log(
            '[apple-signin] authorization failed: '
            'code=${e.code} message=${e.message}',
          );
          return const SocialAuthFailure(SocialAuthError.unknown);
        case AuthorizationErrorCode.notHandled:
          CrashReporter.log(
            '[apple-signin] authorization failed: '
            'code=${e.code} message=${e.message}',
          );
          return const SocialAuthFailure(SocialAuthError.unknown);
        case AuthorizationErrorCode.notInteractive:
          CrashReporter.log(
            '[apple-signin] authorization failed: '
            'code=${e.code} message=${e.message}',
          );
          return const SocialAuthFailure(SocialAuthError.unknown);
        case AuthorizationErrorCode.unknown:
          CrashReporter.log(
            '[apple-signin] authorization failed: '
            'code=${e.code} message=${e.message}',
          );
          return const SocialAuthFailure(SocialAuthError.unknown);
      }
    } on FirebaseAuthException catch (e) {
      return SocialAuthFailure(_mapFirebaseAuthError(e));
    } on FirebaseException {
      return const SocialAuthFailure(SocialAuthError.unknown);
    } on PlatformException catch (e) {
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
    }
  }

  Future<_SocialCredential?> _signInWithGoogle() async {
    final account = await _google.signIn();
    if (account == null) return null; // user cancelled
    final auth = await account.authentication;
    final googleIdToken = auth.idToken;
    if (googleIdToken == null || googleIdToken.isEmpty) {
      throw const _InvalidTokenException();
    }

    await _firebaseInitializer();
    final googleCredential = GoogleAuthProvider.credential(
      accessToken: auth.accessToken,
      idToken: googleIdToken,
    );
    final firebaseCredential = await (_firebaseAuth ?? FirebaseAuth.instance)
        .signInWithCredential(googleCredential);
    final user = firebaseCredential.user;
    if (user == null) throw const _InvalidTokenException();
    final firebaseIdToken = await user.getIdToken();
    if (firebaseIdToken == null || firebaseIdToken.isEmpty) {
      throw const _InvalidTokenException();
    }
    return _SocialCredential(socialId: user.uid, socialToken: firebaseIdToken);
  }

  Future<_SocialCredential?> _signInWithApple() async {
    if (!_isApplePlatform()) {
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
      throw const _InvalidTokenException();
    }
    return _SocialCredential(
      socialId: credential.userIdentifier ?? 'apple',
      socialToken: token,
    );
  }

  Future<_SocialCredential?> _signInWithFacebook() async {
    return const _SocialCredential(
      socialId: 'facebook',
      socialToken: 'facebook-oauth-grant',
    );
  }

  Future<SocialAuthResult> _exchangeToken({
    required SocialProvider provider,
    required _SocialCredential credential,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/auth/social',
        data: <String, dynamic>{
          'socialId': credential.socialId,
          'socialToken': credential.socialToken,
          'socialPlatform': provider.wireName,
          'provider': provider.wireName,
          'idToken': credential.socialToken,
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
      case DioExceptionType.connectionError:
        return SocialAuthError.network;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 409) return SocialAuthError.collision;
        if (status == 401) return SocialAuthError.invalidToken;
        if (status == 403) return SocialAuthError.accountDisabled;
        if (status >= 500) return SocialAuthError.network;
        return SocialAuthError.unknown;
      case DioExceptionType.cancel:
        return SocialAuthError.cancelled;
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return SocialAuthError.unknown;
    }
  }

  SocialAuthError _mapFirebaseAuthError(FirebaseAuthException e) {
    switch (e.code) {
      case 'network-request-failed':
        return SocialAuthError.network;
      case 'user-disabled':
        return SocialAuthError.accountDisabled;
      case 'account-exists-with-different-credential':
      case 'credential-already-in-use':
      case 'email-already-in-use':
        return SocialAuthError.collision;
      case 'invalid-credential':
      case 'invalid-user-token':
      case 'user-token-expired':
        return SocialAuthError.invalidToken;
      default:
        return SocialAuthError.unknown;
    }
  }

  static Future<void> _defaultFirebaseInitializer() async {
    if (Firebase.apps.isNotEmpty) return;
    try {
      await Firebase.initializeApp();
    } on FirebaseException catch (e) {
      if (e.code == 'duplicate-app') return;
      rethrow;
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

class _InvalidTokenException implements Exception {
  const _InvalidTokenException();
}

class _SocialCredential {
  const _SocialCredential({required this.socialId, required this.socialToken});

  final String socialId;
  final String socialToken;
}
