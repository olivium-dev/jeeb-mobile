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
    test('parses { items } envelope and returns OffersSnapshot', () async {
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
                'jeeberId': 'jeeber-1',
                'jeeberName': 'Karim',
                'amount': {'value': 35.0, 'currency': 'USD'},
                'etaMinutes': 15,
                'vehicle': 'scooter',
                'rating': 4.5,
                'ratingCount': 100,
                'status': 'submitted',
                'createdAt': now,
              },
            ],
            'cursor': null,
          },
          statusCode: 200,
        ),
      );

      final snapshot = await repo.fetchOffers('req-1');
      expect(snapshot.offers.length, 1);
      expect(snapshot.offers.first.id, 'offer-1');
      expect(snapshot.offers.first.fee, 35.0);
      expect(snapshot.requestIsOpen, isTrue);
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
