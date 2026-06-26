import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/otp_service.dart';

/// [OtpService] backed by the Mockoon gateway mock at `/v1/auth/otp`.
///
/// Routes match the real gateway contract:
///   POST /v1/auth/otp/request → { ttlSeconds }
///   POST /v1/auth/otp/verify  → { accessToken, refreshToken, user }
///
/// On successful verify the JWT pair is persisted to [AuthTokenStore] so
/// all subsequent authenticated requests can read the access token.
class DioOtpService implements OtpService {
  const DioOtpService(this._dio, this._tokenStore);

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async {
    try {
      final response = await _dio.post(
        '/v1/auth/otp/request',
        data: {'phone': e164Phone},
      );
      final status = response.statusCode ?? 0;
      if (status == 200 || status == 201) return OtpSendOutcome.sent;
      return OtpSendOutcome.networkError;
    } on DioException catch (e) {
      if (e.response?.statusCode == 429) return OtpSendOutcome.rateLimited;
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
        '/v1/auth/otp/verify',
        data: {'phone': e164Phone, 'code': code},
      );
      if (response.statusCode == 200) {
        await _persistTokens(response.data as Map<String, dynamic>?);
        return OtpVerifyOutcome.verified;
      }
      return OtpVerifyOutcome.networkError;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) return OtpVerifyOutcome.invalidCode;
      // 429 is rate-limiting, NOT a wrong code — map to rateLimited so it does
      // not burn an attempt (consistent with sendCode's 429 handling above).
      if (status == 429) return OtpVerifyOutcome.rateLimited;
      if (status == 410) return OtpVerifyOutcome.expired;
      return OtpVerifyOutcome.networkError;
    }
  }

  Future<void> _persistTokens(Map<String, dynamic>? body) async {
    if (body == null) return;
    final access = body['accessToken'] as String?;
    final refresh = body['refreshToken'] as String?;
    final user = body['user'] as Map<String, dynamic>?;
    // The gateway/auth contract returns the identity under `userId`, but the
    // Express mock's OTP-verify handler emits it as `user.id` (it creates the
    // user with `id: uuidv4()`). Accept both so the OTP login path persists a
    // non-null userId on either backend — the auth-repo path already had this
    // `?? id` fallback; the OTP path silently dropped it (userId → null).
    final userId = (user?['userId'] ?? user?['id']) as String?;
    if (access == null || refresh == null) return;
    await _tokenStore.save(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
    );
  }
}
