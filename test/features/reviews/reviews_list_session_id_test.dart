import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';

import '../../support/sync_app_localizations.dart';

class _FakeTokenStore implements AuthTokenStore {
  _FakeTokenStore(this._userId);
  final String? _userId;

  @override
  Future<String?> get userId async => _userId;

  @override
  Future<String?> get accessToken async => null;
  @override
  Future<String?> get refreshToken async => null;
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

/// Records the jeeberId the cubit requests and returns an empty page.
class _CapturingReviewsRepository implements ReviewsRepository {
  String? capturedJeeberId;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    capturedJeeberId = jeeberId;
    return const ReviewsPage(reviews: [], page: 1, totalPages: 1);
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// MIDNIGHT: the empty frame now mounts `JeebEmptyState`, whose illustration
/// loops ∞ by design — `pumpAndSettle` can never settle without reduce motion.
Widget _reduceMotion(Widget child) => Builder(
      builder: (context) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child,
      ),
    );

void main() {
  testWidgets(
      'cold deep-link (no ?jeeberId=) resolves the REAL session id, '
      'never the hardcoded user-jeeber-002', (tester) async {
    final repo = _CapturingReviewsRepository();

    await tester.pumpWidget(
      wrapForTest(
        _reduceMotion(
          ReviewsListScreen(
            repository: repo,
            authTokenStore: _FakeTokenStore('jeeber-session-88'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.capturedJeeberId, 'jeeber-session-88');
    expect(repo.capturedJeeberId, isNot('user-jeeber-002'));
  });

  testWidgets('an explicit ?jeeberId= still selects that jeeber directly',
      (tester) async {
    final repo = _CapturingReviewsRepository();

    await tester.pumpWidget(
      wrapForTest(
        _reduceMotion(
          ReviewsListScreen(
            jeeberId: 'jeeber-viewed-123',
            repository: repo,
            authTokenStore: _FakeTokenStore('jeeber-session-88'),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.capturedJeeberId, 'jeeber-viewed-123');
  });
}
