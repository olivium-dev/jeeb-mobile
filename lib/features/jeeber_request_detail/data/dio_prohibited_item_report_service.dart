import 'package:dio/dio.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../domain/services/prohibited_item_report_service.dart';

/// JRD-03: the real report call. The base class stays a concrete const no-op so
/// the catalog entries and fixtures that construct it keep compiling (R3).
class DioProhibitedItemReportService extends ProhibitedItemReportService {
  DioProhibitedItemReportService(this._dio, {OperationIdFactory? newKey})
    : _newKey = newKey ?? newOperationId;

  final Dio _dio;

  final OperationIdFactory _newKey;

  /// One key per (request, reason), so a repeated report is the same mutation
  /// rather than a second row in the moderation queue.
  final Map<String, String> _keys = <String, String>{};

  @override
  Future<void> report({
    required String requestId,
    required String reason,
  }) async {
    final String slot = '$requestId:$reason';
    try {
      await _dio.post<void>(
        '/v1/requests/$requestId/report',
        data: <String, dynamic>{'reason': reason},
        options: Options(
          headers: <String, dynamic>{
            'Idempotency-Key': _keys.putIfAbsent(slot, _newKey),
          },
        ),
      );
      _keys.remove(slot);
    } on DioException catch (e) {
      throw AppFailure.of(e);
    }
  }
}
