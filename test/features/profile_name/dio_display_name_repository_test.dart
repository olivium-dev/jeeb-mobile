import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/features/profile_name/data/dio_display_name_repository.dart';
import 'package:jeeb_mobile/features/profile_name/domain/display_name_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioDisplayNameRepository repo;

  const meUserId = 'u-77777777-7777-4777-8777-777777777777';
  const meEmail = 'ahmad@example.com';

  setUp(() {
    dio = _MockDio();
    repo = DioDisplayNameRepository(dio);
  });

  Response<Map<String, dynamic>> ok() => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: DioDisplayNameRepository.path),
        statusCode: 200,
        data: const <String, dynamic>{},
      );

  void stubMe() {
    when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
      (_) async => Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: '/v1/users/me'),
        statusCode: 200,
        data: const <String, dynamic>{'userId': meUserId, 'email': meEmail},
      ),
    );
  }

  group('DioDisplayNameRepository.submitDisplayName', () {
    test('PUTs /api/User/profile with the required 4-field body', () async {
      stubMe();
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
      expect(captured[1], <String, dynamic>{
        'userId': meUserId,
        'email': meEmail,
        'username': 'Ahmad',
        'profilePic': '',
      });
    });

    test('trims surrounding whitespace before submitting', () async {
      stubMe();
      when(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => ok());

      await repo.submitDisplayName('  Ahmad Khaled  ');

      final captured = verify(() => dio.put<Map<String, dynamic>>(
            any(),
            data: captureAny(named: 'data'),
          )).captured;
      expect((captured.single as Map)['username'], 'Ahmad Khaled');
    });

    test('blank input is a NO-OP (never blanks the projection)', () async {
      await repo.submitDisplayName('   ');
      verifyNever(() => dio.put<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ));
    });

    test('401 maps to DisplayNameFailure.unauthorized', () async {
      stubMe();
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
      stubMe();
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
