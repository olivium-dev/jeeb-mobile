import '../../../core/network/app_failure.dart';
import '../../../core/network/app_failure_mapper.dart';
import '../../reviews/domain/reviews_repository.dart';
import '../domain/delivery_man_profile_repository.dart';
import '../domain/delivery_man_profile_view_data.dart';
import 'dio_delivery_man_profile_repository.dart' show daysAgoFrom;

/// Reuses the already-registered `ReviewsRepository` so the profile and the
/// reviews screen never diverge on a second contract.
class ReviewsBackedDeliveryManProfileRepository
    implements DeliveryManProfileRepository {
  const ReviewsBackedDeliveryManProfileRepository(this._reviews);

  final ReviewsRepository _reviews;

  @override
  Future<DeliveryManReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    final ReviewsPage source;
    try {
      source = await _reviews.fetchReviews(
        jeeberId: jeeberId,
        page: page,
        pageSize: pageSize,
      );
    } on ReviewsRepositoryException catch (e) {
      throw _translate(e);
    } on AppFailure {
      rethrow;
    } catch (e) {
      throw UnknownFailure(cause: e, parse: true);
    }
    return DeliveryManReviewsPage(
      reviews: source.reviews.map(_toReviewData).toList(growable: false),
      reviewCount: source.reviewCount,
      averageScore: source.averageScore,
      hasMore: source.hasMore,
    );
  }

  DeliveryReviewData _toReviewData(ReviewItem item) => DeliveryReviewData(
        id: item.id,
        reviewerName: item.reviewerFirstName,
        rating: item.score,
        body: item.body ?? '',
        daysAgo: daysAgoFrom(item.timestamp),
      );

  AppFailure _translate(ReviewsRepositoryException e) =>
      e.appFailure ??
      switch (e.failure) {
        ReviewsFailure.notFound => NotFoundFailure(cause: e),
        ReviewsFailure.unauthorized => UnauthorizedFailure(cause: e),
        ReviewsFailure.network => networkFailureFromReachability(cause: e),
        ReviewsFailure.unknown => UnknownFailure(cause: e),
      };
}
