// Isolated native UI test — ReviewsListScreen (reviews-list, JM-068). The
// screen owns its BlocProvider + resolves a ReviewsRepository seam. Passing a
// non-empty `jeeberId` takes the direct build path (no AuthTokenStore
// FutureBuilder), so a scripted fake repo needs no DI/network. Covers the loaded
// aggregate list, the D59 cold-start (< 5 ratings → New badge, hidden score),
// and the empty state.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';

import '../support/screen_harness.dart';

class _FakeReviewsRepo implements ReviewsRepository {
  const _FakeReviewsRepo(this._page);
  final ReviewsPage _page;
  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async =>
      _page;
  @override
  Future<void> reportReview(String reviewId) async {}
}

ReviewsListScreen _reviews(ReviewsPage page) => ReviewsListScreen(
      jeeberId: 'jeeber-001',
      repository: _FakeReviewsRepo(page),
    );

const _rows = <ReviewItem>[
  ReviewItem(
    id: 'rev-1',
    reviewerFirstName: 'Sami',
    score: 5,
    timestamp: '2026-07-01T10:00:00Z',
    body: 'Super fast and careful with the package.',
  ),
  ReviewItem(
    id: 'rev-2',
    reviewerFirstName: 'Lina',
    score: 4,
    timestamp: '2026-06-28T18:30:00Z',
    body: 'Friendly and on time.',
  ),
  ReviewItem(
    id: 'rev-3',
    reviewerFirstName: 'Omar',
    score: 5,
    timestamp: '2026-06-25T09:15:00Z',
  ),
];

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('reviews-list: populated with aggregate (en)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _reviews(const ReviewsPage(
        reviews: _rows,
        page: 1,
        totalPages: 1,
        reviewCount: 37,
        averageScore: 4.7,
      )),
      'reviews-list__populated',
    );
  });

  testWidgets('reviews-list: cold-start New badge, hidden score (en)',
      (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _reviews(const ReviewsPage(
        reviews: [
          ReviewItem(
            id: 'rev-1',
            reviewerFirstName: 'Sami',
            score: 5,
            timestamp: '2026-07-01T10:00:00Z',
            body: 'First delivery, went great!',
          ),
        ],
        page: 1,
        totalPages: 1,
        coldStart: true,
        reviewCount: 3,
      )),
      'reviews-list__cold-start',
    );
  });

  testWidgets('reviews-list: empty state (ar)', (tester) async {
    await pumpAndShoot(
      tester,
      binding,
      _reviews(const ReviewsPage(
        reviews: [],
        page: 1,
        totalPages: 1,
        reviewCount: 0,
      )),
      'reviews-list__empty-ar',
      locale: const Locale('ar'),
    );
  });
}
