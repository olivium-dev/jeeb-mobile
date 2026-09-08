import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/role/role_availability_cubit.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/features/settings/data/shared_prefs_profile_repository.dart';
import 'package:jeeb_mobile/features/settings/data/dio_account_session_terminator.dart';

/// Records every write verb so the test can assert the exact gateway contract
/// the terminator speaks. All calls succeed (204) unless [failUnregister] is
/// set, so the fail-safe local-clear path can be exercised independently.
class _RecordingDio extends Fake implements Dio {
  final List<String> deletePaths = <String>[];
  final List<Map<String, dynamic>?> deleteBodies = <Map<String, dynamic>?>[];
  final List<String> postPaths = <String>[];
  final List<String> patchPaths = <String>[];
  bool failUnregister = false;
  bool failDeletion = false;

  Response<T> _ok<T>(String path) => Response<T>(
        requestOptions: RequestOptions(path: path),
        statusCode: 204,
      );

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
    postPaths.add(path);
    return _ok<T>(path);
  }


  /// F3: `deleteAccount` now THROWS on a failed remote deletion, so the fake
  /// has to answer the PATCH the way the gateway does.
  @override
  Future<Response<T>> patch<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    patchPaths.add(path);
    if (failDeletion) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: 500,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return _ok<T>(path);
  }

  @override
  Future<Response<T>> delete<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    deletePaths.add(path);
    deleteBodies.add(data as Map<String, dynamic>?);
    if (failUnregister) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: 404,
        ),
        type: DioExceptionType.badResponse,
      );
    }
    return _ok<T>(path);
  }
}

/// In-memory secure storage backing the [AuthTokenStore] so the terminator's
/// keystore reads/clear run on the pure-Dart VM.
class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> data = {};

  @override
  Future<String?> read({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async =>
      data[key];

  @override
  Future<void> write({
    required String key,
    required String? value,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    if (value != null) data[key] = value;
  }

  @override
  Future<void> delete({
    required String key,
    IOSOptions? iOptions,
    AndroidOptions? aOptions,
    LinuxOptions? lOptions,
    WebOptions? webOptions,
    MacOsOptions? mOptions,
    WindowsOptions? wOptions,
  }) async {
    data.remove(key);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _RecordingDio dio;
  late _FakeSecureStorage storage;
  late AuthTokenStore tokenStore;

  setUp(() {
    dio = _RecordingDio();
    storage = _FakeSecureStorage();
    tokenStore = AuthTokenStore(storage: storage);
    SharedPreferences.setMockInitialValues(<String, Object>{});
  });

  DioAccountSessionTerminator build({String? deviceId = 'dev-abc'}) =>
      DioAccountSessionTerminator(
        dio,
        tokenStore,
        deviceIdProvider: () async => deviceId,
      );

  test('logout unregisters via DELETE /api/PushNotification/device { deviceId } '
      '— the live gateway route, NOT the dead POST /v1/devices/unregister',
      () async {
    await storage.write(key: 'auth.refreshToken', value: 'rt-1');

    await build().logout();

    // The dead route is gone.
    expect(dio.postPaths, isNot(contains('/v1/devices/unregister')));
    // The live gateway route fired with the deviceId body (userId is derived
    expect(dio.deletePaths, contains('/api/PushNotification/device'));
    final body = dio.deleteBodies.single;
    expect(body?['deviceId'], 'dev-abc');
    expect(body?.containsKey('userId'), isFalse);
  });

  test('logout still clears the local session when the unregister DELETE fails '
      '(best-effort — never blocks logout)', () async {
    await storage.write(key: 'auth.accessToken', value: 'at-1');
    await storage.write(key: 'auth.refreshToken', value: 'rt-1');
    await storage.write(key: 'auth.userId', value: 'u-1');
    dio.failUnregister = true;

    await build().logout();

    // The DELETE was attempted…
    expect(dio.deletePaths, contains('/api/PushNotification/device'));
    // …and the failure did not stop the load-bearing local keystore clear (D5).
    expect(storage.data.containsKey('auth.accessToken'), isFalse);
    expect(storage.data.containsKey('auth.refreshToken'), isFalse);
    expect(storage.data.containsKey('auth.userId'), isFalse);
  });

  test('no persisted deviceId → the unregister hop is skipped (still clears)',
      () async {
    await storage.write(key: 'auth.accessToken', value: 'at-1');

    await build(deviceId: null).logout();

    expect(dio.deletePaths, isEmpty);
    expect(storage.data.containsKey('auth.accessToken'), isFalse);
  });

  test('deleteAccount also unregisters the push device via the live route',
      () async {
    await storage.write(key: 'auth.userId', value: 'u-1');

    await build().deleteAccount();

    expect(dio.deletePaths, contains('/api/PushNotification/device'));
    expect(dio.deleteBodies.single?['deviceId'], 'dev-abc');
  });

  // Close-out 2026-08-11: the cached profile/role snapshots outlived the token,
  // so the NEXT account opened Edit Profile on the previous one's name.
  test('logout drops the cached profile + role snapshots', () async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(
      SharedPrefsProfileRepository.profilePrefsKey,
      '{"phoneE164":"+96170000001","name":"Previous Account"}',
    );
    await prefs.setStringList(
      RoleAvailabilityCubit.availableRolesPrefKey,
      <String>['client', 'jeeber'],
    );
    await prefs.setString(RoleCubit.rolePrefKey, 'jeeber');

    await build().logout();

    expect(prefs.getString(SharedPrefsProfileRepository.profilePrefsKey),
        isNull);
    expect(prefs.getStringList(RoleAvailabilityCubit.availableRolesPrefKey),
        isNull);
    expect(prefs.getString(RoleCubit.rolePrefKey), isNull);
  });
}
