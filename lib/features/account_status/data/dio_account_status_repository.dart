import 'package:dio/dio.dart';

import '../domain/account_status.dart';
import '../domain/account_status_repository.dart';

class DioAccountStatusRepository implements AccountStatusRepository {
  const DioAccountStatusRepository(this._dio);

  final Dio _dio;

  @override
  Future<AccountStatusInfo> fetchStatus() async {
    try {
      final res = await _dio.get<Map<String, dynamic>>('/v1/users/me');
      final data = res.data ?? const <String, dynamic>{};
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
