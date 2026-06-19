import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';

/// Dio-backed [RatingRepository] (JM-034).
///
/// Speaks the gateway contract; `MockGatewayClient` rewrites `/v1/ratings/jeeb`
/// → `/score-taking-service/v1/ratings/jeeb` and sends it to the Express mock
/// on :4010. Verified against `src/services/score-taking-service.ts`:
///
///   POST /v1/ratings/jeeb/submit
///     body: { deliveryId, raterId, rateeId?, score, tags? }
///     → 200 { id, deliveryId, raterId, rateeId, score, tags, revealState }
///     (403 if the caller is not a party to the delivery)
///   GET  /v1/ratings/jeeb/{deliveryId}/status
///     → 200 { deliveryId, state, ratings, ratedCount }  (404 if un-rated)
///
/// `raterId` is REQUIRED by the mock and is resolved from the session
/// [AuthTokenStore] (the mock issues `mock-jwt-access-<userId>` tokens and the
/// store persists `auth.userId`). `rateeId` is best-effort: the mock derives
/// the counterpart from the delivery and tolerates its absence.
class DioRatingRepository implements RatingRepository {
  DioRatingRepository(this._dio, {AuthTokenStore? tokenStore})
      : _tokenStore = tokenStore ?? AuthTokenStore();

  final Dio _dio;
  final AuthTokenStore _tokenStore;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    try {
      final raterId = await _tokenStore.userId;
      await _dio.post<Map<String, dynamic>>(
        '/v1/ratings/jeeb/submit',
        data: <String, dynamic>{
          'deliveryId': deliveryId,
          if (raterId != null && raterId.isNotEmpty) 'raterId': raterId,
          'score': stars,
          'raterRole': isClient ? 'client' : 'jeeber',
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
      );
    } on DioException catch (e) {
      throw RatingRepositoryException(_map(e));
    }
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/ratings/jeeb/$deliveryId/status',
      );
      final data = response.data ?? const <String, dynamic>{};
      return RatingStatus.fromJson(deliveryId, data);
    } on DioException catch (e) {
      throw RatingRepositoryException(_map(e));
    }
  }

  RatingFailure _map(DioException e) {
    if (e.type == DioExceptionType.connectionError ||
        e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.sendTimeout) {
      return RatingFailure.network;
    }
    return RatingFailure.unknown;
  }
}
