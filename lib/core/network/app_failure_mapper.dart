import 'dart:io' show HttpDate, HttpException, SocketException, TlsException;

import 'package:dio/dio.dart';

import '../diagnostics/diag.dart';
import 'app_failure.dart';
import 'auth_interceptor.dart';
import 'gateway_problem.dart';
import 'network_reachability_signals.dart';

/// Typed sentinel carried by a request the client refused to send while a 429
/// back-off window is open. Replaces the English `error:` prose (NET-04/28).
final class RateLimitSuppression {
  const RateLimitSuppression({required this.scope, this.retryAfter});

  /// Path prefix whose window is open, e.g. `/v1/offers`.
  final String scope;

  final Duration? retryAfter;

  @override
  String toString() =>
      'RateLimitSuppression(scope: $scope, '
      'retryAfterSeconds: ${retryAfter?.inSeconds})';
}

/// `Retry-After` as seconds or an HTTP-date; null when absent/unparseable.
Duration? parseRetryAfterHeader(
  Response<dynamic>? response, {
  DateTime Function()? clock,
}) {
  final raw = response?.headers.value('retry-after')?.trim();
  if (raw == null || raw.isEmpty) return null;

  final asSeconds = int.tryParse(raw);
  if (asSeconds != null) {
    return asSeconds <= 0 ? Duration.zero : Duration(seconds: asSeconds);
  }
  try {
    final delta = HttpDate.parse(raw).difference((clock ?? DateTime.now)());
    return delta.isNegative ? Duration.zero : delta;
  } catch (_) {
    return null;
  }
}

/// THE DioException → [AppFailure] classification point (UX-API-AUDIT §3.2).
AppFailure mapDioException(DioException error) {
  final err = error.error;
  if (err is AppFailure) return err;
  if (err is RateLimitSuppression) {
    return RateLimitedFailure(
      retryAfter: err.retryAfter,
      localSuppression: true,
    );
  }

  switch (error.type) {
    case DioExceptionType.connectionTimeout:
    case DioExceptionType.sendTimeout:
    case DioExceptionType.receiveTimeout:
    case DioExceptionType.transformTimeout:
      return TimeoutFailure(phase: error.type, cause: err);
    case DioExceptionType.connectionError:
      return _networkFailure(error, err);
    case DioExceptionType.badCertificate:
      return _networkFailure(error, err, offline: false);
    case DioExceptionType.cancel:
      return UnknownFailure(cause: error);
    case DioExceptionType.unknown:
      if (err is SocketException || err is TlsException) {
        return _networkFailure(error, err);
      }
      return UnknownFailure(
        cause: error,
        parse: err is TypeError || err is FormatException,
      );
    case DioExceptionType.badResponse:
      break;
  }

  final response = error.response;
  final status = response?.statusCode;
  if (status == null) return UnknownFailure(cause: error);

  final problem = GatewayProblem.tryParse(response?.data);
  final traceId =
      problem?.traceId ?? response?.headers.value('x-correlation-id');
  final retryAfter = parseRetryAfterHeader(response) ?? problem?.retryAfter;
  final extra = error.requestOptions.extra;

  return switch (status) {
    401 => UnauthorizedFailure(
      problem: problem,
      traceId: traceId,
      recovering: extra[TokenRefreshInterceptor.recoveringFlag] == true,
      storeUnavailable:
          extra[BearerAuthInterceptor.storeUnavailableFlag] == true,
    ),
    403 => ForbiddenFailure(
      problem: problem,
      traceId: traceId,
      reasonCode: problem?.reasonCode,
      accountStatus: problem?.accountStatus,
    ),
    404 => NotFoundFailure(problem: problem, traceId: traceId),
    409 => ConflictFailure(problem: problem, traceId: traceId),
    410 => GoneFailure(problem: problem, traceId: traceId),
    400 || 413 || 415 || 422 => ValidationFailure(
      problem: problem,
      traceId: traceId,
      fieldErrors: problem?.errors ?? const <String, List<String>>{},
      field: problem?.field,
    ),
    429 => RateLimitedFailure(
      problem: problem,
      traceId: traceId,
      retryAfter: retryAfter,
    ),
    >= 500 => ServerFailure(
      problem: problem,
      traceId: traceId,
      status: status,
      retryAfter: retryAfter,
    ),
    _ => UnknownFailure(problem: problem, traceId: traceId, cause: error),
  };
}

bool get _offline => !NetworkReachabilitySignals.instance.isOnline;

/// Preserve reachability evidence when adapting a legacy feature enum.
NetworkFailure networkFailureFromReachability({Object? cause}) =>
    NetworkFailure(offline: _offline, cause: cause);

/// SDK socket messages and Android/Linux/Darwin error codes are diagnostics,
/// not evidence that the device is offline and never user-facing copy.
NetworkFailureReason classifyTransportError(Object? err) {
  if (err is SocketException) {
    final String message = err.message.toLowerCase();
    final int? code = err.osError?.errorCode;
    if (message.startsWith('failed host lookup') ||
        const <int>{7, 8, -2, -3, -5}.contains(code)) {
      return NetworkFailureReason.hostLookup;
    }
    if (code == 111 || code == 61 || message.contains('refused')) {
      return NetworkFailureReason.refused;
    }
    if (const <int>{101, 113, 51, 65}.contains(code) ||
        message.contains('unreachable')) {
      return NetworkFailureReason.unreachable;
    }
    if (code == 104 ||
        code == 54 ||
        message.contains('reset') ||
        message.contains('closed')) {
      return NetworkFailureReason.closed;
    }
    return NetworkFailureReason.unknown;
  }
  if (err is TlsException) return NetworkFailureReason.tls;
  if (err is HttpException) return NetworkFailureReason.closed;
  return NetworkFailureReason.unknown;
}

NetworkFailure _networkFailure(
  DioException error,
  Object? err, {
  bool? offline,
}) {
  final NetworkFailureReason reason =
      error.type == DioExceptionType.badCertificate
      ? NetworkFailureReason.tls
      : classifyTransportError(err);
  final bool isOffline = offline ?? _offline;
  bool placeholderHost = false;
  try {
    placeholderHost = error.requestOptions.uri.host.endsWith('.invalid');
  } on FormatException {
    // Diagnostics must not replace a transport failure with a URI parse error.
  }
  Diag.event('network_failure_classified', <String, Object?>{
    'reason': reason.name,
    'offline': isOffline,
    'reachability': NetworkReachabilitySignals.instance.knownOnline,
    'errno': err is SocketException ? err.osError?.errorCode : null,
    'placeholderHost': placeholderHost,
    'dioType': error.type.name,
  });
  return NetworkFailure(offline: isOffline, reason: reason, cause: err);
}

/// Appended LAST in the chain so every consumer downstream of the client sees
/// `e.error is AppFailure` without re-deriving meaning from the transport.
class AppFailureInterceptor extends Interceptor {
  const AppFailureInterceptor();

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) {
    if (err.error is AppFailure) {
      handler.next(err);
      return;
    }
    handler.next(err.copyWith(error: mapDioException(err)));
  }
}
