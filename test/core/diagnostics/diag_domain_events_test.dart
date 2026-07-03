import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/notifications/application/badge_count_cubit.dart';
import 'package:jeeb_mobile/core/notifications/application/push_notification_handler.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/role/role_cubit.dart';
import 'package:jeeb_mobile/core/role/user_role.dart';
import 'package:jeeb_mobile/features/offline_mode/application/offline_cubit.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// The new evt seams added by the diag-persistence lane: role_switch,
/// push_permission, connectivity.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late List<String> lines;

  Map<String, dynamic> decodeLine(String line) =>
      jsonDecode(line.substring(Diag.prefix.length + 1))
          as Map<String, dynamic>;

  List<Map<String, dynamic>> eventsNamed(String name) => lines
      .map(decodeLine)
      .where((r) => r['t'] == 'evt' && r['name'] == name)
      .toList();

  setUp(() {
    lines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = lines.add;
  });

  tearDown(Diag.resetForTest);

  group('role_switch (RoleCubit — the single role choke point)', () {
    late RoleCubit cubit;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      cubit = RoleCubit(prefs: await SharedPreferences.getInstance());
    });

    tearDown(() => cubit.close());

    test('an actual switch emits from→to', () async {
      await cubit.setRole(UserRole.jeeber);

      final events = eventsNamed('role_switch');
      expect(events, hasLength(1));
      expect((events.single['data'] as Map)['from'], 'client');
      expect((events.single['data'] as Map)['to'], 'jeeber');
    });

    test('a no-op set (same role) emits NOTHING', () async {
      await cubit.setRole(UserRole.client); // already client
      expect(eventsNamed('role_switch'), isEmpty);
    });

    test('toggle() emits through the same seam', () async {
      await cubit.toggle();
      await cubit.toggle();

      final events = eventsNamed('role_switch');
      expect(events, hasLength(2));
      expect((events.last['data'] as Map)['from'], 'jeeber');
      expect((events.last['data'] as Map)['to'], 'client');
    });
  });

  group('push_permission (PushNotificationHandler.bootstrap)', () {
    test('the notDetermined → granted transition is recorded', () async {
      final handler = PushNotificationHandler(
        transport: FakePushTransport(
          permission: PushPermissionStatus.granted,
        ),
        badgeCount: BadgeCountCubit(),
      );
      addTearDown(handler.close);

      await handler.bootstrap();

      final events = eventsNamed('push_permission');
      expect(events, hasLength(1));
      expect((events.single['data'] as Map)['from'], 'notDetermined');
      expect((events.single['data'] as Map)['to'], 'granted');
    });

    test('denied is recorded too (the "why no push" answer)', () async {
      final handler = PushNotificationHandler(
        transport: FakePushTransport(permission: PushPermissionStatus.denied),
        badgeCount: BadgeCountCubit(),
      );
      addTearDown(handler.close);

      await handler.bootstrap();

      expect(
        (eventsNamed('push_permission').single['data'] as Map)['to'],
        'denied',
      );
    });

    test('a re-bootstrap with an UNCHANGED status emits nothing new',
        () async {
      final handler = PushNotificationHandler(
        transport: FakePushTransport(
          permission: PushPermissionStatus.granted,
        ),
        badgeCount: BadgeCountCubit(),
      );
      addTearDown(handler.close);

      await handler.bootstrap();
      await handler.bootstrap();

      expect(eventsNamed('push_permission'), hasLength(1));
    });

    test('the token is NEVER in the permission event', () async {
      final handler = PushNotificationHandler(
        transport: FakePushTransport(
          permission: PushPermissionStatus.granted,
          token: 'fcm-super-secret-token-ABCD',
        ),
        badgeCount: BadgeCountCubit(),
      );
      addTearDown(handler.close);

      await handler.bootstrap();

      for (final line in lines) {
        expect(line, isNot(contains('fcm-super-secret-token-ABCD')));
      }
    });
  });

  group('connectivity (OfflineCubit — cheap existing hook)', () {
    late OfflineCubit cubit;

    setUp(() => cubit = OfflineCubit());
    tearDown(() => cubit.close());

    test('offline → online transitions are recorded once each', () {
      cubit.setOffline();
      cubit.setOnline();

      final events = eventsNamed('connectivity');
      expect(events, hasLength(2));
      expect((events[0]['data'] as Map)['status'], 'offline');
      expect((events[1]['data'] as Map)['status'], 'online');
    });

    test('repeated same-status sets do NOT spam the stream', () {
      cubit.setOnline(); // already online (initial state)
      cubit.setOffline();
      cubit.setOffline();
      cubit.setOffline();

      expect(eventsNamed('connectivity'), hasLength(1));
    });
  });
}
