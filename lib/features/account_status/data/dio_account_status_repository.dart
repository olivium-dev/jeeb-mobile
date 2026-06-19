import 'package:dio/dio.dart';

import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';

/// LIVE [AccountStatusRepository] over the gateway `GET /users/me`
/// (`MockGatewayClient` rewrites `/users` → `/user-management/users` → :4010).
/// The mock surfaces the D5 `status` enum (U1 — 42_GUARDRAILS_MOCK W-1 FLOOR).
///
/// NOTE (authStub caveat — W-1 FLOOR): the mock's `authStub` resolves *any*
/// bearer to `user-client-001` for `/users/me`, so against the stock mock this
/// reads that user's status. The account-status screen is only ever shown
/// behind the blocked-account gate, and the suspended seam seeds the blocked
/// flag the gate reads; the per-state reason is best-effort. Distinguishing a
/// *specific* blocked jeeber would `GET /users/:id` by the persisted userId
/// (the gate's documented path) — out of scope for this body fill, which reads
/// the AC-named `GET /users/me`.
class DioAccountStatusRepository implements AccountStatusRepository {
  const DioAccountStatusRepository(this._dio);

  final Dio _dio;

  @override
  Future<AccountStatusInfo> fetchStatus() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/users/me');
      final data = res.data ?? const <String, dynamic>{};
      // Defensive parse (40_GUARDRAILS_ARCH §4): tolerate camel/snake reason
      // keys, normalise '' → null.
      final rawReason = (data['statusReason'] ??
          data['status_reason'] ??
          data['reason']) as String?;
      final reason =
          (rawReason != null && rawReason.trim().isNotEmpty) ? rawReason : null;
      return AccountStatusInfo(
        value: AccountStatusValue.fromWire(data['status'] as String?),
        reason: reason,
      );
    } on DioException catch (e) {
      throw AccountStatusRepositoryException(_map(e));
    }
  }

  AccountStatusFailure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return AccountStatusFailure.network;
    }
    if (e.response?.statusCode == 401) {
      return AccountStatusFailure.unauthorized;
    }
    return AccountStatusFailure.unknown;
  }
}
