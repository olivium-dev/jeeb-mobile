import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/features/client_offers/data/dio_offers_repository.dart';
import 'package:jeeb_mobile/features/client_offers/domain/offers_repository.dart';

Dio _dioRespond(Object? body, {int status = 200}) {
  final dio = Dio(BaseOptions(baseUrl: 'http://test'));
  dio.interceptors.add(
    InterceptorsWrapper(
      onRequest: (options, handler) {
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

Dio _dioError(DioExceptionType type, {int? status}) {
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
                    data: null,
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
        final now = DateTime.now().toUtc().toIso8601String();
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
                'createdAt': now,
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
        expect(snapshot.windowExpiresAt.isAfter(DateTime.now()), isTrue);
      });

      test('derives deadline = first-offer createdAt + 5 min when absent',
          () async {
        // Use a recent timestamp (1 min ago) so windowExpiresAt = +4 min is
        // still in the future and the assertion does not become stale over time.
        final created = DateTime.now().toUtc().subtract(const Duration(minutes: 1));
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
        expect(
          snapshot.windowExpiresAt,
          created.add(const Duration(minutes: 5)),
        );
      });

      test('falls back to 5-min window when offer list is empty', () async {
        final before = DateTime.now();
        final repo = DioOffersRepository(_dioRespond(<dynamic>[]));

        final snapshot = await repo.fetchOffers('req-1');
        final after = DateTime.now().add(const Duration(minutes: 5));
        expect(
          snapshot.windowExpiresAt.isAfter(before),
          isTrue,
        );
        expect(
          snapshot.windowExpiresAt.isBefore(after.add(const Duration(seconds: 1))),
          isTrue,
        );
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
        String? capturedPath;
        Map<String, dynamic>? capturedQuery;
        final dio = Dio(BaseOptions(baseUrl: 'http://test'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.path;
              capturedQuery = options.queryParameters;
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
        expect(capturedPath, '/v1/offers');
        expect(capturedQuery, {'requestId': 'req-abc'});
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
    });
  });
}
