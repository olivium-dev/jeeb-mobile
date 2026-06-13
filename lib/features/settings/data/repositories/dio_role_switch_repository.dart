import 'package:dio/dio.dart';

import '../../domain/role_switch_repository.dart';

/// T-MOB-028: Dio-backed [RoleSwitchRepository].
///
/// Endpoint (useMockPrefixes=false, Mockoon :3055):
///   POST /v1/users/me/role/switch  body: { "role": "client" | "jeeber" }
///   → 200: role switched
///   → 403: KYC not approved
///
/// Mock contract verified against Mockoon :3055 route map.
class DioRoleSwitchRepository implements RoleSwitchRepository {
  const DioRoleSwitchRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/users/me/role/switch';

  @override
  Future<RoleSwitchResult> switchRole(String role) async {
    try {
      await _dio.post<void>(_path, data: {'role': role});
      return RoleSwitchResult.success;
    } on DioException catch (e) {
      if (e.response?.statusCode == 403) return RoleSwitchResult.kycGated;
      throw RoleSwitchException(e.message ?? 'role switch failed');
    }
  }
}
