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
      test('parses bare array from mock :3055 GET /v1/requests/:id/offers',
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

      test('uses correct path /v1/requests/:id/offers', () async {
        String? capturedPath;
        final dio = Dio(BaseOptions(baseUrl: 'http://test'));
        dio.interceptors.add(
          InterceptorsWrapper(
            onRequest: (options, handler) {
              capturedPath = options.path;
              handler.resolve(
                Response(
                  data: <dynamic>[],
                  statusCode: 200,
                  requestOptions: options,
                ),
              );
            },
          ),
        );

        await DioOffersRepository(dio).fetchOffers('req-abc');
        expect(capturedPath, '/v1/requests/req-abc/offers');
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
