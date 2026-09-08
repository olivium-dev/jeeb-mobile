// Widget/unit tests for DioOffersRepository (T-MOB-001 / T-MOB-015).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio mockDio;
  late DioOffersRepository repo;

  setUp(() {
    mockDio = _MockDio();
    when(() => mockDio.get<dynamic>(
          any(that: startsWith('/v1/requests/')),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer(
      (_) async => Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        data: const {'status': 'pending'},
        statusCode: 200,
      ),
    );
    repo = DioOffersRepository(mockDio);
  });

  group('fetchOffers', () {
    test('parses { items } envelope and returns OffersSnapshot', () async {
      final now = DateTime.now().toUtc().toIso8601String();
      when(() => mockDio.get<dynamic>(
            '/v1/offers',
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
      when(() => mockDio.get<dynamic>(
            '/v1/offers',
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
            '/v1/offers',
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
      when(() => mockDio.post<dynamic>(any(), options: any(named: 'options'))).thenAnswer((invocation) async {
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
      expect(capturedPath, '/v1/offers/offer-9/accept');
      // S07 fix: the accept call carries NO request body (data is null), so no
      expect(capturedNamed?[#data], isNull,
          reason: 'accept sends no body — status must not be leaked client-side');
      // Checklist (j): Retry and the error snack both re-POST, and
      // RetryInterceptor only replays mutations that carry the key.
      expect(
        (capturedNamed?[#options] as Options?)?.headers?['Idempotency-Key'],
        'accept-offer-9',
      );
    });

    test('returns result (deliveryId null) on 200 with no delivery field',
        () async {
      when(() => mockDio.post<dynamic>(any(), options: any(named: 'options'))).thenAnswer(
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
      when(() => mockDio.post<dynamic>(any(), options: any(named: 'options'))).thenAnswer(
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
      when(() => mockDio.post<dynamic>(any(), options: any(named: 'options'))).thenAnswer(
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
      when(() => mockDio.post<dynamic>(any(), options: any(named: 'options'))).thenThrow(
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
    void stubAcceptError(int statusCode, [Map<String, dynamic>? body]) {
      when(() => mockDio.post<dynamic>(any(), options: any(named: 'options'))).thenThrow(
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

    // AE-07: the bucket comes from the RFC 7807 `type` suffix, never from a
    // non-standard `code` member or English prose.
    test('409 with a request-not-open type suffix -> requestNotOpen', () {
      stubAcceptError(409, const {
        'status': 409,
        'type': 'https://jeeb.dev/errors/request-not-open',
      });
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.requestNotOpen),
      );
    });

    test('409 request-expired is no longer misbucketed', () {
      stubAcceptError(409, const {
        'status': 409,
        'type': 'https://jeeb.dev/errors/request-expired',
      });
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.requestExpired),
      );
    });

    test('409 offer-jeeber-insufficient-balance -> jeeberWalletShort', () {
      stubAcceptError(409, const {
        'status': 409,
        'type': 'https://jeeb.dev/errors/offer-jeeber-insufficient-balance',
      });
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.jeeberWalletShort),
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

    test('409 too-many-active-deliveries -> jeeberAtCapacity (JEBV4-158)', () {
      // BR-10: the winning Jeeber already holds the max concurrent active
      stubAcceptError(409, const {
        'title': 'Jeeber already has the maximum active deliveries.',
        'status': 409,
        'type': 'https://jeeb.dev/errors/too-many-active-deliveries',
      });
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsFailure(OffersFailure.jeeberAtCapacity),
      );
    });

    // The 7-value enum cannot round-trip 401/403/5xx: the transport's own
    // classification rides along so the screen never shows an inert Retry.
    test('a 403 keeps its classified ForbiddenFailure, not "unknown"', () {
      stubAcceptError(403);
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsA(
          isA<OffersRepositoryException>()
              .having((e) => e.failure, 'failure', OffersFailure.unknown)
              .having((e) => e.appFailure, 'appFailure', isA<ForbiddenFailure>()),
        ),
      );
    });

    test('a 500 keeps its classified ServerFailure', () {
      stubAcceptError(500);
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsA(
          isA<OffersRepositoryException>()
              .having((e) => e.appFailure, 'appFailure', isA<ServerFailure>()),
        ),
      );
    });

    test('a 409 with no classification still derives ConflictFailure', () {
      stubAcceptError(409);
      expect(
        () => repo.acceptOffer(requestId: 'req-1', offerId: 'offer-1'),
        throwsA(
          isA<OffersRepositoryException>()
              .having((e) => e.appFailure, 'appFailure', isA<ConflictFailure>()),
        ),
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
