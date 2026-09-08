import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/settings/data/dio_account_service.dart';
import 'package:jeeb_mobile/features/settings/domain/account_service.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

/// Scriptable Dio: `post` either completes 204 or throws [error].
class _FakeDio extends Fake implements Dio {
  _FakeDio({this.error});

  final Object? error;
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
      statusCode: 204,
    );
  }
}

DioException _dioStatus(int status) => DioException(
      type: DioExceptionType.badResponse,
      requestOptions: RequestOptions(path: '/v1/auth/logout'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: '/v1/auth/logout'),
        statusCode: status,
      ),
    );

DioException _timeout() => DioException(
      requestOptions: RequestOptions(path: '/v1/auth/logout'),
      type: DioExceptionType.connectionTimeout,
    );

void main() {
  late _MockAuthTokenStore tokenStore;

  setUp(() {
    tokenStore = _MockAuthTokenStore();
    when(() => tokenStore.refreshToken).thenAnswer((_) async => 'rt-1');
    when(() => tokenStore.clear()).thenAnswer((_) async {});
  });

  group('DioAccountService.signOut — fail-safe (JEBV4-245)', () {
    test('2xx: clears the keystore and returns success', () async {
      final dio = _FakeDio();
      final sut = DioAccountService(dio, tokenStore);

      final outcome = await sut.signOut();

      expect(outcome, AccountActionOutcome.success);
      verify(() => tokenStore.clear()).called(1);
    });

    // The bug (JEBV4-245): a failed/absent logout used to leave the local
    final failures = <String, Object>{
      '404': _dioStatus(404),
      '5xx': _dioStatus(500),
      'timeout': _timeout(),
      'non-Dio': StateError('boom'),
    };

    failures.forEach((label, error) {
      test('$label: still clears the keystore and returns success', () async {
        final dio = _FakeDio(error: error);
        final sut = DioAccountService(dio, tokenStore);

        final outcome = await sut.signOut();

        expect(
          outcome,
          AccountActionOutcome.success,
          reason: '$label: sign-out must be fail-safe',
        );
        verify(() => tokenStore.clear()).called(1);
        expect(dio.postCalls, 1);
      });
    });
  });
}
