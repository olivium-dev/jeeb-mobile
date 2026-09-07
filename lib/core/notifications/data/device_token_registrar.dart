import 'dart:async';
import 'dart:math';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../diagnostics/chat_diagnostics.dart';
import '../../network/app_failure_mapper.dart';
import '../../network/auth_token_store.dart';
import 'push_transport.dart';
import 'shared_prefs_local_push_inbox.dart';

/// What one PUT did, and how long the server asked us to wait before the next.
@immutable
class _RegisterResult {
  const _RegisterResult({required this.registered, this.retryAfter});

  final bool registered;
  final Duration? retryAfter;
}

/// registration must be attributed to a logged-in user, [start] polls
/// registration must never crash or block the app. The status (never the token)
///
/// F3 (device judge, 2026-09-07): a live 502 window turned this into 39 PUTs in
/// 62s. Every wire attempt now runs single-flight on a bounded, jittered
/// exponential backoff that obeys Retry-After, and a spent budget re-arms only
/// on a real trigger (token rotation, login, resume after the cooldown).
class DeviceTokenRegistrar {
  DeviceTokenRegistrar({
    required Dio dio,
    required AuthTokenStore tokenStore,
    required PushTransport transport,
    required SharedPreferences prefs,
    Duration retryInterval = const Duration(seconds: 3),
    int maxAttempts = 40,
    int maxFailureAttempts = 6,
    Duration maxBackoff = const Duration(minutes: 5),
    Duration maxRetryAfter = const Duration(minutes: 15),
    Duration exhaustedCooldown = const Duration(minutes: 15),
    Duration revalidateInterval = const Duration(minutes: 30),
    DateTime Function()? clock,
    Random? random,
  })  : _dio = dio,
        _tokenStore = tokenStore,
        _transport = transport,
        _prefs = prefs,
        _retryInterval = retryInterval,
        _maxAttempts = maxAttempts,
        _maxFailureAttempts = maxFailureAttempts,
        _maxBackoff = maxBackoff,
        _maxRetryAfter = maxRetryAfter,
        _exhaustedCooldown = exhaustedCooldown,
        _revalidateInterval = revalidateInterval,
        _clock = clock ?? DateTime.now,
        _random = random ?? Random();

  final Dio _dio;
  final AuthTokenStore _tokenStore;
  final PushTransport _transport;
  final SharedPreferences _prefs;

  /// Poll tick before a session exists, and the BASE of the failure backoff.
  final Duration _retryInterval;

  /// Bounded cold-start poll: ticks spent waiting for a token AND a session.
  final int _maxAttempts;

  /// Wire attempts allowed per failing round before the registrar goes quiet.
  final int _maxFailureAttempts;
  final Duration _maxBackoff;
  final Duration _maxRetryAfter;
  final Duration _exhaustedCooldown;
  final Duration _revalidateInterval;
  final DateTime Function() _clock;
  final Random _random;

  StreamSubscription<String>? _refreshSub;
  Timer? _retryTimer;
  String? _lastToken;

  String? _lastRegisteredKey;
  DateTime? _lastRegisteredAt;
  bool _disposed = false;

  /// Single-flight latch. Set synchronously on entry to [_run], so three
  /// triggers landing in one window produce one PUT, not three.
  bool _busy = false;

  /// A trigger that arrived mid-flight. Replayed once the step ends, so an
  /// account switch during an in-flight PUT is never dropped.
  String? _pendingReason;
  bool _pendingReset = false;

  /// The (user, token) the current backoff round belongs to.
  String? _roundKey;
  int _failures = 0;
  int _polls = 0;

  /// No PUT before this instant — the backoff window, Retry-After included.
  DateTime? _nextAttemptAt;

  static String _key(String? userId, String token) => '${userId ?? ''}::$token';

  static const String _registerPath = '/api/PushNotification/register';

  static const String _deviceIdKey = 'push.deviceId';

  /// Body members a gateway or edge may carry the wait in. The live Cloudflare
  /// 502 pages used `retry_after`; the gateway problem+json uses `retryAfter`.
  static const List<String> _retryAfterMembers = <String>[
    'retry_after',
    'retryAfter',
    'retry_after_seconds',
    'retryAfterSeconds',
  ];

  Future<void> start() async {
    _refreshSub = _transport.onTokenRefresh.listen((fresh) {
      _lastToken = fresh;
      // A rotated token is a new registration: it opens a fresh budget.
      unawaited(_run('rotation', resetRound: true));
    });

    await _refreshLastToken();
    unawaited(_run('login'));
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
    await _refreshLastToken();
    // D3: a login whose register skipped (token not fetched yet) or failed
    // (offline / 5xx) must not end here — the round re-arms or we go dark.
    await _run('login');
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
    // The session ended: the next login is a real trigger, not a retry.
    _closeRound();
  }

