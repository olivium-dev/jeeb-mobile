import 'package:dio/dio.dart';

/// Gateway-backed prohibited-item flagging RPC.
class ProhibitedItemReportService {
  const ProhibitedItemReportService([this._dio]);

  final Dio? _dio;

  static const String _path = '/prohibited-items/reports';

  Future<void> report({
    required String requestId,
    required String reason,
  }) async {
    final cleanRequestId = requestId.trim();
    final cleanReason = reason.trim();
    if (cleanRequestId.isEmpty || cleanReason.isEmpty) {
      throw const ProhibitedItemReportException('missing report fields');
    }
    final dio = _dio;
    if (dio == null) return;
    try {
      await dio.post<void>(
        _path,
        data: <String, dynamic>{
          'requestId': cleanRequestId,
          'reason': cleanReason,
        },
      );
    } on DioException catch (e) {
      throw ProhibitedItemReportException('report RPC failed', e);
    }
  }
}

class ProhibitedItemReportException implements Exception {
  const ProhibitedItemReportException(this.message, [this.cause]);

  final String message;
  final Object? cause;

  @override
  String toString() =>
      'ProhibitedItemReportException($message${cause == null ? '' : ', $cause'})';
}
