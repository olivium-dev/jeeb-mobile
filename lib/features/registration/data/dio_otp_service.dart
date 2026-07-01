import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../../settings/domain/profile_repository.dart';
import '../../settings/domain/user_profile.dart';
import '../domain/otp_service.dart';

/// [OtpService] backed by the Mockoon gateway mock at `/v1/auth/otp`.
///
/// Routes match the real gateway contract:
///   POST /v1/auth/otp/request → { ttlSeconds }
///   POST /v1/auth/otp/verify  → { accessToken, refreshToken, user }
///
/// On successful verify the JWT pair is persisted to [AuthTokenStore] so
/// all subsequent authenticated requests can read the access token.
///
/// BUG-7 (recipient-phone-missing, physical-run6): on a successful verify the
/// E.164 phone the user SIGNED IN WITH is ALSO persisted to the local
/// [ProfileRepository] (`settings.profile.v1`) — the exact key the
/// [SharedPrefsRecipientPhoneResolver] reads for the default `recipientPhone` on
/// `POST /v1/requests`. Previously this key was NEVER written at sign-in (only
/// by profile-edit), so for a phone-OTP customer the resolver chain returned
/// null (the live `GET /v1/users/me` exposes NO `phone`), the create omitted
/// `recipientPhone`, the delivery row was `recipientPhone:null`, and the at-door
/// handover OTP issue/verify short-circuited 400 `recipient-phone-missing`
/// before the code was ever evaluated. Persisting the sign-in phone here gives
/// the resolver a guaranteed non-null E.164 fallback independent of the server
/// profile.
class DioOtpService implements OtpService {
  const DioOtpService(
    this._dio,
    this._tokenStore, {
    ProfileRepository? profileRepository,
  }) : _profileRepository = profileRepository;

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  /// Optional local profile store. When provided, the E.164 phone from a
  /// successful verify is written here so the recipient-phone resolver has a
  /// guaranteed default. Nullable so the unit tests that only assert the JWT
  /// persistence can omit it; DI always injects [SharedPrefsProfileRepository].
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
        // BUG-7: persist the signed-in E.164 phone as the default recipient
        // phone. Best-effort — a failure here must never fail the sign-in.
        await _persistSignInPhone(e164Phone);
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

  /// Persists [e164Phone] (the number the user just authenticated with) into the
  /// local profile under `settings.profile.v1`, MERGING over any existing
  /// profile so an edited name/photo survives. This is the deterministic source
  /// the [SharedPrefsRecipientPhoneResolver] reads for the default
  /// `recipientPhone`. Best-effort: any storage/parse fault degrades to a no-op
  /// so a default-phone write can NEVER fail the sign-in.
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
      // A default-recipient-phone write must NEVER break authentication.
    }
  }
}
