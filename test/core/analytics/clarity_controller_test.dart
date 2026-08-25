import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/analytics/clarity/application/clarity_controller.dart';
import 'package:jeeb_mobile/core/analytics/clarity/domain/clarity_analytics_port.dart';
import 'package:jeeb_mobile/core/analytics/clarity/domain/clarity_consent.dart';
import 'package:jeeb_mobile/core/analytics/clarity/domain/clarity_consent_store.dart';

void main() {
  Future<BuildContext> contextFor(WidgetTester tester) async {
    late BuildContext result;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            result = context;
            return const SizedBox();
          },
        ),
      ),
    );
    return result;
  }

  testWidgets('requires config, auth, consent, and an attached context', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics();
    final disabled = ClarityController(
      available: false,
      consentStore: _FakeStore(ClarityConsent.granted),
      analytics: analytics,
    );
    await disabled.loadConsent();
    disabled.updateAuthentication(true);
    disabled.attachContext(context);
    await tester.pump();
    expect(analytics.initializeCalls, 0);

    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
    );
    subject.attachContext(context);
    subject.updateAuthentication(true);
    await subject.loadConsent();
    expect(analytics.initializeCalls, 0);
    await subject.grant();
    await tester.pump();
    expect(analytics.initializeCalls, 1);
    expect(analytics.consents.single, (false, true));
    expect(subject.isCaptureActive, isTrue);
  });

  testWidgets('concurrent grants initialize at most once', (tester) async {
    final context = await contextFor(tester);
    final store = _FakeStore(ClarityConsent.unknown);
    final analytics = _FakeAnalytics();
    final subject = ClarityController(
      available: true,
      consentStore: store,
      analytics: analytics,
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    final results = await Future.wait([subject.grant(), subject.grant()]);
    await tester.pump();
    expect(results.where((value) => value), hasLength(1));
    expect(analytics.initializeCalls, 1);
  });

  testWidgets('SDK failure is contained and leaves capture off', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics()..throwOnInitialize = true;
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
      readinessRetryDelays: const [Duration.zero],
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    expect(await subject.grant(), isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    expect(subject.isCaptureActive, isFalse);
  });

  testWidgets('accepted initialization stays off until session readiness', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics()..startSessionOnInitializeCall = null;
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
      readinessRetryDelays: const [Duration(minutes: 1)],
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);

    expect(await subject.grant(), isTrue);
    await tester.pump();
    expect(subject.shouldMountSdkWidget, isTrue);
    expect(subject.isCaptureActive, isFalse);

    analytics.fireSessionStarted();
    await tester.pump();
    expect(subject.isCaptureActive, isTrue);
  });

  testWidgets('immediate failure retries and a later ready session activates', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics()
      ..startSessionOnInitializeCall = 2
      ..initializationResults.addAll([false, true]);
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
      readinessRetryDelays: const [Duration.zero, Duration(minutes: 1)],
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);

    expect(await subject.grant(), isTrue);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();

    expect(analytics.initializeCalls, 2);
    expect(subject.shouldMountSdkWidget, isTrue);
    expect(subject.isCaptureActive, isTrue);
  });

  testWidgets('readiness retry attempts are bounded after timeout', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics()..startSessionOnInitializeCall = null;
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
      readinessRetryDelays: const [Duration.zero, Duration.zero],
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);

    expect(await subject.grant(), isTrue);
    await tester.pump();
    await tester.pump();
    await tester.pump(const Duration(minutes: 5));

    expect(analytics.initializeCalls, 2);
    expect(subject.isCaptureActive, isFalse);
  });

  testWidgets('revocation invalidates a late readiness callback', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics()..startSessionOnInitializeCall = null;
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
      readinessRetryDelays: const [Duration(minutes: 1)],
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    await subject.grant();
    await tester.pump();
    final staleCallback = analytics.sessionStartedCallbacks.single;

    await subject.revoke();
    staleCallback();
    await tester.pump();

    expect(subject.isGranted, isFalse);
    expect(subject.isCaptureActive, isFalse);
    expect(analytics.resumeCalls, 0);
  });

  testWidgets('auth loss invalidates a late readiness callback', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics()..startSessionOnInitializeCall = null;
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
      readinessRetryDelays: const [Duration(minutes: 1)],
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    await subject.grant();
    await tester.pump();
    final staleCallback = analytics.sessionStartedCallbacks.single;

    subject.updateAuthentication(false);
    staleCallback();
    await tester.pump();

    expect(subject.consentState, ClarityConsent.unknown);
    expect(subject.isCaptureActive, isFalse);
    expect(analytics.resumeCalls, 0);
  });

  testWidgets('revoke fails closed immediately even when persistence fails', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final store = _FakeStore(ClarityConsent.unknown);
    final analytics = _FakeAnalytics();
    final subject = ClarityController(
      available: true,
      consentStore: store,
      analytics: analytics,
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    await subject.grant();
    await tester.pump();
    store.writeSucceeds = false;
    final result = subject.revoke();
    expect(subject.isGranted, isFalse);
    expect(subject.isCaptureActive, isFalse);
    expect(analytics.pauseCalls, 1);
    expect(analytics.consents.last, (false, false));
    expect(await result, isFalse);
    expect(analytics.resumeCalls, 0);
  });

  testWidgets('auth loss clears consent before another account can capture', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics();
    final store = _FakeStore(ClarityConsent.granted);
    final subject = ClarityController(
      available: true,
      consentStore: store,
      analytics: analytics,
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    await subject.loadConsent();
    await tester.pump();
    subject.updateAuthentication(false);
    expect(analytics.newSessionCalls, 1);
    expect(analytics.pauseCalls, 1);
    expect(subject.consentState, ClarityConsent.unknown);
    await tester.pump();
    expect(store.value, ClarityConsent.unknown);
    subject.updateAuthentication(true);
    await tester.pump();
    expect(analytics.resumeCalls, 0);
    expect(subject.isCaptureActive, isFalse);
    await subject.grant();
    await tester.pump();
    expect(analytics.resumeCalls, 1);
    expect(subject.isCaptureActive, isTrue);
  });

  testWidgets('cold-start unauthenticated state invalidates an old grant', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final store = _FakeStore(ClarityConsent.granted);
    final analytics = _FakeAnalytics();
    final subject = ClarityController(
      available: true,
      consentStore: store,
      analytics: analytics,
    );
    subject.attachContext(context);
    final loading = subject.loadConsent();
    subject.updateAuthentication(false);
    await loading;
    await tester.pump();

    subject.updateAuthentication(true);
    await tester.pump();
    expect(store.value, ClarityConsent.unknown);
    expect(subject.consentState, ClarityConsent.unknown);
    expect(analytics.initializeCalls, 0);
  });

  testWidgets('revocation reports failure when SDK cannot confirm pause', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics();
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.granted),
      analytics: analytics,
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    await subject.loadConsent();
    await tester.pump();
    analytics.pauseSucceeds = false;

    expect(await subject.revoke(), isFalse);
    expect(analytics.pauseCalls, 2);
    expect(subject.privacyOperationFailed, isTrue);
    expect(subject.isCaptureActive, isFalse);
  });

  testWidgets('latest canonical screen is applied after late activation', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics();
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
    );
    subject.reportClarityScreen('settings');
    subject.updateAuthentication(true);
    subject.attachContext(context);

    await subject.grant();
    await tester.pump();

    expect(analytics.screenNames, ['settings']);
  });

  testWidgets('full lifecycle chain pauses once and resumes behind gates', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics();
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    await subject.grant();
    await tester.pump();
    final staleCallback = analytics.sessionStartedCallbacks.single;

    subject.suspendForLifecycle();
    subject.suspendForLifecycle();
    subject.suspendForLifecycle();
    subject.suspendForLifecycle();
    staleCallback();
    await tester.pump();
    expect(subject.isCaptureActive, isFalse);
    expect(analytics.paused, isTrue);
    expect(analytics.pauseCalls, 1);
    subject.resumeFromLifecycle();
    await tester.pump();

    expect(subject.isCaptureActive, isTrue);
    expect(analytics.resumeCalls, 1);
  });

  testWidgets('detach invalidates readiness until a current context returns', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics()..startSessionOnInitializeCall = null;
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
      readinessRetryDelays: const [Duration(minutes: 1)],
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    await subject.grant();
    await tester.pump();
    final staleCallback = analytics.sessionStartedCallbacks.single;

    subject.detachContext();
    staleCallback();
    await tester.pump();
    expect(subject.isCaptureActive, isFalse);

    subject.attachContext(context);
    await tester.pump();
    analytics.fireSessionStarted();
    await tester.pump();
    expect(subject.isCaptureActive, isTrue);
  });

  testWidgets('dispose cancels retry and ignores a late callback', (
    tester,
  ) async {
    final context = await contextFor(tester);
    final analytics = _FakeAnalytics()..startSessionOnInitializeCall = null;
    final subject = ClarityController(
      available: true,
      consentStore: _FakeStore(ClarityConsent.unknown),
      analytics: analytics,
      readinessRetryDelays: const [Duration(seconds: 1)],
    );
    subject.updateAuthentication(true);
    subject.attachContext(context);
    await subject.grant();
    await tester.pump();
    final lateCallback = analytics.sessionStartedCallbacks.single;

    subject.dispose();
    lateCallback();
    await tester.pump(const Duration(minutes: 1));

    expect(analytics.initializeCalls, 1);
    expect(subject.isCaptureActive, isFalse);
  });
}

