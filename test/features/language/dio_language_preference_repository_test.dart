// Unit tests for DioLanguagePreferenceRepository (JEBV4-205, E10).

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/locale/language_preference_repository.dart';
import 'package:jeeb_mobile/features/language/data/dio_language_preference_repository.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late DioLanguagePreferenceRepository repo;

  setUp(() {
    dio = _MockDio();
    repo = DioLanguagePreferenceRepository(dio);
  });

  Response<Map<String, dynamic>> okPost() => Response<Map<String, dynamic>>(
        requestOptions:
            RequestOptions(path: DioLanguagePreferenceRepository.setPath),
        statusCode: 201,
        data: const <String, dynamic>{'Message': 'Preference set successfully'},
      );

  group('save', () {
    test('POSTs { key: language, value } to the preferences endpoint', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => okPost());

      await repo.save('ar');

      final captured = verify(() => dio.post<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;
      expect(captured[0], '/api/UserPreferences/preferences');
      expect(captured[1], <String, dynamic>{'key': 'language', 'value': 'ar'});
    });

    test('trims the code and never writes to /api/User/* (GR-2)', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenAnswer((_) async => okPost());

      await repo.save('  en  ');

      final captured = verify(() => dio.post<Map<String, dynamic>>(
            captureAny(),
            data: captureAny(named: 'data'),
          )).captured;
      expect(captured[0], startsWith('/api/UserPreferences/'));
      expect((captured[0] as String).contains('/api/User/'), isFalse);
      expect((captured[1] as Map)['value'], 'en');
    });

    test('blank code is a no-op (no network write)', () async {
      await repo.save('   ');
      verifyNever(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          ));
    });

    test('401 maps to unauthorized', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions:
            RequestOptions(path: DioLanguagePreferenceRepository.setPath),
        response: Response<void>(
          requestOptions:
              RequestOptions(path: DioLanguagePreferenceRepository.setPath),
          statusCode: 401,
        ),
      ));

      await expectLater(
        repo.save('ar'),
        throwsA(isA<LanguagePreferenceException>().having(
          (e) => e.failure,
          'failure',
          LanguagePreferenceFailure.unauthorized,
        )),
      );
    });

    test('connection error maps to network', () async {
      when(() => dio.post<Map<String, dynamic>>(
            any(),
            data: any(named: 'data'),
          )).thenThrow(DioException(
        requestOptions:
            RequestOptions(path: DioLanguagePreferenceRepository.setPath),
        type: DioExceptionType.connectionError,
      ));

      await expectLater(
        repo.save('ar'),
        throwsA(isA<LanguagePreferenceException>().having(
          (e) => e.failure,
          'failure',
          LanguagePreferenceFailure.network,
        )),
      );
    });
  });

  group('fetch', () {
    test('GETs the single-key path and returns the stored value', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions:
              RequestOptions(path: DioLanguagePreferenceRepository.getPath),
          statusCode: 200,
          data: const <String, dynamic>{'value': 'ar'},
        ),
      );

      final code = await repo.fetch();

      expect(code, 'ar');
      final path =
          verify(() => dio.get<Map<String, dynamic>>(captureAny())).captured;
      expect(path.single, '/api/UserPreferences/preferences/language');
    });

    test('404 (unset key) returns null, not an error', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(DioException(
        requestOptions:
            RequestOptions(path: DioLanguagePreferenceRepository.getPath),
        response: Response<void>(
          requestOptions:
              RequestOptions(path: DioLanguagePreferenceRepository.getPath),
          statusCode: 404,
        ),
      ));

      expect(await repo.fetch(), isNull);
    });

    test('missing/blank value returns null', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          requestOptions:
              RequestOptions(path: DioLanguagePreferenceRepository.getPath),
          statusCode: 200,
          data: const <String, dynamic>{'value': '   '},
        ),
      );

      expect(await repo.fetch(), isNull);
    });

    test('connection error maps to network', () async {
      when(() => dio.get<Map<String, dynamic>>(any())).thenThrow(DioException(
        requestOptions:
            RequestOptions(path: DioLanguagePreferenceRepository.getPath),
        type: DioExceptionType.connectionError,
      ));

      await expectLater(
        repo.fetch(),
        throwsA(isA<LanguagePreferenceException>().having(
          (e) => e.failure,
          'failure',
          LanguagePreferenceFailure.network,
        )),
      );
    });
  });
}
