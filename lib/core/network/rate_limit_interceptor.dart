import 'dart:io' show HttpDate;
import 'dart:math' as math;

import 'package:dio/dio.dart';

/// Global `429 Too Many Requests` back-off gate (F3 — offers polling storm).
///
/// The customer home tab polls `GET /requests`, `GET /deliveries` and
/// `GET /v1/offers` on a cadence. When the gateway's per-subscription rate
/// limiter trips (HTTP 429) the WORST thing the client can do is keep firing
/// scheduled polls into the closed window — that is exactly what turns a single
/// 429 into a sustained storm. This interceptor:
///
///   1. On any `429`, reads the `Retry-After` header (delta-seconds OR an
///      HTTP-date), adds a small random jitter (so a fleet of clients does not
///      re-stampede in lock-step), and opens a suppression window until that
///      instant (capped at [maxBackoff]).
///   2. While the window is open, it SHORT-CIRCUITS further idempotent reads
///      (`GET`) locally — they never touch the network — so the scheduled polls
///      quietly pause instead of hammering a rate-limited gateway. The rejection
///      is a normal [DioException] the callers already treat as a soft failure
///      (the home load degrades, it never crashes).
///   3. It NEVER retries a request on a schedule into a 429 — non-GET writes
///      (accept offer, create request) are always allowed straight through so a
///      user-initiated action is never silently swallowed by the back-off.
///
/// The window is purely time-based and self-heals: once `Retry-After` elapses,
/// reads flow again and the next poll tick resumes normally.
class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor({
    DateTime Function()? clock,
    math.Random? random,
    Duration maxBackoff = const Duration(seconds: 120),
    Duration defaultBackoff = const Duration(seconds: 5),
    Duration maxJitter = const Duration(seconds: 1),
  })  : _now = clock ?? DateTime.now,
        _random = random ?? math.Random(),
        _maxBackoff = maxBackoff,
        _defaultBackoff = defaultBackoff,
        _maxJitter = maxJitter;

  final DateTime Function() _now;
  final math.Random _random;
  final Duration _maxBackoff;
  final Duration _defaultBackoff;
  final Duration _maxJitter;

  /// Instant until which idempotent reads are suppressed. `null` when no
  /// back-off window is open.
  DateTime? _suppressedUntil;

  /// Exposed for diagnostics/tests: is a back-off window currently open?
  bool get isSuppressed {
    final until = _suppressedUntil;
    return until != null && _now().isBefore(until);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final until = _suppressedUntil;
    // Only reads are suppressed. Writes (POST/PUT/PATCH/DELETE) — the money /
    // action path — always go through so a user action is never dropped.
    final isRead = options.method.toUpperCase() == 'GET';
    if (isRead && until != null && _now().isBefore(until)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'Suppressed by 429 back-off until '
              '${until.toIso8601String()} (Retry-After honored).',
        ),
        // callFollowingErrorInterceptor: false — this is a synthetic local
        // rejection, not a server error; do not re-enter onError handlers.
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    // A clean response means the window (if any) is effectively clear — drop it
    // so we do not keep suppressing after the gateway recovered early.
    if (response.statusCode != null &&
        response.statusCode! < 400 &&
        _suppressedUntil != null) {
      _suppressedUntil = null;
    }
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 429) {
      final retryAfter = _parseRetryAfter(err.response);
      final capped = retryAfter > _maxBackoff ? _maxBackoff : retryAfter;
      final jitterMs = _maxJitter.inMilliseconds == 0
          ? 0
          : _random.nextInt(_maxJitter.inMilliseconds + 1);
      _suppressedUntil =
          _now().add(capped + Duration(milliseconds: jitterMs));
    }
    handler.next(err);
  }

  /// Parse `Retry-After`: an integer delta-seconds OR an HTTP-date. Falls back
  /// to [_defaultBackoff] when the header is absent or unparseable. Never
  /// returns a negative duration.
  Duration _parseRetryAfter(Response<dynamic>? response) {
    final raw = response?.headers.value('retry-after')?.trim();
    if (raw == null || raw.isEmpty) return _defaultBackoff;

    final asSeconds = int.tryParse(raw);
    if (asSeconds != null) {
      return asSeconds <= 0 ? Duration.zero : Duration(seconds: asSeconds);
    }

    try {
      final date = HttpDate.parse(raw);
      final delta = date.difference(_now());
      return delta.isNegative ? Duration.zero : delta;
    } catch (_) {
      return _defaultBackoff;
    }
  }
}
