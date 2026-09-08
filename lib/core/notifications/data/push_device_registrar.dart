import "dart:async" show unawaited;
import "dart:io" show Platform;
import "dart:math" show Random;

import "package:dio/dio.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";
import "package:shared_preferences/shared_preferences.dart";

import "../../diagnostics/diag.dart";
import "../../network/app_failure.dart";
import "../../network/auth_token_store.dart";
import "shared_prefs_local_push_inbox.dart";

class PushDeviceRegistrar {
  PushDeviceRegistrar({
    required Dio dio,
    FlutterSecureStorage? storage,
    AuthTokenStore? authTokenStore,
  })  : _dio = dio,
        _storage = storage ?? const FlutterSecureStorage(),
        _authTokenStore = authTokenStore ?? AuthTokenStore();

  final Dio _dio;
  final FlutterSecureStorage _storage;
  final AuthTokenStore _authTokenStore;

  static const String _deviceIdKey = "push.deviceId";

  static const String _registerPath = "/api/PushNotification/register";

  String? _lastRegisteredKey;

  Future<void> register(String? token) async {
    final userId = await _currentUserId();
    // F7: stamp before the token guard so the inbox scope follows the session
    // even with no FCM token; unawaited — registration must not wait on prefs.
    unawaited(_stampInboxOwner(userId));
    if (token == null || token.isEmpty) return;
    final key = "${userId ?? ''}::$token";
    if (key == _lastRegisteredKey) return;
    try {
      final deviceId = await _deviceId();
      final res = await _dio.put<dynamic>(
        _registerPath,
        data: <String, dynamic>{
          "fcmToken": token,
          "platform": _platform(),
          "deviceId": deviceId,
        },
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        _lastRegisteredKey = key;
      }
      Diag.event("push_device_register", <String, Object?>{
        "status": code,
        "ok": code >= 200 && code < 300,
      });
    } catch (error) {
      // NET-31: silent in release before; a device that never registers is
      // exactly the outage class this needs to be visible for.
      Diag.event("push_device_register_failed", <String, Object?>{
        "kind": AppFailure.of(error).kind.name,
      });
    }
  }

  Future<void> _stampInboxOwner(String? userId) async {
    try {
      await SharedPrefsLocalPushInbox.stampOwner(
        await SharedPreferences.getInstance(),
        userId,
      );
    } catch (error) {
      Diag.event("push_inbox_owner_stamp_failed", <String, Object?>{
        "kind": AppFailure.of(error).kind.name,
      });
    }
  }

  Future<String?> _currentUserId() async {
    try {
      final id = await _authTokenStore.userId;
      return (id != null && id.isNotEmpty) ? id : null;
    } catch (_) {
      return null;
    }
  }

  String _platform() {
    if (Platform.isIOS) return "ios";
    if (Platform.isAndroid) return "android";
    return "unknown";
  }

  Future<String> _deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateId();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  String _generateId() {
    // Was a hand-rolled 64-bit LCG seeded from `DateTime.now()` xor
    Random random;
    try {
      random = Random.secure();
    } on UnsupportedError {
      random = Random();
    }
    final hex = StringBuffer();
    for (var i = 0; i < 32; i++) {
      hex.write(random.nextInt(16).toRadixString(16));
    }
    final s = hex.toString();
    return "${s.substring(0, 8)}-${s.substring(8, 12)}-4${s.substring(13, 16)}"
        "-a${s.substring(17, 20)}-${s.substring(20, 32)}";
  }
}
