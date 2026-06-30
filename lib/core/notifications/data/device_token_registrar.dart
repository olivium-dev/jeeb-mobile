import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../network/auth_token_store.dart';
import 'push_transport.dart';

/// Registers this install's FCM registration token with the push-notification
/// service (via the gateway) so server-side notifications — chat, delivery,
/// KYC, ratings — can target this device.
///
/// Contract (source-verified against JeebGateway PushNotificationController):
/// `PUT /api/PushNotification/register` on the gateway
/// (`http://192.168.2.39:10090` in dev), body `{ fcmToken, deviceId }`, success
/// **201**. The owning userId is resolved server-side from the JWT (`sid`/`sub`)
/// — it is NOT in the body — so the shared [Dio] (`sl<Dio>()`) must carry the
/// `Authorization: Bearer <jwt>` header (its auth interceptor does). The
/// endpoint also requires the `notification.prefs.self` capability claim.
///
/// Lifecycle: construct once after the real push transport is built, call
/// [start]. Because the FCM token is available before the user logs in but the
/// registration must be attributed to a logged-in user, [start] polls
/// [AuthTokenStore] on a bounded schedule until a `userId` is present (super-
/// login / OTP / biometric all persist it), fires the register once, and then
/// re-registers on every FCM token rotation.
///
/// Fail-safe: any transport/HTTP failure is swallowed and logged — push
/// registration must never crash or block the app. The status (never the token)
/// is logged in debug so a QA run can confirm a 2xx on the wire.
class DeviceTokenRegistrar {
  DeviceTokenRegistrar({
    required Dio dio,
    required AuthTokenStore tokenStore,
    required PushTransport transport,
    required SharedPreferences prefs,
    Duration retryInterval = const Duration(seconds: 3),
    int maxAttempts = 40,
  })  : _dio = dio,
        _tokenStore = tokenStore,
        _transport = transport,
        _prefs = prefs,
        _retryInterval = retryInterval,
        _maxAttempts = maxAttempts;

  final Dio _dio;
  final AuthTokenStore _tokenStore;
  final PushTransport _transport;
  final SharedPreferences _prefs;
  final Duration _retryInterval;
  final int _maxAttempts;

  StreamSubscription<String>? _refreshSub;
  Timer? _retryTimer;
  String? _lastToken;
  bool _registered = false;
  bool _disposed = false;

  /// Raw gateway contract path; [Dio]'s rewrite interceptor leaves it unchanged
  /// in live-gateway mode (the device/CI default).
  static const String _registerPath = '/api/PushNotification/register';

  /// SharedPreferences key for the stable per-install device id.
  static const String _deviceIdKey = 'push.deviceId';

  Future<void> start() async {
    // Re-register on rotation (reinstall, restore-from-backup, etc.).
    _refreshSub = _transport.onTokenRefresh.listen((fresh) {
      _lastToken = fresh;
      _registered = false;
      unawaited(_register(reason: 'rotation'));
    });

    try {
      _lastToken = await _transport.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('[push][register] getToken failed: $e');
    }
    _attempt(0);
  }

  /// Poll until a logged-in userId exists, then register exactly once.
  void _attempt(int n) {
    if (_disposed || _registered) return;
    unawaited(() async {
      final userId = await _safeUserId();
      if (userId != null && userId.isNotEmpty) {
        await _register(reason: 'login', userId: userId);
        return;
      }
      if (n + 1 >= _maxAttempts) {
        if (kDebugMode) {
          debugPrint('[push][register] gave up after $_maxAttempts attempts '
              '(no userId — user never logged in)');
        }
        return;
      }
      _retryTimer = Timer(_retryInterval, () => _attempt(n + 1));
    }());
  }

  Future<void> _register({required String reason, String? userId}) async {
    if (_disposed) return;
    final token = _lastToken;
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        debugPrint('[push][register] skip ($reason): no FCM token yet');
      }
      return;
    }
    // userId is resolved server-side from the JWT; we only gate on having a
    // session (a userId present) so we don't register before login.
    final uid = userId ?? await _safeUserId();
    if (uid == null || uid.isEmpty) {
      if (kDebugMode) {
        debugPrint('[push][register] skip ($reason): no session yet');
      }
      return;
    }
    try {
      // NOTE (auth header): the shared Dio LogInterceptor prints request
      // bodies in debug — which would expose the FCM token. We send the token
      // in the body per contract; QA must filter logcat on the `[push]`
      // status lines below (which never contain the token), not the Dio body.
      final res = await _dio.put<dynamic>(
        _registerPath,
        data: <String, dynamic>{
          'fcmToken': token,
          'deviceId': _deviceId(),
        },
      );
      final code = res.statusCode ?? 0;
      if (code >= 200 && code < 300) {
        _registered = true;
        _retryTimer?.cancel();
      }
      if (kDebugMode) {
        // NEVER log the token — only the wire status so QA can confirm 201.
        debugPrint('[push][register] ($reason) '
            'PUT $_registerPath -> $code');
      }
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[push][register] FAILED ($reason) '
            'PUT $_registerPath -> ${e.response?.statusCode} '
            'body=${e.response?.data}');
      }
    } catch (e) {
      if (kDebugMode) debugPrint('[push][register] FAILED ($reason): $e');
    }
  }

  /// Stable per-install device id. Generated once (128-bit secure random hex)
  /// and persisted, so the server can key/dedupe a device row across launches
  /// and token rotations.
  String _deviceId() {
    final existing = _prefs.getString(_deviceIdKey);
    if (existing != null && existing.isNotEmpty) return existing;
    final r = Random.secure();
    final id = List<int>.generate(16, (_) => r.nextInt(256))
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    _prefs.setString(_deviceIdKey, id);
    return id;
  }

  Future<String?> _safeUserId() async {
    try {
      return await _tokenStore.userId;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _retryTimer?.cancel();
    await _refreshSub?.cancel();
  }
}
