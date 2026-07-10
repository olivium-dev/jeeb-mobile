/// Domain contract for submitting a post-delivery rating (JM-034).
///
/// Called from [MutualRatingCubit] after the user taps submit. The gateway
/// persists the rating to the score-taking-service via
/// `POST /v1/ratings/jeeb/submit` (rewritten to
/// `/score-taking-service/v1/ratings/jeeb/submit` by MockGatewayClient).
///
/// Status polling (server-owned reveal): `GET /v1/ratings/jeeb/{id}/status`.
///   Response: { deliveryId, state: pending_both|pending_self|pending_counter|
///               revealed, ratings: [...], ratedCount }
///
/// Mock contract verified against the Express mock score-taking-service on :4010.
library;
import 'entities/rating_status.dart';

/// Typed failure surfaced to the cubit (UI never sees a `DioException`).
enum RatingFailure {
  /// Connection/timeout — the rating did not reach the server.
  network,

  /// Caller is not a party to the delivery (403) or any other server reject.
  unknown,
}

/// Thrown by the data layer; the cubit maps [failure] to localized copy.
class RatingRepositoryException implements Exception {
  const RatingRepositoryException(this.failure, [this.message]);

  final RatingFailure failure;
  final String? message;

  @override
  String toString() => 'RatingRepositoryException($failure, $message)';
}

abstract class RatingRepository {
  /// Submits a [stars] (1–5) rating and optional [comment]/[tags] for
  /// [deliveryId].
  ///
  /// [isClient] true = client rates the Jeeber; false = Jeeber rates the
  /// client. The data layer resolves the caller's `raterId` from the session.
  ///
  /// Throws [RatingRepositoryException] on failure.
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  });

  /// Fetches the current reveal state for a delivery rating.
  /// Returns [RatingStatus] describing whether both, one, or no side rated.
  ///
  /// Throws [RatingRepositoryException] on failure.
  Future<RatingStatus> fetchRatingStatus({required String deliveryId});
}
