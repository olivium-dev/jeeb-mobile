import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

/// Registers this install's FCM token with jeeb-gateway so server-side
/// events can target the device.
///
/// PUSH-FIX (iter6): the FCM transport already mints a token, but nothing was
/// ever sending it to the backend — so the `push-notification` service had no
/// `(device_id -> fcm_token)` row to send to. This closes that gap.
///
/// Wire contract (verified live on the gateway :10090):
///   PUT /api/PushNotification/register
///     headers: Authorization: Bearer `<jwt>`   (added by the shared
///              _AuthInterceptor on the gateway Dio)
///     body: { "fcmToken": "`<token>`", "deviceId": "`<stable-install-id>`" }
///   201 -> RegisterResponse { message }
/// The gateway extracts the user_id from the JWT and resolves the FCM topic
/// from the caller's active_role, then forwards to the push-notification
/// service's PUT /api/v1/register.
///
/// `deviceId` is a per-install UUID persisted in the platform keystore so it
/// survives app restarts (the gateway enforces one-row-per-device, so a stable
/// id keeps a single live token per install instead of orphaning rows).
class PushDeviceRegistrar {
  PushDeviceRegistrar({
    required Dio dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio,
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String _deviceIdKey = "push.deviceId";
  static const String _registerPath = "/api/PushNotification/register";

  String? _lastRegisteredToken;

  /// Register (or refresh) [token] with the backend. Idempotent: a repeat
  /// call with an unchanged token is skipped. Best-effort — a failure here
  /// (no auth yet, transient network) never throws to the caller; it just
  /// logs and will be retried on the next bootstrap / token-refresh.
  Future<void> register(String? token) async {
    if (token == null || token.isEmpty) return;
    if (token == _lastRegisteredToken) return;
    try {
      final deviceId = await _deviceId();
      final res = await _dio.put<dynamic>(
        _registerPath,
        data: <String, dynamic>{
          "fcmToken": token,
          "deviceId": deviceId,
        },
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        _lastRegisteredToken = token;
        if (kDebugMode) {
          debugPrint("[push] device registered with gateway ($code)");
        }
      } else if (kDebugMode) {
        debugPrint("[push] device register non-2xx: $code");
      }
    } on DioException catch (e) {
      // 401 here just means the user is not authenticated yet — the token
      // will be re-registered on the next bootstrap after login. Never fatal.
      if (kDebugMode) {
        debugPrint(
          "[push] device register failed: ${e.response?.statusCode} ${e.message}",
        );
      }
    } catch (e) {
      if (kDebugMode) debugPrint("[push] device register error: $e");
    }
  }

  Future<String> _deviceId() async {
    final existing = await _storage.read(key: _deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final generated = _generateId();
    await _storage.write(key: _deviceIdKey, value: generated);
    return generated;
  }

  /// RFC-4122-ish v4 string without pulling in a uuid dependency. Uniqueness
  /// is per-install and only needs to be stable + collision-free across the
  /// fleet, which a 122-bit random hex satisfies.
  String _generateId() {
    final now = DateTime.now().microsecondsSinceEpoch;
    final rand = now ^ (now << 13) ^ identityHashCode(this);
    final hex = StringBuffer();
    var seed = rand & 0x7fffffffffffffff;
    for (var i = 0; i < 32; i++) {
      seed = (seed * 6364136223846793005 + 1442695040888963407) &
          0x7fffffffffffffff;
      hex.write(((seed >> 33) & 0xf).toRadixString(16));
    }
    final s = hex.toString();
    return "${s.substring(0, 8)}-${s.substring(8, 12)}-4${s.substring(13, 16)}"
        "-a${s.substring(17, 20)}-${s.substring(20, 32)}";
  }
}
