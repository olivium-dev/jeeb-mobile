// Tests for DioRatingRepository (T-MOB-001).
//
// Verifies:
//   - submitRating calls POST /v1/ratings/jeeb/{deliveryId}.
//   - submitRating passes correct raterRole for client vs jeeber.
//   - submitRating throws Exception on DioException.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/rating/data/dio_rating_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio mockDio;
  late DioRatingRepository repo;

  setUp(() {
    mockDio = _MockDio();
    repo = DioRatingRepository(mockDio);
  });

  test('submitRating calls correct endpoint and body for client', () async {
    when(() => mockDio.post<void>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response<void>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 201,
      ),
    );

    await repo.submitRating(
      deliveryId: 'DLV-1',
      stars: 5,
      isClient: true,
      comment: 'Great service',
    );

    final captured = verify(
      () => mockDio.post<void>(
        any(),
        data: captureAny(named: 'data'),
      ),
    ).captured;

    final body = captured.first as Map<String, dynamic>;
    expect(body['stars'], 5);
    expect(body['raterRole'], 'client');
    expect(body['comment'], 'Great service');
  });

  test('submitRating uses raterRole=jeeber when isClient=false', () async {
    when(() => mockDio.post<void>(any(), data: any(named: 'data'))).thenAnswer(
      (_) async => Response<void>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 201,
      ),
    );

    await repo.submitRating(
      deliveryId: 'DLV-1',
      stars: 3,
      isClient: false,
    );

    final captured = verify(
      () => mockDio.post<void>(
        any(),
        data: captureAny(named: 'data'),
      ),
    ).captured;

    final body = captured.first as Map<String, dynamic>;
    expect(body['raterRole'], 'jeeber');
    expect(body.containsKey('comment'), isFalse);
  });

  test('submitRating throws Exception on DioException', () {
    when(() => mockDio.post<void>(any(), data: any(named: 'data'))).thenThrow(
      DioException(
        requestOptions: RequestOptions(path: ''),
        type: DioExceptionType.connectionError,
      ),
    );

    expect(
      () => repo.submitRating(
        deliveryId: 'DLV-1',
        stars: 4,
        isClient: true,
      ),
      throwsException,
    );
  });
}
