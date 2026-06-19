import 'package:dio/dio.dart';

import '../domain/cancel_request_repository.dart';

/// Dio-backed [CancelRequestRepository] for the JM-030 pre-accept cancel.
///
/// Endpoint (30_BACKLOG JM-030 · 42_GUARDRAILS_MOCK §4):
///   POST /v1/delivery/cancel
///     → MockGatewayClient rewrites `/v1/delivery` → `/delivery-service/v1/delivery`
///     body: { "requestId": <id>, "deliveryId": <id>, "trigger": "client_pre_accept" }
///
/// CONTRACT GAP (flagged in handoff): the mock handler is delivery-keyed and
/// SM-1-gated (`delivery-service.ts` l.204). A pending request has no delivery,
/// so a `requestId`-only body 404s (`not_found`) — and even a deliveryId in a
/// non-cancellable state 422s (`transition_not_allowed`). Per D69 the pre-accept
/// cancel is FREE and always allowed, so those two responses are treated as a
/// benign no-op: the request is released client-side and the flow routes home.
/// Only a hard transport error blocks the happy path.
class DioCancelRequestRepository implements CancelRequestRepository {
  const DioCancelRequestRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> cancelRequest({required String requestId}) async {
    try {
      // Gateway-contract path; the interceptor rewrites the `:4010` prefix.
      await _dio.post<dynamic>(
        '/v1/delivery/cancel',
        // Both keys sent: `requestId` is the real intent; `deliveryId` mirrors
        // it so the current delivery-keyed mock can match when a request and
        // its (future) delivery share an id. Harmless extras are ignored.
        data: <String, dynamic>{
          'requestId': requestId,
          'deliveryId': requestId,
          'trigger': 'client_pre_accept',
        },
      );
    } on DioException catch (e) {
      final status = e.response?.statusCode;

      // 404 (no delivery exists for a still-pending request) and
      // 422 (SM-1 rejected the transition) are EXPECTED for a pre-accept cancel
      // against the delivery-keyed mock. D69 makes the cancel free + always
      // allowed, so swallow these and let the flow complete (route home).
      if (status == 404 || status == 422) {
        return;
      }

      if (e.type == DioExceptionType.connectionError ||
          e.type == DioExceptionType.connectionTimeout ||
          e.type == DioExceptionType.sendTimeout ||
          e.type == DioExceptionType.receiveTimeout) {
        throw const CancelRequestException(CancelRequestFailure.network);
      }

      // Any other server error is soft — surfaced as unknown; the cubit treats
      // it as a non-blocking failure (the request is still released locally).
      throw const CancelRequestException(CancelRequestFailure.unknown);
    }
  }
}
