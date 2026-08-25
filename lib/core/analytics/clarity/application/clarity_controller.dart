import 'dart:async';

import 'package:flutter/widgets.dart';

import '../domain/clarity_analytics_port.dart';
import '../domain/clarity_consent.dart';
import '../domain/clarity_consent_store.dart';

/// Coordinates every gate that must be open before capture can run.
///
/// Mutations are serialized, SDK failures are contained, and a revoke/auth-loss
/// closes the in-memory gate synchronously before any persistence or SDK work.
final class ClarityController extends ChangeNotifier
    implements ClarityScreenReporter {
  ClarityController({
    required this.available,
    required ClarityConsentStore consentStore,
    required ClarityAnalyticsPort analytics,
    List<Duration> readinessRetryDelays = const <Duration>[
      Duration(seconds: 10),
      Duration(seconds: 30),
      Duration(minutes: 1),
    ],
  }) : _consentStore = consentStore,
       _analytics = analytics,
       _readinessRetryDelays = List<Duration>.unmodifiable(
         readinessRetryDelays,
       ) {
    assert(readinessRetryDelays.isNotEmpty);
  }

  final bool available;
  final ClarityConsentStore _consentStore;
  final ClarityAnalyticsPort _analytics;
  final List<Duration> _readinessRetryDelays;

  ClarityConsent _consent = ClarityConsent.unknown;
  BuildContext? _context;
  bool _authenticated = false;
  bool _initializationRequested = false;
  bool _sdkReady = false;
  bool _captureActive = false;
  bool _analyticsConsentApplied = false;
  bool _privacyOperationFailed = false;
  bool _needsAuthenticatedBoundary = false;
  bool _resumeRequired = false;
  bool _lifecycleActive = true;
  bool _disposed = false;
  String? _latestScreenName;
  int _consentMutationEpoch = 0;
  int _activationEpoch = 0;
  int _readinessAttempts = 0;
  Timer? _readinessRetryTimer;
  Future<void> _tail = Future<void>.value();

  ClarityConsent get consentState => _consent;
  bool get isGranted => _consent.isGranted;
  bool get shouldMountSdkWidget => _initializationRequested;
  bool get isCaptureActive => _captureActive;
  bool get privacyOperationFailed => _privacyOperationFailed;

  @override
  bool get canReportClarityScreen => _captureActive;

  Future<void> loadConsent() {
    final epoch = _consentMutationEpoch;
    return _enqueue(() async {
      final loaded = await _consentStore.read();
      if (epoch != _consentMutationEpoch) return;
      _setConsent(loaded);
      await _reconcile();
    });
  }

  /// Attaches a context below MaterialApp after the product app's first frame.
  void attachContext(BuildContext context) {
    if (_disposed || !context.mounted) return;
    if (!identical(_context, context)) _closeCaptureForActivationChange();
    _context = context;
    unawaited(_enqueue(_reconcile));
  }

  void detachContext() {
    _context = null;
    _closeCaptureForActivationChange();
  }

  void updateAuthentication(bool authenticated) {
    if (_disposed) return;
    if (!authenticated) {
      _authenticated = false;
      _handleAuthenticationLoss();
      return;
    }
    if (_authenticated) return;
    _authenticated = true;
    unawaited(_enqueue(_reconcile));
  }

  /// Persists opt-in before opening any capture gate.
  Future<bool> grant() {
    if (_disposed || !available) return Future<bool>.value(false);
    final epoch = ++_consentMutationEpoch;
    _setPrivacyOperationFailed(false);
    return _enqueueDecision(() async {
      final persisted = await _consentStore.write(ClarityConsent.granted);
      if (!persisted || epoch != _consentMutationEpoch) return false;
      _setConsent(ClarityConsent.granted);
      await _reconcile();
      return true;
    });
  }

  Future<bool> deny() => _closeConsentGate(ClarityConsent.denied);

  Future<bool> revoke() => _closeConsentGate(ClarityConsent.denied);

  Future<bool> _closeConsentGate(ClarityConsent next) {
    final epoch = ++_consentMutationEpoch;
    _invalidateActivation();
    _setConsent(next);
    _captureActive = false;
    _analyticsConsentApplied = false;
    final sdkStopped = !_initializationRequested || _denyConsentAndPause();
    _setPrivacyOperationFailed(!sdkStopped);
    notifyListeners();
    return _enqueueDecision(() async {
      if (epoch != _consentMutationEpoch) return false;
      final persisted = await _retryPersistence(
        () => _consentStore.write(next),
      );
      if (epoch != _consentMutationEpoch) return false;
      final succeeded = sdkStopped && persisted;
      _setPrivacyOperationFailed(!succeeded);
      return succeeded;
    });
  }

  @override
  void reportClarityScreen(String screenName) {
    _latestScreenName = screenName;
    if (!canReportClarityScreen) return;
    _safe(() => _analytics.setScreenName(screenName));
  }

  /// Pauses capture while the application is not visible.
  void suspendForLifecycle() {
    if (_disposed || !_lifecycleActive) return;
    _lifecycleActive = false;
    _invalidateActivation();
    _captureActive = false;
    if (_initializationRequested) {
      _resumeRequired = true;
      _pauseAndVerify();
    }
    notifyListeners();
  }

  /// Re-opens capture only through the normal config/auth/consent gates.
  void resumeFromLifecycle() {
    if (_disposed || _lifecycleActive) return;
    _lifecycleActive = true;
    unawaited(_enqueue(_reconcile));
  }

  Future<void> _reconcile() async {
    final context = _context;
    if (!available ||
        !_authenticated ||
        !_consent.isGranted ||
        !_lifecycleActive ||
        context == null ||
        !context.mounted) {
      return;
    }

    if (!_analyticsConsentApplied) {
      final applied = _safe(
        () => _analytics.consent(adsStorage: false, analyticsStorage: true),
      );
      if (!applied) return;
      _analyticsConsentApplied = true;
    }

    if (!_sdkReady) {
      _requestSdkReadiness(context);
      return;
    }

    if (_needsAuthenticatedBoundary) {
      if (!_safe(_analytics.startNewSession)) return;
      _needsAuthenticatedBoundary = false;
    }
    if (_resumeRequired && !_safe(_analytics.resume)) return;
    _resumeRequired = false;
    _captureActive = true;
    _reportLatestScreen();
    notifyListeners();
  }

  void _handleAuthenticationLoss() {
    final epoch = ++_consentMutationEpoch;
    _invalidateActivation();
    _setConsent(ClarityConsent.unknown);
    _captureActive = false;
    _analyticsConsentApplied = false;
    final sdkStopped =
        !_initializationRequested || _closeAuthenticatedSdkSession();
    _setPrivacyOperationFailed(!sdkStopped);
    notifyListeners();
    unawaited(_clearConsentAfterAuthLoss(epoch, sdkStopped));
  }

  bool _closeAuthenticatedSdkSession() {
    _needsAuthenticatedBoundary = !_safe(_analytics.startNewSession);
    return _denyConsentAndPause();
  }

  Future<void> _clearConsentAfterAuthLoss(int epoch, bool sdkStopped) {
    return _enqueue(() async {
      final cleared = await _retryPersistence(_consentStore.clear);
      if (epoch != _consentMutationEpoch) return;
      _setPrivacyOperationFailed(!sdkStopped || !cleared);
    });
  }

  bool _denyConsentAndPause() {
    _resumeRequired = true;
    final denied = _retrySdk(
      () => _analytics.consent(adsStorage: false, analyticsStorage: false),
    );
    final paused = _pauseAndVerify();
    return denied && paused;
  }

  bool _pauseAndVerify() {
    for (var attempt = 0; attempt < 2; attempt++) {
      _safe(_analytics.pause);
      if (_safe(_analytics.isPaused)) return true;
    }
    return false;
  }

  bool _retrySdk(bool Function() operation) {
    for (var attempt = 0; attempt < 2; attempt++) {
      if (_safe(operation)) return true;
    }
    return false;
  }

  Future<bool> _retryPersistence(Future<bool> Function() operation) async {
    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        if (await operation()) return true;
      } catch (_) {
        // Continue to the one bounded retry.
      }
    }
    return false;
  }

  void _reportLatestScreen() {
    final screenName = _latestScreenName;
    if (screenName != null) _safe(() => _analytics.setScreenName(screenName));
  }

  void _requestSdkReadiness(BuildContext context) {
    if (_readinessRetryTimer != null ||
        _readinessAttempts >= _readinessRetryDelays.length) {
      return;
    }

    final epoch = _activationEpoch;
    final callbackRegistered = _safe(
      () => _analytics.setSessionStartedCallback(
        () => _onSdkSessionStarted(epoch),
      ),
    );
    final accepted =
        callbackRegistered && _safe(() => _analytics.initialize(context));
    if (accepted && !_initializationRequested) {
      _initializationRequested = true;
      notifyListeners();
    }

    final delay = _readinessRetryDelays[_readinessAttempts++];
    _readinessRetryTimer = Timer(delay, () => _onReadinessTimeout(epoch));
  }

  void _onSdkSessionStarted(int epoch) {
    if (_disposed) return;
    unawaited(
      _enqueue(() async {
        if (!_activationGateOpen(epoch)) return;
        _sdkReady = true;
        _cancelReadinessRetry();
        await _reconcile();
      }),
    );
  }

  void _onReadinessTimeout(int epoch) {
    _readinessRetryTimer = null;
    if (!_activationGateOpen(epoch)) return;
    unawaited(_enqueue(_reconcile));
  }

  bool _activationGateOpen(int epoch) {
    final context = _context;
    return !_disposed &&
        epoch == _activationEpoch &&
        available &&
        _authenticated &&
        _consent.isGranted &&
        _lifecycleActive &&
        context != null &&
        context.mounted;
  }

  void _closeCaptureForActivationChange() {
    _invalidateActivation();
    _captureActive = false;
    if (_initializationRequested) {
      _resumeRequired = true;
      _pauseAndVerify();
    }
    notifyListeners();
  }

  void _invalidateActivation() {
    _activationEpoch++;
    _sdkReady = false;
    _readinessAttempts = 0;
    _cancelReadinessRetry();
  }

  void _cancelReadinessRetry() {
    _readinessRetryTimer?.cancel();
    _readinessRetryTimer = null;
  }

  bool _safe(bool Function() operation) {
    try {
      return operation();
    } catch (_) {
      return false;
    }
  }

  void _setConsent(ClarityConsent next) {
    if (_consent == next) return;
    _consent = next;
    notifyListeners();
  }

  void _setPrivacyOperationFailed(bool failed) {
    if (_privacyOperationFailed == failed) return;
    _privacyOperationFailed = failed;
    notifyListeners();
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final completer = Completer<void>();
    _tail = _tail.then((_) async {
      try {
        await operation();
      } catch (_) {
        // Analytics must never escape into product startup or user flows.
      } finally {
        completer.complete();
      }
    });
    return completer.future;
  }

  Future<bool> _enqueueDecision(Future<bool> Function() operation) {
    final completer = Completer<bool>();
    _tail = _tail.then((_) async {
      try {
        completer.complete(await operation());
      } catch (_) {
        completer.complete(false);
      }
    });
    return completer.future;
  }

  @override
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _context = null;
    _invalidateActivation();
    _captureActive = false;
    super.dispose();
  }
}

class ClarityAnalyticsScope extends InheritedNotifier<ClarityController> {
  const ClarityAnalyticsScope({
    super.key,
    required ClarityController controller,
    required super.child,
  }) : super(notifier: controller);

  static ClarityController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<ClarityAnalyticsScope>()
      ?.notifier;
}
