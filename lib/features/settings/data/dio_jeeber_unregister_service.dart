import 'package:dio/dio.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/gateway_problem.dart';
import '../../../core/network/auth_token_store.dart';
import '../domain/jeeber_unregister_service.dart';

/// Dio-backed [JeeberUnregisterService]: `POST /v1/users/me/role/unregister`.
///
/// The 409 discriminators (`active_delivery` / `positive_wallet_balance`) and
/// the dark-path `502 upstream_fault` are read from `type`, which the gateway
/// emits as a FULL RFC 7807 URI (`https://problems.jeeb.lb/users/<code>`) —
/// only the last path segment is the stable code (`GatewayProblem.typeSuffix`).
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
    } catch (e) {
      final AppFailure failure = AppFailure.of(e);
      Diag.event('jeeber_unregister_failed', {'kind': failure.kind.name});
      return _mapOutcome(failure, e);
    }
  }

  JeeberUnregisterOutcome _mapOutcome(AppFailure failure, Object error) {
    if (failure is NotFoundFailure) return JeeberUnregisterOutcome.notAJeeber;
    // Dark path: UM has no revoke op yet, gateway's UM call fails closed.
    if (failure is ServerFailure && failure.status == 502) {
      return JeeberUnregisterOutcome.unavailable;
    }
    if (failure is ConflictFailure) {
      switch (_typeSuffix(failure, error)) {
        case 'active_delivery':
          return JeeberUnregisterOutcome.activeDelivery;
        case 'positive_wallet_balance':
          return JeeberUnregisterOutcome.positiveBalance;
      }
    }
    return switch (failure.kind) {
      AppFailureKind.network ||
      AppFailureKind.timeout =>
        JeeberUnregisterOutcome.networkError,
      _ => JeeberUnregisterOutcome.serverError,
    };
  }

  /// This endpoint emits `https://problems.jeeb.lb/users/<code>`, not the
  /// `/errors/` shape `typeSuffix` recognises — last segment is the fallback.
  String? _typeSuffix(AppFailure failure, Object error) {
    final GatewayProblem? problem = failure.problem ??
        (error is DioException
            ? GatewayProblem.tryParse(error.response?.data)
            : null);
    return problem?.typeSuffix ?? _lastSegment(problem?.type);
  }

  static String? _lastSegment(String? type) {
    if (type == null || type.isEmpty) return null;
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
