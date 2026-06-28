import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_device_registrar.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';

import 'support/sync_app_localizations.dart';

/// Records every PUT so the test can assert the app → gateway register hop
/// actually fired with the right contract body. The registrar uses
/// `PUT /api/PushNotification/register`, so we override `put`.
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
      statusCode: 204,
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
  group('push chain seam (mirrors app.dart wiring)', () {
    test('bootstrap registers the FCM token with the gateway for ANY transport',
        () async {
      // A non-Firebase transport that yields a token — exactly the case the
      // mock-gateway dev build and integration harness hit. Before iter7 the
      // registrar was only attached for FirebaseMessagingTransport, so this
      // token was never forwarded to the backend.
      final transport = FakePushTransport(token: 'fcm-real-token');
      final dio = _RecordingDio();
      final registrar =
          PushDeviceRegistrar(dio: dio, storage: _FakeSecureStorage());
      final badge = BadgeCountCubit();
      final handler = PushNotificationHandler(
        transport: transport,
        badgeCount: badge,
        onToken: registrar.register,
      );

      await handler.bootstrap();

      expect(dio.paths, ['/api/PushNotification/register']);
      expect(dio.bodies.single['fcmToken'], 'fcm-real-token');
      expect(dio.bodies.single['deviceId'], isNotEmpty);
      expect(dio.bodies.single['platform'], isA<String>());

      await handler.close();
      await badge.close();
    });

    test('a token refresh re-registers the rotated token with the gateway',
        () async {
      final transport = FakePushTransport(token: 'fcm-1');
      final dio = _RecordingDio();
      final registrar =
          PushDeviceRegistrar(dio: dio, storage: _FakeSecureStorage());
      final badge = BadgeCountCubit();
      final handler = PushNotificationHandler(
        transport: transport,
        badgeCount: badge,
        onToken: registrar.register,
      );

      await handler.bootstrap(); // registers fcm-1
      transport.emitTokenRefresh('fcm-2');
      await Future<void>.delayed(Duration.zero);

      expect(dio.paths,
          ['/api/PushNotification/register', '/api/PushNotification/register']);
      expect(dio.bodies.first['fcmToken'], 'fcm-1');
      expect(dio.bodies.last['fcmToken'], 'fcm-2');
      // Same install -> same stable deviceId across both registrations.
      expect(dio.bodies.first['deviceId'], dio.bodies.last['deviceId']);

      await handler.close();
      await badge.close();
    });
  });

  group('JeebApp wires the device-registrar for an injected transport', () {
    setUp(() {
      SharedPreferences.setMockInitialValues(<String, Object>{
        'app.onboarding.completed': true,
      });
    });

    testWidgets(
        'booting with a token-bearing transport forwards the token to the gateway',
        (tester) async {
      final prefs = await SharedPreferences.getInstance();
      final dio = _RecordingDio();
      final registrar =
          PushDeviceRegistrar(dio: dio, storage: _FakeSecureStorage());

      await tester.pumpWidget(
        JeebApp(
          preferences: prefs,
          localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
          sessionGate: const AlwaysAuthenticatedSessionGate(),
          // Non-Firebase transport with a token — proves the iter7 wiring
          // attaches a registrar regardless of the concrete transport class.
          pushTransport: FakePushTransport(token: 'fcm-app-token'),
          pushDeviceRegistrar: registrar,
        ),
      );

      await tester.pump(); // first frame
      await tester.pump(); // redirect → shell
      await tester.pump(); // post-frame _initPushChain setState
      // Dispatcher ctor calls handler.bootstrap() asynchronously; drain it.
      await tester.pump(const Duration(milliseconds: 200));

      expect(dio.paths, contains('/api/PushNotification/register'));
      expect(dio.bodies.first['fcmToken'], 'fcm-app-token');
    });
  });
}
