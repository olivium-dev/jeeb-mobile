import 'package:dio/dio.dart';

import '../domain/cancel_request_repository.dart';

/// Dio-backed [CancelRequestRepository] for the JM-030 pre-accept cancel.
///
/// Endpoint (cycle-3 gateway, request-keyed cancel with canonical semantics):
///   DELETE /v1/requests/{id}
///     → 2xx  request released server-side
///     → 403  not the caller's request        → [CancelRequestFailure.forbidden]
///     → 404  unknown request id              → [CancelRequestFailure.notFound]
///     → 409  no longer cancellable           → [CancelRequestFailure.conflict]
///     (requestId == deliveryId convention; `POST /v1/requests/{id}/cancel`
///     is the equivalent verb-tunnelled alias.)
///
/// HISTORY: this repo used to POST the mock-era `/v1/delivery/cancel`, which
/// 404s on the real gateway, and swallowed the 404/422 — so customer
/// cancellations never reached the server while the UI pretended success
/// (P0 silent failure). Nothing is swallowed anymore: every non-2xx maps to a
/// typed [CancelRequestException] and the UI surfaces it.
class DioCancelRequestRepository implements CancelRequestRepository {
  const DioCancelRequestRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> cancelRequest({required String requestId}) async {
    try {
      await _dio.delete<dynamic>(
        '/v1/requests/${Uri.encodeComponent(requestId)}',
      );
    } on DioException catch (e) {
      throw CancelRequestException(_classify(e), e.message);
    }
  }

  static CancelRequestFailure _classify(DioException e) {
    switch (e.response?.statusCode) {
      case 409:
        return CancelRequestFailure.conflict;
      case 404:
        return CancelRequestFailure.notFound;
      case 403:
        return CancelRequestFailure.forbidden;
    }
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return CancelRequestFailure.network;
      // Every other transport shape (badResponse without a mapped status,
      // cancel, badCertificate, unknown) surfaces as `unknown` — surfaced,
      // never swallowed.
      default:
        return CancelRequestFailure.unknown;
    }
  }
}
