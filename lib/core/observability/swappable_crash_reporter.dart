import 'crash_reporter.dart';

/// A [CrashReporter] whose backing delegate can be swapped at runtime.
///
/// COLD-START CONTRACT (T-mobile-047 / Sprint-5 ANR fix): the cold-start
/// critical path ([Bootstrap.minimal]) must NEVER await `Firebase.initializeApp()`.
/// On a dev/QA build with no `google-services.json` that native call does not
/// fail fast — it hangs/retries for ~40s and blocks the platform MAIN thread,
/// which surfaces as the Android "isn't responding" (ANR) dialog at the 5s mark.
/// A Dart-side `.timeout()` can stop the *await* but cannot unblock the native
/// main-thread work, so the only safe fix is to keep Firebase off the boot path
/// entirely.
///
/// So bootstrap hands the widget tree THIS instance, initialised with a
/// [NoopCrashReporter] delegate, and renders the first frame immediately. The
/// real [FirebaseCrashlyticsReporter] is built from the deferred,
/// post-first-frame bootstrap phase ([Bootstrap.deferred]) and installed via
/// [setDelegate]. Because the instance the error hooks and [CrashContextBridge]
/// hold is stable, the delegate behind it upgrades transparently — any error
/// recorded before the swap is a no-op (acceptable: it is the few-ms boot
/// window), and every error after it reaches Crashlytics.
class SwappableCrashReporter implements CrashReporter {
  SwappableCrashReporter([CrashReporter delegate = const NoopCrashReporter()])
      : _delegate = delegate;

  CrashReporter _delegate;

  /// Upgrades the live delegate (e.g. from [NoopCrashReporter] to
  /// [FirebaseCrashlyticsReporter]) once the deferred Firebase init resolves.
  void setDelegate(CrashReporter delegate) => _delegate = delegate;

  @override
  void recordError(Object error, StackTrace stackTrace, {bool fatal = false}) =>
      _delegate.recordError(error, stackTrace, fatal: fatal);

  @override
  void setUserId(String userId) => _delegate.setUserId(userId);

  @override
  void log(String message) => _delegate.log(message);
}
