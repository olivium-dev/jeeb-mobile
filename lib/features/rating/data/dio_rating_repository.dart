import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';

import '../../../core/network/auth_token_store.dart';
import '../../../core/session/reviews_refresh_signals.dart';
import '../domain/entities/rating_status.dart';
import '../domain/rating_repository.dart';

class DioRatingRepository implements RatingRepository {
  DioRatingRepository(
    this._dio, {
    AuthTokenStore? tokenStore,
    ReviewsRefreshSignals? reviewsRefreshSignals,
  }) : _tokenStore = tokenStore ?? AuthTokenStore(),
       _reviewsRefreshSignals =
           reviewsRefreshSignals ?? ReviewsRefreshSignals.instance;

  final Dio _dio;
  final AuthTokenStore _tokenStore;
  final ReviewsRefreshSignals _reviewsRefreshSignals;

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
      final response = await _dio.post<Map<String, dynamic>>(
        '/v1/ratings/jeeb/submit',
        data: <String, dynamic>{
          'deliveryId': deliveryId,
          if (raterId != null && raterId.isNotEmpty) 'raterId': raterId,
          'score': stars,
          'raterRole': isClient ? 'client' : 'jeeber',
          if (comment != null && comment.isNotEmpty) 'comment': comment,
          if (tags != null && tags.isNotEmpty) 'tags': tags,
        },
        options: Options(
          headers: <String, Object?>{
            'Idempotency-Key': ratingIdempotencyKey(
              deliveryId: deliveryId,
              raterId: raterId,
              stars: stars,
              isClient: isClient,
              comment: comment,
              tags: tags,
            ),
          },
        ),
      );
      // The submit response is authoritative about reveal state but contains no
      // counterpart UUID. Only invalidate this actor's own received-review view;
      // never infer the other profile from a role/name or increment a blind count.
      final data = response.data;
      if (raterId != null &&
          raterId.isNotEmpty &&
          data?['deliveryId'] == deliveryId.trim() &&
          data?['state'] == 'revealed') {
        try {
          if (await _tokenStore.userId == raterId) {
            _reviewsRefreshSignals.signalChanged(
              rateeId: raterId,
              source: this,
            );
          }
        } catch (_) {
          // A successful rating must stay successful if session invalidation fails.
        }
      }
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

  RatingFailure _map(DioException e) => ratingFailureOf(e);
}

/// Derived from the rating itself, so a transport replay and the user's Retry
/// of the SAME rating cannot post it twice.
String ratingIdempotencyKey({
  required String deliveryId,
  required String? raterId,
  required int stars,
  required bool isClient,
  String? comment,
  List<String>? tags,
}) {
  final scope = <String>[
    'rating',
    deliveryId,
    raterId ?? '',
    '$stars',
    isClient ? 'client' : 'jeeber',
    comment ?? '',
    (tags ?? const <String>[]).join(','),
  ].join(':');
  return sha256.convert(utf8.encode(scope)).toString();
}
