import 'dart:async';
import 'dart:math' as math;

import 'package:dio/dio.dart';

import 'app_failure_mapper.dart';

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

  /// NET-04: one window per path prefix, so a throttled `/v1/offers` can no
  /// longer blank `/v1/wallet`.
  final Map<String, DateTime> _suppressedUntil = <String, DateTime>{};

  Timer? _catchUpTimer;

  int _consecutiveCatchUps = 0;

  static const int _maxConsecutiveCatchUps = 3;

  static final RegExp _versionSegment = RegExp(r'^v\d+$');

  /// The resource a 429 suppresses. Version and `api` prefixes are dropped so
  /// `/v1/offers/o-1?x=1` and its unversioned twin `/offers` share one window.
  static String scopeOf(String path) {
    var route = path.split('?').first;
    // An absolute URL would otherwise collapse to the scheme.
    final int schemeEnd = route.indexOf('://');
    if (schemeEnd >= 0) {
      final String rest = route.substring(schemeEnd + 3);
      final int slash = rest.indexOf('/');
      route = slash < 0 ? '' : rest.substring(slash);
    }
    final segments = route.split('/').where((s) => s.isNotEmpty).toList();
    while (segments.isNotEmpty &&
        (segments.first == 'api' || _versionSegment.hasMatch(segments.first))) {
      segments.removeAt(0);
    }
    if (segments.isEmpty) return '/';
    return '/${segments.first}';
  }

  /// The scope resolved at send time, so a path rewritten by a later
  /// interceptor still matches the window its own 429 opened.
  static const String scopeExtraKey = 'jeeb.ratelimit.scope';

  static Duration? parseRetryAfter(
    Response<dynamic>? response, {
    DateTime Function()? clock,
  }) =>
      parseRetryAfterHeader(response, clock: clock);

  bool get isSuppressed => _suppressedUntil.keys.any(isScopeSuppressed);

  bool isScopeSuppressed(String scope) {
    final until = _suppressedUntil[scope];
    return until != null && _now().isBefore(until);
  }

  bool isPathSuppressed(String path) => isScopeSuppressed(scopeOf(path));

  Duration? retryAfterFor(String path) {
    final until = _suppressedUntil[scopeOf(path)];
    if (until == null) return null;
    final left = until.difference(_now());
    return left.isNegative ? null : left;
  }

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) {
    final scope = scopeOf(options.path);
    options.extra[scopeExtraKey] = scope;
    final until = _suppressedUntil[scope];
    if (until != null && !_now().isBefore(until)) {
      // NET-20: a window that ran out without a fresh 429 means we recovered.
      _suppressedUntil.remove(scope);
      _consecutiveCatchUps = 0;
    }
    final isRead = options.method.toUpperCase() == 'GET';
    if (isRead && isScopeSuppressed(scope)) {
      // Explicit: AppFailureInterceptor must still classify a local rejection.
      handler.reject(
        DioException(
          requestOptions: options,
          type: DioExceptionType.cancel,
          error: RateLimitSuppression(
            scope: scope,
            retryAfter: retryAfterFor(options.path),
          ),
        ),
        true,
      );
      return;
    }
    handler.next(options);
  }

  @override
  void onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) {
    _consecutiveCatchUps = 0;
    handler.next(response);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.response?.statusCode == 429) {
      final retryAfter =
          parseRetryAfter(err.response, clock: _now) ?? _defaultBackoff;
      final capped = retryAfter > _maxBackoff ? _maxBackoff : retryAfter;
      final jitterMs = _maxJitter.inMilliseconds == 0
          ? 0
          : _random.nextInt(_maxJitter.inMilliseconds + 1);
      final window = capped + Duration(milliseconds: jitterMs);
      final Object? sent = err.requestOptions.extra[scopeExtraKey];
      final String scope =
          sent is String ? sent : scopeOf(err.requestOptions.path);
      _suppressedUntil[scope] = _now().add(window);
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
    _suppressedUntil.clear();
  }
}
