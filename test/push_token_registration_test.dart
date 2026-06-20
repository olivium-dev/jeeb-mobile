// Tests for push token registration (notif-push-token-registration).
//
// Verifies PushNotificationHandler.bootstrap() POSTs the resolved FCM token to
// the gateway via PushTokenRepository, that a token refresh re-registers, and
// that a registration failure is swallowed (the push chain keeps working).

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/push_token_repository.dart';

class _RecordingTokenRepo implements PushTokenRepository {
  _RecordingTokenRepo({this.throwOnRegister = false});

  final bool throwOnRegister;
  final List<String> registered = [];

  @override
  Future<void> register(String token) async {
    registered.add(token);
    if (throwOnRegister) throw Exception('route not served');
  }
}

void main() {
  test('bootstrap registers the resolved token with the gateway', () async {
    final transport = FakePushTransport(token: 'fcm-token-1');
    final repo = _RecordingTokenRepo();
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: BadgeCountCubit(),
      tokenRepository: repo,
    );

    await handler.bootstrap();

    expect(repo.registered, ['fcm-token-1']);
    expect(handler.state.token, 'fcm-token-1');
    await handler.close();
  });

  test('token refresh re-registers with the gateway', () async {
    final transport = FakePushTransport(token: 'fcm-token-1');
    final repo = _RecordingTokenRepo();
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: BadgeCountCubit(),
      tokenRepository: repo,
    );
    await handler.bootstrap();

    transport.emitTokenRefresh('fcm-token-2');
    // Let the refresh listener's async registration resolve.
    await Future<void>.delayed(Duration.zero);

    expect(repo.registered, contains('fcm-token-2'));
    expect(handler.state.token, 'fcm-token-2');
    await handler.close();
  });

  test('registration failure is swallowed (token still in state)', () async {
    final transport = FakePushTransport(token: 'fcm-token-1');
    final repo = _RecordingTokenRepo(throwOnRegister: true);
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: BadgeCountCubit(),
      tokenRepository: repo,
    );

    await expectLater(handler.bootstrap(), completes);
    expect(handler.state.token, 'fcm-token-1');
    await handler.close();
  });

  test('null repository: bootstrap still resolves token (no-op register)',
      () async {
    final transport = FakePushTransport(token: 'fcm-token-1');
    final handler = PushNotificationHandler(
      transport: transport,
      badgeCount: BadgeCountCubit(),
    );

    await handler.bootstrap();

    expect(handler.state.token, 'fcm-token-1');
    await handler.close();
  });
}
