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
    // transition drives JeebApp to call notifyLogin().
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
    // A second emission (e.g. a duplicate authenticated transition) must be a
    // no-op — the registrar is already registered.
    await registrar.notifyLogin();

    expect(dio.paths, [registerPath]);

    await registrar.dispose();
  });
}
