import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import 'package:jeeb_mobile/features/auth/social/social_auth_error.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_service.dart';
import 'package:jeeb_mobile/features/auth/social/social_provider.dart';

class _MockGoogleSignIn extends Mock implements GoogleSignIn {}

class _MockGoogleSignInAccount extends Mock implements GoogleSignInAccount {}

class _MockGoogleSignInAuthentication extends Mock
    implements GoogleSignInAuthentication {}

class _MockFirebaseAuth extends Mock implements FirebaseAuth {}

class _MockUserCredential extends Mock implements UserCredential {}

class _MockUser extends Mock implements User {}

class _FakeAuthCredential extends Fake implements AuthCredential {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeAuthCredential());
  });

  test(
    'Google login exchanges through Firebase and sends the shared contract',
    () async {
      final google = _MockGoogleSignIn();
      final googleAccount = _MockGoogleSignInAccount();
      final googleAuthentication = _MockGoogleSignInAuthentication();
      final firebaseAuth = _MockFirebaseAuth();
      final userCredential = _MockUserCredential();
      final user = _MockUser();
      var firebaseInitializeCalls = 0;
      RequestOptions? capturedRequest;

      when(google.signIn).thenAnswer((_) async => googleAccount);
      when(
        () => googleAccount.authentication,
      ).thenAnswer((_) async => googleAuthentication);
      when(() => googleAuthentication.idToken).thenReturn('google-id-token');
      when(
        () => googleAuthentication.accessToken,
      ).thenReturn('google-access-token');
      when(
        () => firebaseAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => userCredential);
      when(() => userCredential.user).thenReturn(user);
      when(() => user.uid).thenReturn('firebase-uid');
      when(user.getIdToken).thenAnswer((_) async => 'firebase-id-token');

      final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const <String, dynamic>{
                  'userId': 'user-1',
                  'authToken': 'gateway-auth-token',
                  'refreshToken': 'gateway-refresh-token',
                  'recentlyCreated': false,
                },
              ),
            );
          },
        ),
      );
      final service = DefaultSocialAuthService(
        dio: dio,
        googleSignIn: google,
        firebaseAuth: firebaseAuth,
        firebaseInitializer: () async {
          firebaseInitializeCalls++;
        },
      );

      final result = await service.signIn(SocialProvider.google);

      expect(result, isA<SocialAuthSuccess>());
      expect(firebaseInitializeCalls, 1);
      expect(capturedRequest?.path, '/v1/auth/social');
      expect(capturedRequest?.data, <String, dynamic>{
        'socialId': 'firebase-uid',
        'socialToken': 'firebase-id-token',
        'socialPlatform': 'google',
        'provider': 'google',
        'idToken': 'firebase-id-token',
      });
      final firebaseCredential =
          verify(
                () => firebaseAuth.signInWithCredential(captureAny()),
              ).captured.single
              as OAuthCredential;
      expect(firebaseCredential.providerId, 'google.com');
    },
  );

  test(
    'Apple login exchanges through Firebase with a nonce and sends its ID token',
    () async {
      final google = _MockGoogleSignIn();
      final firebaseAuth = _MockFirebaseAuth();
      final userCredential = _MockUserCredential();
      final user = _MockUser();
      var firebaseInitializeCalls = 0;
      String? capturedAppleNonce;
      List<AppleIDAuthorizationScopes>? capturedScopes;
      RequestOptions? capturedRequest;

      when(
        () => firebaseAuth.signInWithCredential(any()),
      ).thenAnswer((_) async => userCredential);
      when(() => userCredential.user).thenReturn(user);
      when(() => user.uid).thenReturn('firebase-apple-uid');
      when(user.getIdToken).thenAnswer((_) async => 'firebase-apple-id-token');

      final dio = Dio(BaseOptions(baseUrl: 'http://gateway.test'));
      dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            capturedRequest = options;
            handler.resolve(
              Response<Map<String, dynamic>>(
                requestOptions: options,
                statusCode: 200,
                data: const <String, dynamic>{
                  'userId': 'user-apple',
                  'authToken': 'gateway-auth-token',
                  'refreshToken': 'gateway-refresh-token',
                  'recentlyCreated': true,
                },
              ),
            );
          },
        ),
      );
      final service = DefaultSocialAuthService(
        dio: dio,
        googleSignIn: google,
        firebaseAuth: firebaseAuth,
        firebaseInitializer: () async {
          firebaseInitializeCalls++;
        },
        isApplePlatform: () => true,
        appleNonceGenerator: () => 'raw-apple-nonce',
        appleCredentialRequester: ({required scopes, required nonce}) async {
          capturedScopes = scopes;
          capturedAppleNonce = nonce;
          return const AuthorizationCredentialAppleID(
            userIdentifier: 'apple-user-id',
            givenName: 'Jeeb',
            familyName: 'Tester',
            authorizationCode: 'apple-authorization-code',
            email: 'tester@example.com',
            identityToken: 'apple-id-token',
            state: null,
          );
        },
      );

      final result = await service.signIn(SocialProvider.apple);

      expect(result, isA<SocialAuthSuccess>());
      expect(firebaseInitializeCalls, 1);
      expect(capturedScopes, const [
        AppleIDAuthorizationScopes.email,
        AppleIDAuthorizationScopes.fullName,
      ]);
      expect(
        capturedAppleNonce,
        sha256.convert(utf8.encode('raw-apple-nonce')).toString(),
      );
      expect(capturedRequest?.path, '/v1/auth/social');
      expect(capturedRequest?.data, <String, dynamic>{
        'socialId': 'firebase-apple-uid',
        'socialToken': 'firebase-apple-id-token',
        'socialPlatform': 'apple',
        'provider': 'apple',
        'idToken': 'firebase-apple-id-token',
      });
      final firebaseCredential =
          verify(
                () => firebaseAuth.signInWithCredential(captureAny()),
              ).captured.single
              as OAuthCredential;
      expect(firebaseCredential.providerId, 'apple.com');
      expect(firebaseCredential.idToken, 'apple-id-token');
      expect(firebaseCredential.rawNonce, 'raw-apple-nonce');
      expect(firebaseCredential.appleFullPersonName?.givenName, 'Jeeb');
      expect(firebaseCredential.appleFullPersonName?.familyName, 'Tester');
    },
  );

  // AUTH-04: the Facebook branch fabricated `('facebook','facebook-oauth-grant')`
  // and handed it to the gateway as a real credential. Until a real SDK lands,
  // the branch resolves as cancelled and issues NO exchange.
  test('the Facebook path never fabricates a credential', () async {
    RequestOptions? captured;
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://gw.test'));
    dio.httpClientAdapter = _RecordingAdapter((RequestOptions options) {
      captured = options;
      return ResponseBody.fromString('{}', 200);
    });
    final service = DefaultSocialAuthService(dio: dio);

    final SocialAuthResult result =
        await service.signIn(SocialProvider.facebook);

    expect(result, isA<SocialAuthFailure>());
    expect((result as SocialAuthFailure).error, SocialAuthError.cancelled);
    expect(captured, isNull, reason: 'no token exchange may be attempted');
  });
}

/// Records the one request a fabricated credential would have produced.
class _RecordingAdapter implements HttpClientAdapter {
  _RecordingAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      _respond(options);

  @override
  void close({bool force = false}) {}
}
