// Widget/unit tests for DioOffersRepository (T-MOB-001 / T-MOB-015).
//
// Verifies:
//   - fetchOffers parses a valid JSON response into an OffersSnapshot.
//   - acceptOffer returns normally on 200.
//   - acceptOffer throws OffersRepositoryException(offerNotPending) on 409.
//   - fetchOffers throws OffersRepositoryException(network) on DioException.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/domain/jeeber_vehicle.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio mockDio;
  late DioOffersRepository repo;

  setUp(() {
    mockDio = _MockDio();
    repo = DioOffersRepository(mockDio);
  });

  group('fetchOffers', () {
    test(
        'parses { items } envelope using the REAL /v1/offers row shape '
        '(no name/rating/vehicle — those are NOT on the list row)', () async {
      // PRIOR DEFECT (TEST-INTEGRITY-AUDIT #1): this fixture invented
      // jeeberName/vehicle/rating/ratingCount fields. The live `GET /v1/offers`
      // route returns `store.offers` verbatim and `buildOffer`
      // (offer-service.ts) emits ONLY:
      //   { id, requestId, jeeberId, amount:{value,currency},
      //     price:{value,currency}, etaMinutes, note, status, editCount,
      //     submittedAt, createdAt, updatedAt }
      // The Jeeber's name/rating/avatar live ONLY on the chat `offer_card`
      // message body — never on this list row. Testing the invented shape
      // hid the defensive-fallback path that ACTUALLY runs in production
      // (covered by the next test).
      final now = DateTime.now().toUtc().toIso8601String();
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: {
            'items': [
              {
                'id': 'offer-1',
                'requestId': 'req-1',
                'jeeberId': 'user-jeeber-002',
                'amount': {'value': 35.0, 'currency': 'USD'},
                'price': {'value': 35.0, 'currency': 'USD'},
                'etaMinutes': 15,
                'note': 'On my way',
                'status': 'submitted',
                'editCount': 0,
                'submittedAt': now,
                'createdAt': now,
                'updatedAt': now,
              },
            ],
            'cursor': null,
          },
          statusCode: 200,
        ),
      );

      final snapshot = await repo.fetchOffers('req-1');
      expect(snapshot.offers.length, 1);
      final offer = snapshot.offers.first;
      expect(offer.id, 'offer-1');
      expect(offer.jeeberId, 'user-jeeber-002');
      // fee/currency parse out of the nested `amount` money object.
      expect(offer.fee, 35.0);
      expect(offer.currency, 'USD');
      expect(offer.etaMinutes, 15);
      expect(offer.note, 'On my way');
      expect(snapshot.requestIsOpen, isTrue);
    });

    test(
        'PRODUCTION FALLBACK: a name/rating/vehicle-less row renders the '
        'defensive defaults (the path that actually runs)', () async {
      // This is the row shape the live `/v1/offers` ACTUALLY returns (see the
      // test above). The repository's `_parseOffer` must fall back to sane
      // defaults for the display fields the list endpoint never provides. If
      // this fallback regresses, the real offer-review list shows blank names /
      // wrong ratings — a bug the prior (invented-shape) test could not catch.
      final now = DateTime.now().toUtc().toIso8601String();
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: {
            'items': [
              {
                'id': 'offer-7',
                'requestId': 'req-7',
                'jeeberId': 'user-jeeber-099',
                'amount': {'value': 12.5, 'currency': 'USD'},
                'price': {'value': 12.5, 'currency': 'USD'},
                'etaMinutes': 22,
                'status': 'submitted',
                'editCount': 0,
                'submittedAt': now,
                'createdAt': now,
                'updatedAt': now,
                // NOTE: no jeeberName, no rating, no ratingCount, no vehicle —
                // exactly as the live list endpoint emits.
              },
            ],
          },
          statusCode: 200,
        ),
      );

      final snapshot = await repo.fetchOffers('req-7');
      expect(snapshot.offers.length, 1);
      final offer = snapshot.offers.first;
      // Name falls back to the jeeberId (no display name on the row).
      expect(offer.jeeberName, 'user-jeeber-099');
      // Rating/ratingCount fall back to the parse defaults.
      expect(offer.rating, 4.5);
      expect(offer.ratingCount, 0);
      // Vehicle falls back to scooter when absent.
      expect(offer.vehicle, JeeberVehicle.scooter);
      // The real money fields still parse correctly.
      expect(offer.fee, 12.5);
      expect(offer.currency, 'USD');
      expect(offer.etaMinutes, 22);
      // No note on the row → null (not empty string).
      expect(offer.note, isNull);
    });

    test('throws OffersRepositoryException(network) on DioException', () {
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          type: DioExceptionType.connectionError,
        ),
      );

      expect(
        () => repo.fetchOffers('req-1'),
        throwsA(
          isA<OffersRepositoryException>().having(
            (e) => e.failure,
            'failure',
            OffersFailure.network,
          ),
        ),
      );
    });
  });

  group('acceptOffer', () {
    test('returns result (deliveryId null) on 200 with no delivery field',
        () async {
      when(() => mockDio.post<dynamic>(any())).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          // Pre-golden accept body — carries no delivery id.
          data: const {'id': 'req-1', 'status': 'accepted'},
          statusCode: 200,
        ),
      );

      final result =
          await repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1');
      expect(result.deliveryId, isNull);
    });

    test('surfaces deliveryId from the accept response (G3)', () async {
      when(() => mockDio.post<dynamic>(any())).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: const {'id': 'req-1', 'deliveryId': 'dlv-golden-001'},
          statusCode: 200,
        ),
      );

      final result =
          await repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1');
      expect(result.deliveryId, 'dlv-golden-001');
    });

    test('reads snake_case delivery_id defensively (G3)', () async {
      when(() => mockDio.post<dynamic>(any())).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: const {'delivery_id': 'dlv-snake-9'},
          statusCode: 200,
        ),
      );

      final result =
          await repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1');
      expect(result.deliveryId, 'dlv-snake-9');
    });

    test('throws offerNotPending on 409', () {
      when(() => mockDio.post<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: 409,
          ),
          type: DioExceptionType.badResponse,
        ),
      );

      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsA(
          isA<OffersRepositoryException>().having(
            (e) => e.failure,
            'failure',
            OffersFailure.offerNotPending,
          ),
        ),
      );
    });
  });
}
