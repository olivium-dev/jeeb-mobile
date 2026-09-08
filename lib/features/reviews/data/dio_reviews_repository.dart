import 'package:dio/dio.dart';

import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../domain/reviews_repository.dart';

class DioReviewsRepository implements ReviewsRepository {
  const DioReviewsRepository(
    this._dio, {
    OperationIdFactory? operationIdFactory,
  }) : _operationId = operationIdFactory ?? newOperationId;

  final Dio _dio;
  final OperationIdFactory _operationId;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final res = await _dio.get<Map<String, dynamic>>(
        '/v1/ratings/jeeb/reviews',
        queryParameters: <String, Object>{
          'jeeberId': jeeberId,
          'page': page,
          'pageSize': pageSize,
        },
      );
      return _parse(res.data ?? const <String, dynamic>{}, page);
    } on DioException catch (e) {
      throw ReviewsRepositoryException.classified(
        _map(e),
        message: e.message,
        appFailure: AppFailure.of(e),
      );
    }
  }

  @override
  Future<void> reportReview(String reviewId) async {
    try {
      // One key per report attempt: a transport-level replay of THIS POST is
      // deduped, while a user-tapped Retry is a fresh attempt.
      await _dio.post<void>(
        '/v1/ratings/jeeb/reviews/$reviewId/report',
        options: Options(
          headers: <String, Object?>{'Idempotency-Key': _operationId()},
        ),
      );
    } on DioException catch (e) {
      throw ReviewsRepositoryException.classified(
        _map(e),
        message: e.message,
        appFailure: AppFailure.of(e),
      );
    }
  }

  ReviewsPage _parse(Map<String, dynamic> json, int requestedPage) {
    final raw = json['items'] ?? json['reviews'];
    final list = raw is List ? raw : const <dynamic>[];
    final reviews = <ReviewItem>[];
    for (final item in list) {
      if (item is! Map) continue;
      // A missing score is not a 0.0-star review: skip it rather than
      // fabricate a rating (UX-47).
      final review = _review(item.cast<String, dynamic>());
      if (review != null) reviews.add(review);
    }
    final coldStart = json['coldStart'] == true || json['cold_start'] == true;
    return ReviewsPage(
      reviews: reviews,
      page: _int(json['page']) ?? requestedPage,
      totalPages: _int(json['totalPages'] ?? json['total_pages']) ?? 1,
      coldStart: coldStart,
      reviewCount:
          _int(json['reviewCount'] ?? json['review_count']) ?? reviews.length,
      averageScore: coldStart
          ? null
          : _numOrNull(json['averageScore'] ?? json['average_score']),
    );
  }

  ReviewItem? _review(Map<String, dynamic> json) {
    final score = _numOrNull(json['score'] ?? json['rating']);
    if (score == null) return null;
    return ReviewItem(
      id: _str(json['id']) ?? '',
      reviewerFirstName:
          _str(json['reviewerFirstName'] ?? json['reviewer_first_name']) ?? '',
      score: score,
      timestamp:
          _str(json['createdAt'] ?? json['ts'] ?? json['timestamp']) ?? '',
      body: _str(json['body'] ?? json['comment']),
      reportable: json['reportable'] != false,
    );
  }

  double? _numOrNull(Object? v) => (v is num) ? v.toDouble() : null;
  int? _int(Object? v) => (v is num) ? v.toInt() : null;

  String? _str(Object? v) {
    if (v is! String) return null;
    final t = v.trim();
    return t.isEmpty ? null : t;
  }

  ReviewsFailure _map(DioException e) {
    final code = e.response?.statusCode;
    if (code == 404) return ReviewsFailure.notFound;
    if (code == 401 || code == 403) return ReviewsFailure.unauthorized;
    switch (e.type) {
      case DioExceptionType.connectionError:
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.sendTimeout:
        return ReviewsFailure.network;
      default:
        return ReviewsFailure.unknown;
    }
  }
}
