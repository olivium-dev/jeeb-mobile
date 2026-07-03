// Unit tests for DioDisplayNameRepository (profile-name lane).
//
// Verifies the PUT payload shape the cycle-2 gateway mirrors into the users
// projection:
//   PUT /api/User/profile   body: { "username": "<display name>" }
// plus trimming, the empty-input no-op, and typed failure mapping.

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/profile_name/data/dio_display_name_repository.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioDisplayNameRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioDisplayNameRepository(dio);
  });

  Response<Map<String, dynamic>> ok() => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: DioDisplayNameRepository.path),
        statusCode: 200,
        data: const <String, dynamic>{},
      );

  group('DioDisplayNameRepository.submitDisplayName', () {
    test('PUTs /api/User/profile with {username: <name>}', () async {
      when(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => ok());

      await repo.submitDisplayName('Ahmad');

      final captured = verify(() => dio.put<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;
      expect(captured[0], '/api/User/profile');
      expect(captured[1], <String, dynamic>{'username': 'Ahmad'});
    });

    test('trims surrounding whitespace before submitting', () async {
      when(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => ok());

      await repo.submitDisplayName('  Ahmad Khaled  ');

      final captured = verify(() => dio.put<Map<String, dynamic>>(
            any(),
            data: captureAny(named: 'data'),
          )).captured;
      expect(captured.single, <String, dynamic>{'username': 'Ahmad Khaled'});
    });

    test('blank input is a NO-OP (never blanks the projection)', () async {
      await repo.submitDisplayName('   ');
      verifyNever(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ));
    });

    test('401 maps to DisplayNameFailure.unauthorized', () async {
      when(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: DioDisplayNameRepository.path),
        response: Response<void>(
          requestOptions:
              RequestOptions(path: DioDisplayNameRepository.path),
          statusCode: 401,
        ),
      ));

      await expectLater(
        repo.submitDisplayName('Ahmad'),
        throwsA(isA<DisplayNameRepositoryException>().having(
          (e) => e.failure,
          'failure',
          DisplayNameFailure.unauthorized,
        )),
      );
    });

    test('connection error maps to DisplayNameFailure.network', () async {
      when(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions: RequestOptions(path: DioDisplayNameRepository.path),
        type: DioExceptionType.connectionError,
      ));

      await expectLater(
        repo.submitDisplayName('Ahmad'),
        throwsA(isA<DisplayNameRepositoryException>().having(
          (e) => e.failure,
          'failure',
          DisplayNameFailure.network,
        )),
      );
    });
  });
}
