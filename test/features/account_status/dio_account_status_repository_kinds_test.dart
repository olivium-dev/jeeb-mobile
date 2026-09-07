// Critic A4 (the 44th enum): `_map` folded 403 AND every 5xx into `unknown`,
// so the screen could not tell a refusal from an outage.
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/account_status/data/dio_account_status_repository.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status.dart';
import 'package:jeeb_mobile/features/account_status/domain/account_status_repository.dart';

Dio _answering({int? status, DioExceptionType? type}) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (type != null) {
          handler.reject(DioException(requestOptions: options, type: type));
          return;
        }
        handler.reject(
          DioException(
            requestOptions: options,
            type: DioExceptionType.badResponse,
            response: Response<dynamic>(
              requestOptions: options,
              statusCode: status,
            ),
          ),
        );
      },
    ),
  );
  return dio;
}

Future<AccountStatusFailure> _failureFor(Dio dio) async {
  try {
    await DioAccountStatusRepository(dio).fetchStatus();
  } on AccountStatusRepositoryException catch (e) {
    return e.failure;
  }
  fail('expected an AccountStatusRepositoryException');
}

void main() {
  test('403 is forbidden, not unknown', () async {
    expect(
      await _failureFor(_answering(status: 403)),
      AccountStatusFailure.forbidden,
    );
  });

  for (final int status in <int>[500, 502, 503]) {
    test('$status is serverError, not unknown', () async {
      expect(
        await _failureFor(_answering(status: status)),
        AccountStatusFailure.serverError,
      );
    });
  }

  test('401 stays unauthorized', () async {
    expect(
      await _failureFor(_answering(status: 401)),
      AccountStatusFailure.unauthorized,
    );
  });

  test('a connect timeout is network', () async {
    expect(
      await _failureFor(
        _answering(type: DioExceptionType.connectionTimeout),
      ),
      AccountStatusFailure.network,
    );
  });

  test('a 200 still maps the status wire value', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'));
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) => handler.resolve(
          Response<dynamic>(
            requestOptions: options,
            statusCode: 200,
            data: <String, dynamic>{'status': 'suspended'},
          ),
        ),
      ),
    );

    final info = await DioAccountStatusRepository(dio).fetchStatus();

    expect(info.value, AccountStatusValue.suspended);
  });
}
