import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/notifications/data/device_token_registrar.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';

/// Records every PUT so the test can assert the app → gateway register hop
/// fired exactly once. Mirrors the RecordingDio fake in
/// `test/push_registration_e2e_test.dart`.
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

/// D3: fails the first [failFirst] PUTs the way a live 5xx/offline gateway does,
/// so a test can prove the registrar RETRIES instead of going dark.
class _FlakyDio extends Fake implements Dio {
  _FlakyDio({required this.failFirst});

  final int failFirst;
  final List<String> paths = <String>[];

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
    if (paths.length <= failFirst) {
      throw DioException(
        requestOptions: RequestOptions(path: path),
        response: Response<dynamic>(
          requestOptions: RequestOptions(path: path),
          statusCode: 503,
        ),
      );
    }
    return Response<T>(
      requestOptions: RequestOptions(path: path),
      statusCode: 201,
    );
  }
}

/// D3: hands out no FCM token until [availableAfter] `getToken` calls, modelling
/// a cold start where Play Services has not minted the token yet.
class _LateTokenTransport extends FakePushTransport {
  _LateTokenTransport({required this.availableAfter, required this.token});

  final int availableAfter;
  final String token;
  int calls = 0;

  @override
  Future<String?> getToken() async {
    calls++;
    return calls > availableAfter ? token : null;
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

  test(
      'notifyLogin registers once after the poll window expires with no userId '
      '(run-15 root cause)', () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final transport = FakePushTransport(token: 'fcm-login-token');
    final dio = _RecordingDio();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: Duration.zero,
      // Exactly one attempt: the poll gives up immediately (no session yet).
      maxAttempts: 1,
    );

    // Start with NO userId — the bounded poll runs out and registers nothing.
    await registrar.start();
    await Future<void>.delayed(Duration.zero);
    expect(dio.paths, isEmpty,
        reason: 'poll must not register before a userId exists');

    // Interactive login lands: a userId is now persisted and the session
    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );
    await registrar.notifyLogin();

    expect(dio.paths, [registerPath]);
    expect(dio.bodies.single['fcmToken'], 'fcm-login-token');
    expect(dio.bodies.single['deviceId'], isNotEmpty);

