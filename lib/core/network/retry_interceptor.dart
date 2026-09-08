import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'network_reachability_signals.dart';
import 'rate_limit_interceptor.dart';

/// NET-06: bounded transient retry. Only requests that are safe to repeat —
/// idempotent verbs, or a mutation carrying an `Idempotency-Key` — are replayed.
class RetryInterceptor extends Interceptor {
  RetryInterceptor({
    required Dio retryClient,
    this.maxAttempts = 2,
    this.baseDelay = const Duration(milliseconds: 300),
    this.maxJitter = const Duration(milliseconds: 200),
    RateLimitInterceptor? rateLimiter,
    math.Random? random,
    Future<void> Function(Duration)? delay,
  })  : _retryClient = retryClient,
        _rateLimiter = rateLimiter,
        _random = random ?? math.Random(),
        _delay = delay ?? Future<void>.delayed;

  final Dio _retryClient;
  final RateLimitInterceptor? _rateLimiter;
  final math.Random _random;
  final Future<void> Function(Duration) _delay;

  /// Replays after the first failure, so 2 means at most 3 wire attempts.
  final int maxAttempts;
  final Duration baseDelay;
  final Duration maxJitter;

  static const String attemptsFlag = 'jeeb.retry.attempts';

  static const String idempotencyHeader = 'Idempotency-Key';

  static const Set<String> idempotentMethods = <String>{
    'GET',
    'HEAD',
    'OPTIONS',
    'PUT',
    'DELETE',
  };

  static bool isReplayable(RequestOptions options) {
    // A FormData/Stream body is one-shot: a replay would send empty parts.
    if (options.data is FormData || options.data is Stream) return false;
    if (idempotentMethods.contains(options.method.toUpperCase())) return true;
    return options.headers.keys.any(
      (key) => key.toLowerCase() == idempotencyHeader.toLowerCase(),
    );
  }

  /// Read/send timeouts are NOT transient: the request reached the backend, so
  /// a replay only doubles a wait the caller already paid and adds load.
  static bool isTransient(DioException err) {
    switch (err.type) {
      case DioExceptionType.connectionError:
        return NetworkReachabilitySignals.instance.isOnline;
      case DioExceptionType.connectionTimeout:
        return true;
      case DioExceptionType.badResponse:
        final status = err.response?.statusCode ?? 0;
        return status == 502 || status == 503 || status == 504;
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.badCertificate:
      case DioExceptionType.cancel:
      case DioExceptionType.unknown:
        return false;
    }
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final options = err.requestOptions;
    final seen = options.extra[attemptsFlag];
    var done = seen is int ? seen : 0;
    var current = err;

    while (done < maxAttempts &&
        isTransient(current) &&
        isReplayable(options) &&
        !_suppressed(options)) {
      await _delay(_backoffFor(done));
      done++;
      options.extra[attemptsFlag] = done;
      try {
        handler.resolve(await _retryClient.fetch<dynamic>(options));
        return;
      } on DioException catch (retryErr) {
        current = retryErr;
      }
    }
    handler.next(current);
  }

  /// Prefers the scope stamped at send time, so a rewritten path still
  /// matches the window its own 429 opened.
  bool _suppressed(RequestOptions options) {
    final limiter = _rateLimiter;
    if (limiter == null) return false;
    final Object? scope = options.extra[RateLimitInterceptor.scopeExtraKey];
    return scope is String
        ? limiter.isScopeSuppressed(scope)
        : limiter.isPathSuppressed(options.path);
  }

  Duration _backoffFor(int attemptsDone) {
    final scaled = baseDelay * math.pow(2, attemptsDone).toDouble();
    final jitterMs = maxJitter.inMilliseconds == 0
        ? 0
        : _random.nextInt(maxJitter.inMilliseconds + 1);
    return scaled + Duration(milliseconds: jitterMs);
  }
}
