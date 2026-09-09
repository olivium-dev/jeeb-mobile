import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/core/widgets/jeeb/jeeb_pull_to_refresh.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/application/delivery_man_profile_reviews_cubit.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_repository.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_view_data.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/delivery_man_profile_screen.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/presentation/widgets/delivery_man_profile_header.dart';
import 'package:jeeb_mobile/features/reviews/application/reviews_cubit.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

class _PublicRepo implements DeliveryManProfileRepository {
  DeliveryManReviewsPage result = const DeliveryManReviewsPage(
    reviews: [],
    reviewCount: 5,
    averageScore: 4.2,
  );
  @override
  Future<DeliveryManReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async => result;
}

class _PendingPublic implements DeliveryManProfileRepository {
  final reads = <Completer<DeliveryManReviewsPage>>[];
  @override
  Future<DeliveryManReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) {
    final read = Completer<DeliveryManReviewsPage>();
    reads.add(read);
    return read.future;
  }
}

class _PendingReviews implements ReviewsRepository {
  final reads = <Completer<ReviewsPage>>[];
  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) {
    final read = Completer<ReviewsPage>();
    reads.add(read);
    return read.future;
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

void main() {
  testWidgets(
    'public header uses fetched count/average/cold-start, not route seed',
    (tester) async {
      useReduceMotion(tester);
      final repo = _PublicRepo();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.midnight(),
          localizationsDelegates: const [
            SyncAppLocalizationsDelegate(),
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: DeliveryManProfileScreen(
            data: const DeliveryManProfileViewData(
              name: 'Test',
              rating: 4.9,
              reviewCount: 4,
              location: '',
              isAvailable: false,
              reviews: [],
              jeeberId: 'actor',
            ),
            repositoryOverride: repo,
          ),
        ),
      );
      await tester.pumpAndSettle();
      var header = tester.widget<DeliveryManProfileHeader>(
        find.byType(DeliveryManProfileHeader),
      );
      expect(header.reviewCount, 5);
      expect(header.rating, 4.2);
      expect(header.isColdStart, isFalse);
      repo.result = const DeliveryManReviewsPage(reviews: [], reviewCount: 1);
      await tester
          .widget<JeebPullToRefresh>(find.byType(JeebPullToRefresh))
          .onRefresh();
      await tester.pumpAndSettle();
      header = tester.widget<DeliveryManProfileHeader>(
        find.byType(DeliveryManProfileHeader),
      );
      expect(header.reviewCount, 1);
      expect(header.isColdStart, isTrue);
      expect(
        header.rating,
        isNot(4.2),
        reason: 'hidden aggregate must be cleared',
      );
    },
  );

  test(
    'public summary discards older response and post-session/disposal results',
    () async {
      final repo = _PendingPublic();
      final cubit = DeliveryManProfileReviewsCubit(
        repository: repo,
        jeeberId: 'actor',
      );
      final first = cubit.load();
      final next = cubit.refresh();
      repo.reads[1].complete(
        const DeliveryManReviewsPage(
          reviews: [],
          reviewCount: 6,
          averageScore: 4.5,
        ),
      );
      await next;
      repo.reads[0].complete(
        const DeliveryManReviewsPage(reviews: [], reviewCount: 4),
      );
      await first;
      expect(cubit.state.reviewCount, 6);
      expect(cubit.state.averageScore, 4.5);
      final pending = cubit.refresh();
      cubit.endSession();
      repo.reads.last.complete(
        const DeliveryManReviewsPage(
          reviews: [],
          reviewCount: 7,
          averageScore: 4.8,
        ),
      );
      await pending;
      expect(cubit.state.reviewCount, 0);
      await cubit.close();
      await cubit.refresh();
      expect(repo.reads.length, 3);
    },
  );

  test(
    'failed first-page refresh releases superseded pagination and blocks overlap',
    () async {
      final repo = _PendingReviews();
      final cubit = ReviewsCubit(repository: repo, jeeberId: 'actor');
      final initial = cubit.load();
      repo.reads[0].complete(
        const ReviewsPage(reviews: [], page: 1, totalPages: 3, reviewCount: 4),
      );
      await initial;
      final page2 = cubit.loadMore();
      final fresh = cubit.refresh();
      await cubit.loadMore();
      expect(repo.reads.length, 3);
      repo.reads[2].completeError(StateError('refresh unavailable'));
      await fresh;
      repo.reads[1].complete(
        const ReviewsPage(reviews: [], page: 2, totalPages: 3, reviewCount: 4),
      );
      await page2;
      expect(cubit.state.page, 1);
      expect(cubit.state.loadingMore, isFalse);
      expect(cubit.state.refreshError, isNotNull);
      final retry = cubit.loadMore();
      expect(repo.reads.length, 4);
      repo.reads[3].complete(
        const ReviewsPage(reviews: [], page: 2, totalPages: 3, reviewCount: 4),
      );
      await retry;
      expect(cubit.state.page, 2);
      await cubit.close();
    },
  );

  test(
    'old pagination cannot overwrite a newer first page or resurrect disposed state',
    () async {
      final repo = _PendingReviews();
      final cubit = ReviewsCubit(repository: repo, jeeberId: 'actor');
      final initial = cubit.load();
      repo.reads[0].complete(
        const ReviewsPage(reviews: [], page: 1, totalPages: 3, reviewCount: 4),
      );
      await initial;
      final page2 = cubit.loadMore();
      final fresh = cubit.refresh();
      repo.reads[2].complete(
        const ReviewsPage(
          reviews: [],
          page: 1,
          totalPages: 1,
          reviewCount: 5,
          averageScore: 4.6,
        ),
      );
      await fresh;
      repo.reads[1].complete(
        const ReviewsPage(reviews: [], page: 2, totalPages: 3, reviewCount: 4),
      );
      await page2;
      expect(cubit.state.page, 1);
      expect(cubit.state.hasMore, isFalse);
      expect(cubit.state.reviewCount, 5);
      final late = cubit.refresh();
      await cubit.close();
      repo.reads.last.completeError(StateError('late response'));
      await late;
    },
  );
}
