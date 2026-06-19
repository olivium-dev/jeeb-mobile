import 'package:dio/dio.dart';

import '../domain/support_repository.dart';

/// Dio-backed [SupportRepository] (JM-063) — the support-ticket service (S1).
///
/// NOT the DI default yet: S1 is backend-owned and not yet mounted on `:4010`
/// (42_GUARDRAILS_MOCK §4), so `injection_container.dart` binds the
/// [StubSupportRepository] INTEGRATOR-STUB until S1 lands. This impl is the swap
/// target — repoint the DI registration here (and add a `/v1/support` rewrite
/// key) without touching the screen when S1 is verified.
///
/// Gateway path `/v1/support/tickets` (the expected S1 contract); the rewrite
/// key is added in the S1 hand-off. DO NOT hardcode the service prefix here
/// (40_GUARDRAILS_ARCH §4 / DO-NOT).
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
