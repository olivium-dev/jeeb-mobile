class ReviewItem {
  const ReviewItem({
    required this.id,
    required this.reviewerFirstName,
    required this.score,
    required this.timestamp,
    this.body,
    this.reportable = true,
  });

  final String id;
  final String reviewerFirstName;
  final double score;

  final String timestamp;

  final String? body;

  final bool reportable;
}

class ReviewsPage {
  const ReviewsPage({
    required this.reviews,
    required this.page,
    required this.totalPages,
    this.coldStart = false,
    this.reviewCount = 0,
    this.averageScore,
  });

  final List<ReviewItem> reviews;
  final int page;
  final int totalPages;

  final bool coldStart;

  final int reviewCount;

  final double? averageScore;

  bool get hasMore => page < totalPages;
}

enum ReviewsFailure { network, notFound, unauthorized, unknown }

class ReviewsRepositoryException implements Exception {
  const ReviewsRepositoryException(this.failure, [this.message]);

  final ReviewsFailure failure;
  final String? message;

  @override
  String toString() => 'ReviewsRepositoryException($failure, $message)';
}

abstract class ReviewsRepository {
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page,
    int pageSize,
  });

  Future<void> reportReview(String reviewId);
}
