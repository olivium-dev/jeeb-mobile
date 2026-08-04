import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:mocktail/mocktail.dart';

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
}
