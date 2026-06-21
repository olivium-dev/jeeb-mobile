import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/features/settings/data/repositories/dio_role_switch_repository.dart';
import 'package:jeeb_mobile/features/settings/domain/role_switch_repository.dart';

/// Stub that records the last POST and returns a fixed response/error.
class _FakeDio extends Fake implements Dio {
  String? lastPath;
  Map<String, dynamic>? lastData;
  Response<dynamic>? nextResponse;
  DioException? nextError;

  @override
  Future<Response<T>> post<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    lastPath = path;
    lastData = data as Map<String, dynamic>?;
    if (nextError != null) throw nextError!;
    return nextResponse! as Response<T>;
  }
}

class _MockAuthTokenStore extends Mock implements AuthTokenStore {}

void main() {
  late _FakeDio dio;
  late _MockAuthTokenStore tokenStore;
  late DioRoleSwitchRepository sut;

  setUp(() {
    dio = _FakeDio();
    tokenStore = _MockAuthTokenStore();
    sut = DioRoleSwitchRepository(dio, tokenStore);
    when(() => tokenStore.save(
          accessToken: any(named: 'accessToken'),
          refreshToken: any(named: 'refreshToken'),
          userId: any(named: 'userId'),
        )).thenAnswer((_) async {});
    when(() => tokenStore.clear()).thenAnswer((_) async {});
  });

  group('switchRole — endpoint contract (T-MOB-028)', () {
    test('calls POST /v1/users/me/role/switch with the target role', () async {
      dio.nextResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {
          'accessToken': 'access-new',
          'refreshToken': 'refresh-new',
        },
      );

      await sut.switchRole('jeeber');

      expect(dio.lastPath, '/v1/users/me/role/switch');
      expect(dio.lastData?['role'], 'jeeber');
    });

    test('returns success on 200', () async {
      dio.nextResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {
          'accessToken': 'access-new',
          'refreshToken': 'refresh-new',
        },
      );

      final result = await sut.switchRole('jeeber');

      expect(result, RoleSwitchResult.success);
    });
  });

  group('D-ROLE-TOGGLE — re-minted token adoption', () {
    test(
        'saves the new access+refresh PAIR (with userId) when the 200 body '
        'carries the re-minted tokens', () async {
      dio.nextResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {
          'userId': 'c23efd76',
          'active_role': 'jeeber',
          'available_roles': ['client', 'jeeber'],
          'accessToken': 'access-jeeber-capable',
          'refreshToken': 'refresh-jeeber-capable',
        },
      );

      final result = await sut.switchRole('jeeber');

      expect(result, RoleSwitchResult.success);
      verify(() => tokenStore.save(
            accessToken: 'access-jeeber-capable',
            refreshToken: 'refresh-jeeber-capable',
            userId: 'c23efd76',
          )).called(1);
    });

    test(
        'degrade: keeps the existing token (no save, no clear) when the 200 '
        'body carries EMPTY tokens', () async {
      dio.nextResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {
          'active_role': 'jeeber',
          'accessToken': '',
          'refreshToken': '',
        },
      );

      final result = await sut.switchRole('jeeber');

      expect(result, RoleSwitchResult.success);
      verifyNever(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          ));
      verifyNever(() => tokenStore.clear());
    });

    test(
        'degrade: keeps the existing token (no save) when the 200 body OMITS '
        'the tokens entirely', () async {
      dio.nextResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {'active_role': 'jeeber'},
      );

      final result = await sut.switchRole('jeeber');

      expect(result, RoleSwitchResult.success);
      verifyNever(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          ));
      verifyNever(() => tokenStore.clear());
    });

    test('degrade: keeps the existing token when only the refresh is missing',
        () async {
      dio.nextResponse = Response<Map<String, dynamic>>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 200,
        data: const {'accessToken': 'access-only'},
      );

      final result = await sut.switchRole('jeeber');

      expect(result, RoleSwitchResult.success);
      verifyNever(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          ));
    });
  });

  group('switchRole — error mapping (T-MOB-028)', () {
    test('returns kycGated on 403 and never touches the token store', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 403,
        ),
      );

      final result = await sut.switchRole('jeeber');

      expect(result, RoleSwitchResult.kycGated);
      verifyNever(() => tokenStore.save(
            accessToken: any(named: 'accessToken'),
            refreshToken: any(named: 'refreshToken'),
            userId: any(named: 'userId'),
          ));
      verifyNever(() => tokenStore.clear());
    });

    test('throws RoleSwitchException on a non-403 network error', () async {
      dio.nextError = DioException(
        requestOptions: RequestOptions(path: ''),
        message: 'connection timeout',
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: ''),
          statusCode: 500,
        ),
      );

      expect(
        () => sut.switchRole('jeeber'),
        throwsA(isA<RoleSwitchException>()),
      );
    });
  });
}
