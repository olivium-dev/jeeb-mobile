import 'package:dio/dio.dart';

import 'app_failure_mapper.dart';
import 'gateway_problem.dart';

enum AppFailureKind {
  network,
  timeout,
  server,
  unauthorized,
  forbidden,
  notFound,
  conflict,
  gone,
  validation,
  rateLimited,
  unknown,
}

/// The one error model. Everything thrown below the UI is classified into a
/// subtype of this; features read [kind]/[problem], never the raw transport.
sealed class AppFailure implements Exception {
  const AppFailure({this.problem, this.traceId, this.cause});

  /// THE mapping point for anything caught in a repository or cubit.
  static AppFailure of(Object error) => error is AppFailure
      ? error
      : error is DioException
          ? mapDioException(error)
          : UnknownFailure(cause: error);

  /// Parsed RFC 7807 body, when the response carried one.
  final GatewayProblem? problem;

  /// `problem.traceId` or the `x-correlation-id` response header.
  final String? traceId;

  /// Diagnostics only — never rendered, never logged verbatim.
  final Object? cause;

  AppFailureKind get kind;

  bool get isRetryable => switch (kind) {
        AppFailureKind.network ||
        AppFailureKind.timeout ||
        AppFailureKind.server ||
        AppFailureKind.rateLimited ||
        AppFailureKind.unknown =>
          true,
        _ => false,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppFailure &&
          other.runtimeType == runtimeType &&
          other.problem == problem &&
          other.traceId == traceId &&
          other.cause == cause;

  @override
  int get hashCode => Object.hash(runtimeType, problem, traceId, cause);

  /// Never interpolates [cause] or problem prose: failures reach crash logs.
  String _describe(String name, [String? extra]) {
    final parts = <String>[
      if (extra != null && extra.isNotEmpty) extra,
      if (problem?.typeSuffix != null) 'type: ${problem!.typeSuffix}',
      if (traceId != null) 'traceId: $traceId',
      if (cause != null) 'hasCause: true',
    ];
    return '$name(${parts.join(', ')})';
  }
}

/// Offline or unreachable; [offline] means reachability said there is no
/// transport, not merely that this request failed.
final class NetworkFailure extends AppFailure {
  const NetworkFailure({
    this.offline = false,
    super.problem,
    super.traceId,
    super.cause,
  });

  final bool offline;

  @override
  AppFailureKind get kind => AppFailureKind.network;

  @override
  bool operator ==(Object other) =>
      super == other && other is NetworkFailure && other.offline == offline;

  @override
  int get hashCode => Object.hash(super.hashCode, offline);

  @override
  String toString() => _describe('NetworkFailure', 'offline: $offline');
}

final class TimeoutFailure extends AppFailure {
  const TimeoutFailure({
    required this.phase,
    super.problem,
    super.traceId,
    super.cause,
  });

  /// connect / send / receive.
  final DioExceptionType phase;

  @override
  AppFailureKind get kind => AppFailureKind.timeout;

  @override
  bool operator ==(Object other) =>
      super == other && other is TimeoutFailure && other.phase == phase;

  @override
  int get hashCode => Object.hash(super.hashCode, phase);

  @override
  String toString() => _describe('TimeoutFailure', 'phase: ${phase.name}');
}

final class ServerFailure extends AppFailure {
  const ServerFailure({
    required this.status,
    this.retryAfter,
    super.problem,
    super.traceId,
    super.cause,
  });

  final int status;
  final Duration? retryAfter;

  bool get unavailable => status == 502 || status == 503 || status == 504;

  @override
  AppFailureKind get kind => AppFailureKind.server;

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is ServerFailure &&
      other.status == status &&
      other.retryAfter == retryAfter;

  @override
  int get hashCode => Object.hash(super.hashCode, status, retryAfter);

  @override
  String toString() => _describe('ServerFailure', 'status: $status');
}

/// 401. [recovering] = raised inside the refresh cooldown (NET-17);
/// [storeUnavailable] = the token store could not be read (NET-02).
final class UnauthorizedFailure extends AppFailure {
  const UnauthorizedFailure({
    this.recovering = false,
    this.storeUnavailable = false,
    super.problem,
    super.traceId,
    super.cause,
  });

  final bool recovering;
  final bool storeUnavailable;

