import "dart:io" show Platform;
import "dart:math" show Random;

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../../network/auth_token_store.dart";

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
    if (token == null || token.isEmpty) return;
    final userId = await _currentUserId();
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
        if (kDebugMode) {
          debugPrint("[push] device registered with gateway ($code)");
        }
      } else if (kDebugMode) {
        debugPrint("[push] device register non-2xx: $code");
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint(
          "[push] device register failed: ${e.response?.statusCode} ${e.type}",
        );
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint("[push] device register error: ${e.runtimeType}");
      }
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
    // `identityHashCode`. That had two problems: the seed carried very little
    // entropy for a value that must be "collision-free across the fleet", and
    // the 64-bit literals/operators cannot be compiled to JavaScript at all —
    // which broke `flutter widget-preview start`, whose scaffold only targets
    // the web device.
    //
    // `Random.secure()` is a platform CSPRNG, so this is strictly stronger for
    // the documented contract while producing the same 32-hex-digit shape.
    // The fallback matters because `Random.secure()` throws on platforms with
    // no secure source; a weak id still beats a crash on first launch.
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
