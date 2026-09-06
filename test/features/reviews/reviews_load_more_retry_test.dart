// TEST-16 / UX-47 / AE-25: a failed page offers a real retry, a scoreless
// review is skipped rather than fabricated at 0.0, and a 409 is classified.

import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/core/theme/app_theme.dart';
import 'package:jeeb_mobile/features/reviews/data/dio_reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';
import 'package:jeeb_mobile/features/reviews/presentation/reviews_list_screen.dart';
import 'package:jeeb_mobile/l10n/app_localizations.dart';

import '../../support/midnight_test_harness.dart';
import '../../support/sync_app_localizations.dart';

ReviewItem _item(String id) => ReviewItem(
  id: id,
  reviewerFirstName: 'Rana',
  score: 5,
  timestamp: '2026-07-03T10:00:00Z',
);

/// First page lands with `hasMore`; every page after it fails.
class _LoadMoreFailingRepository implements ReviewsRepository {
  int calls = 0;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async {
    calls += 1;
    if (page == 1) {
      // Enough rows to overflow the viewport, or nothing ever scrolls.
      return ReviewsPage(
        reviews: <ReviewItem>[for (int i = 0; i < 12; i++) _item('rev-$i')],
        page: 1,
        totalPages: 3,
        reviewCount: 40,
        averageScore: 4.8,
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

class _ScriptedAdapter implements HttpClientAdapter {
  _ScriptedAdapter(this._respond);

  final ResponseBody Function(RequestOptions options) _respond;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => _respond(options);

  @override
  void close({bool force = false}) {}
}

ResponseBody _json(Object json, [int status = 200]) => ResponseBody.fromString(
  jsonEncode(json),
  status,
  headers: <String, List<String>>{
    Headers.contentTypeHeader: <String>[Headers.jsonContentType],
  },
);

void main() {
  Widget harness(
    ReviewsRepository repo, {
    Locale locale = const Locale('en'),
  }) => MaterialApp(
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
    home: ReviewsListScreen(jeeberId: 'jeeber-1', repository: repo),
  );

  Finder byId(String id) => find.bySemanticsIdentifier(id);

  for (final locale in const <Locale>[Locale('en'), Locale('ar')]) {
    testWidgets('[${locale.languageCode}] a failed page keeps a retry that '
        're-invokes loadMore', (tester) async {
      useReduceMotion(tester);
      final repo = _LoadMoreFailingRepository();
      await tester.pumpWidget(harness(repo, locale: locale));
      await tester.pumpAndSettle();

      // The next page is fetched on scroll, and that page fails. Drag to the
      // very bottom so the footer slot is actually built.
      for (int i = 0; i < 8; i++) {
        await tester.drag(find.byType(ListView), const Offset(0, -400));
        await tester.pumpAndSettle();
      }

      // A fling can re-arm the scroll listener several times; what matters is
      // that the page failed and the footer offers a real retry.
      final before = repo.calls;
      expect(before, greaterThan(1));
      expect(byId('reviews_load_more_retry'), findsOneWidget);

      await tester.tap(byId('reviews_load_more_retry'));
      await tester.pumpAndSettle();
      expect(repo.calls, greaterThan(before));
    });
  }

  test(
    'a review with no usable score is skipped, never rendered as 0.0',
    () async {
      final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
        ..httpClientAdapter = _ScriptedAdapter(
          (_) => _json(<String, Object?>{
            'items': <Object?>[
              <String, Object?>{'id': 'rev-1', 'score': 4.5},
              <String, Object?>{'id': 'rev-2'},
              <String, Object?>{'id': 'rev-3', 'score': 'garbled'},
            ],
            'page': 1,
            'totalPages': 1,
          }),
        );

      final page = await DioReviewsRepository(
        dio,
      ).fetchReviews(jeeberId: 'jeeber-1');

      expect(page.reviews.map((r) => r.id), <String>['rev-1']);
      expect(page.reviews.single.score, 4.5);
    },
  );

  test('a 409 report failure classifies as a ConflictFailure', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = _ScriptedAdapter(
        (_) => _json(<String, Object?>{
          'type': 'https://jeeb.app/problems/already-rated',
          'title': 'Already rated',
        }, 409),
      );

    await expectLater(
      DioReviewsRepository(dio).reportReview('rev-1'),
      throwsA(
        isA<ReviewsRepositoryException>().having(
          (e) => e.appFailure,
          'appFailure',
          isA<ConflictFailure>(),
        ),
      ),
    );
  });

  test('a 429 report failure classifies as RateLimitedFailure', () async {
    final dio = Dio(BaseOptions(baseUrl: 'https://gateway.test'))
      ..httpClientAdapter = _ScriptedAdapter(
        (_) => _json(<String, Object?>{}, 429),
      );

    await expectLater(
      DioReviewsRepository(dio).reportReview('rev-1'),
      throwsA(
        isA<ReviewsRepositoryException>().having(
          (e) => e.appFailure,
          'appFailure',
          isA<RateLimitedFailure>(),
        ),
      ),
    );
  });
}
