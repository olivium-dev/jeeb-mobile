import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../../settings/domain/profile_repository.dart';
import '../../settings/domain/user_profile.dart';
import '../domain/otp_service.dart';

class DioOtpService implements OtpService {
  const DioOtpService(
    this._dio,
    this._tokenStore, {
    ProfileRepository? profileRepository,
  }) : _profileRepository = profileRepository;

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  final ProfileRepository? _profileRepository;

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
      final response = e.response;
      if (response == null) return OtpSendOutcome.networkError;
      final status = response.statusCode;
      if (status == 429) return OtpSendOutcome.rateLimited;
      if (status == 400) return OtpSendOutcome.invalidPhone;
      return OtpSendOutcome.serverError;
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
        await _persistSignInPhone(e164Phone);
        return OtpVerifyOutcome.verified;
      }
      return OtpVerifyOutcome.networkError;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      if (status == 401) return OtpVerifyOutcome.invalidCode;
      if (status == 429) return OtpVerifyOutcome.rateLimited;
      if (status == 410) return OtpVerifyOutcome.expired;
      if (status == 403 && _isAccountSuspended(e.response?.data)) {
        return OtpVerifyOutcome.accountSuspended;
      }
      return OtpVerifyOutcome.networkError;
    }
  }

  Future<void> _persistTokens(Map<String, dynamic>? body) async {
    if (body == null) return;
    final access = body['accessToken'] as String?;
    final refresh = body['refreshToken'] as String?;
    final user = body['user'] as Map<String, dynamic>?;
    final userId = (user?['userId'] ?? user?['id']) as String?;
    if (access == null || refresh == null) return;
    await _tokenStore.save(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
    );
  }

  Future<void> _persistSignInPhone(String e164Phone) async {
    final repo = _profileRepository;
    if (repo == null) return;
    final phone = e164Phone.trim();
    if (phone.isEmpty) return;
    try {
      final existing = await repo.load();
      final merged = existing == null
          ? UserProfile(phoneE164: phone)
          : existing.copyWith(phoneE164: phone);
      await repo.save(merged);
    } catch (_) {
    }
  }
}

/// The gateway's suspended-login problem, per OtpSignInProblems:
///   type = https://problems.jeeb.lb/auth/account_suspended
///   accountStatus = "suspended"
/// Either field is sufficient; a bare 403 without them is NOT treated as a
/// suspension, so an unrelated forbidden never renders as one.
bool _isAccountSuspended(Object? body) {
  if (body is! Map) return false;
  final type = body['type'];
  if (type is String && type.endsWith('/account_suspended')) return true;
  return body['accountStatus'] == 'suspended';
}
