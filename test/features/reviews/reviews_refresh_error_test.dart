// LR-07 / UX-30: a failed refresh keeps the rows and says so; a cold failure
// retries through a real loading rung; a 401 gets the sign-in way out.

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/reviews/application/reviews_cubit.dart';
import 'package:jeeb_mobile/features/reviews/application/reviews_state.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

const ReviewsPage _page = ReviewsPage(
  reviews: <ReviewItem>[
    ReviewItem(
      id: 'rev-1',
      reviewerFirstName: 'Rana',
      score: 5,
      timestamp: '2026-07-03T10:00:00Z',
      body: 'On time.',
    ),
  ],
  page: 1,
  totalPages: 1,
  reviewCount: 1,
  averageScore: 5,
);

class _RefreshFailingRepository implements ReviewsRepository {
  int calls = 0;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls += 1;
    if (calls == 1) return _page;
    throw const ReviewsRepositoryException.classified(
      ReviewsFailure.network,
      appFailure: NetworkFailure(offline: true),
    );
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

class _FailingRepository implements ReviewsRepository {
  const _FailingRepository(this.kind, this.failure);

  final ReviewsFailure kind;
  final AppFailure failure;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async =>
      throw ReviewsRepositoryException.classified(kind, appFailure: failure);

  @override
  Future<void> reportReview(String reviewId) async {}
}

/// Cold read fails, then the retry succeeds — proves `retry()` flips loading.
class _FailThenSucceedRepository implements ReviewsRepository {
  int calls = 0;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls += 1;
    if (calls == 1) {
      throw const ReviewsRepositoryException.classified(
        ReviewsFailure.network,
        appFailure: NetworkFailure(offline: true),
      );
    }
    return _page;
  }

  @override
  Future<void> reportReview(String reviewId) async {}
}

void main() {
  Widget harness(ReviewsRepository repo, {Locale locale = const Locale('en')}) {
    final router = GoRouter(
      initialLocation: '/reviews',
      routes: <RouteBase>[
        GoRoute(
          path: '/reviews',
          builder: (_, _) =>
              ReviewsListScreen(jeeberId: 'jeeber-1', repository: repo),
        ),
        GoRoute(
          path: '/login',
          name: 'login',
          builder: (_, _) => const Scaffold(body: Text('login')),
        ),
      ],
    );
    return MaterialApp.router(
      routerConfig: router,
      theme: AppTheme.midnight(),
      locale: locale,
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
        SyncAppLocalizationsDelegate(),
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child!,
      ),
    );
  }

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    final tag = locale.languageCode;

    testWidgets('[$tag] a failed refresh keeps the rows and shows the strip', (
      tester,
    ) async {
      useReduceMotion(tester);
      final repo = _RefreshFailingRepository();
      await tester.pumpWidget(harness(repo, locale: locale));
      await tester.pumpAndSettle();

      expect(byId('review_rev-1'), findsOneWidget);

      await tester.fling(find.byType(ListView), const Offset(0, 320), 1000);
      await tester.pumpAndSettle();

      expect(repo.calls, greaterThan(1));
      expect(byId('review_rev-1'), findsOneWidget);
      expect(byId('reviews_error'), findsNothing);
      expect(byId('reviews_refresh_error'), findsOneWidget);

      await tester.tap(byId('reviews_refresh_error_dismiss_cta'));
      await tester.pumpAndSettle();
      expect(byId('reviews_refresh_error'), findsNothing);
    });
  }

  testWidgets('a cold failure retries through a real loading rung', (
    tester,
  ) async {
    useReduceMotion(tester);
    final repo = _FailThenSucceedRepository();
    await tester.pumpWidget(harness(repo));
    await tester.pumpAndSettle();

    expect(byId('reviews_error'), findsOneWidget);
    expect(byId('reviews_retry_cta'), findsOneWidget);

    await tester.tap(byId('reviews_retry_cta'));
    await tester.pumpAndSettle();

    expect(repo.calls, 2);
    expect(byId('review_rev-1'), findsOneWidget);
    expect(byId('reviews_error'), findsNothing);
  });

  test('retry() flips to loading first, unlike refresh()', () async {
    final cubit = ReviewsCubit(
      repository: _FailThenSucceedRepository(),
      jeeberId: 'jeeber-1',
    );
    await cubit.load();
    expect(cubit.state.status, ReviewsStatus.failed);

    final seen = <ReviewsStatus>[];
    final sub = cubit.stream.listen((s) => seen.add(s.status));
    await cubit.retry();
    await Future<void>.delayed(Duration.zero);
    await sub.cancel();

    expect(seen, <ReviewsStatus>[ReviewsStatus.loading, ReviewsStatus.loaded]);
    await cubit.close();
  });

  testWidgets('unauthorized gets the sign-in way out, never a Retry', (
    tester,
  ) async {
    useReduceMotion(tester);
    await tester.pumpWidget(
      harness(
        const _FailingRepository(
          ReviewsFailure.unauthorized,
          UnauthorizedFailure(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(byId('reviews_error'), findsOneWidget);
    expect(byId('reviews_error_signin_cta'), findsOneWidget);
    expect(byId('reviews_retry_cta'), findsNothing);
  });

  test('a failed refresh never touches the cold-error slot', () async {
    final cubit = ReviewsCubit(
      repository: _RefreshFailingRepository(),
      jeeberId: 'jeeber-1',
    );
    await cubit.load();
    await cubit.refresh();

    expect(cubit.state.status, ReviewsStatus.loaded);
    expect(cubit.state.error, isNull);
    expect(cubit.state.refreshError, isNotNull);
    cubit.acknowledgeRefreshError();
    expect(cubit.state.refreshError, isNull);
    await cubit.close();
  });
}
