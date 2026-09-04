import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';

import 'support/sync_app_localizations.dart';

/// S14 cold-start init-ordering regression.
void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'app.onboarding.completed': true,
    });
  });

  testWidgets(
    'push chain does NOT build the FCM transport until Firebase init completes',
    (tester) async {
      final prefs = await SharedPreferences.getInstance();

      // The deferred Firebase.initializeApp() future, held open by the test.
      final firebaseGate = Completer<void>();
      var firebaseInitialized = false;

      // Observes WHEN the FCM transport is constructed relative to Firebase init.
      var builderCalled = false;
      var builtBeforeFirebaseInit = false;

      await tester.pumpWidget(
        JeebApp(
          preferences: prefs,
          localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
          sessionGate: const AlwaysAuthenticatedSessionGate(),
          // pushTransport intentionally NOT injected → exercises the real FCM
          firebaseInitializer: () =>
              firebaseGate.future.then((_) => firebaseInitialized = true),
          fcmTransportBuilder: () async {
            builderCalled = true;
            // Models the `[core/no-app]` precondition: building the FCM transport
            if (!firebaseInitialized) builtBeforeFirebaseInit = true;
            return FakePushTransport(token: 'fcm-real-token');
          },
        ),
      );

      // first frame → schedules the post-frame _initPushChain.
      await tester.pump();
      // run the post-frame callback + start _initPushChainAsync.
      await tester.pump();

      // CORE ORDERING ASSERTION: with Firebase init still pending, the FCM
      expect(
        builderCalled,
        isFalse,
        reason: 'FCM transport was constructed before Firebase init resolved',
      );

      // Resolve the deferred Firebase init, then let the chain continue.
      firebaseGate.complete();
      await tester.pump();
      await tester.pump();

      // Now the transport is built — and only after Firebase init.
      expect(
        builderCalled,
        isTrue,
        reason: 'FCM transport should be built once Firebase init completed',
      );
      expect(
        builtBeforeFirebaseInit,
        isFalse,
        reason: 'transport must be built strictly AFTER Firebase init',
      );

      // Drain the client-home snapshot timer (150ms in-memory load) the
      await tester.pump(const Duration(milliseconds: 250));
    },
  );

  testWidgets(
    'a genuine FCM build failure still degrades to the fake fallback',
    (tester) async {
      // Guards the catch-branch: the fix must not remove the legitimate
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        JeebApp(
          preferences: prefs,
          localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
          sessionGate: const AlwaysAuthenticatedSessionGate(),
          firebaseInitializer: () async {}, // resolves immediately
          fcmTransportBuilder: () async =>
              throw StateError('simulated FCM bridge failure'),
        ),
      );

      await tester.pump();
      await tester.pump();
      // Drain the client-home snapshot timer the authenticated shell schedules.
      await tester.pump(const Duration(milliseconds: 250));

      // No exception escaped the chain; the app survived a genuine FCM failure.
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('REQUIRE_REAL_PUSH rejects the silent fake fallback', (
    tester,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    StateError? failure;

    await tester.pumpWidget(
      JeebApp(
        preferences: prefs,
        localizationsDelegateOverride: const SyncAppLocalizationsDelegate(),
        sessionGate: const AlwaysAuthenticatedSessionGate(),
        firebaseInitializer: () async {},
        fcmTransportBuilder: () async =>
            throw StateError('simulated required FCM failure'),
        requireRealPush: true,
        requiredPushFailureHandler: (error) => failure = error,
      ),
    );

    await tester.pump();
    await tester.pump();
    expect(
      failure,
      isA<StateError>(),
      reason: 'a required-push build must never silently use FakePushTransport',
    );
    expect(tester.takeException(), isNull);
    await tester.pump(const Duration(milliseconds: 250));
  });
}
