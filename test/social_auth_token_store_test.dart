import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token.dart';
import 'package:jeeb_mobile/features/auth/social/social_auth_token_store.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

class _MockSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  test(
    'social session is saved through the canonical auth token store',
    () async {
      final authTokenStore = _MockAuthTokenStore();
      final secureStorage = _MockSecureStorage();
      when(
        () => authTokenStore.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
        ),
      ).thenAnswer((_) async {});
      when(
        () => secureStorage.write(
          key: any(named: 'key'),
          value: any(named: 'value'),
        ),
      ).thenAnswer((_) async {});
      final store = SecureSocialAuthTokenStore(
        storage: secureStorage,
        authTokenStore: authTokenStore,
      );

      await store.save(
        const SocialAuthSession(
          userId: 'user-1',
          authToken: 'access-token',
          refreshToken: 'refresh-token',
          recentlyCreated: true,
        ),
      );

      verify(
        () => authTokenStore.save(
          accessToken: 'access-token',
          refreshToken: 'refresh-token',
          userId: 'user-1',
        ),
      ).called(1);
      verify(
        () => secureStorage.write(key: 'jeeb.auth.recentlyCreated', value: '1'),
      ).called(1);
    },
  );
}
