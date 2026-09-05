// iter6 offer-405 fix — DioOfferSubmissionRepository unit tests.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/app_failure.dart';
import 'package:jeeb_mobile/features/offers/data/dio_offer_submission_repository.dart';
import 'package:jeeb_mobile/features/offers/domain/offer_submission_repository.dart';

class _MockDio extends Mock implements Dio {}

Response<Map<String, dynamic>> _resp(
  Map<String, dynamic> data, {
  int status = 201,
}) =>
    Response<Map<String, dynamic>>(
      requestOptions: RequestOptions(path: ''),
      data: data,
      statusCode: status,
    );

DioException _err(int status, {Object? body}) => DioException(
      requestOptions: RequestOptions(path: ''),
      type: DioExceptionType.badResponse,
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: status,
        data: body,
      ),
    );

void main() {
  late _MockDio dio;
  late DioOfferSubmissionRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioOfferSubmissionRepository(dio);
  });

  // A live-shaped 201 OfferDto (no conversationId in the body).
  Map<String, dynamic> liveOfferDto({
    String id = 'offer-abc',
    String requestId = 'req-fcb53e13',
  }) =>
      {
        'id': id,
        'requestId': requestId,
        'jeeberId': 'jeeber-kamal',
        'status': 'pending',
        'fee': 5,
        'etaMinutes': 10,
        'note': null,
        'createdAt': '2026-06-21T20:18:00Z',
        'updatedAt': null,
      };

  group('submitOffer — route + body (BUG-2: the live offer route)', () {
    test('POSTs to the live request-scoped route /requests/{id}/offers '
        '(NO /v1; NOT the mock /v1/offers, NOT the absent /v1/requests/.../offers)',
        () async {
      String? capturedPath;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        capturedPath = invocation.positionalArguments.first as String;
        return _resp(liveOfferDto());
      });

      await repo.submitOffer(
        requestId: 'req-fcb53e13',
        priceUsd: 5,
        etaMinutes: 10,
      );

      // LIVE TRUTH (live-api-route-corrections.md + RequestOffersController
      expect(capturedPath, '/requests/req-fcb53e13/offers');
      expect(capturedPath, isNot(contains('/v1/offers')),
          reason: 'the bare /v1/offers route 405s on the live gateway');
      expect(capturedPath, isNot(contains('/v1/requests')),
          reason: 'the /v1/requests/{id}/offers route is absent (404) on live');
      expect(capturedPath!.contains('/v1'), isFalse,
          reason: 'offer-create carries no /v1 (only accept does)');
    });

    test('sends the gateway CreateOfferBody field names (fee/etaMinutes/note) '
        '— NOT priceUsd/requestId in the body', () async {
      Map<String, dynamic>? body;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        body = invocation.namedArguments[#data] as Map<String, dynamic>;
        return _resp(liveOfferDto());
      });

      await repo.submitOffer(
        requestId: 'req-1',
        priceUsd: 7.5,
        etaMinutes: 15,
        note: 'leave at door',
      );

      expect(body!['fee'], 7.5);
      expect(body!['etaMinutes'], 15);
      expect(body!['note'], 'leave at door');
      // The requestId travels in the URL, not the body; priceUsd was mock-only.
      expect(body!.containsKey('requestId'), isFalse);
      expect(body!.containsKey('priceUsd'), isFalse);
    });

    test('omits the note key when no note is supplied', () async {
      Map<String, dynamic>? body;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        body = invocation.namedArguments[#data] as Map<String, dynamic>;
        return _resp(liveOfferDto());
      });

      await repo.submitOffer(requestId: 'req-1', priceUsd: 3, etaMinutes: 20);

      expect(body!.containsKey('note'), isFalse);
    });
  });

  group('submitOffer — response parse', () {
    test('parses the 201 OfferDto `id` as the offerId', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _resp(liveOfferDto(id: 'offer-xyz')));

      final result = await repo.submitOffer(
        requestId: 'req-1',
        priceUsd: 5,
        etaMinutes: 10,
      );

      expect(result.offerId, 'offer-xyz');
    });

    test('falls back to the requestId for conversationId when the live 201 '
        'omits it (the jeeber is seated server-side, keyed by requestId)',
        () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => _resp(liveOfferDto(requestId: 'req-corr-key')),
      );

      final result = await repo.submitOffer(
        requestId: 'req-corr-key',
        priceUsd: 5,
        etaMinutes: 10,
      );

      expect(result.conversationId, 'req-corr-key');
    });

    test('prefers an explicit conversationId if the gateway ever returns one',
        () async {
      final dto = liveOfferDto()..['conversationId'] = 'conv-server-minted';
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _resp(dto));

      final result = await repo.submitOffer(
        requestId: 'req-1',
        priceUsd: 5,
        etaMinutes: 10,
      );

      expect(result.conversationId, 'conv-server-minted');
    });

    test('tolerates the legacy `offerId` key', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer(
        (_) async => _resp(const {'offerId': 'legacy-offer-1'}),
      );

      final result = await repo.submitOffer(
        requestId: 'req-1',
        priceUsd: 5,
        etaMinutes: 10,
      );

      expect(result.offerId, 'legacy-offer-1');
    });
  });

  group('submitOffer — error mapping', () {
    test('404 (request not found) → requestGone', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(_err(404));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>().having(
          (e) => e.failure,
          'failure',
          OfferSubmissionFailure.requestGone,
        )),
      );
    });

    test('bare 409 (no discriminator) → requestGone', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(_err(409));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>().having(
          (e) => e.failure,
          'failure',
          OfferSubmissionFailure.requestGone,
        )),
      );
    });

    test('409 request-not-open-for-offers → requestGone (bounce to feed), '
        'NOT the cap', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(_err(409, body: {
        'type': 'request-not-open-for-offers',
        'title': 'Request is not open for offers',
      }));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>().having(
          (e) => e.failure,
          'failure',
          OfferSubmissionFailure.requestGone,
        )),
      );
    });

    test('409 offer-already-exists → duplicateOffer (withdraw and re-bid), '
        'distinct from request-not-open', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(_err(409, body: {
        'type': 'https://jeeb.app/errors/offer-already-exists',
        'title': 'Offer already exists',
      }));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>().having(
          (e) => e.failure,
          'failure',
          OfferSubmissionFailure.duplicateOffer,
        )),
      );
    });

    test('AE-05/UX-12: a 409 whose detail carries a GUID containing "20" is '
        'requestGone, never a retired cap', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(_err(409, body: {
        'title': 'Conflict',
        'detail': 'offer 9c37b6af-4e21-4e4a-9c1b-1f2a3b4c2013 conflicts',
      }));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>().having(
          (e) => e.failure,
          'failure',
          OfferSubmissionFailure.requestGone,
        )),
      );
    });

    test('402 → insufficientBalance with parsed amounts', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(_err(402, body: {
        'needed': 0.5,
        'available': 0.2,
        'currency': 'USD',
      }));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>()
            .having((e) => e.failure, 'failure',
                OfferSubmissionFailure.insufficientBalance)
            .having((e) => e.balance?.needed, 'needed', 0.5)
            .having((e) => e.balance?.available, 'available', 0.2)),
      );
    });

    test('connection error → network', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>().having(
          (e) => e.failure,
          'failure',
          OfferSubmissionFailure.network,
        )),
      );
    });

    test('405 (or any other 4xx) → server', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(_err(405));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>().having(
          (e) => e.failure,
          'failure',
          OfferSubmissionFailure.server,
        )),
      );
    });

    test('500 → server carrying a ServerFailure cause, and NO "HTTP 500" '
        'string anywhere on the exception', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenThrow(_err(500));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>()
            .having((e) => e.failure, 'failure',
                OfferSubmissionFailure.server)
            .having((e) => e.cause, 'cause', isA<ServerFailure>())
            .having((e) => e.toString(), 'toString',
                isNot(contains('HTTP')))),
      );
    });

    test('NET-12: every submit carries an Idempotency-Key header, and the '
        'composer-owned key is the one sent', () async {
      Options? captured;
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((invocation) async {
        captured = invocation.namedArguments[#options] as Options?;
        return _resp(liveOfferDto());
      });

      await repo.submitOfferIdempotent(
        requestId: 'req-1',
        priceUsd: 5,
        etaMinutes: 10,
        idempotencyKey: 'draft-key-1',
      );

      expect(captured?.headers?['Idempotency-Key'], 'draft-key-1');
    });

    test('a 201 that names no offer is NOT a success', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
            options: any(named: 'options'),
          )).thenAnswer((_) async => _resp(<String, dynamic>{}));

      await expectLater(
        repo.submitOffer(requestId: 'req-1', priceUsd: 5, etaMinutes: 10),
        throwsA(isA<OfferSubmissionException>()
            .having((e) => e.failure, 'failure',
                OfferSubmissionFailure.server)
            .having((e) => e.cause, 'cause', isA<UnknownFailure>())),
      );
    });
  });
}
