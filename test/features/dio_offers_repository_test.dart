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

    test('renders a LIVE-gateway offer with status "pending" (regression)',
        () async {
      // The live jeeb-gateway/offer-service stamps a fresh acceptable offer as
      // status:"pending" (the :4010 mock used "submitted"). Before the fix the
      // client filtered "pending" out, leaving "Choose a Jeeber" stuck on
      // "Waiting for offers" even though the offer arrived 200. This is the
      // exact wire shape captured from the live gateway on 2026-06-30.
      when(() => mockDio.get<dynamic>(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer(
        (_) async => Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: const {
            'items': [
              {
                'id': '667355d6-9a43-472c-a4b0-bec7c5151741',
                'requestId': '3f8ec2e4-b6b1-4fb9-83e3-243a5326de7f',
                'jeeberId': 'd1000000-0000-4000-8000-000000000002',
                'status': 'pending',
                'fee': 15,
                'etaMinutes': 15,
                'note': null,
              },
            ],
          },
          statusCode: 200,
        ),
      );

      final snapshot = await repo.fetchOffers('3f8ec2e4');
      expect(snapshot.offers, hasLength(1));
      expect(snapshot.offers.first.id, '667355d6-9a43-472c-a4b0-bec7c5151741');
      expect(snapshot.offers.first.fee, 15.0);
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
    test('POSTs to the live accept route /v1/offers/{offerId}/accept with '
        'NO body (preserve S07: do not leak status into the accept DTO)',
        () async {
      String? capturedPath;
      Map<Symbol, dynamic>? capturedNamed;
      when(() => mockDio.post<dynamic>(any())).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments.first as String;
        capturedNamed = invocation.namedArguments;
        return Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          data: const {'id': 'req-1', 'status': 'accepted'},
          statusCode: 200,
        );
      });

      await repo.acceptOffer(requestId: 'req-1', offerId: 'offer-9');

      // Accept IS /v1-prefixed (V1/JeebOffersController), asymmetric with the
      // /v1-less offer-create route.
      expect(capturedPath, '/v1/offers/offer-9/accept');
      // S07 fix: the accept call carries NO request body (data is null), so no
      // client-minted status (e.g. "accepted") can leak into the accept DTO.
      expect(capturedNamed?[#data], isNull,
          reason: 'accept sends no body — status must not be leaked client-side');
    });

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

    // sprint-009 scenario matrix #7: the gateway reuses 409 for several
    // distinct accept conflicts and discriminates via the ProblemDetails body
    // (OffersController.cs / RequestNotOpen409FidelityTests). Request-level
    // closures must map to requestNotOpen ("This request is no longer open."),
    // offer-level conflicts stay offerNotPending.
    void stubAcceptError(int statusCode, [Map<String, dynamic>? body]) {
      when(() => mockDio.post<dynamic>(any())).thenThrow(
        DioException(
          requestOptions: RequestOptions(path: ''),
          response: Response(
            requestOptions: RequestOptions(path: ''),
            statusCode: statusCode,
            data: body,
          ),
          type: DioExceptionType.badResponse,
        ),
      );
    }

    Matcher throwsFailure(OffersFailure failure) => throwsA(
          isA<OffersRepositoryException>()
              .having((e) => e.failure, 'failure', failure),
        );

    test('409 request-not-acceptable ProblemDetails -> requestNotOpen', () {
      stubAcceptError(409, const {
        'title': 'Request is no longer acceptable.',
        'status': 409,
        'type': 'https://jeeb.dev/errors/request-not-acceptable',
      });
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.requestNotOpen),
      );
    });

    test('409 already-accepted ProblemDetails -> requestNotOpen', () {
      stubAcceptError(409, const {
        'title': 'Offer already accepted.',
        'status': 409,
        'type': 'https://jeeb.dev/errors/already-accepted',
      });
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.requestNotOpen),
      );
    });

    test('409 with upstream request_not_open code -> requestNotOpen', () {
      stubAcceptError(409, const {'code': 'request_not_open', 'status': 409});
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.requestNotOpen),
      );
    });

    test('409 offer-not-pending ProblemDetails stays offerNotPending', () {
      stubAcceptError(409, const {
        'title': 'Offer can no longer be accepted.',
        'status': 409,
        'type': 'https://jeeb.dev/errors/offer-not-pending',
      });
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.offerNotPending),
      );
    });

    test('409 too-many-active-deliveries stays offerNotPending', () {
      stubAcceptError(409, const {
        'title': 'Jeeber already has the maximum active deliveries.',
        'status': 409,
        'type': 'https://jeeb.dev/errors/too-many-active-deliveries',
      });
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.offerNotPending),
      );
    });

    test('410 offer-expired -> requestNotOpen', () {
      stubAcceptError(410);
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.requestNotOpen),
      );
    });

    test('404 (offer/request pruned server-side) -> requestNotOpen, '
        'never a generic failure', () {
      stubAcceptError(404);
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.requestNotOpen),
      );
    });
  });
}
