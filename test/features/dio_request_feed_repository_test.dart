// Tests for DioRequestFeedRepository — the jeeber discovery feed.

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
      expect(r.expiresAt, isNull,
          reason: 'an omitted server expiry must not become a client deadline');
    });

    // ── P7 TX — the feed card deadline is SERVER-ANCHORED, never a parsed
    test('TX.1 — offerDeadlineInSeconds anchors against the injected clock',
        () async {
      final t0 = DateTime.utc(2026, 6, 30, 9, 41);
      final anchored = DioRequestFeedRepository(dio: dio, now: () => t0);
      addTearDown(anchored.dispose);
      dio.nextResponse = _resp({
        'items': [
          {
            'requestId': 'req-expiring',
            'status': 'pending',
            'description': 'Flowers',
            'createdAt': '2026-06-30T09:41:00Z',
            'offerDeadlineInSeconds': 900,
            'myOffer': null,
          },
        ],
        'totalCount': 1,
      });

      final result = await anchored.refresh();

      expect(result.single.expiresAt, t0.add(const Duration(minutes: 15)));
    });

    test('TX.2 — a legacy absolute is NOT honoured (the dual-read is gone)',
        () async {
      dio.nextResponse = _resp({
        'items': [
          {
            'requestId': 'req-legacy',
            'status': 'pending',
            'description': 'Flowers',
            'createdAt': '2026-06-30T09:41:00Z',
            'broadcastExpiresAt': '2026-06-30T10:11:00Z',
            'expiresAt': '2026-06-30T10:11:00Z',
            'myOffer': null,
          },
        ],
        'totalCount': 1,
      });

      final result = await repo.refresh();

      expect(
        result.single.expiresAt,
        isNull,
        reason: 'no server absolute may become a client deadline',
      );
    });

    test('TX.3 — no deadline field at all: null deadline, card stays live',
        () async {
      dio.nextResponse = _resp({
        'items': [
          {
            'requestId': 'req-no-deadline',
            'status': 'pending',
            'description': 'Flowers',
            'createdAt': '2026-06-30T09:41:00Z',
            'myOffer': null,
          },
        ],
        'totalCount': 1,
      });

      // The feed deliberately does NOT throw — only the customer waiting
      final result = await repo.refresh();

      expect(result, hasLength(1));
      expect(result.single.expiresAt, isNull);
      expect(result.single.requestIsOpen, isTrue);
    });

    test('terminal request status is preserved as non-actionable authority',
        () async {
      dio.nextResponse = _resp({
        'items': [
          {
            'requestId': 'req-stale',
            'status': 'Expired',
            'description': 'No longer available',
            'createdAt': '2026-06-30T09:41:00Z',
            'myOffer': null,
          },
        ],
        'totalCount': 1,
      });

      final result = await repo.refresh();

      expect(result, hasLength(1));
      expect(result.single.requestIsOpen, isFalse);
    });

    test('unknown and absent tier ids remain unidentified', () async {
      dio.nextResponse = _resp({
        'items': [
          {
            'requestId': 'req-unknown-tier',
            'status': 'pending',
            'description': 'Potatoes',
            'tierId': '2bd0d5df-0000-0000-0000-000000000000',
            'createdAt': '2026-06-30T09:41:00Z',
            'myOffer': null,
          },
          {
            'requestId': 'req-no-tier',
            'status': 'pending',
            'description': 'Documents',
            'createdAt': '2026-06-30T09:42:00Z',
            'myOffer': null,
          },
        ],
        'totalCount': 2,
      });

      final result = await repo.refresh();

      expect(result.map((request) => request.tier), everyElement(isNull));
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
