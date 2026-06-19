import '../domain/reviews_repository.dart';

/// In-memory empty [ReviewsRepository] — a presentation FALLBACK / test seam
/// only, NEVER registered in DI (40_GUARDRAILS_ARCH §6 / §12: fakes are a
/// constructor seam, not a DI default; the DI binding is the
/// [StubReviewsRepository] / LIVE `DioReviewsRepository` — see
/// `injection_container.dart` JM-068).
///
/// Used by [ReviewsListScreen] when `sl<ReviewsRepository>()` is not registered
/// (e.g. the router-resolution widget tests, which build the route tree without
/// `configureDependencies()`) — mirrors `EmptyWalletLedgerRepository` (JM-055) /
/// `EmptyNotificationsRepository` (JM-057). Returns one empty, non-cold-start
/// page so the screen renders its empty state instead of throwing on an
/// unconfigured GetIt.
class EmptyReviewsRepository implements ReviewsRepository {
  const EmptyReviewsRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const ReviewsPage(
      reviews: <ReviewItem>[],
      page: 1,
      totalPages: 1,
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}