final class _FakeStore implements ClarityConsentStore {
  _FakeStore(this.value);
  ClarityConsent value;
  bool writeSucceeds = true;
  bool clearSucceeds = true;

  @override
  Future<ClarityConsent> read() async => value;

  @override
  Future<bool> write(ClarityConsent consent) async {
    if (!writeSucceeds) return false;
    value = consent;
    return true;
  }

  @override
  Future<bool> clear() async {
    if (!clearSucceeds) return false;
    value = ClarityConsent.unknown;
    return true;
  }
}

final class _FakeAnalytics implements ClarityAnalyticsPort {
  int initializeCalls = 0;
  int callbackRegistrationCalls = 0;
  int pauseCalls = 0;
  int resumeCalls = 0;
  int newSessionCalls = 0;
  bool throwOnInitialize = false;
  bool callbackRegistrationSucceeds = true;
  bool pauseSucceeds = true;
  bool paused = false;
  bool sessionExists = false;
  int? startSessionOnInitializeCall = 1;
  final List<bool> initializationResults = [];
  final List<VoidCallback> sessionStartedCallbacks = [];
  final List<(bool, bool)> consents = [];
  final List<String?> screenNames = [];

  @override
  bool setSessionStartedCallback(VoidCallback onSessionStarted) {
    callbackRegistrationCalls++;
    sessionStartedCallbacks.add(onSessionStarted);
    if (!callbackRegistrationSucceeds) return false;
    if (sessionExists) onSessionStarted();
    return true;
  }

  @override
  bool initialize(BuildContext context) {
    initializeCalls++;
    if (throwOnInitialize) throw StateError('SDK down');
    final result = initializationResults.isEmpty
        ? true
        : initializationResults.removeAt(0);
    if (result && startSessionOnInitializeCall == initializeCalls) {
      fireSessionStarted();
    }
    return result;
  }

  void fireSessionStarted([int? callbackIndex]) {
    sessionExists = true;
    final callback = callbackIndex == null
        ? sessionStartedCallbacks.last
        : sessionStartedCallbacks[callbackIndex];
    callback();
  }

  @override
  bool consent({required bool adsStorage, required bool analyticsStorage}) {
    consents.add((adsStorage, analyticsStorage));
    return true;
  }

  @override
  bool pause() {
    pauseCalls++;
    if (!pauseSucceeds) return false;
    paused = true;
    return true;
  }

  @override
  bool isPaused() => paused;

  @override
  bool resume() {
    resumeCalls++;
    paused = false;
    return true;
  }

  @override
  bool startNewSession() {
    newSessionCalls++;
    return true;
  }

  @override
  bool setScreenName(String? screenName) {
    screenNames.add(screenName);
    return true;
  }
}
