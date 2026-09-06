// Designed states for `ReviewsListScreen` (JM-068, the all-reviews list) — ONE

import 'dart:async';

import '../../../core/network/app_failure.dart';
import '../../../core/network/gateway_problem.dart';
import '../../../core/network/auth_token_store.dart';
import '../../../features/reviews/domain/reviews_repository.dart';

/// The jeeber every dev surface reads reviews for.
/// Passed explicitly so the screen takes its `jeeberId != null` branch and never
const String reviewsListScreenJeeberId = 'jeeber-042';

// ─────────────────────────────────────────────────────────────────────────

/// Never resolves — keeps the screen on the first-load skeletons (D73).
/// A [Completer] that is never completed holds no timer and no subscription, so
/// it settles under `pumpAndSettle` like any static widget. The shimmer it puts
class ReviewsListScreenPendingRepository implements ReviewsRepository {
  const ReviewsListScreenPendingRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) {
    return Completer<ReviewsPage>().future;
  }

  @override
  Future<void> reportReview(String reviewId) => Completer<void>().future;
}

/// Every read throws a typed [ReviewsRepositoryException].
/// The type matters: `ReviewsCubit.load` maps [ReviewsRepositoryException] to
/// the specific copy for its [ReviewsFailure] and buckets everything else into
class ReviewsListScreenFailingRepository implements ReviewsRepository {
  const ReviewsListScreenFailingRepository(this.failure, [this.appFailure]);

  final ReviewsFailure failure;

  /// The classified failure the screen renders through.
  final AppFailure? appFailure;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ReviewsRepositoryException.classified(
      failure,
      appFailure: appFailure ?? switch (failure) {
        ReviewsFailure.network => const NetworkFailure(),
        ReviewsFailure.notFound => const NotFoundFailure(),
        ReviewsFailure.unauthorized => const UnauthorizedFailure(),
        ReviewsFailure.unknown => const UnknownFailure(),
      },
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// The first read lands, every read after it fails — LR-07's warm failure,
/// where the rows must stay and the strip reports the miss.
class ReviewsListScreenRefreshFailingRepository implements ReviewsRepository {
  ReviewsListScreenRefreshFailingRepository(this.page);

  final ReviewsPage page;
  int calls = 0;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls += 1;
    if (calls == 1) return this.page;
    throw const ReviewsRepositoryException.classified(
      ReviewsFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// Page 1 lands with `hasMore`; every page after it fails — TEST-16's footer.
class ReviewsListScreenLoadMoreFailingRepository implements ReviewsRepository {
  const ReviewsListScreenLoadMoreFailingRepository(this.firstPage);

  final ReviewsPage firstPage;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    if (page == 1) {
      return ReviewsPage(
      reviews: firstPage.reviews,
      page: 1,
      totalPages: 2,
      coldStart: firstPage.coldStart,
      reviewCount: firstPage.reviewCount,
      averageScore: firstPage.averageScore,
      );
    }
    throw const ReviewsRepositoryException.classified(
      ReviewsFailure.unknown,
      appFailure: ServerFailure(status: 500),
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// AE-25: the report comes back 409 `already-rated`.
class ReviewsListScreenReportConflictRepository implements ReviewsRepository {
  const ReviewsListScreenReportConflictRepository(this.page);

  final ReviewsPage page;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async => this.page;

  @override
  Future<void> reportReview(String reviewId) async =>
      throw ReviewsRepositoryException.classified(
        ReviewsFailure.unknown,
        appFailure: ConflictFailure(problem: GatewayProblem.tryParse({
          'type': 'https://jeeb.app/errors/already-rated',
          'title': 'already-rated',
          'status': 409,
        })),
      );
}

/// D59 cold-start posture: fewer than five ratings hides the aggregate score
/// behind the "New" badge while the individual row still renders.
class ReviewsListScreenColdStartRepository implements ReviewsRepository {
  const ReviewsListScreenColdStartRepository();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    return const ReviewsPage(
      reviews: <ReviewItem>[
        ReviewItem(
          id: 'review-101',
          reviewerFirstName: 'Nour',
          score: 5,
          timestamp: '2026-06-30T10:00:00.000Z',
          body: 'Great first delivery!',
        ),
      ],
      page: 1,
      totalPages: 1,
      coldStart: true,
      reviewCount: 1,
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// Answers every read with one designed [ReviewsPage], whatever page is asked
/// for.
/// Every cast it serves is single-page (`page == totalPages`), so `hasMore` is
class ReviewsListScreenStaticRepository implements ReviewsRepository {
  const ReviewsListScreenStaticRepository(this.page);

  final ReviewsPage page;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async => this.page;

  @override
  Future<void> reportReview(String reviewId) async {}
}

// ─────────────────────────────────────────────────────────────────────────

/// The designed pages, one per state that the shipping stand-ins cannot reach.
/// Every cast uses comment copy no other cast uses, so a state accidentally
/// rewired to a neighbouring fixture shows the wrong sentence on screen instead
class ReviewsListScreenPages {
  const ReviewsListScreenPages._();

  /// An ESTABLISHED jeeber — 42 completed ratings — whose `averageScore` came
  /// back NULL.
  static const ReviewsPage scoreWithheld = ReviewsPage(
    reviews: <ReviewItem>[
      ReviewItem(
        id: 'review-201',
        reviewerFirstName: 'Rana',
        score: 4,
        timestamp: '2026-07-28T09:15:00.000Z',
        body: 'Left the parcel with the concierge.',
      ),
      ReviewItem(
        id: 'review-202',
        reviewerFirstName: 'Karim',
        score: 5,
        timestamp: '2026-07-26T17:40:00.000Z',
        body: 'Called ahead before arriving.',
      ),
    ],
    page: 1,
    totalPages: 1,
    reviewCount: 42,
  );

  /// The layout ceiling: the longest comment a reviewer plausibly types, from a
  /// reviewer whose "first name" is really a full compound name.
  static const ReviewsPage longestContent = ReviewsPage(
    reviews: <ReviewItem>[
      ReviewItem(
        id: 'review-301',
        reviewerFirstName: 'Abdulrahman Al-Muhandis',
        score: 2,
        timestamp: '2026-07-30T12:00:00.000Z',
        body:
            'He arrived almost an hour after the window I picked and did not '
            'answer the two calls I made in between. The package itself was '
            'fine and he was polite at the door, but I had to reschedule the '
            'rest of my afternoon around a delivery that was supposed to take '
            'twenty minutes.',
      ),
      ReviewItem(
        id: 'review-302',
        reviewerFirstName: 'Tarek',
        score: 5,
        timestamp: '2026-07-29T08:05:00.000Z',
        body: 'On time.',
      ),
    ],
    page: 1,
    totalPages: 1,
    reviewCount: 128,
    averageScore: 3.9,
  );
}

// ─────────────────────────────────────────────────────────────────────────

/// An [AuthTokenStore] whose `userId` never resolves.
/// The screen only reads the store when it was opened with NO `jeeberId` — the
/// cold deep-link path pinned by `test/features/reviews/
class ReviewsListScreenStalledTokenStore implements AuthTokenStore {
  ReviewsListScreenStalledTokenStore();

  final Completer<String?> _never = Completer<String?>();

  @override
  Future<String?> get userId => _never.future;

  @override
  Future<String?> get accessToken => _never.future;

  @override
  Future<String?> get refreshToken => _never.future;

  @override
  Future<bool> get hasToken async => false;

  @override
  Future<void> clear() async {}

  @override
  Future<void> save({
    required String accessToken,
    required String refreshToken,
    String? userId,
  }) async {}
}
