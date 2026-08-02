import 'dart:async';
import 'dart:io' show HttpDate;
import 'dart:math' as math;

import 'package:dio/dio.dart';

class RateLimitInterceptor extends Interceptor {
  RateLimitInterceptor({
    this.onBackoffWindowClosed,
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

  final void Function()? onBackoffWindowClosed;

  DateTime? _suppressedUntil;

  Timer? _catchUpTimer;

  int _consecutiveCatchUps = 0;

  static const int _maxConsecutiveCatchUps = 3;

  bool get isSuppressed {
    final until = _suppressedUntil;
    return until != null && _now().isBefore(until);
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final until = _suppressedUntil;
    final isRead = options.method.toUpperCase() == 'GET';
    if (isRead && until != null && _now().isBefore(until)) {
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: 'Suppressed by 429 back-off until '
              '${until.toIso8601String()} (Retry-After honored).',
        ),
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(Response<dynamic> response, ResponseInterceptorHandler handler) {
    _consecutiveCatchUps = 0;
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
      final window = capped + Duration(milliseconds: jitterMs);
      _suppressedUntil = _now().add(window);
      _scheduleCatchUp(window);
    }
    handler.next(err);
  }

  void _scheduleCatchUp(Duration window) {
    final callback = onBackoffWindowClosed;
    if (callback == null) return;
    if (_consecutiveCatchUps >= _maxConsecutiveCatchUps) return;
    _catchUpTimer?.cancel();
    _catchUpTimer = Timer(window + const Duration(milliseconds: 250), () {
      _catchUpTimer = null;
      _consecutiveCatchUps++;
      callback();
    });
  }

  void dispose() {
    _catchUpTimer?.cancel();
    _catchUpTimer = null;
  }

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
