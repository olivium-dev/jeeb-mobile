import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../diagnostics/chat_diagnostics.dart';
import '../../network/auth_token_store.dart';
import 'push_transport.dart';

/// registration must be attributed to a logged-in user, [start] polls
/// registration must never crash or block the app. The status (never the token)
class DeviceTokenRegistrar {
  DeviceTokenRegistrar({
    required Dio dio,
    required AuthTokenStore tokenStore,
    required PushTransport transport,
    required SharedPreferences prefs,
    Duration retryInterval = const Duration(seconds: 3),
    int maxAttempts = 40,
    Duration revalidateInterval = const Duration(minutes: 30),
    DateTime Function()? clock,
  })  : _dio = dio,
        _tokenStore = tokenStore,
        _transport = transport,
        _prefs = prefs,
        _retryInterval = retryInterval,
        _maxAttempts = maxAttempts,
        _revalidateInterval = revalidateInterval,
        _clock = clock ?? DateTime.now;

  final Dio _dio;
  final AuthTokenStore _tokenStore;
  final PushTransport _transport;
  final SharedPreferences _prefs;
  final Duration _retryInterval;
  final int _maxAttempts;
  final Duration _revalidateInterval;
  final DateTime Function() _clock;

  StreamSubscription<String>? _refreshSub;
  Timer? _retryTimer;
  String? _lastToken;

  String? _lastRegisteredKey;
  DateTime? _lastRegisteredAt;
  bool _disposed = false;

  static String _key(String? userId, String token) => '${userId ?? ''}::$token';

  static const String _registerPath = '/api/PushNotification/register';

  static const String _deviceIdKey = 'push.deviceId';

  Future<void> start() async {
    _refreshSub = _transport.onTokenRefresh.listen((fresh) {
      _lastToken = fresh;
      unawaited(() async {
        if (!await _register(reason: 'rotation')) _attempt(0);
      }());
    });

    await _refreshLastToken();
    _attempt(0);
  }

  Future<void> _refreshLastToken() async {
    if (_lastToken != null && _lastToken!.isNotEmpty) return;
    try {
      _lastToken = await _transport.getToken();
    } catch (e) {
      if (kDebugMode) debugPrint('[push][register] getToken failed: $e');
    }
  }

  Future<void> notifyLogin() async {
    if (_disposed) return;
    // The cold-start poll may still be pending; cancel it so we don't race a
    _retryTimer?.cancel();
    await _refreshLastToken();
    // D3: a login whose register skipped (token not fetched yet) or failed
    // (offline / 5xx) must not end here — re-arm the poll or we go dark.
    if (!await _register(reason: 'login')) _attempt(0);
  }

  /// D3 self-heal: the server row can disappear while this process lives (the
  /// device id re-owned elsewhere, an admin purge, a DB reset).
  Future<void> revalidate() async {
    if (_disposed) return;
    final last = _lastRegisteredAt;
    if (last != null && _clock().difference(last) < _revalidateInterval) return;
    _lastRegisteredKey = null;
    await notifyLogin();
  }

  /// user with zero tokens. There is no race: the DELETE runs during logout and
  void notifySignedOut() {
    if (_disposed) return;
    _lastRegisteredKey = null;
    _lastRegisteredAt = null;
  }

  void _attempt(int n) {
    if (_disposed) return;
    unawaited(() async {
      // The FCM token can land AFTER the first poll tick; re-ask every round or
      // a null-at-start token would keep the device unreachable for this run.
      await _refreshLastToken();
      final userId = await _safeUserId();
      if (userId != null && userId.isNotEmpty) {
        if (await _register(reason: 'login', userId: userId)) return;
      }
      if (n + 1 >= _maxAttempts) {
        if (kDebugMode) {
          debugPrint('[push][register] gave up after $_maxAttempts attempts');
        }
        return;
      }
      _retryTimer?.cancel();
      _retryTimer = Timer(_retryInterval, () => _attempt(n + 1));
    }());
  }

  /// Returns true when this device is known-registered for the current
  /// (user, token) — either the PUT succeeded or an earlier one already did.
  Future<bool> _register({required String reason, String? userId}) async {
    if (_disposed) return false;
    final token = _lastToken;
    if (token == null || token.isEmpty) {
      if (kDebugMode) {
        debugPrint('[push][register] skip ($reason): no FCM token yet');
      }
      return false;
    }
    final uid = userId ?? await _safeUserId();
    if (uid == null || uid.isEmpty) {
      if (kDebugMode) {
        debugPrint('[push][register] skip ($reason): no session yet');
      }
      return false;
    }
    final key = _key(uid, token);
    if (key == _lastRegisteredKey) {
      if (kDebugMode) {
        debugPrint('[push][register] skip ($reason): already registered '
            'for this (user, token)');
      }
      return true;
    }
    try {
      final res = await _dio.put<dynamic>(
        _registerPath,
        data: <String, dynamic>{
          'fcmToken': token,
          'deviceId': _deviceId(),
        },
      );
      final code = res.statusCode ?? 0;
      if (kDebugMode) {
        debugPrint('[push][register] ($reason) '
            'PUT $_registerPath -> $code');
      }
      PushRegistrationDiagnostics.record(reason: reason, status: code);
      if (code >= 200 && code < 300) {
        _lastRegisteredKey = key;
        _lastRegisteredAt = _clock();
        _retryTimer?.cancel();
        return true;
      }
      return false;
    } on DioException catch (e) {
      if (kDebugMode) {
        debugPrint('[push][register] FAILED ($reason) '
            'PUT $_registerPath -> ${e.response?.statusCode} '
            'body=${e.response?.data}');
      }
      PushRegistrationDiagnostics.record(
        reason: reason,
        status: e.response?.statusCode,
        error: e.type.name,
      );
      return false;
    } catch (e) {
      if (kDebugMode) debugPrint('[push][register] FAILED ($reason): $e');
      PushRegistrationDiagnostics.record(
        reason: reason,
        error: e.runtimeType.toString(),
      );
      return false;
    }
  }

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
