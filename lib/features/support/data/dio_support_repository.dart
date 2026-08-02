import 'package:dio/dio.dart';

import '../domain/support_repository.dart';

class DioSupportRepository implements SupportRepository {
  const DioSupportRepository(this._dio);

  final Dio _dio;

  @override
  Future<SupportTicket> submitTicket(SupportTicketDraft draft) async {
    try {
      final res = await _dio.post<Map<String, dynamic>>(
        '/v1/support/tickets',
        data: <String, Object?>{
          'category': draft.category.name,
          'body': draft.body,
          if (draft.orderRef != null) 'orderRef': draft.orderRef,
          if (draft.attachmentPaths.isNotEmpty)
            'attachments': draft.attachmentPaths,
        },
      );
      final data = res.data ?? const <String, dynamic>{};
      return SupportTicket(
        id: _str(data['id'] ?? data['ticketId']) ?? '',
        status: _str(data['status']) ?? 'open',
      );
    } on DioException catch (e) {
      throw SupportRepositoryException(_map(e), e.message);
    }
  }

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  SupportFailure _map(DioException e) {
    final code = e.response?.statusCode;
    if (code == 401 || code == 403) return SupportFailure.unauthorized;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return SupportFailure.network;
      default:
        return SupportFailure.unknown;
    }
  }
}
