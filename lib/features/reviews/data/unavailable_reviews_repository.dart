import '../domain/reviews_repository.dart';

/// The release fallback when no [ReviewsRepository] is registered: it fails
/// loudly rather than presenting a DI miss as "no reviews yet" (EP-26/GEN-01).
class UnavailableReviewsRepository implements ReviewsRepository {
  const UnavailableReviewsRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) {
    throw const ReviewsRepositoryException(
      ReviewsFailure.unknown,
      'ReviewsRepository unregistered',
    );
  }

  @override
  Future<void> reportReview(String reviewId) {
    throw const ReviewsRepositoryException(
      ReviewsFailure.unknown,
      'ReviewsRepository unregistered',
    );
  }
}
