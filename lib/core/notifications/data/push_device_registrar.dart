import "dart:io" show Platform;
import "dart:math" show Random;

import "package:dio/dio.dart";
import "package:flutter/foundation.dart";
import "package:flutter_secure_storage/flutter_secure_storage.dart";

import "../../network/auth_token_store.dart";

/// Registers this install's FCM token with jeeb-gateway so server-side
/// events (delivery updates, chat, KYC, ratings) can target the device.
///
/// The FCM transport mints a token but nothing forwards it to the backend on
/// its own — without this hop the `push-notification` service has no
/// `(device_id -> fcm_token)` row to send to. This closes that gap.
///
/// Wire contract (gateway BFF — no direct push-notification-service call):
///   PUT /api/PushNotification/register
///     headers: Authorization: Bearer `<jwt>`   (attached by the shared
///              bearer interceptor on the gateway Dio — see resolveGatewayDio)
///     body: { "fcmToken": "`<token>`", "platform": "android|ios",
///             "deviceId": "`<stable-install-id>`" }
///     2xx -> registered
/// The gateway extracts the user_id from the JWT and resolves the push topic
/// from the caller's active role, then forwards to the push-notification
/// service. This is STILL a gateway BFF hop (the controller is
/// `PushNotificationController.RegisterDevice`, `[Authorize]`, deriving the
/// owner server-side from the bearer) — the app never calls the
/// push-notification service directly, so the no-inter-service-coupling law
/// holds.
///
/// ROUTE-DEBT (sprint-05 push-proof §1f): the app PREVIOUSLY called
/// `POST /v1/devices/register`, which 404s on the live gateway (:10090) — so
/// the FCM token was never stored and every push was a `NoDevices` no-op (the
/// root cause push never worked on device). The route that actually answers is
/// the existing `PUT /api/PushNotification/register` controller, so we point at
/// it to unblock real push NOW. FOLLOW-UP for the gateway team: expose a
/// versioned `PUT /v1/devices/register` BFF alias (same controller, same
/// bearer-derived identity) so the mobile contract matches the rest of the
/// `/v1/...` gateway surface and we don't pin the app to the `/api/[controller]`
/// MVC default route. Verb is PUT (not POST) — the controller is `[HttpPut]`.
///
/// `deviceId` is a per-install id persisted in the platform keystore so it
/// survives app restarts (the backend keeps one live token per device, so a
/// stable id avoids orphaning rows on each launch).
///
/// IDENTITY (S0-PUSH-03 / S0-PUSH-04 — "keyed by the real UUID, kill the
/// split-token-store"): the body carries NO userId — the gateway derives the
/// owner SERVER-SIDE from the bearer JWT, so the token always lands under the
/// authenticated session UUID, never a mock/hardcoded id. But the dedup that
/// makes [register] idempotent must therefore be keyed by `(sessionUserId,
/// token)`, NOT by the token alone. Two live-run defects this fixes:
///   1. The FIRST register attempt on a fresh login runs BEFORE the OTP/super
///      -login lands a bearer (the cold-start bootstrap fires pre-auth) — that
///      attempt 401s under a null identity and is (correctly) not cached, but
///      once the SAME token is re-offered post-auth the identity flips
///      null -> real-UUID, so the key changes and the token is finally
///      registered under the authenticated UUID instead of being skipped as
///      "already sent".
///   2. A second user signing in on the same install reuses the same stable
///      FCM token; keying by token alone would SKIP their registration, so
///      pushes for user B would keep targeting user A's server-side row (the
///      split-token-store trap). Keying by `(userId, token)` re-registers the
///      token under B.
/// The session UUID is read from [AuthTokenStore] (the SAME keystore the bearer
/// interceptor reads), never a `SessionSeamBootstrap` constant.
///
/// PII: the FCM token is a device identifier — it is NEVER logged. Only the
/// HTTP status code (and exception type) is ever emitted, and only in debug.
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

  /// Live gateway BFF route for device registration. PUT (the controller is
  /// `[HttpPut("register")]` under `[Route("api/[controller]")]`). See the
  /// ROUTE-DEBT note above: a `/v1/devices/register` alias is the preferred
  /// long-term contract once the gateway team adds it.
  static const String _registerPath = "/api/PushNotification/register";

  /// The `(sessionUserId, token)` pair last confirmed (2xx) with the gateway.
  /// Keyed by identity so a login as a different user — or the first
  /// authenticated offer of a token whose pre-auth attempt 401'd — is never
  /// skipped as a duplicate (S0-PUSH-03).
  String? _lastRegisteredKey;

  /// Register (or refresh) [token] with the backend. Idempotent PER IDENTITY: a
  /// repeat call with the same `(sessionUserId, token)` pair is skipped, but a
  /// change in EITHER the token (rotation) or the authenticated user (login /
  /// account switch) re-registers. Best-effort — a failure here (not
  /// authenticated yet, transient network, Firebase not configured) never
  /// throws to the caller; it logs a status (never the token) and is retried on
  /// the next bootstrap / token-refresh / login.
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
          // NEVER log the token value or the userId (PII). Status code only.
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

  /// The authenticated session UUID this registration is keyed against, read
  /// from the SAME [AuthTokenStore] the bearer interceptor reads. Returns
  /// `null` when the user is not authenticated yet (pre-login bootstrap) or the
  /// keystore is unavailable (e.g. the pure-Dart test VM) — a null identity is
  /// a valid dedup key and is intentionally distinct from any real UUID, so the
  /// first post-login offer of the same token re-registers it under the bearer.
  Future<String?> _currentUserId() async {
    try {
      final id = await _authTokenStore.userId;
      return (id != null && id.isNotEmpty) ? id : null;
    } catch (_) {
      // No keystore channel (test VM) / read failure -> treat as anonymous.
      return null;
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