    await registrar.dispose();
  });

  test('notifyLogin does not double-register when already registered',
      () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final transport = FakePushTransport(token: 'fcm-login-token');
    final dio = _RecordingDio();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: Duration.zero,
      maxAttempts: 1,
    );

    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );

    // First login emission registers exactly once.
    await registrar.notifyLogin();
    // A second emission (e.g. a duplicate authenticated transition for the SAME
    await registrar.notifyLogin();

    expect(dio.paths, [registerPath]);

    await registrar.dispose();
  });

  test(
      'JEBV4-159: a SECOND authenticated transition as a DIFFERENT user '
      '(account switch) RE-fires register for the new user', () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
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

    // User A logs in → registers under A.
    await tokenStore.save(
      accessToken: 'mock-jwt-access-uA',
      refreshToken: 'mock-refresh-uA',
      userId: 'userA',
    );
    await registrar.notifyLogin();

    // Super-login account switch: user B's tokens land on the SAME install with
    await tokenStore.save(
      accessToken: 'mock-jwt-access-uB',
      refreshToken: 'mock-refresh-uB',
      userId: 'userB',
    );
    await registrar.notifyLogin();

    // TWO registers — one per identity — not one.
    expect(dio.paths, [registerPath, registerPath],
        reason: 'account switch must re-register the new user');
    // The device id is stable across the switch (one row per device, re-owned).
    expect(dio.bodies[0]['deviceId'], dio.bodies[1]['deviceId']);
    expect(dio.bodies.every((b) => b['fcmToken'] == 'fcm-shared-token'), isTrue);

    await registrar.dispose();
  });

  test('onTokenRefresh re-registers the rotated token under the current user',
      () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final transport = FakePushTransport(token: 'fcm-token-v1');
    final dio = _RecordingDio();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: Duration.zero,
      maxAttempts: 1,
    );

    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );
    // start() subscribes to onTokenRefresh AND polls for the userId (present),
    await registrar.start();
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(dio.paths, [registerPath]);
    expect(dio.bodies.single['fcmToken'], 'fcm-token-v1');

    // FCM rotates the token (reinstall / restore). The refresh listener must
    transport.emitTokenRefresh('fcm-token-v2');
    await Future<void>.delayed(const Duration(milliseconds: 20));

    expect(dio.paths, [registerPath, registerPath]);
    expect(dio.bodies.last['fcmToken'], 'fcm-token-v2');

    await registrar.dispose();
  });

  test(
      'register is idempotent: repeated notifyLogin for the same (user, token) '
      'sends exactly one PUT', () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final transport = FakePushTransport(token: 'fcm-idem-token');
    final dio = _RecordingDio();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: Duration.zero,
      maxAttempts: 1,
    );

    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );

    await registrar.notifyLogin();
    await registrar.notifyLogin();
    await registrar.notifyLogin();

    expect(dio.paths, [registerPath],
        reason: 'same identity + token must not re-hit the gateway');

    await registrar.dispose();
  });

  test(
      'JEBV4-159: a login AFTER sign-out re-registers even as the SAME user '
      '(the DELETE /device on logout removed the token row)', () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final transport = FakePushTransport(token: 'fcm-token');
    final dio = _RecordingDio();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: Duration.zero,
      maxAttempts: 1,
    );

    // Login → register under u1.
    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );
    await registrar.notifyLogin();
    expect(dio.paths.length, 1);

    // Sign-out: the session goes unauthenticated → JeebApp calls
    await tokenStore.clear();
    registrar.notifySignedOut();

    // Same user u1 logs back in.
    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );
    await registrar.notifyLogin();

    expect(dio.paths, [registerPath, registerPath],
        reason: 'a login after sign-out must re-register even for the same '
            'user, since DELETE /device dropped the token row');

    await registrar.dispose();
  });

  test(
      'D3: a login whose PUT FAILS re-arms the poll and registers on a later '
      'attempt (was: one failure left the device unreachable forever)',
      () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final transport = FakePushTransport(token: 'fcm-flaky');
    final dio = _FlakyDio(failFirst: 2);
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: const Duration(milliseconds: 5),
      maxAttempts: 10,
    );

    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );
    await registrar.notifyLogin();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(dio.paths.length, 3,
        reason: 'two 503s then a success — the retry must not stop at the '
            'first failure');

    await registrar.dispose();
  });

  test(
      'D3: an FCM token that only arrives on a later poll tick still registers '
      '(no onNewToken callback fires for an already-cached token)', () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final transport = _LateTokenTransport(availableAfter: 2, token: 'fcm-late');
    final dio = _RecordingDio();
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: const Duration(milliseconds: 5),
      maxAttempts: 10,
    );

    // Already signed in at cold start, but getToken() returns null twice.
    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );
    await registrar.start();
    await Future<void>.delayed(const Duration(milliseconds: 120));

    expect(dio.paths, [registerPath]);
    expect(dio.bodies.single['fcmToken'], 'fcm-late');

    await registrar.dispose();
  });

  test(
      'D3: revalidate() re-asserts the device row once the rate-limit window '
      'has passed, and is a no-op inside it', () async {
    final storage = _FakeSecureStorage();
    final tokenStore = AuthTokenStore(storage: storage);
    final transport = FakePushTransport(token: 'fcm-heal');
    final dio = _RecordingDio();
    var now = DateTime.utc(2026, 8, 10, 12);
    final registrar = DeviceTokenRegistrar(
      dio: dio,
      tokenStore: tokenStore,
      transport: transport,
      prefs: prefs,
      retryInterval: Duration.zero,
      maxAttempts: 1,
      revalidateInterval: const Duration(minutes: 30),
      clock: () => now,
    );

    await tokenStore.save(
      accessToken: 'mock-jwt-access-u1',
      refreshToken: 'mock-refresh-u1',
      userId: 'u1',
    );
    await registrar.notifyLogin();
    expect(dio.paths.length, 1);

    // Inside the window: a resume must not re-hit the gateway.
    now = now.add(const Duration(minutes: 5));
    await registrar.revalidate();
    expect(dio.paths.length, 1);

    // Past the window: re-assert, so a row deleted server-side comes back.
    now = now.add(const Duration(minutes: 31));
    await registrar.revalidate();
    expect(dio.paths.length, 2);

    await registrar.dispose();
  });
}
