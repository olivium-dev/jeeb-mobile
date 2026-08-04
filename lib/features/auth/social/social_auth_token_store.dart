import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../../core/network/auth_token_store.dart';
import 'social_auth_token.dart';

/// Secure persistence for the JWT bundle minted by jeeb-gateway after a
/// successful social sign-in. Backed by Keychain on iOS and
/// EncryptedSharedPreferences on Android.
abstract class SocialAuthTokenStore {
  Future<void> save(SocialAuthSession session);
  Future<SocialAuthSession?> read();
  Future<void> clear();
}

class SecureSocialAuthTokenStore implements SocialAuthTokenStore {
  SecureSocialAuthTokenStore({
    FlutterSecureStorage? storage,
    AuthTokenStore? authTokenStore,
  })  : _storage = storage ?? const FlutterSecureStorage(),
        _authTokenStore = authTokenStore ?? AuthTokenStore();

  final FlutterSecureStorage _storage;
  final AuthTokenStore _authTokenStore;

  static const _recentlyCreatedKey = 'jeeb.auth.recentlyCreated';

  @override
  Future<void> save(SocialAuthSession session) async {
    await _authTokenStore.save(
      accessToken: session.authToken,
      refreshToken: session.refreshToken,
      userId: session.userId,
    );
    await _storage.write(
      key: _recentlyCreatedKey,
      value: session.recentlyCreated ? '1' : '0',
    );
  }

  @override
  Future<SocialAuthSession?> read() async {
    final userId = await _authTokenStore.userId;
    final authToken = await _authTokenStore.accessToken;
    final refreshToken = await _authTokenStore.refreshToken;
    if (userId == null || authToken == null || refreshToken == null) {
      return null;
    }
    final recent = await _storage.read(key: _recentlyCreatedKey);
    return SocialAuthSession(
      userId: userId,
      authToken: authToken,
      refreshToken: refreshToken,
      recentlyCreated: recent == '1',
    );
  }

  @override
  Future<void> clear() async {
    await _authTokenStore.clear();
    await _storage.delete(key: _recentlyCreatedKey);
  }
}