  /// One registration step: resolve the identity, honour the window, PUT once,
  /// then schedule (or decline to schedule) the next step.
  Future<void> _run(String reason, {bool resetRound = false}) async {
    if (_disposed) return;
    if (_busy) {
      _pendingReason = reason;
      _pendingReset = _pendingReset || resetRound;
      return;
    }
    _busy = true;
    try {
      await _refreshLastToken();
      final token = _lastToken;
      final uid = await _safeUserId();
      if (token == null || token.isEmpty) {
        _onSkipped(reason, 'no FCM token yet');
        return;
      }
      if (uid == null || uid.isEmpty) {
        _onSkipped(reason, 'no session yet');
        return;
      }

      final key = _key(uid, token);
      if (key == _lastRegisteredKey) {
        if (kDebugMode) {
          debugPrint('[push][register] skip ($reason): already registered '
              'for this (user, token)');
        }
        _closeRound();
        return;
      }
      if (resetRound || key != _roundKey) _openRound(key);

      final now = _clock();
      final due = _nextAttemptAt;
      if (due != null && now.isBefore(due)) {
        // Inside the backoff window. Keep the timer armed; never PUT early.
        if (_failures < _maxFailureAttempts) {
          _armTimer(due.difference(now), reason);
        }
        return;
      }
      if (_failures >= _maxFailureAttempts) {
        // Budget spent and the cooldown has passed: this trigger opens a new
        // round rather than resuming the exhausted one.
        _openRound(key);
      }

      final result = await _put(reason: reason, token: token);
      if (result.registered) {
        _lastRegisteredKey = key;
        _lastRegisteredAt = _clock();
        _closeRound();
        return;
      }
      _onFailed(reason, result.retryAfter);
    } finally {
      _busy = false;
      _replayPendingTrigger();
    }
  }

  void _replayPendingTrigger() {
    final reason = _pendingReason;
    if (reason == null || _disposed) return;
    final reset = _pendingReset;
    _pendingReason = null;
    _pendingReset = false;
    unawaited(_run(reason, resetRound: reset));
  }

  /// Cold start with no token or no session yet: a flat, bounded poll. Nothing
  /// reached the network, so this never consumes the failure budget.
  void _onSkipped(String reason, String why) {
    if (kDebugMode) debugPrint('[push][register] skip ($reason): $why');
    _polls++;
    if (_polls >= _maxAttempts) {
      if (kDebugMode) {
        debugPrint('[push][register] poll gave up after $_maxAttempts ticks');
      }
      return;
    }
    _armTimer(_retryInterval, reason);
  }

  void _onFailed(String reason, Duration? retryAfter) {
    _failures++;
    if (_failures >= _maxFailureAttempts) {
      // Quiet until a real trigger (rotation, login, resume) AND the cooldown.
      _nextAttemptAt = _clock().add(_exhaustedCooldown);
      _retryTimer?.cancel();
      if (kDebugMode) {
        debugPrint('[push][register] budget spent after $_maxFailureAttempts '
            'attempts; quiet for ${_exhaustedCooldown.inSeconds}s');
      }
      return;
    }
    final delay = _backoffFor(_failures - 1, retryAfter);
    _nextAttemptAt = _clock().add(delay);
    _armTimer(delay, reason);
  }

  /// Exponential off [_retryInterval], capped, never below a Retry-After hint,
  /// plus up to 25% jitter so installs do not re-converge into a herd.
  Duration _backoffFor(int failuresBefore, Duration? retryAfter) {
    final baseMs = _retryInterval.inMilliseconds;
    var ms = baseMs <= 0
        ? 0
        : min(baseMs << min(failuresBefore, 20), _maxBackoff.inMilliseconds);
    if (retryAfter != null && retryAfter > Duration.zero) {
      ms = max(
        ms,
        min(retryAfter.inMilliseconds, _maxRetryAfter.inMilliseconds),
      );
    }
    if (ms <= 0) return Duration.zero;
    return Duration(milliseconds: ms + _random.nextInt((ms ~/ 4) + 1));
  }

  void _openRound(String key) {
    _roundKey = key;
    _failures = 0;
    _polls = 0;
    _nextAttemptAt = null;
    _retryTimer?.cancel();
  }

  void _closeRound() {
    _roundKey = null;
    _failures = 0;
    _polls = 0;
    _nextAttemptAt = null;
    _retryTimer?.cancel();
  }

  void _armTimer(Duration delay, String reason) {
    if (_disposed) return;
    _retryTimer?.cancel();
    _retryTimer = Timer(delay, () => unawaited(_run(reason)));
  }

  /// The single PUT. Never throws: every outcome is classified for the caller
  /// and recorded for [PushRegistrationDiagnostics].
  Future<_RegisterResult> _put({
    required String reason,
    required String token,
  }) async {
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
        return const _RegisterResult(registered: true);
      }
      return _RegisterResult(
        registered: false,
        retryAfter: _retryAfterOf(res),
      );
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
      return _RegisterResult(
        registered: false,
        retryAfter: _retryAfterOf(e.response),
      );
    } catch (e) {
      if (kDebugMode) debugPrint('[push][register] FAILED ($reason): $e');
      PushRegistrationDiagnostics.record(
        reason: reason,
        error: e.runtimeType.toString(),
      );
      return const _RegisterResult(registered: false);
    }
  }

  /// The server's own wait, from the `Retry-After` header or a body member.
  Duration? _retryAfterOf(Response<dynamic>? response) {
    final header = parseRetryAfterHeader(response, clock: _clock);
    if (header != null && header > Duration.zero) return header;
    final data = response?.data;
    if (data is! Map) return null;
    for (final member in _retryAfterMembers) {
      final raw = data[member];
      final seconds = raw is num
          ? raw.toDouble()
          : (raw is String ? double.tryParse(raw) : null);
      if (seconds != null && seconds > 0) {
        return Duration(milliseconds: (seconds * 1000).round());
      }
    }
    return null;
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
      final id = await _tokenStore.userId;
      // F7: mirror the owner for the FCM background isolate, which keys inbox
      // rows by it and cannot reach the keystore.
      await SharedPrefsLocalPushInbox.stampOwner(_prefs, id);
      return id;
    } catch (_) {
      return null;
    }
  }

  Future<void> dispose() async {
    _disposed = true;
    _pendingReason = null;
    _retryTimer?.cancel();
    await _refreshSub?.cancel();
  }
}
