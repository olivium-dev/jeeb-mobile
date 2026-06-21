import 'package:dio/dio.dart';

import '../domain/recipient_phone_resolver.dart';

/// Dio-backed [RecipientPhoneResolver] that defaults the recipient phone to the
/// SIGNED-IN client's own phone, read from the gateway getMe contract.
///
/// Endpoint (gateway contract; `MockGatewayClient` rewrites `/v1/users` →
/// `/user-management/users` for `:4010`):
///   GET /v1/users/me  → { id, phone, name, availableRoles, ... }
///
/// The `phone` field is the requester's E.164 number. Used as the default
/// recipient phone on `POST /requests` (T-BE-019 / JEB-55) so the gateway
/// request-store row carries a non-null `RecipientPhone` and the at-door
/// handover OTP can be issued/verified. Resolution is best-effort: any failure
/// (offline / 401 / malformed body) returns `null` so the order create proceeds
/// unchanged (the gateway field is optional).
class DioRecipientPhoneResolver implements RecipientPhoneResolver {
  const DioRecipientPhoneResolver(this._dio);

  final Dio _dio;

  // Gateway-contract path — DO NOT hardcode the `:4010` service prefix; the
  // MockGatewayClient interceptor rewrites `/v1/users` → `/user-management/users`.
  static const String _path = '/v1/users/me';

  @override
  Future<String?> resolve() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(_path);
      final json = response.data ?? const <String, dynamic>{};
      // snake_case + camelCase both accepted (defensive parse, 40_GUARDRAILS §4).
      final raw = json['phone'] ?? json['phoneE164'] ?? json['phone_e164'];
      if (raw is! String) return null;
      final trimmed = raw.trim();
      return trimmed.isEmpty ? null : trimmed;
    } catch (_) {
      // Best-effort: a default-phone lookup must never fail the order create.
      return null;
    }
  }
}
