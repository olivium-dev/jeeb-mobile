// AE-06: `_problemCode` read `data['code'] ?? data['title'] ?? data['type']`,
// none of which the gateway emits as a bare code, so `invalid_recovery_code`
// and `invalid_token` were UNREACHABLE. The problem's type suffix is the key.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/auth/data/dio_auth_repository.dart';
import 'package:jeeb_mobile/features/auth/domain/auth_repository.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function() _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async =>
      _respond();

  @override
  void close({bool force = false}) {}
}

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

DioAuthRepository _repo(int status, {String? typeSuffix}) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
    ..httpClientAdapter = _ScriptedAdapter(
      () => ResponseBody.fromString(
        jsonEncode(<String, Object?>{
          'status': status,
          if (typeSuffix != null)
            'type': 'https://problems.jeeb.lb/errors/$typeSuffix',
        }),
        status,
        headers: <String, List<String>>{
          Headers.contentTypeHeader: <String>[Headers.jsonContentType],
        },
      ),
    );
  return DioAuthRepository(dio, _MockAuthTokenStore());
}

Future<AuthFailure> _failureOf(DioAuthRepository repo) async {
  try {
    await repo.login(email: 'a@b.test', password: 'Password1');
  } on AuthRepositoryException catch (e) {
    return e.failure;
  }
  fail('expected an AuthRepositoryException');
}

void main() {
  test('401 invalid_recovery_code is reachable at last', () async {
    expect(
      await _failureOf(_repo(401, typeSuffix: 'invalid_recovery_code')),
      AuthFailure.invalidRecoveryCode,
    );
  });

  test('401 invalid_token is reachable at last', () async {
    expect(
      await _failureOf(_repo(401, typeSuffix: 'invalid_token')),
      AuthFailure.invalidToken,
    );
  });

  test('a bare 401 stays invalidCredentials', () async {
    expect(await _failureOf(_repo(401)), AuthFailure.invalidCredentials);
  });

  test('409 is an email collision', () async {
    expect(await _failureOf(_repo(409)), AuthFailure.emailCollision);
  });

  test('400 is a bad request', () async {
    expect(await _failureOf(_repo(400)), AuthFailure.badRequest);
  });

  test('503 is a serverError, never the caller\'s network', () async {
    final AuthFailure failure = await _failureOf(_repo(503));
    expect(failure, AuthFailure.serverError);
    expect(failure, isNot(AuthFailure.network));
  });

  test('500 is a serverError too', () async {
    expect(await _failureOf(_repo(500)), AuthFailure.serverError);
  });

  test('a connect timeout stays a network failure', () async {
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
      ..httpClientAdapter = _ScriptedAdapter(
        () => throw DioException(
          requestOptions: RequestOptions(path: '/v1/auth/login'),
          type: DioExceptionType.connectionTimeout,
        ),
      );

    expect(
      await _failureOf(DioAuthRepository(dio, _MockAuthTokenStore())),
      AuthFailure.network,
    );
  });

  test('a 404 falls through to unknown', () async {
    expect(await _failureOf(_repo(404)), AuthFailure.unknown);
  });
}