  @override
  AppFailureKind get kind => AppFailureKind.unauthorized;

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is UnauthorizedFailure &&
      other.recovering == recovering &&
      other.storeUnavailable == storeUnavailable;

  @override
  int get hashCode => Object.hash(super.hashCode, recovering, storeUnavailable);

  @override
  String toString() => _describe(
        'UnauthorizedFailure',
        'recovering: $recovering, storeUnavailable: $storeUnavailable',
      );
}

final class ForbiddenFailure extends AppFailure {
  const ForbiddenFailure({
    this.reasonCode,
    this.accountStatus,
    super.problem,
    super.traceId,
    super.cause,
  });

  final String? reasonCode;
  final String? accountStatus;

  @override
  AppFailureKind get kind => AppFailureKind.forbidden;

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is ForbiddenFailure &&
      other.reasonCode == reasonCode &&
      other.accountStatus == accountStatus;

  @override
  int get hashCode => Object.hash(super.hashCode, reasonCode, accountStatus);

  @override
  String toString() => _describe(
        'ForbiddenFailure',
        'reasonCode: $reasonCode, accountStatus: $accountStatus',
      );
}

final class NotFoundFailure extends AppFailure {
  const NotFoundFailure({super.problem, super.traceId, super.cause});

  @override
  AppFailureKind get kind => AppFailureKind.notFound;

  @override
  String toString() => _describe('NotFoundFailure');
}

/// 409; `problem.typeSuffix` disambiguates the conflict.
final class ConflictFailure extends AppFailure {
  const ConflictFailure({super.problem, super.traceId, super.cause});

  @override
  AppFailureKind get kind => AppFailureKind.conflict;

  @override
  String toString() => _describe('ConflictFailure');
}

final class GoneFailure extends AppFailure {
  const GoneFailure({super.problem, super.traceId, super.cause});

  @override
  AppFailureKind get kind => AppFailureKind.gone;

  @override
  String toString() => _describe('GoneFailure');
}

/// 400/422/413/415 plus the `errors{}` / `field` problem members.
final class ValidationFailure extends AppFailure {
  const ValidationFailure({
    this.fieldErrors = const <String, List<String>>{},
    this.field,
    super.problem,
    super.traceId,
    super.cause,
  });

  final Map<String, List<String>> fieldErrors;
  final String? field;

  @override
  AppFailureKind get kind => AppFailureKind.validation;

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is ValidationFailure &&
      other.field == field &&
      deepJsonEquals(other.fieldErrors, fieldErrors);

  @override
  int get hashCode => Object.hash(super.hashCode, field, fieldErrors.length);

  @override
  String toString() => _describe(
        'ValidationFailure',
        'fields: ${fieldErrors.length}, field: $field',
      );
}

/// 429 from the gateway, or a locally suppressed request during the
/// client-side back-off window ([localSuppression]).
final class RateLimitedFailure extends AppFailure {
  const RateLimitedFailure({
    this.retryAfter,
    this.localSuppression = false,
    super.problem,
    super.traceId,
    super.cause,
  });

  final Duration? retryAfter;
  final bool localSuppression;

  @override
  AppFailureKind get kind => AppFailureKind.rateLimited;

  @override
  bool operator ==(Object other) =>
      super == other &&
      other is RateLimitedFailure &&
      other.retryAfter == retryAfter &&
      other.localSuppression == localSuppression;

  @override
  int get hashCode => Object.hash(super.hashCode, retryAfter, localSuppression);

  @override
  String toString() => _describe(
        'RateLimitedFailure',
        'retryAfterSeconds: ${retryAfter?.inSeconds}, '
            'localSuppression: $localSuppression',
      );
}

/// [parse] marks a FormatException/TypeError raised by our own decoding.
final class UnknownFailure extends AppFailure {
  const UnknownFailure({
    this.parse = false,
    super.problem,
    super.traceId,
    super.cause,
  });

  final bool parse;

  @override
  AppFailureKind get kind => AppFailureKind.unknown;

  @override
  bool operator ==(Object other) =>
      super == other && other is UnknownFailure && other.parse == parse;

  @override
  int get hashCode => Object.hash(super.hashCode, parse);

  @override
  String toString() => _describe('UnknownFailure', 'parse: $parse');
}
