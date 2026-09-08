import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/registration/data/super_login_service.dart';

/// Stub Dio that records the last POST and returns a fixed response/error.
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

Response<Map<String, dynamic>> _resp(int status, Map<String, dynamic>? body) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: ''),
      statusCode: status,
      data: body,
    );

void main() {
  late _FakeDio dio;
  late DefaultSuperLoginService sut;

  setUp(() {
    dio = _FakeDio();
    sut = DefaultSuperLoginService(dio: dio);
  });

  group('FR-P0-4 super-login service — endpoint contract', () {
    test('POSTs {userId, superAdminPassCode} to /api/User/user-id-login',
        () async {
      dio.nextResponse = _resp(200, {
        'userId': 'super-user-001',
        'authToken': 'real-access-token',
        'refreshToken': 'real-refresh-token',
      });

      await sut.signIn(userId: 'super-user-001', passcode: 's3cret');

      expect(dio.lastPath, '/api/User/user-id-login');
      expect(dio.lastData?['userId'], 'super-user-001');
      expect(dio.lastData?['superAdminPassCode'], 's3cret');
    });

    test('returns a session with the REAL server tokens (never mock-jwt-*)',
        () async {
      dio.nextResponse = _resp(200, {
        'userId': 'super-user-001',
        'authToken': 'real-access-token',
        'refreshToken': 'real-refresh-token',
      });

      final result =
          await sut.signIn(userId: 'super-user-001', passcode: 's3cret');

      expect(result, isA<SuperLoginSuccess>());
      final session = (result as SuperLoginSuccess).session;
      expect(session.userId, 'super-user-001');
      expect(session.accessToken, 'real-access-token');
      expect(session.refreshToken, 'real-refresh-token');
      expect(session.accessToken, isNot(contains('mock-jwt')));
    });

    test('stores an EMPTY refreshToken when the route omits one', () async {
      // The gateway super-login route returns only {userId, authToken}.
      // Never substitute the access token: a fake refresh value turns the
      // clean "no refresh token -> logout" path into a doomed rotation.
      dio.nextResponse = _resp(200, {
        'userId': 'super-user-001',
        'authToken': 'um-audience-token',
      });

      final result =
          await sut.signIn(userId: 'super-user-001', passcode: 's3cret');

      final session = (result as SuperLoginSuccess).session;
      expect(session.refreshToken, isEmpty);
      expect(session.accessToken, 'um-audience-token');
    });
  });

  group('FR-P0-4 super-login service — error mapping', () {
    test('401 maps to invalidCredentials', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: _resp(401, {'error': 'unauthorized'}),
      );

      final result = await sut.signIn(userId: 'x', passcode: 'wrong');

      expect(result, isA<SuperLoginFailure>());
      expect((result as SuperLoginFailure).error,
          SuperLoginError.invalidCredentials);
    });

    test('400 maps to invalidCredentials', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: _resp(400, {'error': 'bad request'}),
      );

      final result = await sut.signIn(userId: 'x', passcode: 'wrong');
      expect((result as SuperLoginFailure).error,
          SuperLoginError.invalidCredentials);
    });

    test('connection error maps to network', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      );

      final result = await sut.signIn(userId: 'x', passcode: 'y');
      expect((result as SuperLoginFailure).error, SuperLoginError.network);
    });

    test('5xx maps to network', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.badResponse,
        response: _resp(503, {'error': 'unavailable'}),
      );

      final result = await sut.signIn(userId: 'x', passcode: 'y');
      expect((result as SuperLoginFailure).error, SuperLoginError.network);
    });

    test('a 200 with no token is treated as a credential rejection', () async {
      dio.nextResponse = _resp(200, {'userId': 'x'}); // missing authToken

      final result = await sut.signIn(userId: 'x', passcode: 'y');
      expect((result as SuperLoginFailure).error,
          SuperLoginError.invalidCredentials);
    });
  });
}
