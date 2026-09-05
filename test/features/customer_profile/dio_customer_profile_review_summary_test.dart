import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/customer_profile/data/dio_customer_profile_repository.dart';

class _RoutingAdapter implements HttpClientAdapter {
  _RoutingAdapter({
    required this.identity,
    required this.reviews,
    this.reviewsStatus = 200,
  });

  final Map<String, Object?> identity;
  final Map<String, Object?> reviews;
  final int reviewsStatus;
  final List<RequestOptions> requests = <RequestOptions>[];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    final isIdentity = options.path == '/v1/users/me';
    final body = isIdentity ? identity : reviews;
    final status = isIdentity ? 200 : reviewsStatus;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: <String, List<String>>{
        Headers.contentTypeHeader: <String>[Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

DioCustomerProfileRepository _repository(_RoutingAdapter adapter) {
  final dio = Dio(BaseOptions(baseUrl: 'https://gw.test'))
    ..httpClientAdapter = adapter;
  return DioCustomerProfileRepository(dio);
}

void main() {
  test('joins cold-start review count for the verified profile user', () async {
    final adapter = _RoutingAdapter(
      identity: const <String, Object?>{
        'userId': '34a52972-29f1-4216-8534-05b74339c1c3',
        'name': 'Nour',
      },
      reviews: const <String, Object?>{
        'reviewCount': 2,
        'averageScore': null,
        'coldStart': true,
      },
    );

    final profile = await _repository(adapter).fetchProfile();

    expect(profile.name, 'Nour');
    expect(profile.ratingCount, 2);
    expect(profile.rating, isNull, reason: 'cold-start score stays hidden');
    expect(adapter.requests, hasLength(2));
    expect(adapter.requests.last.path, '/v1/ratings/jeeb/reviews');
    expect(
      adapter.requests.last.queryParameters,
      containsPair('jeeberId', '34a52972-29f1-4216-8534-05b74339c1c3'),
    );
    expect(adapter.requests.last.queryParameters, containsPair('pageSize', 1));
  });

  test(
    'joins the public aggregate once the cold-start threshold is cleared',
    () async {
      final adapter = _RoutingAdapter(
        identity: const <String, Object?>{
          'userId': '106078a3-4758-45c1-9d31-71b503a3fce4',
          'name': 'Karim',
        },
        reviews: const <String, Object?>{
          'reviewCount': 6,
          'averageScore': 4.75,
          'coldStart': false,
        },
      );

      final profile = await _repository(adapter).fetchProfile();

      expect(profile.ratingCount, 6);
      expect(profile.rating, 4.75);
    },
  );

  test('review-summary failure does not block account controls', () async {
    final adapter = _RoutingAdapter(
      identity: const <String, Object?>{
        'userId': 'user-1',
        'name': 'Karim',
        'rating': 4.4,
        'ratingCount': 7,
      },
      reviews: const <String, Object?>{'title': 'Unavailable'},
      reviewsStatus: 503,
    );

    final profile = await _repository(adapter).fetchProfile();

    expect(profile.name, 'Karim');
    // UX-33: a review-service outage clears the rating and says so, rather
    // than presenting a stale identity rating as live.
    expect(profile.ratingUnavailable, isTrue);
    expect(profile.rating, isNull);
  });
}
