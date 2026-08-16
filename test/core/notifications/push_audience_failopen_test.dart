import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/diagnostics/diag.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/notifications/domain/notification_message.dart';
import 'package:jeeb_mobile/core/notifications/domain/push_audience.dart';
import 'package:jeeb_mobile/core/notifications/presentation/push_banner_host.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';

import '../../support/sync_app_localizations.dart';

/// D2 regression. `isPushAudienceMatch` documents a fail-open on unknown roles
/// (`if (localRoles.isEmpty) return true`), but `_JeebAppState._sessionLocalRoles`
/// synthesised `{activeRole}` whenever the server `available_roles` list was
/// still empty, so the resolver could never hand the matcher an empty set and
/// the fail-open branch was unreachable. A jeeber-audience push then hit the
/// default `client` role and was discarded with
/// `push_suppressed {"audience_role":"driver","reason":"audience_mismatch"}` —
/// the same silent drop OA-21 had just removed from the server.
///
/// The widget tests below drive the REAL production resolver through the REAL
/// handler (JeebApp + FakePushTransport); nothing about the gate is restated
/// in the test, so they fail on the pre-fix wiring rather than on a copy of it.
NotificationMessage _newRequestPush({String audienceRole = 'driver'}) =>
    NotificationMessage(
      id: 'push-oa21-new-request',
      category: NotificationCategory.newRequest,
      title: 'New request nearby',
      body: 'A client is waiting for a jeeber',
      receivedAt: DateTime.utc(2026, 8, 15, 12),
      data: <String, String>{
        'type': 'new_request',
        'audience_role': audienceRole,
        'requestId': 'req-oa21',
      },
    );

Future<FakePushTransport> _bootApp(WidgetTester tester) async {
  final prefs = await SharedPreferences.getInstance();
  final transport = FakePushTransport(token: 'fcm-failopen');
  await tester.pumpWidget(
    JeebApp(
      preferences: prefs,
      localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
      sessionGate: const AlwaysAuthenticatedSessionGate(),
      pushTransport: transport,
    ),
  );
  await tester.pump(); // first frame
  await tester.pump(); // redirect -> shell
  await tester.pump(); // post-frame _initPushChain setState
  await tester.pump(const Duration(milliseconds: 200)); // handler.bootstrap()
  return transport;
}

void main() {
  late List<String> diagLines;

  setUp(() {
    // No `app.available_roles`: getMe has not landed (or is degraded), which is
    // exactly the state the fail-open exists for.
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
    diagLines = <String>[];
    Diag.enabledOverride = true;
    Diag.sink = diagLines.add;
  });

  tearDown(Diag.resetForTest);

  group('push audience gate fails OPEN while session roles are unresolved', () {
    testWidgets(
      'a driver-audience push is NOT suppressed before available_roles resolves',
      (tester) async {
        final transport = await _bootApp(tester);

        transport.emitForeground(_newRequestPush());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          diagLines.where((line) => line.contains('push_suppressed')),
          isEmpty,
          reason: 'roles are UNKNOWN (available_roles empty), so the audience '
              'gate must fail open instead of classifying the device from the '
              'default active role',
        );
        expect(
          find.byKey(pushBannerCardKey),
          findsOneWidget,
          reason: 'the push the server correctly sent must reach the user',
        );

        // Drain the banner auto-dismiss timer without settling: the shell
        // runs a repeating animation, so pumpAndSettle never converges.
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
      },
    );

    testWidgets(
      'a client-audience push is equally delivered while roles are unresolved',
      (tester) async {
        final transport = await _bootApp(tester);

        transport.emitForeground(_newRequestPush(audienceRole: 'customer'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(
          diagLines.where((line) => line.contains('push_suppressed')),
          isEmpty,
        );
        expect(find.byKey(pushBannerCardKey), findsOneWidget);

        // Drain the banner auto-dismiss timer without settling: the shell
        // runs a repeating animation, so pumpAndSettle never converges.
        await tester.pump(const Duration(seconds: 6));
        await tester.pump();
      },
    );
  });

  group('sessionPushRoles', () {
    test('an empty available_roles resolves to UNKNOWN, never to the active '
        'role', () {
      expect(
        sessionPushRoles(availableRoles: const <String>[], activeRole: 'client'),
        isEmpty,
      );
      expect(
        sessionPushRoles(availableRoles: const <String>[], activeRole: 'jeeber'),
        isEmpty,
      );
    });

    test('a resolved available_roles is used as published', () {
      expect(
        sessionPushRoles(
          availableRoles: const <String>['client'],
          activeRole: 'client',
        ),
        <String>{'client'},
      );
    });

    test('the active role is never dropped from a resolved list', () {
      // Role-service degradation: the server says client-only while the session
      // is actively operating as a jeeber. The session demonstrably holds it.
      expect(
        sessionPushRoles(
          availableRoles: const <String>['client'],
          activeRole: 'jeeber',
        ),
        <String>{'client', 'jeeber'},
      );
    });

    test('blank entries do not count as a resolved list', () {
      expect(
        sessionPushRoles(
          availableRoles: const <String>['', '   '],
          activeRole: 'client',
        ),
        isEmpty,
      );
    });

    test('the resolved set drives the matcher the way the gate expects', () {
      expect(
        isPushAudienceMatch(
          const {'audience_role': 'driver'},
          sessionPushRoles(
            availableRoles: const <String>[],
            activeRole: 'client',
          ),
        ),
        isTrue,
      );
      expect(
        isPushAudienceMatch(
          const {'audience_role': 'driver'},
          sessionPushRoles(
            availableRoles: const <String>['client'],
            activeRole: 'client',
          ),
        ),
        isFalse,
      );
      expect(
        isPushAudienceMatch(
          const {'audience_role': 'driver'},
          sessionPushRoles(
            availableRoles: const <String>['client'],
            activeRole: 'jeeber',
          ),
        ),
        isTrue,
      );
    });
  });
}
