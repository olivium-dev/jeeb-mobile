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
      // D16: the gateway now sends reasonCode; older builds still send only the
      // raw template, so derive it here too rather than depend on the deploy.
      final sentCode = (data['statusReasonCode'] ??
          data['status_reason_code'] ??
          data['reasonCode']) as String?;
      final code = (sentCode != null && sentCode.trim().isNotEmpty)
          ? sentCode.trim()
          : ModerationReasonWire.codeOf(rawReason);
      return AccountStatusInfo(
        value: AccountStatusValue.fromWire(data['status'] as String?),
        reason: ModerationReasonWire.humanReason(rawReason),
        reasonCode: code,
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
