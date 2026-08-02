import 'package:dio/dio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../core/session/firebase_identity_teardown.dart';
import '../domain/account_session_terminator.dart';

class DioAccountSessionTerminator implements AccountSessionTerminator {
  DioAccountSessionTerminator(
    this._dio,
    this._tokenStore, {
    Future<String?> Function()? deviceIdProvider,
    FirebaseIdentityTeardown? firebaseSignOut,
  })  : _deviceIdProvider = deviceIdProvider ?? _defaultDeviceIdProvider,
        _firebaseSignOut = firebaseSignOut ?? signOutFirebaseIdentity;

  final Dio _dio;
  final AuthTokenStore _tokenStore;

/// Ends the SECOND identity this app holds — see [signOutFirebaseIdentity]
  final FirebaseIdentityTeardown _firebaseSignOut;

  final Future<String?> Function() _deviceIdProvider;

  static const String _deviceIdPrefsKey = 'push.deviceId';

  static Future<String?> _defaultDeviceIdProvider() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(_deviceIdPrefsKey);
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> logout() async {
    await _revokeGatewaySession();
    await _unregisterPushDevice();
    await _clearLocalSession();
  }

  @override
  Future<void> deleteAccount() async {
    await _requestAccountDeletion();
    await _unregisterPushDevice();
    await _clearLocalSession();
  }

  Future<void> _revokeGatewaySession() async {
    try {
      final refreshToken = await _tokenStore.refreshToken;
      await _dio.post<void>(
        '/v1/auth/logout',
        data: <String, dynamic>{'refreshToken': ?refreshToken},
      );
    } catch (_) {
    }
  }

  Future<void> _unregisterPushDevice() async {
    try {
      final deviceId = await _deviceIdProvider();
      if (deviceId == null || deviceId.isEmpty) return;
      await _dio.delete<void>(
        '/api/PushNotification/device',
        data: <String, dynamic>{'deviceId': deviceId},
      );
    } catch (_) {
    }
  }

  Future<void> _requestAccountDeletion() async {
    try {
      final userId = await _tokenStore.userId;
      if (userId == null) return;
      await _dio.patch<void>(
        '/v1/users/$userId/status',
        data: const <String, dynamic>{'status': 'deleted'},
      );
    } catch (_) {
    }
  }

  Future<void> _clearLocalSession() async {
    try {
      await _tokenStore.clear();
    } catch (_) {
    }
    try {
      await _firebaseSignOut();
    } catch (_) {
    }
  }
}
