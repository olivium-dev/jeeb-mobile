import "dart:io" show Platform;

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

/// Registers this install's FCM token with jeeb-gateway so server-side
/// events (delivery updates, chat, KYC, ratings) can target the device.
///
/// The FCM transport mints a token but nothing forwards it to the backend on
/// its own — without this hop the `push-notification` service has no
/// `(device_id -> fcm_token)` row to send to. This closes that gap.
///
/// Wire contract (gateway BFF — no direct push-notification-service call):
///   POST /v1/devices/register
///     headers: Authorization: Bearer `<jwt>`   (attached by the shared
///              bearer interceptor on the gateway Dio — see resolveGatewayDio)
///     body: { "fcmToken": "`<token>`", "platform": "android|ios",
///             "deviceId": "`<stable-install-id>`" }
///     2xx -> registered
/// The gateway extracts the user_id from the JWT and resolves the push topic
/// from the caller's active role, then forwards to the push-notification
/// service. The mock backend rewrites this to `/push-notification/v1/devices/
/// register` (see MockGatewayClient._pathToServicePrefix '/v1/devices').
///
/// `deviceId` is a per-install id persisted in the platform keystore so it
/// survives app restarts (the backend keeps one live token per device, so a
/// stable id avoids orphaning rows on each launch).
///
/// PII: the FCM token is a device identifier — it is NEVER logged. Only the
/// HTTP status code (and exception type) is ever emitted, and only in debug.
class PushDeviceRegistrar {
  PushDeviceRegistrar({
    required Dio dio,
    FlutterSecureStorage? storage,
  })  : _dio = dio,
        _storage = storage ?? const FlutterSecureStorage();

  final Dio _dio;
  final FlutterSecureStorage _storage;

  static const String _deviceIdKey = "push.deviceId";
  static const String _registerPath = "/v1/devices/register";

  String? _lastRegisteredToken;

  /// Register (or refresh) [token] with the backend. Idempotent: a repeat
  /// call with an unchanged token is skipped. Best-effort — a failure here
  /// (not authenticated yet, transient network, Firebase not configured) never
  /// throws to the caller; it logs a status (never the token) and is retried on
  /// the next bootstrap / token-refresh.
  Future<void> register(String? token) async {
    if (token == null || token.isEmpty) return;
    if (token == _lastRegisteredToken) return;
    try {
      final deviceId = await _deviceId();
      final res = await _dio.post<dynamic>(
        _registerPath,
        data: <String, dynamic>{
          "fcmToken": token,
          "platform": _platform(),
          "deviceId": deviceId,
        },
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        _lastRegisteredToken = token;
        if (kDebugMode) {
          // NEVER log the token value (PII). Status code only.
          debugPrint("[push] device registered with gateway ($code)");
        }
      } else if (kDebugMode) {
        debugPrint("[push] device register non-2xx: $code");
      }
    } on DioException catch (e) {
      // 401 here just means the user is not authenticated yet — the token
      // will be re-registered on the next bootstrap after login. Never fatal,
      // and the token is never included in the log line.
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

  /// Wire value for the `platform` discriminator the push-notification service
  /// keys topic resolution on. `dart:io` is safe here — Jeeb ships iOS/Android
  /// only (no web target).
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
