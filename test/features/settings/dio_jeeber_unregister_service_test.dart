import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/settings/data/dio_jeeber_unregister_service.dart';
import 'package:jeeb_mobile/features/settings/domain/jeeber_unregister_service.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

const _path = '/v1/users/me/role/unregister';

/// Scriptable Dio: `post` either completes 200 with [responseData] or throws
/// [error].
class _FakeDio extends Fake implements Dio {
  _FakeDio({this.responseData, this.error});

  final Map<String, dynamic>? responseData;
  final DioException? error;
  int postCalls = 0;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    postCalls++;
    final e = error;
    if (e != null) throw e;
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 200,
      data: responseData as T?,
    );
  }
}

DioException _dioError({
  required int status,
  Map<String, dynamic>? data,
}) =>
    DioException(
      requestOptions: RequestOptions(path: _path),
      // Real Dio always sets this for an HTTP error response; the classifier
      // reads it.
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: _path),
        statusCode: status,
        data: data,
      ),
    );

void main() {
  late _MockAuthTokenStore tokenStore;

  setUp(() {
    tokenStore = _MockAuthTokenStore();
    when(() => tokenStore.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {});
  });

  group('DioJeeberUnregisterService — outcome mapping', () {
    test('200: returns success and adopts the re-minted tokens', () async {
      final dio = _FakeDio(responseData: const {
        'accessToken': 'at-1',
        'refreshToken': 'rt-1',
        'userId': 'u-1',
        'activeRole': 'client',
        'availableRoles': ['client'],
      });
      final sut = DioJeeberUnregisterService(dio, tokenStore);

      final outcome = await sut.unregister();

      expect(outcome, JeeberUnregisterOutcome.success);
      verify(() => tokenStore.save(
            accessToken: 'at-1',
            refreshToken: 'rt-1',
            userId: 'u-1',
          )).called(1);
    });

    test('200 with no tokens in the body: still success, no token adopted',
        () async {
      final dio = _FakeDio(responseData: const {'activeRole': 'client'});
      final sut = DioJeeberUnregisterService(dio, tokenStore);

      final outcome = await sut.unregister();

      expect(outcome, JeeberUnregisterOutcome.success);
      verifyNever(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          ));
    });

    test('404 not_a_jeeber: maps to notAJeeber', () async {
      final dio = _FakeDio(
        error: _dioError(
          status: 404,
          data: {'type': 'https://problems.jeeb.lb/users/not_a_jeeber'},
        ),
      );
      final sut = DioJeeberUnregisterService(dio, tokenStore);

      expect(await sut.unregister(), JeeberUnregisterOutcome.notAJeeber);
    });

    test('409 active_delivery: maps to activeDelivery', () async {
      final dio = _FakeDio(
        error: _dioError(
          status: 409,
          data: {'type': 'https://problems.jeeb.lb/users/active_delivery'},
        ),
      );
      final sut = DioJeeberUnregisterService(dio, tokenStore);

      expect(await sut.unregister(), JeeberUnregisterOutcome.activeDelivery);
    });

    test('409 positive_wallet_balance: maps to positiveBalance', () async {
      final dio = _FakeDio(
        error: _dioError(
          status: 409,
          data: {
            'type': 'https://problems.jeeb.lb/users/positive_wallet_balance',
          },
        ),
      );
      final sut = DioJeeberUnregisterService(dio, tokenStore);

      expect(await sut.unregister(), JeeberUnregisterOutcome.positiveBalance);
    });

    // AE-21: a 409 the client does not recognise is a SERVER refusal, not a
    // connectivity problem — the old networkError blamed the user's signal.
    test('409 with an unrecognised type: falls back to serverError, never '
        'guesses a discriminator', () async {
      final dio = _FakeDio(
        error: _dioError(
          status: 409,
          data: {'type': 'https://problems.jeeb.lb/users/some_new_guard'},
        ),
      );
      final sut = DioJeeberUnregisterService(dio, tokenStore);

      expect(await sut.unregister(), JeeberUnregisterOutcome.serverError);
    });

    test('502 upstream_fault: maps to unavailable (the dark path), never '
        'success', () async {
      final dio = _FakeDio(
        error: _dioError(
          status: 502,
          data: {'type': 'https://problems.jeeb.lb/users/upstream_fault'},
        ),
      );
      final sut = DioJeeberUnregisterService(dio, tokenStore);

      expect(await sut.unregister(), JeeberUnregisterOutcome.unavailable);
    });

    test('timeout/connection error: maps to networkError', () async {
      final dio = _FakeDio(
        error: DioException(
          requestOptions: RequestOptions(path: _path),
          type: DioExceptionType.connectionTimeout,
        ),
      );
      final sut = DioJeeberUnregisterService(dio, tokenStore);

      expect(await sut.unregister(), JeeberUnregisterOutcome.networkError);
    });

    test('a non-Dio throw still resolves to an outcome, never rethrows',
        () async {
      final sut = DioJeeberUnregisterService(_ThrowingDio(), tokenStore);

      expect(await sut.unregister(), JeeberUnregisterOutcome.serverError);
    });
  });
}

/// Throws a plain (non-Dio) exception, exercising the service's outer
/// catch-all.
class _ThrowingDio extends Fake implements Dio {
  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    throw StateError('boom');
  }
}
