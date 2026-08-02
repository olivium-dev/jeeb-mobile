// Designed states for `ReviewsListScreen` (JM-068, the all-reviews list) — ONE
// source of truth, two consumers.
//
//   lib/devtool/catalog/entries/batch_10_entries.dart   the designer-facing,
//                                                       on-device Screen Catalog
//   lib/features/reviews/presentation/
//     reviews_list_screen.dart                          the JEEB PREVIEWS
//                                                       section at its bottom
//
// The catalog's five states were hand-built inside the entry file: a
// `_PendingReviewsRepository` that never resolves, a `_FailingReviewsRepository`
// that throws a typed failure, a `_ColdStartReviewsRepository` with the D59
// posture, and the two shipping stand-ins ([StubReviewsRepository],
// [EmptyReviewsRepository]). The three private ones moved here whole when the
// screen got a preview section, because two copies of the same "designed state"
// drift and the catalog is the one a designer signs off against. Nothing about
// what the catalog RENDERS changed in the move — same three behaviours, same
// cold-start row, same jeeber id.
//
// The two shipping repositories stayed where they were: they are not fixtures,
// they are app code both surfaces already share, so there is nothing to
// extract and nothing that can drift.
//
// Two casts are NEW and belong only to the preview canvas, which reviews states
// the catalog does not carry:
//
//   [ReviewsListScreenPages.scoreWithheld]   an ESTABLISHED jeeber whose
//                                            `averageScore` came back null —
//                                            the state where the aggregate
//                                            header mislabels him "New".
//   [ReviewsListScreenPages.longestContent]  the layout ceiling: a long
//                                            reviewer name and the longest
//                                            comment a reviewer plausibly
//                                            types, on the narrowest phone.
//
// NOTHING here touches the network. Every repository answers from a const page,
// throws, or never completes — the `CatalogNetworkGuard` both hosts install is a
// net, not the plan. There is no Dio and no GetIt on any path below.
//
// ## Why the timestamps are fixed instants and the rendered ages are not
//
// `ReviewRow` calls `ReviewsL10n.relativeTime(review.timestamp)` with no `now`
// argument, so the age is resolved against the wall clock and there is no
// injectable seam to pin it. A fixed ISO instant therefore renders an age that
// GROWS ("45d ago" this month, "75d ago" the next). That is the same trade the
// catalog entry already made and it is kept deliberately: a const page is what
// lets both surfaces share one literal. Never assert on a rendered age.
//
// This file lives under `lib/devtool/`, which `tool/preview_inventory.dart`
// excludes from preview coverage and which is not reachable from any shipping
// code path.

import 'dart:async';

import '../../../core/network/auth_token_store.dart';
import '../../../features/reviews/domain/reviews_repository.dart';

/// The jeeber every dev surface reads reviews for.
///
/// Passed explicitly so the screen takes its `jeeberId != null` branch and never
/// reaches [AuthTokenStore] — the one state that DOES exercise that branch uses
/// [ReviewsListScreenStalledTokenStore] instead.
const String reviewsListScreenJeeberId = 'jeeber-042';

// ─────────────────────────────────────────────────────────────────────────
// Repositories — four outcomes, no network
// ─────────────────────────────────────────────────────────────────────────

/// Never resolves — keeps the screen on the first-load skeletons (D73).
///
/// A [Completer] that is never completed holds no timer and no subscription, so
/// it settles under `pumpAndSettle` like any static widget. The shimmer it puts
/// on screen does not, which is why the preview that uses this fake mutes its
/// ticker.
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
///
/// The type matters: `ReviewsCubit.load` maps [ReviewsRepositoryException] to
/// the specific copy for its [ReviewsFailure] and buckets everything else into
/// `ReviewsFailure.unknown`, so a fake throwing a bare `Exception` would render
/// the generic "Could not load reviews." under whichever failure it claimed.
class ReviewsListScreenFailingRepository implements ReviewsRepository {
  const ReviewsListScreenFailingRepository(this.failure);

  final ReviewsFailure failure;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    throw ReviewsRepositoryException(failure);
  }

  @override
  Future<void> reportReview(String reviewId) async {}
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
///
/// Every cast it serves is single-page (`page == totalPages`), so `hasMore` is
/// false and the screen never mounts its load-more footer. That is deliberate:
/// `_LoadedListState._onScroll` asks for the next page as soon as the viewport
/// comes within 400 pt of the end, and a fake that claimed more pages while
/// returning the same rows would keep a dev surface asking forever.
class ReviewsListScreenStaticRepository implements ReviewsRepository {
  const ReviewsListScreenStaticRepository(this.page);

  final ReviewsPage page;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async =>
      this.page;

  @override
  Future<void> reportReview(String reviewId) async {}
}

// ─────────────────────────────────────────────────────────────────────────
// Casts
// ─────────────────────────────────────────────────────────────────────────

/// The designed pages, one per state that the shipping stand-ins cannot reach.
///
/// Every cast uses comment copy no other cast uses, so a state accidentally
/// rewired to a neighbouring fixture shows the wrong sentence on screen instead
/// of looking plausible.
class ReviewsListScreenPages {
  const ReviewsListScreenPages._();

  /// An ESTABLISHED jeeber — 42 completed ratings — whose `averageScore` came
  /// back NULL.
  ///
  /// `_AggregateHeader` branches on `state.coldStart || state.averageScore ==
  /// null`, so this page renders the D59 cold-start header: the "New" chip and
  /// "New Jeeber — overall score appears after a few completed deliveries."
  /// over a list of 42 reviews. `coldStart` is false here on purpose; the wire
  /// contract makes `averageScore` nullable independently of it, and this is
  /// what the screen does when the two disagree.
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
  ///
  /// Three squeezes meet on this page and each fails differently. The aggregate
  /// header is an unflexed [Text] in a Row after a fixed-size star. The
  /// attribution line has no `maxLines`, so the compound name wraps rather than
  /// ellipsizing — and `ReviewRow` prints it TWICE, once itself and once as
  /// `OmdsReviewCard.userName`. The comment does not clamp either: the row
  /// GROWS — 341 dp on a 320 pt frame — so the second review starts at 446 and
  /// is cut by the fold at 568, taking its Report affordance with it.
  ///
  /// A score of 2 with a long body is not a contrived pairing — the reviews
  /// people write at length are the angry ones.
  static const ReviewsPage longestContent = ReviewsPage(
    reviews: <ReviewItem>[
      ReviewItem(
        id: 'review-301',
        reviewerFirstName: 'Abdulrahman Al-Muhandis',
        score: 2,
        timestamp: '2026-07-30T12:00:00.000Z',
        body: 'He arrived almost an hour after the window I picked and did not '
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
// Session
// ─────────────────────────────────────────────────────────────────────────

/// An [AuthTokenStore] whose `userId` never resolves.
///
/// The screen only reads the store when it was opened with NO `jeeberId` — the
/// cold deep-link path pinned by `test/features/reviews/
/// reviews_list_session_id_test.dart` (S0-OAD-03). Until that read returns, the
/// screen shows a bare `Scaffold` with a centred spinner and NO app bar, which
/// is a surface no other state produces and the only one this fake exists to
/// show.
///
/// Real reads go to `FlutterSecureStorage`, which on a cold start after a device
/// reboot is a keychain unlock — not instant, and not previewable any other way.
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
