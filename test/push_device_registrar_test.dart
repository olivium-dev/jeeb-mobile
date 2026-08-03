import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/network/auth_token_store.dart';
import 'package:jeeb_mobile/core/notifications/data/push_device_registrar.dart';

/// Stub Dio that records the last PUT and returns a canned response/error.
/// The registrar uses `PUT /api/PushNotification/register` (the gateway
/// controller is `[HttpPut]`), so we override `put` — overriding `post` would
class _FakeDio extends Fake implements Dio {
  String? lastPath;
  Map<String, dynamic>? lastData;
  int calls = 0;
  Response<dynamic>? nextResponse;
  DioException? nextError;

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
    calls += 1;
    lastPath = path;
    lastData = data as Map<String, dynamic>?;
    if (nextError != null) throw nextError!;
    return nextResponse! as Response<T>;
  }
}

/// In-memory FlutterSecureStorage so the registrar's stable deviceId path runs
/// on the pure-Dart VM without the platform keystore channel.
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

/// The REAL `push-notification` register route answers `204 No Content` with
/// an EMPTY body (verified in the backend's `push-e2e.test.ts` and the service
Response<dynamic> _ok() => Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 204,
      data: null,
    );

/// Stable per-install device id shape emitted by `PushDeviceRegistrar`:
/// a UUID-v4-style `8-4-4-4-12` hex string with the version nibble pinned to
final _deviceIdPattern = RegExp(
  r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-a[0-9a-f]{3}-[0-9a-f]{12}$',
);

void main() {
  late _FakeDio dio;
  late _FakeSecureStorage storage;
  late PushDeviceRegistrar sut;

  setUp(() {
    dio = _FakeDio();
    storage = _FakeSecureStorage();
    sut = PushDeviceRegistrar(dio: dio, storage: storage);
  });

  test('registers via the gateway-contract PUT /api/PushNotification/register',
      () async {
    dio.nextResponse = _ok();

    await sut.register('fcm-token-abc');

    // The live gateway BFF route (sprint-05 push-proof §1f): the prior
    expect(dio.lastPath, '/api/PushNotification/register');
    expect(dio.lastData?['fcmToken'], 'fcm-token-abc');
    // Platform discriminator present (android/ios/unknown on the test VM).
    expect(dio.lastData?['platform'], isA<String>());
    expect(
      dio.lastData?['platform'],
      anyOf('android', 'ios', 'unknown'),
    );
    // A stable per-install deviceId is sent — assert its exact UUID-v4 shape,
    final deviceId = dio.lastData?['deviceId'] as String?;
    expect(deviceId, isNotNull);
    expect(deviceId, matches(_deviceIdPattern));
    // The same id is persisted to secure storage for reuse across launches.
    expect(await storage.read(key: 'push.deviceId'), deviceId);
  });

  test('is idempotent — a repeat call with the same token is skipped', () async {
    dio.nextResponse = _ok();

    await sut.register('same-token');
    await sut.register('same-token');

    expect(dio.calls, 1);
  });

  test('re-registers when the token rotates (refresh)', () async {
    dio.nextResponse = _ok();

    await sut.register('token-1');
    await sut.register('token-2');

    expect(dio.calls, 2);
    expect(dio.lastData?['fcmToken'], 'token-2');
  });

  test('reuses the same persisted deviceId across registrations', () async {
    dio.nextResponse = _ok();

    await sut.register('token-1');
    final first = dio.lastData?['deviceId'];
    await sut.register('token-2');
    final second = dio.lastData?['deviceId'];

    expect(first, second);
  });

  test('null / empty token is a no-op (no network call)', () async {
    await sut.register(null);
    await sut.register('');

    expect(dio.calls, 0);
  });

  test('a failed (unauthenticated) register never throws and is retried',
      () async {
    dio.nextError = DioException(
      requestOptions: RequestOptions(path: '/api/PushNotification/register'),
      response: Response<dynamic>(
        requestOptions: RequestOptions(path: ''),
        statusCode: 401,
      ),
      type: DioExceptionType.badResponse,
    );

    // Does not throw despite the 401.
    await sut.register('token-x');
    expect(dio.calls, 1);

    // Because it was not recorded as registered, a later attempt with the SAME
    dio.nextError = null;
    dio.nextResponse = _ok();
    await sut.register('token-x');
    expect(dio.calls, 2);
  });

  group('identity-keyed dedup (S0-PUSH-03 / S0-PUSH-04)', () {
    // The body NEVER carries a userId — the gateway derives the owner from the

    test(
        'the register body never carries a userId — identity is server-derived '
        'from the bearer, never a mock/hardcoded id', () async {
      final storage = _FakeSecureStorage();
      await storage.write(key: 'auth.userId', value: 'uuid-real');
      final sut = PushDeviceRegistrar(
        dio: dio,
        storage: storage,
        authTokenStore: AuthTokenStore(storage: storage),
      );
      dio.nextResponse = _ok();

      await sut.register('fcm-token');

      expect(dio.lastData!.containsKey('userId'), isFalse);
      expect(dio.lastData!.keys, containsAll(['fcmToken', 'platform', 'deviceId']));
    });

    test(
        're-registers the SAME token under the authenticated UUID after a '
        'pre-auth attempt (kills the "already sent" skip on fresh login)',
        () async {
      final storage = _FakeSecureStorage();
      final tokenStore = AuthTokenStore(storage: storage);
      final sut = PushDeviceRegistrar(
        dio: dio,
        storage: storage,
        authTokenStore: tokenStore,
      );
      dio.nextResponse = _ok();

      // Pre-auth bootstrap: no session UUID yet. Registers under the anonymous
      await sut.register('fcm-stable');
      expect(dio.calls, 1);

      // Login lands the real UUID in the same keystore the bearer reads.
      await storage.write(key: 'auth.userId', value: 'uuid-after-login');

      // Re-bootstrap offers the UNCHANGED token. Token-only dedup would skip
      await sut.register('fcm-stable');
      expect(dio.calls, 2);
      expect(dio.lastData!['fcmToken'], 'fcm-stable');
    });

    test(
        'a second user on the same install re-registers the shared token '
        '(no split-token-store leak to the first user)', () async {
      final storage = _FakeSecureStorage();
      await storage.write(key: 'auth.userId', value: 'uuid-A');
      final sut = PushDeviceRegistrar(
        dio: dio,
        storage: storage,
        authTokenStore: AuthTokenStore(storage: storage),
      );
      dio.nextResponse = _ok();

      await sut.register('shared-fcm');
      expect(dio.calls, 1);

      // Same token is idempotent for the SAME user.
      await sut.register('shared-fcm');
      expect(dio.calls, 1);

      // User B signs in on the same device (same stable FCM token). Must
      await storage.write(key: 'auth.userId', value: 'uuid-B');
      await sut.register('shared-fcm');
      expect(dio.calls, 2);
    });
  });
}
