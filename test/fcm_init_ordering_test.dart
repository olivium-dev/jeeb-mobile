import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:jeeb_mobile/app/app.dart';
import 'package:jeeb_mobile/core/notifications/data/push_transport.dart';
import 'package:jeeb_mobile/core/session/session_gate.dart';

import 'support/sync_app_localizations.dart';

class _TokenProbeTransport extends FakePushTransport {
  _TokenProbeTransport({required this.token, this.tokenFailure});

  final String? token;
  final Object? tokenFailure;
  int getTokenCalls = 0;
  bool disposed = false;

  @override
  Future<String?> getToken() async {
    getTokenCalls += 1;
    if (tokenFailure != null) throw tokenFailure!;
    return token;
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await super.dispose();
  }
}

/// S14 cold-start init-ordering regression.
///
/// The bug: `_initPushChainAsync` constructed/initialized the real
/// [FirebaseMessagingTransport] (whose ctor reaches `FirebaseMessaging.instance`
/// → `Firebase.app()`) BEFORE the deferred `Firebase.initializeApp()` had
/// completed. On a cold/slow boot that threw `[core/no-app]`, the catch silently
/// degraded to [FakePushTransport], and the app got no real FCM token and
/// received no push.
///
/// These tests pin the ordering through the [JeebApp.firebaseInitializer] and
/// [JeebApp.fcmTransportBuilder] seams: the FCM transport must NOT be built
/// until the Firebase-init guard has resolved. The first test FAILS against the
/// pre-fix ordering (transport built immediately, before the guard) and PASSES
/// once the chain awaits the guard first.
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
          // branch of _initPushChainAsync.
          firebaseInitializer: () =>
              firebaseGate.future.then((_) => firebaseInitialized = true),
          fcmTransportBuilder: () async {
            builderCalled = true;
            // Models the `[core/no-app]` precondition: building the FCM transport
            // before Firebase init is the defect.
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
      // transport must not have been built yet. Pre-fix, the chain builds it
      // immediately and this fails.
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
      // authenticated shell schedules, so the binding tears down cleanly.
      await tester.pump(const Duration(milliseconds: 250));
    },
  );

  testWidgets(
    'a genuine FCM build failure still degrades to the fake fallback',
    (tester) async {
      // Guards the catch-branch: the fix must not remove the legitimate
      // FakePushTransport fallback for real errors (only stop it firing merely
      // because init had not finished yet).
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

  test(
    'required real push surfaces FCM failure instead of silently using fake',
    () async {
      await expectLater(
        resolvePushTransport(
          requireRealPush: true,
          firebaseInitializer: () async {},
          transportBuilder: () async =>
              throw StateError('simulated required FCM failure'),
        ),
        throwsA(isA<StateError>()),
      );
    },
  );

  test('required real push rejects a transport with no FCM token', () async {
    final transport = _TokenProbeTransport(token: null);

    await expectLater(
      resolvePushTransport(
        requireRealPush: true,
        firebaseInitializer: () async {},
        transportBuilder: () async => transport,
      ),
      throwsA(isA<StateError>()),
    );
    expect(transport.getTokenCalls, 1);
  });

  test(
    'required real push preserves token acquisition failure and disposes',
    () async {
      final failure = StateError('simulated rejected Firebase configuration');
      final transport = _TokenProbeTransport(
        token: null,
        tokenFailure: failure,
      );

      await expectLater(
        resolvePushTransport(
          requireRealPush: true,
          firebaseInitializer: () async {},
          transportBuilder: () async => transport,
        ),
        throwsA(same(failure)),
      );
      expect(transport.disposed, isTrue);
    },
  );

  test(
    'required real push accepts a nonempty FCM token without printing it',
    () async {
      const sensitiveToken = 'sensitive-fcm-token-must-not-be-printed';
      final transport = _TokenProbeTransport(token: sensitiveToken);
      final printed = <String>[];
      final originalDebugPrint = debugPrint;
      debugPrint = (message, {wrapWidth}) {
        if (message != null) printed.add(message);
      };
      try {
        final resolved = await resolvePushTransport(
          requireRealPush: true,
          firebaseInitializer: () async {},
          transportBuilder: () async => transport,
        );
        expect(resolved, same(transport));
        expect(transport.getTokenCalls, 1);
        expect(printed.join('\n'), isNot(contains(sensitiveToken)));
      } finally {
        debugPrint = originalDebugPrint;
      }
    },
  );

  test('default push path does not require token readiness', () async {
    final transport = _TokenProbeTransport(token: null);

    final resolved = await resolvePushTransport(
      requireRealPush: false,
      firebaseInitializer: () async {},
      transportBuilder: () async => transport,
    );

    expect(resolved, same(transport));
    expect(transport.getTokenCalls, 0);
  });
}
