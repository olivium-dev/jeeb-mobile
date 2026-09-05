library;

import 'package:dio/dio.dart' show DioExceptionType;

import '../../../core/network/app_failure.dart';
import 'entities/rating_status.dart';

enum RatingFailure {
  network,

  unknown,

  timeout,
  forbidden,
  notFound,
  rateLimited,
  server,
}

class RatingRepositoryException implements Exception {
  const RatingRepositoryException(this.failure, [this.message]);

  final RatingFailure failure;
  final String? message;

  @override
  String toString() => 'RatingRepositoryException($failure, $message)';
}

abstract class RatingRepository {
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  });

  Future<RatingStatus> fetchRatingStatus({required String deliveryId});
}

/// The one classification point for the rating leg; shared with the cubits so
/// a thrown TypeError and a 403 do not read as the same failure.
RatingFailure ratingFailureOf(Object error) =>
    switch (AppFailure.of(error).kind) {
      AppFailureKind.network => RatingFailure.network,
      AppFailureKind.timeout => RatingFailure.timeout,
      AppFailureKind.unauthorized ||
      AppFailureKind.forbidden =>
        RatingFailure.forbidden,
      AppFailureKind.notFound || AppFailureKind.gone => RatingFailure.notFound,
      AppFailureKind.rateLimited => RatingFailure.rateLimited,
      AppFailureKind.server => RatingFailure.server,
      _ => RatingFailure.unknown,
    };

/// The copy-family failure a [RatingFailure] renders as.
AppFailure ratingAppFailure(RatingFailure failure) => switch (failure) {
  RatingFailure.network => const NetworkFailure(),
  RatingFailure.timeout =>
    const TimeoutFailure(phase: DioExceptionType.receiveTimeout),
  RatingFailure.forbidden => const ForbiddenFailure(),
  RatingFailure.notFound => const NotFoundFailure(),
  RatingFailure.rateLimited => const RateLimitedFailure(),
  RatingFailure.server => const ServerFailure(status: 500),
  RatingFailure.unknown => const UnknownFailure(),
};
