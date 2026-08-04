import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/notifications/data/device_token_registrar.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/session/session_cubit.dart';

/// JEBV4-159 — session-role-sync seam (mirrors `JeebApp._wireSessionRoleSync`).
/// The existing `device_token_registrar_login_test.dart` proves the registrar
/// re-registers when `notifyLogin()` / `notifySignedOut()` are called directly.

class _RecordingDio extends Fake implements Dio {
  final List<String> paths = <String>[];
  final List<Map<String, dynamic>> bodies = <Map<String, dynamic>>[];

  @override
  Future<Response<T>> put<T>(
    String path, {
    Object? data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    ProgressCallback? onSendProgress,
    ProgressCallback? onReceiveProgress,
  }) async {
    paths.add(path);
    bodies.add(data! as Map<String, dynamic>);
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
    );
  }
}

class _FakeSecureStorage extends Fake implements FlutterSecureStorage {
  final Map<String, String> _data = {};

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
      _data[key];

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
    if (value != null) _data[key] = value;
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
    _data.remove(key);
  }
}

void main() {
  const registerPath = '/api/PushNotification/register';

  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues(<String, Object>{});
    prefs = await SharedPreferences.getInstance();
  });

  /// Reproduces `JeebApp._wireSessionRoleSync` verbatim for the push leg: the
  /// owned [SessionCubit]'s stream drives the registrar on every transition.
  Future<void> wirePushToSession(
    SessionCubit session,
    DeviceTokenRegistrar registrar,
  ) async {
    session.stream.listen((state) {
      if (state.isAuthenticated) {
        registrar.notifyLogin();
      } else if (state.isUnauthenticated) {
        registrar.notifySignedOut();
      }
    });
  }

  test(
      'JEBV4-159 wiring: a real SessionCubit login → sign-out → login-as-'
      'different-user drives a register PUT for EACH authenticated identity',
      () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final session = SessionCubit(tokenStore: tokenStore);
    final transport = FakePushTransport(token: 'fcm-shared-token');
    final dio = _RecordingDio();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: Duration.zero,
      maxAttempts: 1,
    );

    await wirePushToSession(session, registrar);

    // --- Login as user A (unauthenticated → authenticated) -----------------
    await tokenStore.save(
      accessToken: 'mock-jwt-access-userA',
      refreshToken: 'mock-refresh-userA',
      userId: 'userA',
    );
    await session.refresh(); // emits authenticated → notifyLogin()
    // Let the async listener → notifyLogin → _register chain settle.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(dio.paths, [registerPath],
        reason: 'first login must register the current user with the gateway');
    expect(dio.bodies.single['fcmToken'], 'fcm-shared-token');

    // --- Sign out (authenticated → unauthenticated) ------------------------
    await tokenStore.clear();
    await session.refresh(); // emits unauthenticated → notifySignedOut()
    await Future<void>.delayed(Duration.zero);

    expect(dio.paths.length, 1,
        reason: 'sign-out itself must not hit the register endpoint');

    // --- Login as a DIFFERENT user B (the crux of JEBV4-159) ---------------
    await tokenStore.save(
      accessToken: 'mock-jwt-access-userB',
      refreshToken: 'mock-refresh-userB',
      userId: 'userB',
    );
    await session.refresh(); // emits authenticated → notifyLogin()
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(dio.paths, [registerPath, registerPath],
        reason: 'a user-switch login must RE-register so the switched-in user '
            'has a live device-token row for targeted offer_accepted pushes');
    // Stable per-install device id is re-owned by user B, not orphaned.
    expect(dio.bodies[0]['deviceId'], dio.bodies[1]['deviceId']);
    expect(dio.bodies.every((b) => b['fcmToken'] == 'fcm-shared-token'), isTrue);

    await registrar.dispose();
    await session.close();
  });
}
