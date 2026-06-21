import 'package:dio/dio.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../domain/role_switch_repository.dart';

/// T-MOB-028: Dio-backed [RoleSwitchRepository].
///
/// Endpoint (useMockPrefixes=false, Mockoon :3055):
///   POST /v1/users/me/role/switch  body: { "role": "client" | "jeeber" }
///   → 200: role switched — body carries a freshly re-minted, capability-scoped
///          JWT pair (`accessToken` + `refreshToken`) for the now-active role.
///   → 403: KYC not approved
///
/// D-ROLE-TOGGLE (iter6): the gateway re-mints a jeeber-capable token on switch
/// (`UsersMeController.SwitchRole`), but the old `_dio.post<void>` discarded it,
/// so the [AuthTokenStore]-backed bearer stayed stale and every subsequent
/// jeeber route (earnings, availability) returned 403 forbidden-capability until
/// a full re-login. We now ADOPT the re-minted pair: on a 200 carrying both
/// tokens we swap the access+refresh PAIR together (kept in sync for logout).
/// If the body omits the tokens (the gateway's documented best-effort degrade
/// path), we KEEP the existing stored token rather than blanking the session.
///
/// Mock contract verified against Mockoon :3055 route map.
class DioRoleSwitchRepository implements RoleSwitchRepository {
  const DioRoleSwitchRepository(this._dio, this._tokenStore);

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  static const String _path = '/v1/users/me/role/switch';

  @override
  Future<RoleSwitchResult> switchRole(String role) async {
    try {
      final response =
          await _dio.post<Map<String, dynamic>>(_path, data: {'role': role});
      await _adoptRemintedTokens(response.data);
      return RoleSwitchResult.success;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return RoleSwitchResult.kycGated;
      throw RoleSwitchException(e.message ?? 'role switch failed');
    }
  }

  /// Persist the re-minted access+refresh pair from a successful switch.
  ///
  /// Degrades safely: a null body or missing/empty tokens leaves the current
  /// stored token untouched (no [AuthTokenStore.save], no [clear]).
  Future<void> _adoptRemintedTokens(Map<String, dynamic>? body) async {
    if (body == null) return;
    final access = body['accessToken'] as String?;
    final refresh = body['refreshToken'] as String?;
    if (access == null || access.isEmpty) return;
    if (refresh == null || refresh.isEmpty) return;
    final userId = body['userId'] as String?;
    await _tokenStore.save(
      accessToken: access,
      refreshToken: refresh,
      userId: userId,
    );
  }
}
