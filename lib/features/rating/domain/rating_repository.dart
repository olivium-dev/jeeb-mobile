/// Domain contract for submitting a post-delivery rating.
///
/// Called from [MutualRatingScreen] after the user taps submit. The gateway
/// persists the rating to the score-taking-service via
/// `POST /api/deliveries/{deliveryId}/rate`.
///
/// Status polling: GET /api/deliveries/{deliveryId}/rating
///   Response: { status: pending_mine|pending_theirs|both_rated|auto_revealed,
///               counterpartRating?: { stars, comment? } }
///
/// Mock contract verified against Mockoon :3055.
import 'entities/rating_status.dart';

abstract class RatingRepository {
  /// Submits a [stars] (1–5) rating and optional [comment] for [deliveryId].
  ///
  /// [isClient] true = client rates the Jeeber; false = Jeeber rates the client.
  Future<void> submitRating({
    required String deliveryId,
    required int stars,
    required bool isClient,
    String? comment,
    List<String>? tags,
  });

  /// Fetches the current reveal state for a delivery rating.
  /// Returns [RatingStatus] describing whether both, one, or no side rated.
  Future<RatingStatus> fetchRatingStatus({required String deliveryId});
}
