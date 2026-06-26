import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/data/push_device_registrar.dart';

/// Stub Dio that records the last POST and returns a canned response/error.
class _FakeDio extends Fake implements Dio {
  String? lastPath;
  Map<String, dynamic>? lastData;
  int calls = 0;
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

Response<dynamic> _ok() => Response<dynamic>(
      requestOptions: RequestOptions(path: ''),
      statusCode: 201,
      data: {'message': 'registered'},
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

  test('registers via the gateway-contract POST /v1/devices/register', () async {
    dio.nextResponse = _ok();

    await sut.register('fcm-token-abc');

    expect(dio.lastPath, '/v1/devices/register');
    expect(dio.lastData?['fcmToken'], 'fcm-token-abc');
    // Platform discriminator present (android/ios/unknown on the test VM).
    expect(dio.lastData?['platform'], isA<String>());
    // A stable per-install deviceId is sent and persisted.
    final deviceId = dio.lastData?['deviceId'] as String?;
    expect(deviceId, isNotNull);
    expect(deviceId, isNotEmpty);
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
      requestOptions: RequestOptions(path: '/v1/devices/register'),
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
    // token retries (the refresh/bootstrap re-register path).
    dio.nextError = null;
    dio.nextResponse = _ok();
    await sut.register('token-x');
    expect(dio.calls, 2);
  });
}
