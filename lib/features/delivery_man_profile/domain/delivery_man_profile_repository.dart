import 'delivery_man_profile_view_data.dart';

/// One page of a jeeber's public reviews.
class DeliveryManReviewsPage {
  const DeliveryManReviewsPage({
    required this.reviews,
    required this.reviewCount,
    this.averageScore,
    this.hasMore = false,
  });

  final List<DeliveryReviewData> reviews;
  final int reviewCount;
  final double? averageScore;
  final bool hasMore;

  static const DeliveryManReviewsPage empty = DeliveryManReviewsPage(
    reviews: <DeliveryReviewData>[],
    reviewCount: 0,
  );
}

/// Throws `AppFailure` subtypes only — no outcome enum, no result type.
abstract class DeliveryManProfileRepository {
  Future<DeliveryManReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  });
}
