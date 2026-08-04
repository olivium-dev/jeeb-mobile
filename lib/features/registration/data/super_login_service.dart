import 'package:dio/dio.dart';

enum SuperLoginError { invalidCredentials, network, unknown }

class SuperLoginSession {
  const SuperLoginSession({
    required this.userId,
    required this.accessToken,
    required this.refreshToken,
  });

  final String userId;
  final String accessToken;

  final String refreshToken;
}

sealed class SuperLoginResult {
  const SuperLoginResult();
}

class SuperLoginSuccess extends SuperLoginResult {
  const SuperLoginSuccess(this.session);
  final SuperLoginSession session;
}

class SuperLoginFailure extends SuperLoginResult {
  const SuperLoginFailure(this.error);
  final SuperLoginError error;
}

abstract class SuperLoginService {
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  });
}

class DefaultSuperLoginService implements SuperLoginService {
  DefaultSuperLoginService({required Dio dio}) : _dio = dio;

  final Dio _dio;

  static const String _endpoint = '/api/User/user-id-login';

  @override
  Future<SuperLoginResult> signIn({
    required String userId,
    required String passcode,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _endpoint,
        data: <String, dynamic>{
          'userId': userId,
          'superAdminPassCode': passcode,
        },
      );
      final data = response.data;
      if (data == null) {
        return const SuperLoginFailure(SuperLoginError.unknown);
      }
      final session = _parseSession(data);
      if (session == null) {
        return const SuperLoginFailure(SuperLoginError.invalidCredentials);
      }
      return SuperLoginSuccess(session);
    } on DioException catch (e) {
      return SuperLoginFailure(_mapDioError(e));
    }
  }

  SuperLoginSession? _parseSession(Map<String, dynamic> data) {
    final userId = data['userId'] as String?;
    final accessToken = data['authToken'] as String?;
    if (userId == null ||
        userId.isEmpty ||
        accessToken == null ||
        accessToken.isEmpty) {
      return null;
    }
    final refreshToken = data['refreshToken'] as String?;
    return SuperLoginSession(
      userId: userId,
      accessToken: accessToken,
      refreshToken:
          (refreshToken != null && refreshToken.isNotEmpty)
              ? refreshToken
              : accessToken,
    );
  }

  SuperLoginError _mapDioError(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return SuperLoginError.network;
      case DioExceptionType.badResponse:
        final status = e.response?.statusCode ?? 0;
        if (status == 400 || status == 401 || status == 403) {
          return SuperLoginError.invalidCredentials;
        }
        if (status >= 500) return SuperLoginError.network;
        return SuperLoginError.unknown;
      case DioExceptionType.cancel:
      case DioExceptionType.badCertificate:
      case DioExceptionType.transformTimeout:
      case DioExceptionType.unknown:
        return SuperLoginError.unknown;
    }
  }
}
