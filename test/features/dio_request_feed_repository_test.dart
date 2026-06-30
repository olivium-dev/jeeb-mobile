// Tests for DioRequestFeedRepository — the jeeber discovery feed.
//
// Verifies against the FROZEN jeeb-gateway Contract B
// (`jeeb-gateway/jeeber-feed` v1.0.0, request-centric):
//   GET /v1/jeebers/me/feed?status=pending → 200 JeeberFeedResponse
//        { items:[JeeberFeedItem...], totalCount }
//
// Regression guard: the feed previously polled `GET /requests?status=pending`
// (the caller's OWN client requests, status ignored) → a jeeber always saw 0
// rows. These tests pin (1) the endpoint and (2) the JeeberFeedItem parse
// alignment (requestId key, nested FeedLocation, myOffer annotation,
// degrade-don't-drop when routing fields are absent).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/jeeber_request_feed/data/dio_request_feed_repository.dart';
import 'package:jeeb_mobile/features/jeeber_request_feed/data/request_feed_models.dart';

/// Stub Dio that records the last GET path and returns a fixed response.
class _FakeDio extends Fake implements Dio {
  String? lastGetPath;
  Response<dynamic>? nextResponse;
  DioException? nextError;

  @override
  Future<Response<T>> get<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastGetPath = path;
    if (nextError != null) throw nextError!;
    return nextResponse! as Response<T>;
  }
}

Response<dynamic> _resp(Object? body) => Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 200,
      data: body,
    );

void main() {
  late _FakeDio dio;
  late DioRequestFeedRepository repo;

  setUp(() {
    dio = _FakeDio();
    repo = DioRequestFeedRepository(dio: dio);
  });

  tearDown(() => repo.dispose());

  group('endpoint contract (regression — must target the request-centric feed)',
      () {
    test('refresh() GETs /v1/jeebers/me/feed?status=pending, NOT /requests',
        () async {
      dio.nextResponse = _resp({'items': <dynamic>[], 'totalCount': 0});

      await repo.refresh();

      expect(dio.lastGetPath, '/v1/jeebers/me/feed?status=pending');
      expect(dio.lastGetPath, isNot(contains('/requests?status=pending')));
    });

    test('empty/offline feed → no requests (200 {items:[],totalCount:0})',
        () async {
      dio.nextResponse = _resp({'items': <dynamic>[], 'totalCount': 0});

      final result = await repo.refresh();

      expect(result, isEmpty);
    });
  });

  group('JeeberFeedItem parse alignment (frozen Contract B shape)', () {
    test('keys the item by requestId and maps description + tierId + location',
        () async {
      dio.nextResponse = _resp({
        'items': [
          {
            'requestId': 'req-123',
            'status': 'pending',
            'description': 'Grocery pickup — Spinneys Dbayeh',
            'tierId': 'express',
            'distanceMeters': 2500,
            'createdAt': '2026-06-30T09:41:00Z',
            'pickup': {
              'address': 'Spinneys Dbayeh',
              'location': {'lat': 33.95, 'lng': 35.58},
            },
            'dropoff': {
              'address': 'Achrafieh',
              'location': {'lat': 33.88, 'lng': 35.52},
            },
            'myOffer': null,
          },
        ],
        'totalCount': 1,
      });

      final result = await repo.refresh();

      expect(result, hasLength(1));
      final r = result.single;
      expect(r.id, 'req-123');
      expect(r.itemsSummary, 'Grocery pickup — Spinneys Dbayeh');
      expect(r.tier, JeeberRequestTier.standard); // express → standard chip
      expect(r.pickup.label, 'Spinneys Dbayeh');
      expect(r.pickup.latitude, 33.95);
      expect(r.dropoff.label, 'Achrafieh');
      // distanceMeters → distanceFromYouKm
      expect(r.distanceFromYouKm, 2.5);
      // No existing offer → incoming (Ignore/Offer card)
      expect(r.feedStatus, JeeberFeedItemStatus.incoming);
    });

    test('myOffer present → pendingResponse and feeCents → earnings', () async {
      dio.nextResponse = _resp({
        'items': [
          {
            'requestId': 'req-456',
            'status': 'pending',
            'description': 'Pharmacy run',
            'createdAt': '2026-06-30T10:00:00Z',
            'myOffer': {
              'offerId': 'off-1',
              'status': 'submitted',
              'feeCents': 1250,
              'etaMinutes': 30,
              'note': null,
            },
          },
        ],
        'totalCount': 1,
      });

      final result = await repo.refresh();

      expect(result, hasLength(1));
      final r = result.single;
      expect(r.id, 'req-456');
      expect(r.feedStatus, JeeberFeedItemStatus.pendingResponse);
      expect(r.potentialEarnings, 12.5); // 1250 cents → $12.50
    });

    test('degrade-don\'t-drop: item with no pickup/dropoff still renders',
        () async {
      // pickup/dropoff are RECOMMENDED-nullable in the freeze; the MVP-required
      // set (requestId/status/description/createdAt/myOffer) must still yield a
      // visible card so the jeeber can act.
      dio.nextResponse = _resp({
        'items': [
          {
            'requestId': 'req-789',
            'status': 'pending',
            'description': 'Document delivery',
            'createdAt': '2026-06-30T11:00:00Z',
            'myOffer': null,
          },
        ],
        'totalCount': 1,
      });

      final result = await repo.refresh();

      expect(result, hasLength(1));
      expect(result.single.id, 'req-789');
    });
  });
}
