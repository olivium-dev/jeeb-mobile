// NET-01: every transport outcome has exactly one classification.

import 'dart:io' show SocketException;
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/app_failure_mapper.dart';
import 'package:jeeb_mobile/core/network/auth_interceptor.dart';
import 'package:jeeb_mobile/core/network/network_reachability_signals.dart';

RequestOptions _options({Map<String, dynamic>? extra}) =>
    RequestOptions(path: '/v1/offers', extra: extra ?? <String, dynamic>{});

DioException _badResponse(
  int status, {
  Object? body,
  Map<String, List<String>>? headers,
  Map<String, dynamic>? extra,
}) {
  final options = _options(extra: extra);
  return DioException(
    requestOptions: options,
    type: DioExceptionType.badResponse,
    response: Response<dynamic>(
      requestOptions: options,
      statusCode: status,
      data: body,
      headers: Headers.fromMap(headers ?? const <String, List<String>>{}),
    ),
  );
}

class _EchoAdapter implements HttpClientAdapter {
  _EchoAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      _respond(options);

  @override
  void close({bool force = false}) {}
}

void main() {
  tearDown(NetworkReachabilitySignals.debugReset);

  group('transport-level types', () {
    test('each timeout phase becomes a TimeoutFailure carrying the phase', () {
      for (final type in const <DioExceptionType>[
        DioExceptionType.connectionTimeout,
        DioExceptionType.sendTimeout,
        DioExceptionType.receiveTimeout,
      ]) {
        final failure = mapDioException(
          DioException(requestOptions: _options(), type: type),
        );
        expect(failure, isA<TimeoutFailure>(), reason: type.name);
        expect((failure as TimeoutFailure).phase, type);
        expect(failure.kind, AppFailureKind.timeout);
      }
    });

    test('a connection error is a NetworkFailure, offline only when the bus '
        'says there is no transport', () {
      final online = mapDioException(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.connectionError,
        ),
      );
      expect((online as NetworkFailure).offline, isFalse);

      NetworkReachabilitySignals.instance.debugObserve(online: false);
      final offline = mapDioException(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.connectionError,
        ),
      );
      expect((offline as NetworkFailure).offline, isTrue);
    });

    test('an unknown-type SocketException is still a NetworkFailure', () {
      final failure = mapDioException(
        DioException(
          requestOptions: _options(),
          error: const SocketException('closed'),
        ),
      );
      expect(failure, isA<NetworkFailure>());
    });

    test('a decoding TypeError is an UnknownFailure marked as a parse fault',
        () {
      final failure = mapDioException(
        DioException(requestOptions: _options(), error: TypeError()),
      );
      expect((failure as UnknownFailure).parse, isTrue);
    });

    test('a cancel with no sentinel is unknown, never a rate limit', () {
      final failure = mapDioException(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.cancel,
        ),
      );
      expect(failure, isA<UnknownFailure>());
      expect((failure as UnknownFailure).parse, isFalse);
    });

    test('the RateLimitSuppression sentinel maps to a local rate limit', () {
      final failure = mapDioException(
        DioException(
          requestOptions: _options(),
          type: DioExceptionType.cancel,
          error: const RateLimitSuppression(
            scope: '/v1/offers',
            retryAfter: Duration(seconds: 12),
          ),
        ),
      );
      expect(failure, isA<RateLimitedFailure>());
      final rate = failure as RateLimitedFailure;
      expect(rate.localSuppression, isTrue);
      expect(rate.retryAfter, const Duration(seconds: 12));
    });

    test('an already-classified error passes straight through', () {
      const already = NotFoundFailure();
      expect(
        mapDioException(
          DioException(requestOptions: _options(), error: already),
        ),
        same(already),
      );
    });
  });

  group('status codes', () {
    test('the whole status table lands on one kind each', () {
      final table = <int, AppFailureKind>{
        400: AppFailureKind.validation,
        401: AppFailureKind.unauthorized,
        403: AppFailureKind.forbidden,
        404: AppFailureKind.notFound,
        409: AppFailureKind.conflict,
        410: AppFailureKind.gone,
        413: AppFailureKind.validation,
        415: AppFailureKind.validation,
        422: AppFailureKind.validation,
        429: AppFailureKind.rateLimited,
        500: AppFailureKind.server,
        502: AppFailureKind.server,
        503: AppFailureKind.server,
        504: AppFailureKind.server,
        418: AppFailureKind.unknown,
      };
      table.forEach((status, kind) {
        expect(mapDioException(_badResponse(status)).kind, kind,
            reason: '$status');
      });
    });

    test('502/503/504 are flagged unavailable, 500 is not', () {
      for (final status in const <int>[502, 503, 504]) {
        expect(
          (mapDioException(_badResponse(status)) as ServerFailure).unavailable,
          isTrue,
          reason: '$status',
        );
      }
      expect(
        (mapDioException(_badResponse(500)) as ServerFailure).unavailable,
        isFalse,
      );
    });

    test('a 400 lifts the ASP.NET errors{} map onto the failure', () {
      final failure = mapDioException(
        _badResponse(400, body: <String, Object?>{
          'type': 'https://jeeb/errors/validation',
          'title': 'Invalid request',
          'status': 400,
          'errors': <String, Object?>{
            'fee': <String>['Fee is below the floor.'],
          },
          'field': 'fee',
        }),
      ) as ValidationFailure;
      expect(failure.fieldErrors['fee'], <String>['Fee is below the floor.']);
      expect(failure.field, 'fee');
      expect(failure.problem?.typeSuffix, 'validation');
    });

    test('a 403 carries the jeeb reason/account extensions', () {
      final failure = mapDioException(
        _badResponse(403, body: <String, Object?>{
          'type': 'https://jeeb/errors/account-suspended',
          'status': 403,
          'reasonCode': 'kyc_required',
          'accountStatus': 'suspended',
        }),
      ) as ForbiddenFailure;
      expect(failure.reasonCode, 'kyc_required');
      expect(failure.accountStatus, 'suspended');
      expect(failure.problem?.typeSuffix, 'account-suspended');
    });

    test('a 401 reads the interceptor flags off the request', () {
      final plain = mapDioException(_badResponse(401)) as UnauthorizedFailure;
      expect(plain.recovering, isFalse);
      expect(plain.storeUnavailable, isFalse);

      final flagged = mapDioException(
        _badResponse(401, extra: <String, dynamic>{
          TokenRefreshInterceptor.recoveringFlag: true,
          BearerAuthInterceptor.storeUnavailableFlag: true,
        }),
      ) as UnauthorizedFailure;
      expect(flagged.recovering, isTrue);
      expect(flagged.storeUnavailable, isTrue);
    });

    test('Retry-After is read from the header, then the problem body', () {
      final fromHeader = mapDioException(
        _badResponse(429, headers: <String, List<String>>{
          'retry-after': <String>['45'],
        }),
      ) as RateLimitedFailure;
      expect(fromHeader.retryAfter, const Duration(seconds: 45));
      expect(fromHeader.localSuppression, isFalse);

      final fromBody = mapDioException(
        _badResponse(429, body: <String, Object?>{
          'type': 'https://jeeb/errors/too-many-requests',
          'status': 429,
          'retryAfter': 20,
        }),
      ) as RateLimitedFailure;
      expect(fromBody.retryAfter, const Duration(seconds: 20));
    });

    test('traceId comes from the body, else the correlation header', () {
      final body = mapDioException(
        _badResponse(500, body: <String, Object?>{
          'status': 500,
          'traceId': 'trace-from-body',
        }),
      );
      expect(body.traceId, 'trace-from-body');

      final header = mapDioException(
        _badResponse(500, headers: <String, List<String>>{
          'x-correlation-id': <String>['trace-from-header'],
        }),
      );
      expect(header.traceId, 'trace-from-header');
    });

    test('a non-problem body (HTML error page) never invents a problem', () {
      final failure = mapDioException(
        _badResponse(503, body: '<html>502 Bad Gateway</html>'),
      );
      expect(failure.problem, isNull);
      expect(failure, isA<ServerFailure>());
    });

    test('toString never leaks the cause or the server prose', () {
      final failure = mapDioException(
        _badResponse(409, body: <String, Object?>{
          'type': 'https://jeeb/errors/offer-already-exists',
          'detail': 'You already sent an offer for request ORD-1.',
          'status': 409,
        }),
      );
      expect(failure.toString(), contains('offer-already-exists'));
      expect(failure.toString(), isNot(contains('ORD-1')));
    });
  });

  group('AppFailure.of', () {
    test('wraps a non-Dio throwable as unknown and keeps AppFailures', () {
      expect(AppFailure.of(const FormatException('bad')), isA<UnknownFailure>());
      const already = GoneFailure();
      expect(AppFailure.of(already), same(already));
    });
  });

  group('AppFailureInterceptor', () {
    test('attaches the classification to every error the client raises',
        () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
        ..interceptors.add(const AppFailureInterceptor())
        ..httpClientAdapter = _EchoAdapter(
          (_) => ResponseBody.fromString(
            '{"type":"https://jeeb/errors/gone","status":410}',
            410,
            headers: <String, List<String>>{
              Headers.contentTypeHeader: <String>[Headers.jsonContentType],
            },
          ),
        );

      Object? attached;
      try {
        await dio.get<dynamic>('/v1/offers');
      } on DioException catch (e) {
        attached = e.error;
      }
      expect(attached, isA<GoneFailure>());
      expect((attached! as GoneFailure).problem?.typeSuffix, 'gone');
    });

    test('is idempotent: an already-classified error is left alone', () {
      const failure = ConflictFailure();
      final err = DioException(requestOptions: _options(), error: failure);
      expect(mapDioException(err), same(failure));
    });
  });
}
