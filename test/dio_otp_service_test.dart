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
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 429,
        ),
      );

      final outcome = await sut.sendCode('+96170000001');

      expect(outcome, OtpSendOutcome.rateLimited);
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

    test('returns accountSuspended on 403 carrying only accountStatus', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response(
          requestOptions: RequestOptions(path: ''),
          statusCode: 403,
          data: const {'accountStatus': 'suspended'},
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

      expect(outcome, OtpVerifyOutcome.networkError);
      expect(outcome, isNot(OtpVerifyOutcome.accountSuspended));
    });

    test('returns invalidCode on 401', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
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
