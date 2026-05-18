import 'package:dio/dio.dart';

import '../domain/otp_service.dart';

/// [OtpService] backed by the mock backend at `/auth-service/auth/otp`.
///
/// The path-rewrite interceptor in [MockGatewayClient] translates gateway
/// paths to mock prefixes, so this service uses gateway-style paths.
class DioOtpService implements OtpService {
  const DioOtpService(this._dio);

  final Dio _dio;

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async {
    try {
      final response = await _dio.post(
        '/auth/otp/request',
        data: {'phone': e164Phone},
      );
      if (response.statusCode == 200 || response.statusCode == 201) {
        return OtpSendOutcome.sent;
      }
      return OtpSendOutcome.networkError;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) {
        return OtpSendOutcome.rateLimited;
      }
      return OtpSendOutcome.networkError;
    }
  }

  @override
  Future<OtpVerifyOutcome> verifyCode({
    required String e164Phone,
    required String code,
  }) async {
    try {
      final response = await _dio.post(
        '/auth/otp/verify',
        data: {'phone': e164Phone, 'code': code},
      );
      if (response.statusCode == 200) {
        return OtpVerifyOutcome.verified;
      }
      return OtpVerifyOutcome.networkError;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) {
        return OtpVerifyOutcome.invalidCode;
      }
      if (status == 410) {
        return OtpVerifyOutcome.expired;
      }
      return OtpVerifyOutcome.networkError;
    }
  }
}
