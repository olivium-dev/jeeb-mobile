import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../core/network/gateway_problem.dart';
import '../../settings/domain/profile_repository.dart';
import '../../settings/domain/user_profile.dart';
import '../domain/otp_service.dart';

class DioOtpService implements OtpService, OtpSendResultService {
  const DioOtpService(
    this._dio,
    this._tokenStore, {
    ProfileRepository? profileRepository,
  }) : _profileRepository = profileRepository;

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  final ProfileRepository? _profileRepository;

  @override
  Future<OtpSendOutcome> sendCode(String e164Phone) async =>
      (await requestCode(e164Phone)).outcome;

  @override
  Future<OtpSendResult> requestCode(String e164Phone) async {
    try {
      final response = await _dio.post(
        '/v1/auth/otp/request',
        data: {'phone': e164Phone},
      );
      final status = response.statusCode ?? 0;
      if (status >= 200 && status < 300) {
        return OtpSendResult(
          outcome: OtpSendOutcome.sent,
          ttlSeconds: _ttlSeconds(response.data),
        );
      }
      return const OtpSendResult(outcome: OtpSendOutcome.serverError);
    } on DioException catch (e) {
      final failure = AppFailure.of(e);
      return switch (failure) {
        RateLimitedFailure(:final Duration? retryAfter) => OtpSendResult(
          outcome: OtpSendOutcome.rateLimited,
          retryAfter: retryAfter,
        ),
        ValidationFailure() => const OtpSendResult(
          outcome: OtpSendOutcome.invalidPhone,
        ),
        // Only these two blame the connection: `UnknownFailure` covers cancel,
        // a null status and every unmapped 4xx, none of which is connectivity.
        NetworkFailure() || TimeoutFailure() => const OtpSendResult(
          outcome: OtpSendOutcome.networkError,
        ),
        _ => const OtpSendResult(outcome: OtpSendOutcome.serverError),
      };
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
      final status = response.statusCode ?? 0;
      if (status < 200 || status >= 300) return OtpVerifyOutcome.serverError;
      // A 2xx that carried no token pair is NOT a sign-in: reporting `verified`
      // here lands the user in an authenticated shell with an empty store.
      if (!await _persistTokens(response.data)) {
        return OtpVerifyOutcome.serverError;
      }
      await _persistSignInPhone(e164Phone);
      return OtpVerifyOutcome.verified;
    } on DioException catch (e) {
      final failure = AppFailure.of(e);
      return switch (failure) {
        UnauthorizedFailure() => OtpVerifyOutcome.invalidCode,
        RateLimitedFailure() => OtpVerifyOutcome.rateLimited,
        GoneFailure() => OtpVerifyOutcome.expired,
        ForbiddenFailure(:final GatewayProblem? problem)
            when _isAccountSuspended(problem) =>
          OtpVerifyOutcome.accountSuspended,
        ServerFailure(:final bool unavailable) => unavailable
            ? OtpVerifyOutcome.serviceUnavailable
            : OtpVerifyOutcome.serverError,
        // `UnknownFailure` is cancel / null status / unmapped 4xx — never the
        // user's connection, so it must not read as "check your connection".
        NetworkFailure() || TimeoutFailure() => OtpVerifyOutcome.networkError,
        _ => OtpVerifyOutcome.serverError,
      };
    }
  }

  /// False when the body carried no usable token pair, so the caller can refuse
  /// to report a sign-in that did not happen.
  Future<bool> _persistTokens(Object? body) async {
    // A blind `as Map` here threw a TypeError out of `verifyCode` for a 204 or
    // an HTML body — past every `on DioException` the cubit has.
    if (body is! Map) return false;
    final access = body['accessToken'] as String?;
    final refresh = body['refreshToken'] as String?;
    final user = body['user'];
    final userId = (user is Map ? (user['userId'] ?? user['id']) : null)
        as String?;
    if (access == null || refresh == null) return false;
    await _tokenStore.save(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
    );
    return true;
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
    } catch (e) {
      Diag.event('otp_signin_phone_persist_failed', {
        'kind': AppFailure.of(e).kind.name,
      });
    }
  }

  static int? _ttlSeconds(Object? body) {
    if (body is! Map) return null;
    final raw = body['ttlSeconds'] ?? body['ttl_seconds'];
    if (raw is int) return raw;
    if (raw is num) return raw.round();
    if (raw is String) return int.tryParse(raw.trim());
    return null;
  }
}

/// The gateway's suspended-login problem: `typeSuffix` cannot see the
/// `/auth/account_suspended` link, so the raw tail is checked too.
bool _isAccountSuspended(GatewayProblem? problem) {
  if (problem == null) return false;
  if (problem.accountStatus == 'suspended') return true;
  if (problem.typeSuffix == 'account_suspended') return true;
  return problem.type?.endsWith('/account_suspended') ?? false;
}
