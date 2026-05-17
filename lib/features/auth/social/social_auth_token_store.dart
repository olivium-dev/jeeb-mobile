import 'package:flutter_secure_storage/flutter_secure_storage.dart';

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
  SecureSocialAuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              iOptions: IOSOptions(
                accessibility: KeychainAccessibility.first_unlock,
              ),
            );

  final FlutterSecureStorage _storage;

  static const _userIdKey = 'jeeb.auth.userId';
  static const _authTokenKey = 'jeeb.auth.authToken';
  static const _refreshTokenKey = 'jeeb.auth.refreshToken';
  static const _recentlyCreatedKey = 'jeeb.auth.recentlyCreated';

  @override
  Future<void> save(SocialAuthSession session) async {
    await _storage.write(key: _userIdKey, value: session.userId);
    await _storage.write(key: _authTokenKey, value: session.authToken);
    await _storage.write(key: _refreshTokenKey, value: session.refreshToken);
    await _storage.write(
      key: _recentlyCreatedKey,
      value: session.recentlyCreated ? '1' : '0',
    );
  }

  @override
  Future<SocialAuthSession?> read() async {
    final userId = await _storage.read(key: _userIdKey);
    final authToken = await _storage.read(key: _authTokenKey);
    final refreshToken = await _storage.read(key: _refreshTokenKey);
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
    await _storage.delete(key: _userIdKey);
    await _storage.delete(key: _authTokenKey);
    await _storage.delete(key: _refreshTokenKey);
    await _storage.delete(key: _recentlyCreatedKey);
  }
}
