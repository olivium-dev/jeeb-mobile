// SC-097 regression — the reviews-list (JM-068) must fetch the AUTHENTICATED
// jeeber's reviews, NOT the hard-coded mock seed `user-jeeber-002`.
//
// The defect: `ReviewsListScreen` fell back to a `_defaultJeeberId =
// 'user-jeeber-002'` constant whenever the route carried no explicit
// `?jeeberId=` — which is the normal case for a jeeber viewing their OWN
// reviews. A real driver therefore saw the mock's empty "No reviews yet" instead
// of their own reviews / cold-start state.
//
// The fix resolves the id from `AuthTokenStore.userId` (the persisted
// `auth.userId`, the same source `DioRatingRepository` reads) when there is no
// explicit id. These tests pin that contract:
//   1. no explicit id + an authed session → `fetchReviews(jeeberId: <authed>)`,
//      and the captured id is NEVER `user-jeeber-002`;
//   2. the authed user's cold-start payload (<5 reviews) renders the D59
//      New badge + hidden-score note + the rows (not the empty state);
//   3. an explicit `?jeeberId=` still WINS (viewing ANOTHER jeeber);
//   4. no session + no explicit id → the empty state, never the mock id.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';

import '../../support/sync_app_localizations.dart';

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

/// Captures the `jeeberId` the screen fetches with, and replays a scripted page.
class _CapturingReviewsRepository implements ReviewsRepository {
  _CapturingReviewsRepository({required this.page});

  final ReviewsPage page;
  final List<String> fetchedJeeberIds = <String>[];

  String? get lastJeeberId =>
      fetchedJeeberIds.isEmpty ? null : fetchedJeeberIds.last;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    fetchedJeeberIds.add(jeeberId);
    return this.page;
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

ReviewItem _review(String id, double score) => ReviewItem(
      id: id,
      reviewerFirstName: 'Reviewer-$id',
      score: score,
      timestamp: '2026-06-21T10:00:00Z',
      body: 'Body $id',
    );

void main() {
  // The real authenticated jeeber (a Kamal-style live UUID) — explicitly NOT
  // the mock seed.
  const authedJeeberId = 'c23efd76-6fa4-40cf-814c-116f67ea5e95';
  const mockSeedJeeberId = 'user-jeeber-002';

  late _MockAuthTokenStore tokenStore;

  setUp(() {
    tokenStore = _MockAuthTokenStore();
  });

  Future<void> pumpScreen(
    WidgetTester tester, {
    String? jeeberId,
    required ReviewsRepository repository,
    required AuthTokenStore store,
  }) async {
    await tester.pumpWidget(
      wrapForTest(
        ReviewsListScreen(
          jeeberId: jeeberId,
          repository: repository,
          tokenStore: store,
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'no explicit id → fetches the AUTHENTICATED jeeber id, never user-jeeber-002',
    (tester) async {
      when(() => tokenStore.userId)
          .thenAnswer((_) async => authedJeeberId);
      final repo = _CapturingReviewsRepository(
        page: const ReviewsPage(reviews: [], page: 1, totalPages: 1),
      );

      await pumpScreen(tester, repository: repo, store: tokenStore);

      expect(repo.lastJeeberId, authedJeeberId);
      expect(repo.lastJeeberId, isNot(mockSeedJeeberId));
      expect(repo.fetchedJeeberIds, isNot(contains(mockSeedJeeberId)));
    },
  );

  testWidgets(
    'authed cold-start (<5 reviews) renders the New badge + hidden-score note + rows',
    (tester) async {
      when(() => tokenStore.userId)
          .thenAnswer((_) async => authedJeeberId);
      // The real jeeber has 2 reviews → cold-start (server-driven), score hidden.
      final repo = _CapturingReviewsRepository(
        page: ReviewsPage(
          reviews: [_review('r1', 5), _review('r2', 4)],
          page: 1,
          totalPages: 1,
          coldStart: true,
          reviewCount: 2,
        ),
      );

      await pumpScreen(tester, repository: repo, store: tokenStore);

      // Fetched for the authed jeeber, not the mock.
      expect(repo.lastJeeberId, authedJeeberId);
      // D59 cold-start UX renders for the REAL user (not "No reviews yet").
      expect(find.bySemanticsIdentifier('reviews_new_badge'), findsOneWidget);
      expect(
        find.bySemanticsIdentifier('reviews_hidden_score_note'),
        findsOneWidget,
      );
      // The actual review rows render — the empty state does NOT.
      expect(find.bySemanticsIdentifier('reviews_empty'), findsNothing);
      expect(find.bySemanticsIdentifier('review_r1_reviewer_name'),
          findsOneWidget);
      expect(find.bySemanticsIdentifier('review_r2_reviewer_name'),
          findsOneWidget);
    },
  );

  testWidgets(
    'explicit ?jeeberId= still WINS (viewing another jeeber) — auth not consulted',
    (tester) async {
      const otherJeeberId = 'some-other-jeeber-id';
      final repo = _CapturingReviewsRepository(
        page: const ReviewsPage(reviews: [], page: 1, totalPages: 1),
      );

      await pumpScreen(
        tester,
        jeeberId: otherJeeberId,
        repository: repo,
        store: tokenStore,
      );

      expect(repo.lastJeeberId, otherJeeberId);
      verifyNever(() => tokenStore.userId);
    },
  );

  testWidgets(
    'no explicit id + no session → empty state, NEVER the mock id',
    (tester) async {
      when(() => tokenStore.userId).thenAnswer((_) async => null);
      final repo = _CapturingReviewsRepository(
        page: const ReviewsPage(reviews: [], page: 1, totalPages: 1),
      );

      await pumpScreen(tester, repository: repo, store: tokenStore);

      // Never fetched the mock id (in fact never fetched at all — no jeeber).
      expect(repo.fetchedJeeberIds, isNot(contains(mockSeedJeeberId)));
      expect(repo.fetchedJeeberIds, isEmpty);
      expect(find.bySemanticsIdentifier('reviews_empty'), findsOneWidget);
    },
  );
}
