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

  /// The `(sessionUserId, token)` pair last confirmed (2xx) with the gateway.
  ///
  /// JEBV4-159 root-cause fix: this REPLACES the old one-shot `bool _registered`
  /// latch. That latch flipped `true` on the first successful register and then
  /// permanently short-circuited [notifyLogin] and [_register] for the LIFE OF
  /// THE PROCESS — so after a sign-out+sign-in, a super-login account switch, or
  /// a role switch (all of which re-emit `authenticated` on the same live
  /// [DeviceTokenRegistrar] instance), the NEW user was never registered and the
  /// push-notification service resolved them to zero device tokens (targeted
  /// pushes silently no-op'd). Keying the dedup by `(userId, token)` instead
  /// means a change in EITHER the authenticated user (login / account switch) or
  /// the token (rotation) re-registers, while a duplicate `authenticated`
  /// emission for the SAME identity is still skipped. `null` = nothing confirmed
  /// yet (also the reset value after sign-out — see [notifySignedOut]).
  String? _lastRegisteredKey;
  bool _disposed = false;

  /// Dedup key for [token] under the current authenticated [userId]. A null
  /// userId (pre-login) and any distinct user both produce distinct keys, so the
  /// first post-login offer of a token — and every later account switch —
  /// re-registers rather than being skipped as a duplicate.
  static String _key(String? userId, String token) => '${userId ?? ''}::$token';

  /// Raw gateway contract path; [Dio]'s rewrite interceptor leaves it unchanged
  /// in live-gateway mode (the device/CI default).
  static const String _registerPath = '/api/PushNotification/register';

  /// SharedPreferences key for the stable per-install device id.
  static const String _deviceIdKey = 'push.deviceId';

  Future<void> start() async {
    // Re-register on rotation (reinstall, restore-from-backup, etc.). The new
    // token yields a different `(userId, token)` dedup key, so [_register]
    // re-fires without any explicit latch reset.
    _refreshSub = _transport.onTokenRefresh.listen((fresh) {
      _lastToken = fresh;
      unawaited(_register(reason: 'rotation'));
    });

    try {
      _lastToken = await _transport.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('[push][register] getToken failed: $e');
    }
    _attempt(0);
  }

  /// Every-login trigger. [JeebApp] calls this on EVERY session transition into
  /// `authenticated` — the initial interactive login (run-15 root cause: the
  /// bounded [start] poll can expire before login lands), AND every subsequent
  /// sign-out→sign-in, super-login account switch, or role switch on the same
  /// live process (JEBV4-159 root cause: those re-emit `authenticated` on this
  /// same instance, and the old one-shot latch swallowed them, so the new user
  /// was never registered → zero device tokens → targeted pushes no-op'd).
  ///
  /// Idempotent PER IDENTITY: a duplicate emission for the SAME `(userId, token)`
  /// is skipped inside [_register], but a change in the authenticated user (a
  /// switch) always re-registers the CURRENT user's token. Disposed → no-op.
  Future<void> notifyLogin() async {
    if (_disposed) return;
    // The cold-start poll may still be pending; cancel it so we don't race a
    // late _attempt for the same (now-known) identity.
    _retryTimer?.cancel();
    if (_lastToken == null || _lastToken!.isEmpty) {
      try {
        _lastToken = await _transport.getToken();
      } catch (e) {
        if (kDebugMode) {
          debugPrint('[push][register] notifyLogin getToken failed: $e');
        }
      }
    }
    await _register(reason: 'login');
  }

  /// Sign-out trigger. [JeebApp] calls this on every transition into
  /// `unauthenticated`. It clears the `(userId, token)` dedup cache so that a
  /// later login re-registers even as the SAME user — necessary because the
  /// logout flow ([DioAccountSessionTerminator]) fires
  /// `DELETE /api/PushNotification/device`, removing this install's token row
  /// server-side. Without this reset the next same-user login would compute an
  /// identical key and be skipped as a "duplicate", leaving the re-logged-in
  /// user with zero tokens. There is no race: the DELETE runs during logout and
  /// the re-register runs on the NEXT login — strictly sequential user actions.
  void notifySignedOut() {
    if (_disposed) return;
    _lastRegisteredKey = null;
  }

  /// Poll until a logged-in userId exists, then register for that identity. Once
  /// registered, the `(userId, token)` dedup in [_register] makes a repeat a
  /// no-op, and this poll stops rescheduling (it returns after the register
  /// below), so there is no busy loop.
  void _attempt(int n) {
    if (_disposed) return;
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
    // Idempotent PER IDENTITY (JEBV4-159): skip only when this exact
    // `(userId, token)` pair was already confirmed. A different user (account
    // switch) or a rotated token changes the key and re-registers, so the
    // CURRENT user always has a live token row on the server.
    final key = _key(uid, token);
    if (key == _lastRegisteredKey) {
      if (kDebugMode) {
        debugPrint('[push][register] skip ($reason): already registered '
            'for this (user, token)');
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
        _lastRegisteredKey = key;
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
