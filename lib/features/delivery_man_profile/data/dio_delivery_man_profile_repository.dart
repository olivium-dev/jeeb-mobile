import 'package:dio/dio.dart';

import '../../../core/network/app_failure.dart';
import '../domain/delivery_man_profile_repository.dart';
import '../domain/delivery_man_profile_view_data.dart';

/// Reads the proven `/v1/ratings/jeeb/reviews` contract directly, for the case
/// where no `ReviewsRepository` is registered.
class DioDeliveryManProfileRepository implements DeliveryManProfileRepository {
  const DioDeliveryManProfileRepository(this._dio);

  final Dio _dio;

  @override
  Future<DeliveryManReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    try {
      final Response<Map<String, dynamic>> res =
          await _dio.get<Map<String, dynamic>>(
        '/v1/ratings/jeeb/reviews',
        queryParameters: <String, Object>{
          'jeeberId': jeeberId,
          'page': page,
          'pageSize': pageSize,
        },
      );
      final Map<String, dynamic>? body = res.data;
      // A missing body is a broken contract, never "no reviews yet".
      if (body == null) throw const UnknownFailure(parse: true);
      return _parse(body, page);
    } on DioException catch (e) {
      throw AppFailure.of(e);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(cause: e, parse: true);
    }
  }

  DeliveryManReviewsPage _parse(Map<String, dynamic> json, int requestedPage) {
    final Object? raw = json['items'] ?? json['reviews'];
    if (raw is! List) throw const UnknownFailure(parse: true);
    final List<dynamic> list = raw;
    final List<DeliveryReviewData> reviews = <DeliveryReviewData>[];
    for (final dynamic item in list) {
      if (item is Map) {
        reviews.add(_review(item.cast<String, dynamic>()));
      }
    }
    final int page = _int(json['page']) ?? requestedPage;
    final int totalPages = _int(json['totalPages'] ?? json['total_pages']) ?? 1;
    final bool coldStart =
        json['coldStart'] == true || json['cold_start'] == true;
    return DeliveryManReviewsPage(
      reviews: reviews,
      reviewCount:
          _int(json['reviewCount'] ?? json['review_count']) ?? reviews.length,
      averageScore: coldStart
          ? null
          : _numOrNull(json['averageScore'] ?? json['average_score']),
      hasMore: page < totalPages,
    );
  }

  DeliveryReviewData _review(Map<String, dynamic> json) {
    final String? name =
        _str(json['reviewerFirstName'] ?? json['reviewer_first_name']);
    return DeliveryReviewData(
      id: _str(json['id']) ?? '',
      reviewerName: name ?? '',
      rating: _numOrNull(json['score'] ?? json['rating']) ?? 0,
      body: _str(json['body'] ?? json['comment']) ?? '',
      daysAgo: daysAgoFrom(
        _str(json['createdAt'] ?? json['ts'] ?? json['timestamp']),
      ),
    );
  }

  double? _numOrNull(Object? v) => v is num ? v.toDouble() : null;
  int? _int(Object? v) => v is num ? v.toInt() : null;

  String? _str(Object? v) {
    if (v is! String) return null;
    final String t = v.trim();
    return t.isEmpty ? null : t;
  }
}

/// Whole days between [raw] and now; an unparseable stamp reads as today.
int daysAgoFrom(String? raw, {DateTime? now}) {
  if (raw == null) return 0;
  final DateTime? at = DateTime.tryParse(raw);
  if (at == null) return 0;
  final int days = (now ?? DateTime.now()).difference(at).inDays;
  return days < 0 ? 0 : days;
}
