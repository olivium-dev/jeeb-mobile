import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  String? _lastRegisteredKey;
  bool _disposed = false;

  static String _key(String? userId, String token) => '${userId ?? ''}::$token';

  static const String _registerPath = '/api/PushNotification/register';

  static const String _deviceIdKey = 'push.deviceId';

  Future<void> start() async {
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

  Future<void> notifyLogin() async {
    if (_disposed) return;
    // The cold-start poll may still be pending; cancel it so we don't race a
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

  /// user with zero tokens. There is no race: the DELETE runs during logout and
  void notifySignedOut() {
    if (_disposed) return;
    _lastRegisteredKey = null;
  }

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
    final uid = userId ?? await _safeUserId();
    if (uid == null || uid.isEmpty) {
      if (kDebugMode) {
        debugPrint('[push][register] skip ($reason): no session yet');
      }
      return;
    }
    final key = _key(uid, token);
    if (key == _lastRegisteredKey) {
      if (kDebugMode) {
        debugPrint('[push][register] skip ($reason): already registered '
            'for this (user, token)');
      }
      return;
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
      if (code >= 200 && code < 300) {
        _lastRegisteredKey = key;
        _retryTimer?.cancel();
      }
      if (kDebugMode) {
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
