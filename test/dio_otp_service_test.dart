import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/registration/data/dio_otp_service.dart';
import 'package:jeeb_mobile/features/registration/domain/otp_service.dart';

/// Stub that records the last POST path and returns a fixed response.
class _FakeDio extends Fake implements Dio {
  String? lastPath;
  Map<String, dynamic>? lastData;
  Response<dynamic>? nextResponse;
  DioException? nextError;

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
    lastPath = path;
    lastData = data as Map<String, dynamic>?;
    if (nextError != null) throw nextError!;
    return nextResponse! as Response<T>;
  }
}

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

void main() {
  late _FakeDio dio;
  late _MockAuthTokenStore tokenStore;
  late DioOtpService sut;

  setUp(() {
    dio = _FakeDio();
    tokenStore = _MockAuthTokenStore();
    sut = DioOtpService(dio, tokenStore);
  });

  group('sendCode — endpoint contract (T-MOB-004)', () {
    test('calls POST /v1/auth/otp/request with the E.164 phone', () async {
      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {'ttlSeconds': 300},
      );

      await sut.sendCode('+96170000001');

      expect(dio.lastPath, '/v1/auth/otp/request');
      expect(dio.lastData?['phone'], '+96170000001');
    });

    test('returns sent on 200', () async {
      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {'ttlSeconds': 300},
      );

      final outcome = await sut.sendCode('+96170000001');

      expect(outcome, OtpSendOutcome.sent);
    });

    test('returns rateLimited on 429', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 429,
        ),
      );

      final outcome = await sut.sendCode('+96170000001');

      expect(outcome, OtpSendOutcome.rateLimited);
    });

    test('returns invalidPhone on 400', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 400,
        ),
      );

      final outcome = await sut.sendCode('+96170000001');

      expect(outcome, OtpSendOutcome.invalidPhone);
    });

    test('returns serverError on 502', () async {
      // 502 is representative of any 5xx or other unexpected response status.
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 502,
        ),
      );

      final outcome = await sut.sendCode('+96170000001');

      expect(outcome, OtpSendOutcome.serverError);
    });

    test('returns networkError when no response is received', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      );

      final outcome = await sut.sendCode('+96170000001');

      expect(outcome, OtpSendOutcome.networkError);
    });

    // AE-29: any 2xx is a send, not just 200.
    test('accepts 201 as sent', () async {
      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 201,
        data: {'ttlSeconds': 120},
      );

      expect(await sut.sendCode('+96170000001'), OtpSendOutcome.sent);
    });

    // AE-17 / F16: the 429 window is the SERVER's, not our policy's guess.
    test('requestCode carries Retry-After from a 429', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 429,
          headers: Headers.fromMap(<String, List<String>>{
            'retry-after': <String>['45'],
          }),
        ),
      );

      final result = await sut.requestCode('+96170000001');

      expect(result.outcome, OtpSendOutcome.rateLimited);
      expect(result.retryAfter, const Duration(seconds: 45));
    });

    // AE-29: the gateway's own code lifetime drives the cooldown when present.
    test('requestCode reads ttlSeconds in both spellings', () async {
      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {'ttlSeconds': 300},
      );
      expect((await sut.requestCode('+96170000001')).ttlSeconds, 300);

      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {'ttl_seconds': 90},
      );
      expect((await sut.requestCode('+96170000001')).ttlSeconds, 90);
    });

    test('a 503 is a server fault, never the caller\'s connection', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 503,
        ),
      );

      final result = await sut.requestCode('+96170000001');

      expect(result.outcome, OtpSendOutcome.serverError);
      expect(result.outcome, isNot(OtpSendOutcome.networkError));
    });
  });

  group('verifyCode — endpoint contract (T-MOB-004)', () {
    test('calls POST /v1/auth/otp/verify with phone and code', () async {
      when(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});

      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'accessToken': 'access-abc',
          'refreshToken': 'refresh-xyz',
          'user': {'userId': 'user-123', 'active_role': 'client'},
        },
      );

      await sut.verifyCode(e164Phone: '+96170000001', code: '1234');

      expect(dio.lastPath, '/v1/auth/otp/verify');
      expect(dio.lastData?['phone'], '+96170000001');
      expect(dio.lastData?['code'], '1234');
    });

    test('persists JWT pair to AuthTokenStore on success', () async {
      when(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});

      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'accessToken': 'access-abc',
          'refreshToken': 'refresh-xyz',
          'user': {'userId': 'user-123', 'active_role': 'client'},
        },
      );

      final outcome = await sut.verifyCode(
        e164Phone: '+96170000001',
        code: '1234',
      );

      expect(outcome, OtpVerifyOutcome.verified);
      verify(() => tokenStore.save(
            accessToken: 'access-abc',
            refreshToken: 'refresh-xyz',
            userId: 'user-123',
          )).called(1);
    });

    // Regression (sprint-7 step-login): the LIVE Express mock's OTP-verify
    test('persists userId from mock user.id shape (not userId)', () async {
      when(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});

      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: {
          'accessToken': 'mock-jwt-access-user-123',
          'refreshToken': 'mock-jwt-refresh-user-123',
          'expiresIn': 3600,
          'user': {'id': 'user-123', 'phone': '+96170000001', 'activeRole': 'client'},
        },
      );

      final outcome = await sut.verifyCode(
        e164Phone: '+96170000001',
        code: '1234',
      );

      expect(outcome, OtpVerifyOutcome.verified);
      verify(() => tokenStore.save(
            accessToken: 'mock-jwt-access-user-123',
            refreshToken: 'mock-jwt-refresh-user-123',
            userId: 'user-123',
          )).called(1);
    });

    // A suspended account used to fall through to networkError, which the OTP
    // screen renders as "Wrong code. Try again." — sending a suspended user to
    // re-enter a code that was already correct.
    test('returns accountSuspended on 403 with the problem type', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 403,
          data: const {
            'type': 'https://problems.jeeb.lb/auth/account_suspended',
            'title': 'Account is suspended.',
            'accountStatus': 'suspended',
          },
        ),
      );

      final outcome = await sut.verifyCode(
        e164Phone: '+96170000001',
        code: '123456',
      );

      expect(outcome, OtpVerifyOutcome.accountSuspended);
    });

    // No `type` link, but still a problem document (`status` is an RFC 7807
    // member) — the extension member alone is enough.
    test('returns accountSuspended on 403 without the type link', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 403,
          data: const {'status': 403, 'accountStatus': 'suspended'},
        ),
      );

      final outcome = await sut.verifyCode(
        e164Phone: '+96170000001',
        code: '123456',
      );

      expect(outcome, OtpVerifyOutcome.accountSuspended);
    });

    // A forbidden that is NOT a suspension must not be relabelled as one.
    test('a bare 403 is not treated as a suspension', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 403,
          data: const {'type': 'https://problems.jeeb.lb/auth/forbidden'},
        ),
      );

      final outcome = await sut.verifyCode(
        e164Phone: '+96170000001',
        code: '123456',
      );

      expect(outcome, OtpVerifyOutcome.serverError);
      expect(outcome, isNot(OtpVerifyOutcome.accountSuspended));
    });

    // F5 (P0): a 200 with no token pair used to report `verified` into an EMPTY
    // token store — an authenticated shell with no bearer.
    test('a 200 with no tokens is a serverError and writes nothing', () async {
      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {'user': {'userId': 'user-123'}},
      );

      final outcome = await sut.verifyCode(
        e164Phone: '+96170000001',
        code: '1234',
      );

      expect(outcome, OtpVerifyOutcome.serverError);
      verifyNever(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          ));
    });

    test('a 200 with a null body is a serverError and writes nothing', () async {
      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
      );

      expect(
        await sut.verifyCode(e164Phone: '+96170000001', code: '1234'),
        OtpVerifyOutcome.serverError,
      );
      verifyNever(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          ));
    });

    test('accepts a 201 verify with a full token pair', () async {
      when(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          )).thenAnswer((_) async {});

      dio.nextResponse = Response(
        requestOptions: RequestOptions(path: ''),
        statusCode: 201,
        data: {
          'accessToken': 'a',
          'refreshToken': 'r',
          'user': {'userId': 'user-1'},
        },
      );

      expect(
        await sut.verifyCode(e164Phone: '+96170000001', code: '1234'),
        OtpVerifyOutcome.verified,
      );
    });

    // AE-16 / F29: "sign-in is down" must never read as "check your connection".
    test('503 identity_unavailable is serviceUnavailable, not network', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 503,
          data: const {
            'type': 'https://problems.jeeb.lb/errors/identity_unavailable',
            'status': 503,
          },
        ),
      );

      final outcome = await sut.verifyCode(
        e164Phone: '+96170000001',
        code: '1234',
      );

      expect(outcome, OtpVerifyOutcome.serviceUnavailable);
      expect(outcome, isNot(OtpVerifyOutcome.networkError));
    });

    test('a 500 is a serverError, not a networkError', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
        ),
      );

      expect(
        await sut.verifyCode(e164Phone: '+96170000001', code: '1234'),
        OtpVerifyOutcome.serverError,
      );
    });

    test('a connect timeout stays a networkError', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionTimeout,
      );

      expect(
        await sut.verifyCode(e164Phone: '+96170000001', code: '1234'),
        OtpVerifyOutcome.networkError,
      );
    });

    test('returns invalidCode on 401', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 401,
        ),
      );

      final outcome = await sut.verifyCode(
        e164Phone: '+96170000001',
        code: '0000',
      );

      expect(outcome, OtpVerifyOutcome.invalidCode);
    });
  });
}
