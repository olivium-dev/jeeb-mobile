import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/network/gateway_problem.dart';

void main() {
  const samples = <AppFailureKind, AppFailure>{
    AppFailureKind.network: NetworkFailure(offline: true),
    AppFailureKind.timeout:
        TimeoutFailure(phase: DioExceptionType.receiveTimeout),
    AppFailureKind.server: ServerFailure(status: 503),
    AppFailureKind.unauthorized: UnauthorizedFailure(),
    AppFailureKind.forbidden: ForbiddenFailure(reasonCode: 'account_suspended'),
    AppFailureKind.notFound: NotFoundFailure(),
    AppFailureKind.conflict: ConflictFailure(),
    AppFailureKind.gone: GoneFailure(),
    AppFailureKind.validation: ValidationFailure(field: 'phone'),
    AppFailureKind.rateLimited: RateLimitedFailure(),
    AppFailureKind.unknown: UnknownFailure(),
  };

  group('AppFailureKind coverage', () {
    test('every kind has exactly one subtype and every subtype is an Exception',
        () {
      expect(samples.length, AppFailureKind.values.length);
      expect(samples.keys, containsAll(AppFailureKind.values));
      for (final entry in samples.entries) {
        expect(entry.value.kind, entry.key);
        expect(entry.value, isA<Exception>());
      }
    });
  });

  group('isRetryable', () {
    test('recovering authentication retries while terminal variants do not', () {
      expect(const UnauthorizedFailure(recovering: true).isRetryable, isTrue);
      expect(const UnauthorizedFailure().isRetryable, isFalse);
      expect(
        const UnauthorizedFailure(storeUnavailable: true).isRetryable,
        isFalse,
      );
      expect(
        const UnauthorizedFailure(recovering: true, storeUnavailable: true)
            .isRetryable,
        isTrue,
      );
    });

    const table = <AppFailureKind, bool>{
      AppFailureKind.network: true,
      AppFailureKind.timeout: true,
      AppFailureKind.server: true,
      AppFailureKind.rateLimited: true,
      AppFailureKind.unknown: true,
      AppFailureKind.unauthorized: false,
      AppFailureKind.forbidden: false,
      AppFailureKind.notFound: false,
      AppFailureKind.conflict: false,
      AppFailureKind.gone: false,
      AppFailureKind.validation: false,
    };

    test('matches the retry table for every kind', () {
      expect(table.length, AppFailureKind.values.length);
      for (final entry in table.entries) {
        expect(
          samples[entry.key]!.isRetryable,
          entry.value,
          reason: 'isRetryable for ${entry.key.name}',
        );
      }
    });

    test('a parse failure stays retryable as an unknown kind', () {
      const failure = UnknownFailure(parse: true);
      expect(failure.parse, isTrue);
      expect(failure.isRetryable, isTrue);
    });
  });

  group('AppFailure.of', () {
    test('passes an already-classified failure through untouched', () {
      const failure = ServerFailure(status: 500, traceId: 'trace-1');
      expect(identical(AppFailure.of(failure), failure), isTrue);
      const validation = ValidationFailure(field: 'phone');
      expect(identical(AppFailure.of(validation), validation), isTrue);
    });

    test('wraps a non-Dio error as UnknownFailure carrying the cause', () {
      const error = FormatException('bad payload');
      final failure = AppFailure.of(error);
      expect(failure, isA<UnknownFailure>());
      expect(failure.kind, AppFailureKind.unknown);
      expect(failure.cause, same(error));
      expect(failure.problem, isNull);
      expect(failure.traceId, isNull);
    });

    test('wraps a StateError from a repository', () {
      final failure = AppFailure.of(StateError('no session'));
      expect(failure, isA<UnknownFailure>());
      expect((failure as UnknownFailure).parse, isFalse);
    });
  });

  group('subtype payloads', () {
    test('NetworkFailure distinguishes offline from unreachable', () {
      expect(const NetworkFailure(offline: true).offline, isTrue);
      expect(const NetworkFailure().offline, isFalse);
    });

    test('TimeoutFailure keeps the phase', () {
      const failure = TimeoutFailure(phase: DioExceptionType.sendTimeout);
      expect(failure.phase, DioExceptionType.sendTimeout);
    });

    test('ServerFailure.unavailable is true only for 502/503/504', () {
      expect(const ServerFailure(status: 500).unavailable, isFalse);
      expect(const ServerFailure(status: 502).unavailable, isTrue);
      expect(const ServerFailure(status: 503).unavailable, isTrue);
      expect(const ServerFailure(status: 504).unavailable, isTrue);
      expect(
        const ServerFailure(status: 503, retryAfter: Duration(seconds: 20))
            .retryAfter,
        const Duration(seconds: 20),
      );
    });

    test('UnauthorizedFailure carries the refresh and store flags', () {
      const failure =
          UnauthorizedFailure(recovering: true, storeUnavailable: true);
      expect(failure.recovering, isTrue);
      expect(failure.storeUnavailable, isTrue);
      expect(const UnauthorizedFailure().recovering, isFalse);
      expect(const UnauthorizedFailure().storeUnavailable, isFalse);
    });

    test('ValidationFailure defaults to no field errors', () {
      expect(const ValidationFailure().fieldErrors, isEmpty);
      expect(const ValidationFailure().field, isNull);
    });

    test('RateLimitedFailure distinguishes local suppression from a 429', () {
      const local = RateLimitedFailure(
        retryAfter: Duration(seconds: 5),
        localSuppression: true,
      );
      expect(local.localSuppression, isTrue);
      expect(local.retryAfter, const Duration(seconds: 5));
      expect(const RateLimitedFailure().localSuppression, isFalse);
    });
  });

  group('problem and traceId plumbing', () {
    test('a parsed problem and traceId ride along on any subtype', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/offer-already-exists',
        'status': 409,
        'traceId': 'trace-42',
      });
      final failure =
          ConflictFailure(problem: problem, traceId: problem!.traceId);
      expect(failure.problem!.typeSuffix, 'offer-already-exists');
      expect(failure.traceId, 'trace-42');
      expect(failure.kind, AppFailureKind.conflict);
      expect(failure.isRetryable, isFalse);
    });

    test('ValidationFailure mirrors the problem errors{} map', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/validation-failed',
        'status': 400,
        'errors': <String, Object?>{
          'phone': <String>['Invalid number.'],
        },
        'field': 'phone',
      });
      final failure = ValidationFailure(
        problem: problem,
        fieldErrors: problem!.errors,
        field: problem.field,
      );
      expect(failure.fieldErrors['phone'], <String>['Invalid number.']);
      expect(failure.field, 'phone');
    });
  });

  group('value semantics', () {
    test('subtypes are const-constructible and canonicalised', () {
      expect(
        identical(const NotFoundFailure(), const NotFoundFailure()),
        isTrue,
      );
      expect(
        identical(
          const ServerFailure(status: 500),
          const ServerFailure(status: 500),
        ),
        isTrue,
      );
    });

    test('== and hashCode compare kind and payload', () {
      expect(
        const ServerFailure(status: 500),
        const ServerFailure(status: 500),
      );
      expect(
        const ServerFailure(status: 500).hashCode,
        const ServerFailure(status: 500).hashCode,
      );
      expect(
        const ServerFailure(status: 500) == const ServerFailure(status: 503),
        isFalse,
      );
      expect(
        const NetworkFailure(offline: true) == const NetworkFailure(),
        isFalse,
      );
      expect(
        const RateLimitedFailure(localSuppression: true) ==
            const RateLimitedFailure(),
        isFalse,
      );
    });

    test('different subtypes with the same base fields are not equal', () {
      expect(
        const NotFoundFailure(traceId: 'x') == const GoneFailure(traceId: 'x'),
        isFalse,
      );
      expect(
        const ConflictFailure() == const GoneFailure(),
        isFalse,
      );
    });

    test('ValidationFailure compares field errors structurally', () {
      Map<String, List<String>> phoneErrors(String message) =>
          <String, List<String>>{
            'phone': <String>[message],
          };
      final a = ValidationFailure(fieldErrors: phoneErrors('Invalid number.'));
      final b = ValidationFailure(fieldErrors: phoneErrors('Invalid number.'));
      final c = ValidationFailure(fieldErrors: phoneErrors('Required.'));
      expect(a, b);
      expect(identical(a.fieldErrors, b.fieldErrors), isFalse);
      expect(a == c, isFalse);
    });
  });

  group('toString', () {
    test('names the subtype and its discriminating payload', () {
      expect(
        const NetworkFailure(offline: true).toString(),
        'NetworkFailure(offline: true)',
      );
      expect(
        const ServerFailure(status: 503, traceId: 'trace-9').toString(),
        'ServerFailure(status: 503, traceId: trace-9)',
      );
      expect(const NotFoundFailure().toString(), 'NotFoundFailure()');
      expect(
        const TimeoutFailure(phase: DioExceptionType.connectionTimeout)
            .toString(),
        contains('connectionTimeout'),
      );
    });

    test('includes the problem type suffix but never the server prose', () {
      final problem = GatewayProblem.tryParse(const <String, Object?>{
        'type': 'https://jeeb.dev/errors/prohibited-item-blocked',
        'title': 'Conflict',
        'detail': 'Recipient 03 555 123 asked for a knife.',
        'status': 409,
      });
      final text = ConflictFailure(problem: problem).toString();
      expect(text, contains('prohibited-item-blocked'));
      expect(text, isNot(contains('Recipient')));
      expect(text, isNot(contains('knife')));
    });

    test('never leaks the cause payload', () {
      final failure = UnknownFailure(
        cause: DioException(
          requestOptions: RequestOptions(
            path: '/v1/wallet',
            headers: <String, Object?>{'Authorization': 'Bearer secret-token'},
          ),
          error: 'secret-token',
        ),
      );
      final text = failure.toString();
      expect(text, 'UnknownFailure(parse: false, hasCause: true)');
      expect(text, isNot(contains('secret-token')));
      expect(text, isNot(contains('/v1/wallet')));
    });
  });
}
