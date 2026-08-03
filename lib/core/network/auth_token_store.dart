import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class AuthTokenStore {
  AuthTokenStore({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _storage;

  static const _accessKey = 'auth.accessToken';
  static const _refreshKey = 'auth.refreshToken';
  static const _userIdKey = 'auth.userId';

  Future<String?> get accessToken => _storage.read(key: _accessKey);
  Future<String?> get refreshToken => _storage.read(key: _refreshKey);
  Future<String?> get userId => _storage.read(key: _userIdKey);

  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {
    await _storage.write(key: _accessKey, value: accessToken);
    await _storage.write(key: _refreshKey, value: refreshToken);
    if (userId != null) {
      await _storage.write(key: _userIdKey, value: userId);
    }
  }

  Future<void> clear() async {
    await _storage.delete(key: _accessKey);
    await _storage.delete(key: _refreshKey);
    await _storage.delete(key: _userIdKey);
  }

  Future<bool> get hasToken async => (await accessToken) != null;
}
