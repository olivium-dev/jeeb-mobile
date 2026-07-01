// JM-031 — DioOrderSummaryRepository unit tests.
//
// Verifies the repository wires the REAL mock endpoints and parses the exact
// `order_accepted` journey-seed shapes (jeeb-mock-backend
// src/fixtures/journey-seed.ts → seedOrderAccepted / seedDeliveryRow):
//   * GET /v1/delivery/:id   → price (amount.value), tier, jeeberName, title,
//                              requestId, conversationId fallback
//   * GET /v1/requests/:id   → conversationId + item/price fallback
//   * GET /v1/offers?req=    → accepted-offer etaMinutes (delivery row omits it)
//   * GET /v1/users/:jeeberId → jeeber rating + ratingCount (D6)
// Plus failure mapping: 404 → notFound, connectionError → network. Secondary
// (enrichment) fetches NEVER fail the summary — a thrown request/offer/user
// fetch still yields the core delivery-derived fields.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/order_summary/data/dio_order_summary_repository.dart';
import 'package:jeeb_mobile/features/order_summary/domain/order_summary_repository.dart';

class _MockDio extends Mock implements Dio {}

Response<T> _ok<T>(T data) => Response<T>(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: 200,
    );

DioException _dio(int? status, {DioExceptionType? type}) => DioException(
      requestOptions: RequestOptions(path: ''),
      type: type ?? DioExceptionType.badResponse,
      response: status == null
          ? null
          : Response<dynamic>(
              requestOptions: RequestOptions(path: ''),
              statusCode: status,
            ),
    );

// Journey-seed `order_accepted` delivery row (seedDeliveryRow + usd()).
Map<String, dynamic> _deliveryRow() => {
      'id': 'del-client-001-active',
      'requestId': 'req-client-001-accepted',
      'clientId': 'user-client-001',
      'jeeberId': 'user-jeeber-002',
      'tier': 'express',
      'status': 'Ordered',
      'title': 'Groceries from Spinneys',
      'amount': {'value': 9.0, 'minorUnits': 900, 'currency': 'USD'},
      'jeeberName': 'Kamal Hajj',
      'conversationId': 'conv-journey-accepted',
    };

Map<String, dynamic> _requestRow() => {
      'id': 'req-client-001-accepted',
      'displayId': 'ORD-503003',
      'tier': 'express',
      'status': 'matched',
      'title': 'Groceries from Spinneys',
      'amount': {'value': 9.0, 'minorUnits': 900, 'currency': 'USD'},
      'conversationId': 'conv-journey-accepted',
    };

Map<String, dynamic> _offersEnvelope() => {
      'items': [
        {
          'id': 'offer-001',
          'requestId': 'req-client-001-accepted',
          'jeeberId': 'user-jeeber-002',
          'etaMinutes': 20,
          'status': 'accepted',
        },
      ],
    };

// user-jeeber-002 = Kamal Hajj (seed.ts: rating 4.9, ratingCount 312).
Map<String, dynamic> _userRow() => {
      'id': 'user-jeeber-002',
      'name': 'Kamal Hajj',
      'rating': 4.9,
      'ratingCount': 312,
      'avatarUrl': 'https://cdn.jeeb.app/u/kamal.png',
    };

void main() {
  setUpAll(() {
    registerFallbackValue(<String, dynamic>{});
  });

  late _MockDio dio;
  late DioOrderSummaryRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioOrderSummaryRepository(dio);
  });

  // Routes each GET to the right fixture by path/query.
  void stubHappyPath() {
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((inv) async {
      final path = inv.positionalArguments.first as String;
      // BUG-8: the delivery read now uses the plural `/v1/deliveries/{id}`
      // aggregate route on the origin gateway (default originGateway=true).
      if (path == '/v1/deliveries/del-client-001-active') {
        return _ok(_deliveryRow());
      }
      if (path == '/v1/requests/req-client-001-accepted') {
        return _ok(_requestRow());
      }
      if (path == '/v1/users/user-jeeber-002') {
        return _ok(_userRow());
      }
      throw _dio(404);
    });
    when(() => dio.get<dynamic>(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => _ok<dynamic>(_offersEnvelope()));
  }

  group('fetchSummary — order_accepted journey shape', () {
    test('parses every pinned field from the real mock payloads', () async {
      stubHappyPath();

      final s = await repo.fetchSummary('del-client-001-active');

      expect(s.deliveryId, 'del-client-001-active');
      expect(s.requestId, 'req-client-001-accepted');
      expect(s.conversationId, 'conv-journey-accepted');
      expect(s.price, 9.0); // amount.value money object
      expect(s.currency, 'USD');
      expect(s.jeeberName, 'Kamal Hajj');
      expect(s.tier, 'express');
      expect(s.etaMinutes, 20); // from the accepted offer, not the delivery row
      expect(s.jeeberRating, 4.9); // from /users/:jeeberId (D6)
      expect(s.jeeberRatingCount, 312);
      expect(s.itemSummary, 'Groceries from Spinneys');
      expect(s.hasRating, isTrue);
    });

    test('enrichment failures NEVER fail the summary (core fields survive)',
        () async {
      // Delivery succeeds; request/offers/user all blow up.
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer((inv) async {
        final path = inv.positionalArguments.first as String;
        if (path == '/v1/deliveries/del-client-001-active') {
          return _ok(_deliveryRow());
        }
        throw _dio(500); // request + user enrichment fail
      });
      when(() => dio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(_dio(null, type: DioExceptionType.connectionError));

      final s = await repo.fetchSummary('del-client-001-active');

      // Core delivery-derived fields still present.
      expect(s.price, 9.0);
      expect(s.jeeberName, 'Kamal Hajj');
      expect(s.tier, 'express');
      expect(s.itemSummary, 'Groceries from Spinneys');
      expect(s.conversationId, 'conv-journey-accepted'); // from delivery row
      // ETA + rating degrade to null (their sources failed) — no crash.
      expect(s.etaMinutes, isNull);
      expect(s.jeeberRating, isNull);
      expect(s.hasRating, isFalse);
    });
  });

  group('fetchSummary — failure mapping', () {
    test('404 on the delivery fetch → notFound', () {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(_dio(404));
      expect(
        () => repo.fetchSummary('missing'),
        throwsA(
          isA<OrderSummaryRepositoryException>().having(
            (e) => e.failure,
            'failure',
            OrderSummaryFailure.notFound,
          ),
        ),
      );
    });

    test('connectionError on the delivery fetch → network', () {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(
        _dio(null, type: DioExceptionType.connectionError),
      );
      expect(
        () => repo.fetchSummary('del-client-001-active'),
        throwsA(
          isA<OrderSummaryRepositoryException>().having(
            (e) => e.failure,
            'failure',
            OrderSummaryFailure.network,
          ),
        ),
      );
    });
  });
}
