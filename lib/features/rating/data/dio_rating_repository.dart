import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';

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
