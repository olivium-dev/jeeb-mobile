import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';

Dio _dioRespond(
  Object? offersBody, {
  int status = 200,
  Object? requestBody = const {'status': 'pending'},
}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        final body = options.path.startsWith('/v1/requests/')
            ? requestBody
            : offersBody;
        handler.resolve(
          Response(
            data: body,
            statusCode: status,
            requestOptions: options,
          ),
        );
      },
    ),
  );
  return dio;
}

Dio _dioError(DioExceptionType type, {int? status, Object? body}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
        handler.reject(
          DioException(
            requestOptions: options,
            type: type,
            response: status != null
                ? Response(
                    data: body,
                    statusCode: status,
                    requestOptions: options,
                  )
                : null,
          ),
        );
      },
    ),
  );
  return dio;
}

void main() {
  group('DioOffersRepository — T-MOB-015 endpoint contract', () {
    group('fetchOffers', () {
      test('parses { items: [...] } envelope from GET /v1/offers?requestId=',
          () async {
        final now = DateTime.now().toUtc();
        final t1 = now.subtract(const Duration(minutes: 1)).toIso8601String();
        final repo = DioOffersRepository(
          _dioRespond({
            'items': [
              {
                'id': 'offer-001',
                'requestId': 'req-client-001-offers',
                'jeeberId': 'user-jeeber-002',
                'status': 'submitted',
                'amount': {'value': 6.0, 'currency': 'USD'},
                'price': {'value': 6.0, 'currency': 'USD'},
                'etaMinutes': 20,
                'note': 'On my way',
                'createdAt': t1,
              },
              {
                'id': 'offer-002',
                'requestId': 'req-client-001-offers',
                'jeeberId': 'user-jeeber-003',
                'status': 'withdrawn',
                'amount': {'value': 7.5, 'currency': 'USD'},
                'etaMinutes': 35,
                'createdAt': t1,
              },
            ],
            'cursor': null,
          }),
        );

        final snapshot = await repo.fetchOffers('req-client-001-offers');

        // Withdrawn offer is filtered out — only the live submitted bid shows.
        expect(snapshot.offers.length, 1);
        expect(snapshot.offers.first.id, 'offer-001');
        expect(snapshot.offers.first.fee, 6.0);
        expect(snapshot.offers.first.currency, 'USD');
        expect(snapshot.offers.first.etaMinutes, 20);
        expect(snapshot.offers.first.note, 'On my way');
        expect(snapshot.requestIsOpen, isTrue);
      });

      test(
          'renders a LIVE gateway offer whose status is "pending" '
          '(iter6 offer-card render gap)', () async {
        // The LIVE gateway BFF collapses offer-service submitted/edited/pending
        // → "pending" and emits the flat OfferDto shape inside { items: [...] }.
        // Before the fix the repo's live-status set was {submitted, edited}, so
        // this real on-device offer was silently dropped → the Choose-a-Jeeber
        // screen showed "Waiting for offers" even though the body had the offer.
        const submittedAt = '2026-07-04T23:05:45.994303Z';
        final repo = DioOffersRepository(
          _dioRespond({
            'items': [
              {
                'id': 'a7e85c0b-real-offer',
                'requestId': '7299b700-real-request',
                'jeeberId': 'd1000000-0000-4000-8000-000000000002',
                'status': 'pending',
                'fee': 6.5,
                'etaMinutes': 18,
                'note': 'Karim here, on my way',
                'createdAt': submittedAt,
              },
            ],
          }),
        );

        final snapshot = await repo.fetchOffers('7299b700-real-request');

        // The pending offer survives the filter and surfaces as a card-ready
        // Offer with the jeeber's fee / ETA / note parsed.
        expect(snapshot.offers, hasLength(1));
        expect(snapshot.offers.first.id, 'a7e85c0b-real-offer');
        expect(snapshot.offers.first.jeeberId,
            'd1000000-0000-4000-8000-000000000002');
        expect(snapshot.offers.first.fee, 6.5);
        expect(snapshot.offers.first.etaMinutes, 18);
        expect(snapshot.offers.first.note, 'Karim here, on my way');
        expect(snapshot.requestIsOpen, isTrue);
        expect(snapshot.requestIsExpired, isFalse);
        expect(snapshot.windowExpiresAt, isNull,
            reason: 'an old offer timestamp must not become a client deadline');
      });

      test(
          'un-enriched row defaults to an HONEST 0.0 rating / 0 count — never '
          'a fabricated 4.5 (SW-08)', () async {
        // The live offer-list endpoint does NOT enrich rows with the Jeeber's
        // display name or rating (O-list-enrich gap). The pre-fix parser
        // defaulted a missing rating to 4.5, which — paired with a 0 count —
        // produced the "4.5 (0)" fabrication the offer card used to render.
        final now = DateTime.now().toUtc().toIso8601String();
        final repo = DioOffersRepository(
          _dioRespond({
            'items': [
              {
                'id': 'unrated-offer',
                'requestId': 'req-1',
                'jeeberId': 'd1000000-0000-4000-8000-000000000002',
                'status': 'pending',
                'fee': 6.5,
                'etaMinutes': 18,
                'createdAt': now,
                // no jeeberName, no rating, no ratingCount
              },
            ],
          }),
        );

        final snapshot = await repo.fetchOffers('req-1');
        final offer = snapshot.offers.single;

        // Rating is an honest zero, not the old fabricated 4.5.
        expect(offer.rating, 0.0);
        expect(offer.ratingCount, 0);
        // With no name on the row, jeeberName falls back to the id — which the
        // presentation layer (OfferCard) suppresses via displayNameOrNull.
        expect(offer.jeeberName, 'd1000000-0000-4000-8000-000000000002');
      });

      test('marks request closed when an accepted offer is present', () async {
        final now = DateTime.now().toUtc().toIso8601String();
        final repo = DioOffersRepository(
          _dioRespond({
            'items': [
              {
                'id': 'offer-001',
                'jeeberId': 'j1',
                'status': 'accepted',
                'amount': {'value': 6.0, 'currency': 'USD'},
                'etaMinutes': 20,
                'createdAt': now,
              },
            ],
          }),
        );

        final snapshot = await repo.fetchOffers('req-1');
        expect(snapshot.requestIsOpen, isFalse);
        // The accepted offer is not a live bid — it is filtered from the list.
        expect(snapshot.offers, isEmpty);
      });

      test('still parses a bare top-level array (legacy / tolerant path)',
          () async {
        // Use a recent timestamp so the derived 5-min deadline is always in the
        // future regardless of when this test runs (blocker fix 2026-06-13).
        final now = DateTime.now().toUtc();
        final t1 = now.subtract(const Duration(minutes: 1)).toIso8601String();
        final t2 = now.subtract(const Duration(seconds: 30)).toIso8601String();
        final repo = DioOffersRepository(
          _dioRespond([
            {
              'id': 'e-offer-kamal',
              'requestId': 'request-replies-001',
              'jeeberId': 'user-jeeber-002',
              'status': 'submitted',
              'fee': 35.00,
              'etaMinutes': 25,
              'createdAt': t1,
            },
            {
              'id': 'e-offer-rana',
              'requestId': 'request-replies-001',
              'jeeberId': 'user-jeeber-003',
              'status': 'submitted',
              'fee': 30.00,
              'etaMinutes': 30,
              'createdAt': t2,
            },
          ]),
        );

        final snapshot = await repo.fetchOffers('request-replies-001');

        expect(snapshot.offers.length, 2);
        expect(snapshot.offers[0].id, 'e-offer-kamal');
        expect(snapshot.offers[0].fee, 35.00);
        expect(snapshot.offers[1].id, 'e-offer-rana');
        expect(snapshot.requestIsOpen, isTrue);
        expect(snapshot.windowExpiresAt, isNull);
      });

      test('does not derive a deadline from first-offer createdAt when absent',
          () async {
        final created = DateTime.utc(2026, 7, 4, 23, 5, 45);
        final repo = DioOffersRepository(
          _dioRespond([
            {
              'id': 'o1',
              'jeeberId': 'j1',
              'fee': 20.0,
              'etaMinutes': 10,
              'createdAt': created.toIso8601String(),
            },
          ]),
        );

        final snapshot = await repo.fetchOffers('req-1');
        expect(snapshot.windowExpiresAt, isNull);
      });

      test('does not fabricate a deadline when the offer list is empty',
          () async {
        final repo = DioOffersRepository(_dioRespond(<dynamic>[]));

        final snapshot = await repo.fetchOffers('req-1');
        expect(snapshot.windowExpiresAt, isNull);
      });

      test('preserves a server-provided request deadline exactly', () async {
        final repo = DioOffersRepository(
          _dioRespond(
            const {'items': <dynamic>[]},
            requestBody: const {
              'status': 'pending',
              'windowExpiresAt': '2026-07-22T17:00:00Z',
            },
          ),
        );

        final snapshot = await repo.fetchOffers('req-1');

        expect(snapshot.windowExpiresAt, DateTime.utc(2026, 7, 22, 17));
        expect(snapshot.requestIsOpen, isTrue);
      });

      test('terminal request status wins over a stale pending offer row',
          () async {
        final repo = DioOffersRepository(
          _dioRespond(
            const {
              'items': [
                {
                  'id': 'stale-offer',
                  'jeeberId': 'jeeber-1',
                  'status': 'pending',
                  'createdAt': '2026-07-04T23:05:45Z',
                },
              ],
            },
            requestBody: const {
              'status': 'expired',
              'requestIsOpen': true,
            },
          ),
        );

        final snapshot = await repo.fetchOffers('req-1');

        expect(snapshot.offers, hasLength(1));
        expect(snapshot.requestIsOpen, isFalse);
        expect(snapshot.requestIsExpired, isTrue);
        expect(snapshot.windowExpiresAt, isNull);
      });

      test('throws network failure on connection error', () async {
        final repo = DioOffersRepository(
          _dioError(DioExceptionType.connectionError),
        );

        await expectLater(
          repo.fetchOffers('req-1'),
          throwsA(
            predicate<OffersRepositoryException>(
              (e) => e.failure == OffersFailure.network,
            ),
          ),
        );
      });

      test('uses path /v1/offers with requestId query (JM-028 contract)',
          () async {
        final captured = <RequestOptions>[];
        final dio = Dio(BaseOptions(baseUrl: 'http://test'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              captured.add(options);
              handler.resolve(
                Response(
                  data: const {'items': <dynamic>[]},
                  statusCode: 200,
                  requestOptions: options,
                ),
              );
            },
          ),
        );

        await DioOffersRepository(dio).fetchOffers('req-abc');
        expect(
          captured.map((request) => request.path),
          ['/v1/offers', '/v1/requests/req-abc'],
        );
        expect(captured.first.queryParameters, {'requestId': 'req-abc'});
      });
    });

    group('acceptOffer', () {
      test('completes normally on 200', () async {
        final repo = DioOffersRepository(_dioRespond(null));

        await expectLater(
          repo.acceptOffer(requestId: 'req-1', offerId: 'e-offer-kamal'),
          completes,
        );
      });

      test('uses path /v1/offers/:offerId/accept (AC2)', () async {
        String? capturedPath;
        final dio = Dio(BaseOptions(baseUrl: 'http://test'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.path;
              handler.resolve(
                Response(
                  data: null,
                  statusCode: 200,
                  requestOptions: options,
                ),
              );
            },
          ),
        );

        await DioOffersRepository(dio).acceptOffer(
          requestId: 'req-1',
          offerId: 'e-offer-kamal',
        );
        expect(capturedPath, '/v1/offers/e-offer-kamal/accept');
      });

      test('throws offerNotPending on 409 race conflict (AC3)', () async {
        final repo = DioOffersRepository(
          _dioError(DioExceptionType.badResponse, status: 409),
        );

        await expectLater(
          repo.acceptOffer(requestId: 'req-1', offerId: 'oid'),
          throwsA(
            predicate<OffersRepositoryException>(
              (e) => e.failure == OffersFailure.offerNotPending,
            ),
          ),
        );
      });

      test('throws requestNotOpen on 410', () async {
        final repo = DioOffersRepository(
          _dioError(DioExceptionType.badResponse, status: 410),
        );

        await expectLater(
          repo.acceptOffer(requestId: 'req-1', offerId: 'oid'),
          throwsA(
            predicate<OffersRepositoryException>(
              (e) => e.failure == OffersFailure.requestNotOpen,
            ),
          ),
        );
      });

      test(
          'throws jeeberAtCapacity (not offerNotPending) on a 409 '
          'too-many-active-deliveries ProblemDetails (BR-10 mislabel fix)',
          () async {
        final repo = DioOffersRepository(
          _dioError(
            DioExceptionType.badResponse,
            status: 409,
            body: <String, dynamic>{
              'type': 'https://jeeb.dev/errors/too-many-active-deliveries',
              'title':
                  'Maximum 2 active deliveries. Complete a delivery before '
                      'accepting another.',
              'status': 409,
              'detail': 'Jeeber has 7 active deliveries (limit 2).',
            },
          ),
        );

        await expectLater(
          repo.acceptOffer(requestId: 'req-1', offerId: 'oid'),
          throwsA(
            predicate<OffersRepositoryException>(
              (e) => e.failure == OffersFailure.jeeberAtCapacity,
            ),
          ),
        );
      });

      test('still throws offerNotPending on a 409 without the BR-10 type',
          () async {
        final repo = DioOffersRepository(
          _dioError(
            DioExceptionType.badResponse,
            status: 409,
            body: <String, dynamic>{
              'type': 'https://jeeb.dev/errors/offer-not-acceptable',
              'status': 409,
            },
          ),
        );

        await expectLater(
          repo.acceptOffer(requestId: 'req-1', offerId: 'oid'),
          throwsA(
            predicate<OffersRepositoryException>(
              (e) => e.failure == OffersFailure.offerNotPending,
            ),
          ),
        );
      });
    });
  });
}
