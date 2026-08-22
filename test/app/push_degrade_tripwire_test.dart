import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';

import '../support/sync_app_localizations.dart';

/// F6: the silent-degrade class (Firebase/FCM init fails after bounded
/// retries -> app looks fine, push is dead). Proves the app.dart push chain
/// emits a greppable `JEEB-PUSH-DEGRADED` line at the failure and at the
/// fallback commit, with a distinct `reason` per failure path, and emits
/// NOTHING on the healthy path.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
  });

  // testWidgets verifies foundation debug vars are unset when the body
  // returns, so the restore must happen inline (not via addTearDown) here.
  Future<List<String>> runChain(
    WidgetTester tester, {
    required Future<void> Function() firebaseInitializer,
    required Future<PushTransport> Function() fcmTransportBuilder,
  }) async {
    final original = debugPrint;
    final lines = <String>[];
    debugPrint = (String? message, {int? wrapWidth}) {
      if (message != null) lines.add(message);
    };
    final prefs = await SharedPreferences.getInstance();
    try {
      await tester.pumpWidget(
        JeebApp(
          preferences: prefs,
          localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
          sessionGate: const AlwaysAuthenticatedSessionGate(),
          firebaseInitializer: firebaseInitializer,
          fcmTransportBuilder: fcmTransportBuilder,
        ),
      );
      await tester.pump();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 250));
    } finally {
      debugPrint = original;
    }
    return lines;
  }

  testWidgets('a Firebase init failure logs init_channel_error then '
      'retries_exhausted, and takes the fake path', (tester) async {
    final lines = await runChain(
      tester,
      firebaseInitializer: () async =>
          throw Exception('plugin channel unavailable'),
      fcmTransportBuilder: () async => FakePushTransport(),
    );

    expect(tester.takeException(), isNull);
    expect(lines, contains('[push] FCM transport unavailable; using fake'));
    expect(
      lines,
      contains('JEEB-PUSH-DEGRADED reason=init_channel_error stage=init '
          'deviceId=unknown'),
    );
    expect(
      lines,
      contains('JEEB-PUSH-DEGRADED reason=retries_exhausted stage=init '
          'deviceId=unknown'),
    );
  });

  testWidgets('a Firebase init timeout logs init_timeout', (tester) async {
    final lines = await runChain(
      tester,
      firebaseInitializer: () async =>
          throw TimeoutException('firebase init timed out'),
      fcmTransportBuilder: () async => FakePushTransport(),
    );

    expect(
      lines,
      contains('JEEB-PUSH-DEGRADED reason=init_timeout stage=init '
          'deviceId=unknown'),
    );
  });

  testWidgets(
      'a transport-build failure after Firebase is up logs token_null',
      (tester) async {
    final lines = await runChain(
      tester,
      firebaseInitializer: () async {},
      fcmTransportBuilder: () async =>
          throw StateError('simulated FCM bridge failure'),
    );

    expect(
      lines,
      contains('JEEB-PUSH-DEGRADED reason=token_null stage=token '
          'deviceId=unknown'),
    );
  });

  testWidgets('the healthy push chain emits no JEEB-PUSH-DEGRADED line',
      (tester) async {
    final lines = await runChain(
      tester,
      firebaseInitializer: () async {},
      fcmTransportBuilder: () async => FakePushTransport(token: 'ok'),
    );

    expect(lines.where((l) => l.startsWith('JEEB-PUSH-DEGRADED')), isEmpty);
  });
}
