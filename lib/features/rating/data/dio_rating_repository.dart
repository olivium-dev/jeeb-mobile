import 'package:dio/dio.dart';

import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';

/// Dio-backed [RatingRepository].
///
/// Endpoint contract verified against Mockoon :3055 (useMockPrefixes=false):
///   POST /api/deliveries/{deliveryId}/rate
///     body: { stars, comment?, tags?, raterRole: "client"|"jeeber" }
///     → 200 SubmitRatingResponse
///   GET  /api/deliveries/{deliveryId}/rating
///     → 200 { status, counterpartRating? }
class DioRatingRepository implements RatingRepository {
  const DioRatingRepository(this._dio);

  final Dio _dio;

  @override
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  }) async {
    try {
      await _dio.post<void>(
        '/api/deliveries/$deliveryId/rate',
        data: {
          'stars': stars,
          'raterRole': isClient ? 'client' : 'jeeber',
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
      );
    } on DioException {
      throw Exception('Rating submission failed');
    }
  }

  @override
  Future<RatingStatus> fetchRatingStatus({required String deliveryId}) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/api/deliveries/$deliveryId/rating',
      );
      final data = response.data;
      if (data == null) throw Exception('Empty rating status response');
      return RatingStatus.fromJson(deliveryId, data);
    } on DioException {
      throw Exception('Failed to fetch rating status');
    }
  }
}
