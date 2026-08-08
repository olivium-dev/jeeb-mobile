import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/jeeber_unregister_service.dart';

/// Dio-backed [JeeberUnregisterService]: `POST /v1/users/me/role/unregister`.
///
/// The 409 discriminators (`active_delivery` / `positive_wallet_balance`) and
/// the dark-path `502 upstream_fault` are read from `type`, which the gateway
/// emits as a FULL RFC 7807 URI (`https://problems.jeeb.lb/users/<code>`) —
/// only the last path segment is the stable code, see [_shortType].
class DioJeeberUnregisterService implements JeeberUnregisterService {
  DioJeeberUnregisterService(this._dio, this._tokenStore);

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  static const String _path = '/v1/users/me/role/unregister';

  @override
  Future<JeeberUnregisterOutcome> unregister() async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(_path);
      await _adoptRemintedTokens(response.data);
      return JeeberUnregisterOutcome.success;
    } on DioException catch (e) {
      return _mapOutcome(e);
    } catch (_) {
      return JeeberUnregisterOutcome.networkError;
    }
  }

  JeeberUnregisterOutcome _mapOutcome(DioException e) {
    final status = e.response?.statusCode;
    if (status == 404) return JeeberUnregisterOutcome.notAJeeber;
    // Dark path: UM has no revoke op yet, gateway's UM call fails closed.
    if (status == 502) return JeeberUnregisterOutcome.unavailable;
    if (status == 409) {
      switch (_shortType(e.response?.data)) {
        case 'active_delivery':
          return JeeberUnregisterOutcome.activeDelivery;
        case 'positive_wallet_balance':
          return JeeberUnregisterOutcome.positiveBalance;
      }
    }
    return JeeberUnregisterOutcome.networkError;
  }

  /// Last path segment of a ProblemDetails `type` URI, or null if absent/
  /// unshaped — never guess a discriminator from an unrecognised body.
  String? _shortType(Object? body) {
    if (body is! Map) return null;
    final type = body['type'];
    if (type is! String || type.isEmpty) return null;
    final segments = type.split('/').where((s) => s.isNotEmpty).toList();
    return segments.isEmpty ? null : segments.last;
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
