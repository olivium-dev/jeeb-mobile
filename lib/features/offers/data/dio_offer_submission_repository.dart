import 'package:dio/dio.dart';

import '../domain/offer_submission_repository.dart';

/// Dio-backed [OfferSubmissionRepository].
///
/// Endpoint contract (Mockoon :3055, useMockPrefixes=false):
///   POST /v1/offers
///   body: { requestId, priceUsd, etaMinutes, note }
///   200 → { offerId, conversationId }
///   409 → request already claimed (race)
///   422 → validation echo
class DioOfferSubmissionRepository implements OfferSubmissionRepository {
  const DioOfferSubmissionRepository(this._dio);

  final Dio _dio;

  static const String _path = '/v1/offers';

  @override
  Future<OfferSubmissionResult> submitOffer({
    required String requestId,
    required double priceUsd,
    required int etaMinutes,
    String? note,
  }) async {
    try {
      final response = await _dio.post<Map<String, dynamic>>(
        _path,
        data: _buildBody(requestId, priceUsd, etaMinutes, note),
      );
      return _parseResult(response.data);
    } on DioException catch (e) {
      throw _mapDioError(e);
    }
  }

  Map<String, dynamic> _buildBody(
    String requestId,
    double priceUsd,
    int etaMinutes,
    String? note,
  ) {
    return {
      'requestId': requestId,
      'priceUsd': priceUsd,
      'etaMinutes': etaMinutes,
      if (note != null && note.isNotEmpty) 'note': note,
    };
  }

  OfferSubmissionResult _parseResult(Map<String, dynamic>? data) {
    final offerId = data?['offerId'] as String? ?? '';
    final conversationId = data?['conversationId'] as String? ?? '';
    return OfferSubmissionResult(
      offerId: offerId,
      conversationId: conversationId,
    );
  }

  OfferSubmissionException _mapDioError(DioException e) {
    final status = e.response?.statusCode;
    if (status == 409) {
      return const OfferSubmissionException(OfferSubmissionFailure.requestGone);
    }
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout) {
      return const OfferSubmissionException(OfferSubmissionFailure.network);
    }
    return OfferSubmissionException(
      OfferSubmissionFailure.server,
      'HTTP $status',
    );
  }
}
