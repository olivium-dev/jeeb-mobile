import 'package:dio/dio.dart';

import '../../../../core/network/auth_token_store.dart';
import '../../domain/role_switch_repository.dart';

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
