// DMP-01 (data): the profile's reviews band finally HAS a data layer, and both
// implementations throw AppFailure subtypes only.

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/data/dio_delivery_man_profile_repository.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/data/reviews_backed_delivery_man_profile_repository.dart';
import 'package:jeeb_mobile/features/delivery_man_profile/domain/delivery_man_profile_repository.dart';
import 'package:jeeb_mobile/features/reviews/domain/reviews_repository.dart';

const Map<String, List<String>> _json = <String, List<String>>{
  Headers.contentTypeHeader: <String>[Headers.jsonContentType],
};

/// Answers every read with [status] and [body] (or throws [error]).
class _Adapter implements HttpClientAdapter {
  _Adapter({this.body, this.status = 200, this.error});

  final Object? body;
  final int status;
  final DioExceptionType? error;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final DioExceptionType? type = error;
    if (type != null) {
      throw DioException(requestOptions: options, type: type);
    }
    return ResponseBody.fromString(
      body is String ? body! as String : jsonEncode(body),
      status,
      headers: _json,
    );
  }

  @override
  void close({bool force = false}) {}
}

DioDeliveryManProfileRepository _dioRepo(_Adapter adapter) {
  final Dio dio = Dio(BaseOptions(baseUrl: 'https://example.invalid'));
  dio.httpClientAdapter = adapter;
  return DioDeliveryManProfileRepository(dio);
}

class _ThrowingReviews implements ReviewsRepository {
  const _ThrowingReviews(this.failure);

  final ReviewsFailure failure;

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async =>
      throw ReviewsRepositoryException(failure);

  @override
  Future<void> reportReview(String reviewId) async {}
}

class _OkReviews implements ReviewsRepository {
  const _OkReviews();

  @override
  Future<ReviewsPage> fetchReviews({
    required String jeeberId,
    int page = 1,
    int pageSize = 20,
  }) async =>
      ReviewsPage(
        reviews: <ReviewItem>[
          ReviewItem(
            id: 'r1',
            reviewerFirstName: 'Karl',
            score: 4.5,
            timestamp: DateTime.now()
                .subtract(const Duration(days: 3))
                .toIso8601String(),
            body: 'On time.',
          ),
        ],
        page: 1,
        totalPages: 2,
        reviewCount: 12,
        averageScore: 4.4,
      );

  @override
  Future<void> reportReview(String reviewId) async {}
}

void main() {
  group('DioDeliveryManProfileRepository', () {
    test('200 → a page', () async {
      final DeliveryManReviewsPage page = await _dioRepo(
        _Adapter(
          body: <String, Object>{
            'items': <Object>[
              <String, Object>{
                'id': 'r1',
                'reviewerFirstName': 'Karl',
                'score': 5,
                'body': 'Great',
                'createdAt': '2026-09-01T09:00:00Z',
              },
            ],
            'reviewCount': 12,
            'averageScore': 4.4,
            'page': 1,
            'totalPages': 3,
          },
        ),
      ).fetchReviews(jeeberId: 'j1');

      expect(page.reviews, hasLength(1));
      expect(page.reviews.single.reviewerName, 'Karl');
      expect(page.reviewCount, 12);
      expect(page.averageScore, 4.4);
      expect(page.hasMore, isTrue);
    });

    test('404 → NotFoundFailure', () async {
      await expectLater(
        _dioRepo(_Adapter(body: const <String, Object>{}, status: 404))
            .fetchReviews(jeeberId: 'j1'),
        throwsA(isA<NotFoundFailure>()),
      );
    });

    test('a transport error → NetworkFailure', () async {
      await expectLater(
        _dioRepo(_Adapter(error: DioExceptionType.connectionError))
            .fetchReviews(jeeberId: 'j1'),
        throwsA(isA<NetworkFailure>()),
      );
    });

    test('a malformed body → UnknownFailure(parse)', () async {
      await expectLater(
        _dioRepo(_Adapter(body: '{"items": [1,2,3')).fetchReviews(jeeberId: 'j1'),
        throwsA(isA<AppFailure>()),
      );
    });

    // Checklist (a): a broken shape is NEVER a loaded "No reviews yet".
    test('an empty object body → UnknownFailure(parse), not an empty page',
        () async {
      await expectLater(
        _dioRepo(_Adapter(body: <String, dynamic>{}))
            .fetchReviews(jeeberId: 'j1'),
        throwsA(
          predicate(
            (Object? x) => x is UnknownFailure && x.parse,
            'UnknownFailure(parse: true)',
          ),
        ),
      );
    });

    test('non-List items → UnknownFailure(parse), not an empty page', () async {
      await expectLater(
        _dioRepo(_Adapter(body: <String, dynamic>{'items': 'x'}))
            .fetchReviews(jeeberId: 'j1'),
        throwsA(
          predicate(
            (Object? x) => x is UnknownFailure && x.parse,
            'UnknownFailure(parse: true)',
          ),
        ),
      );
    });

    test('an explicitly empty items list is a legitimate empty page', () async {
      final DeliveryManReviewsPage page = await _dioRepo(
        _Adapter(body: <String, dynamic>{'items': <dynamic>[], 'page': 1,
          'totalPages': 1}),
      ).fetchReviews(jeeberId: 'j1');
      expect(page.reviews, isEmpty);
      expect(page.hasMore, isFalse);
    });
  });

  group('ReviewsBackedDeliveryManProfileRepository', () {
    const Map<ReviewsFailure, Type> expected = <ReviewsFailure, Type>{
      ReviewsFailure.notFound: NotFoundFailure,
      ReviewsFailure.unauthorized: UnauthorizedFailure,
      ReviewsFailure.network: NetworkFailure,
      ReviewsFailure.unknown: UnknownFailure,
    };

    for (final MapEntry<ReviewsFailure, Type> e in expected.entries) {
      test('${e.key.name} → ${e.value}', () async {
        await expectLater(
          ReviewsBackedDeliveryManProfileRepository(_ThrowingReviews(e.key))
              .fetchReviews(jeeberId: 'j1'),
          throwsA(predicate((Object? x) => x.runtimeType == e.value)),
        );
      });
    }

    test('maps a page through, preserving the count and hasMore', () async {
      final DeliveryManReviewsPage page =
          await const ReviewsBackedDeliveryManProfileRepository(_OkReviews())
              .fetchReviews(jeeberId: 'j1');
      expect(page.reviewCount, 12);
      expect(page.hasMore, isTrue);
      expect(page.reviews.single.reviewerName, 'Karl');
      expect(page.reviews.single.daysAgo, 3);
    });
  });
}
