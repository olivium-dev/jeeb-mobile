// Tests for DioRatingRepository (JM-034).
//
// Verifies against the real Express mock score-taking-service contract:
//   - submitRating POSTs /v1/ratings/jeeb/submit with deliveryId + score +
//     raterRole + raterId (from the session token store).
//   - submitRating passes raterRole=client vs jeeber.
//   - submitRating maps a DioException to a typed RatingRepositoryException
//     (network on connection errors).
//   - fetchRatingStatus GETs /v1/ratings/jeeb/{id}/status and parses the
//     mock `state` shape.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/rating/data/dio_rating_repository.dart';
import 'package:jeeb_mobile/features/rating/domain/entities/rating_status.dart';
import 'package:jeeb_mobile/features/rating/domain/rating_repository.dart';

class _MockDio extends Mock implements Dio {}

class _FakeTokenStore extends AuthTokenStore {
  _FakeTokenStore(this._userId);
  final String? _userId;
  @override
  Future<String?> get userId async => _userId;
}

void main() {
  late _MockDio mockDio;
  late DioRatingRepository repo;

  setUp(() {
    mockDio = _MockDio();
    repo = DioRatingRepository(
      mockDio,
      tokenStore: _FakeTokenStore('user-client-001'),
    );
  });

  test('submitRating POSTs the score-taking submit contract for client',
      () async {
    when(() => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        )).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {'id': 'r-1'},
      ),
    );

    await repo.submitRating(
      deliveryId: 'DLV-1',
      stars: 5,
      isClient: true,
      comment: 'Great service',
    );

    final captured = verify(
      () => mockDio.post<Map<String, dynamic>>(
        captureAny(),
        data: captureAny(named: 'data'),
      ),
    ).captured;

    final path = captured[0] as String;
    final body = captured[1] as Map<String, dynamic>;
    expect(path, '/v1/ratings/jeeb/submit');
    expect(body['deliveryId'], 'DLV-1');
    expect(body['score'], 5);
    expect(body['raterRole'], 'client');
    expect(body['raterId'], 'user-client-001');
    expect(body['comment'], 'Great service');
  });

  test('submitRating uses raterRole=jeeber when isClient=false', () async {
    when(() => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        )).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {'id': 'r-2'},
      ),
    );

    await repo.submitRating(deliveryId: 'DLV-1', stars: 3, isClient: false);

    final body = verify(
      () => mockDio.post<Map<String, dynamic>>(
        any(),
        data: captureAny(named: 'data'),
      ),
    ).captured.first as Map<String, dynamic>;
    expect(body['raterRole'], 'jeeber');
    expect(body.containsKey('comment'), isFalse);
  });

  test('submitRating maps a connection error to RatingFailure.network', () {
    when(() => mockDio.post<Map<String, dynamic>>(
          any(),
          data: any(named: 'data'),
        )).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(
      () => repo.submitRating(deliveryId: 'DLV-1', stars: 4, isClient: true),
      throwsA(
        isA<RatingRepositoryException>().having(
          (e) => e.failure,
          'failure',
          RatingFailure.network,
        ),
      ),
    );
  });

  test('fetchRatingStatus parses the mock state shape', () async {
    when(() => mockDio.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {
          'deliveryId': 'DLV-1',
          'state': 'revealed',
          'ratings': [
            {'score': 4, 'comment': 'ok'},
          ],
          'ratedCount': 2,
        },
      ),
    );

    final status = await repo.fetchRatingStatus(deliveryId: 'DLV-1');
    expect(status.revealState, RatingRevealState.bothRated);
    expect(status.counterpartRating?.stars, 4);
  });
}
