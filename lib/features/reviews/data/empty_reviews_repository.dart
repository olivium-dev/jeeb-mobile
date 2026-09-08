import '../domain/reviews_repository.dart';

class EmptyReviewsRepository implements ReviewsRepository {
  const EmptyReviewsRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const ReviewsPage(reviews: <ReviewItem>[], page: 1, totalPages: 1);
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}
