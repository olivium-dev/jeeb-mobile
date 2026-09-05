// F5 (P0): `verifyCode` reported `verified` for a 2xx that carried no token
// pair, landing the user in an authenticated shell with an EMPTY store. These
// run through a real Dio + scripted adapter, so the whole transport path is
// under test — not just the outcome mapping.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/registration/data/dio_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options, int hit) _respond;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    return _respond(options, requests.length);
  }

  @override
  void close({bool force = false}) {}
}

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

ResponseBody _json(int status, Map<String, Object?> body) =>
    ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );

void main() {
  late _MockAuthTokenStore store;

  setUp(() {
    store = _MockAuthTokenStore();
    when(
      () => store.save(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
        userId: any(named: 'userId'),
      ),
    ).thenAnswer((_) async {});
  });

  DioOtpService sut(_ScriptedAdapter adapter) {
    final Dio dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
      ..httpClientAdapter = adapter;
    return DioOtpService(dio, store);
  }

  void verifyNothingSaved() {
    verifyNever(
      () => store.save(
        accessToken: any(named: 'accessToken'),
        refreshToken: any(named: 'refreshToken'),
        userId: any(named: 'userId'),
      ),
    );
  }

  test('a 200 with neither token is serverError and writes nothing', () async {
    final adapter = _ScriptedAdapter(
      (_, _) => _json(200, <String, Object?>{
        'user': <String, Object?>{'userId': 'u-1'},
      }),
    );

    final OtpVerifyOutcome outcome = await sut(adapter).verifyCode(
      e164Phone: '+96170000001',
      code: '1234',
    );

    expect(outcome, OtpVerifyOutcome.serverError);
    expect(outcome, isNot(OtpVerifyOutcome.verified));
    verifyNothingSaved();
  });

  test('a 200 carrying only an accessToken writes nothing', () async {
    final adapter = _ScriptedAdapter(
      (_, _) => _json(200, <String, Object?>{'accessToken': 'a'}),
    );

    expect(
      await sut(adapter).verifyCode(e164Phone: '+96170000001', code: '1234'),
      OtpVerifyOutcome.serverError,
    );
    verifyNothingSaved();
  });

  test('a 200 with both tokens verifies and saves exactly once', () async {
    final adapter = _ScriptedAdapter(
      (_, _) => _json(200, <String, Object?>{
        'accessToken': 'access-abc',
        'refreshToken': 'refresh-xyz',
        'user': <String, Object?>{'userId': 'u-1'},
      }),
    );

    expect(
      await sut(adapter).verifyCode(e164Phone: '+96170000001', code: '1234'),
      OtpVerifyOutcome.verified,
    );
    verify(
      () => store.save(
        accessToken: 'access-abc',
        refreshToken: 'refresh-xyz',
        userId: 'u-1',
      ),
    ).called(1);
  });

  // AE-29: the gateway may answer 201; only 200 used to count.
  test('a 201 with both tokens verifies too', () async {
    final adapter = _ScriptedAdapter(
      (_, _) => _json(201, <String, Object?>{
        'accessToken': 'a',
        'refreshToken': 'r',
        'user': <String, Object?>{'id': 'u-2'},
      }),
    );

    expect(
      await sut(adapter).verifyCode(e164Phone: '+96170000001', code: '1234'),
      OtpVerifyOutcome.verified,
    );
    verify(
      () => store.save(
        accessToken: 'a',
        refreshToken: 'r',
        userId: 'u-2',
      ),
    ).called(1);
  });

  test('a 204 is a serverError, not a sign-in', () async {
    final adapter = _ScriptedAdapter(
      (_, _) => ResponseBody.fromString('', 204),
    );

    expect(
      await sut(adapter).verifyCode(e164Phone: '+96170000001', code: '1234'),
      OtpVerifyOutcome.serverError,
    );
    verifyNothingSaved();
  });
}
