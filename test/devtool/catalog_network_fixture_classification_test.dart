import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/notifications_list_screen_fixtures.dart';
import 'package:jeeb_mobile/devtool/catalog/fixtures/reviews_list_screen_fixtures.dart';
import 'package:jeeb_mobile/features/notifications/domain/notifications_repository.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';

void main() {
  for (final entry in <NotificationsFailure, AppFailure>{
    NotificationsFailure.network: const NetworkFailure(),
    NotificationsFailure.unauthorized: const UnauthorizedFailure(),
    NotificationsFailure.unknown: const UnknownFailure(),
  }.entries) {
    test('notification fixture preserves ${entry.key.name}', () async {
      await expectLater(
        NotificationsListScreenFailingRepository(
          failure: entry.key,
        ).fetchNotifications(),
        throwsA(
          isA<NotificationsRepositoryException>().having(
            (e) => e.appFailure,
            'classified failure',
            entry.value,
          ),
        ),
      );
    });
  }
  for (final entry in <ReviewsFailure, AppFailure>{
    ReviewsFailure.network: const NetworkFailure(),
    ReviewsFailure.unauthorized: const UnauthorizedFailure(),
    ReviewsFailure.notFound: const NotFoundFailure(),
    ReviewsFailure.unknown: const UnknownFailure(),
  }.entries) {
    test('review fixture preserves ${entry.key.name}', () async {
      await expectLater(
        ReviewsListScreenFailingRepository(
          entry.key,
        ).fetchReviews(jeeberId: 'fixture'),
        throwsA(
          isA<ReviewsRepositoryException>().having(
            (e) => e.appFailure,
            'classified failure',
            entry.value,
          ),
        ),
      );
    });
  }
  test(
    'explicit reachability evidence wins over generic network fixture',
    () async {
      const offline = NetworkFailure(offline: true);
      await expectLater(
        const NotificationsListScreenFailingRepository(
          appFailure: offline,
        ).fetchNotifications(),
        throwsA(
          isA<NotificationsRepositoryException>().having(
            (e) => e.appFailure,
            'classified failure',
            offline,
          ),
        ),
      );
      await expectLater(
        const ReviewsListScreenFailingRepository(
          ReviewsFailure.network,
          offline,
        ).fetchReviews(jeeberId: 'fixture'),
        throwsA(
          isA<ReviewsRepositoryException>().having(
            (e) => e.appFailure,
            'classified failure',
            offline,
          ),
        ),
      );
    },
  );
}
