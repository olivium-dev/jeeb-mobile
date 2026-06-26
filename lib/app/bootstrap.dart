import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dev_seam/dev_seam.dart';
import '../core/dev_seam/session_seam_bootstrap.dart';
import '../core/di/injection_container.dart';
import '../core/observability/crash_reporter.dart';
import '../core/observability/crash_reporting_initializer.dart';
import '../core/observability/firebase_crashlytics_reporter.dart';
import '../core/observability/swappable_crash_reporter.dart';

/// Two-phase cold-start bootstrap (T-mobile-047, extended in T-mobile-049,
/// hardened against the cold-start ANR in Sprint 5).
///
/// Phase 1 — [minimal] runs before the first frame. It loads ONLY what the
/// root widget tree needs to render: [SharedPreferences] and the synchronous DI
/// registrations. It NEVER touches the network and NEVER awaits a native
/// initializer, so the first frame paints immediately. Target wall-clock:
/// < 250 ms on a Galaxy A14.
///
/// It hands the tree a [SwappableCrashReporter] (Noop delegate) and installs the
/// error hooks on it right away, so crashes during the rest of boot are caught
/// by a stable reporter whose delegate upgrades transparently later.
///
/// Phase 2 — [deferred] runs from `addPostFrameCallback` after the first
/// frame paints. It performs work that is convenient-but-not-critical:
/// `initializeDateFormatting()` AND — critically — `Firebase.initializeApp()` +
/// the real Crashlytics reporter. Firebase init is moved OFF the boot critical
/// path because on a dev/QA build with no `google-services.json` the native
/// call hangs/retries for ~40s on the platform main thread, which is what
/// triggered the cold-start ANR ("Jeeb Dev isn't responding"). A Dart-side
/// `.timeout()` could stop the await but not unblock the native main thread, so
/// the only safe fix is to never run it before first frame.
///
/// Both phases emit Dart-VM `Timeline` events so Flutter DevTools' CPU
/// profiler can attribute cost back to a named phase.
class Bootstrap {
  Bootstrap._();

  /// Critical-path init. Resolves with the [BootstrapResult] the root widget
  /// needs to start rendering real content (post-splash).
  ///
  /// This phase performs NO network I/O and awaits NO native initializer — the
  /// crash reporter starts as a Noop-backed [SwappableCrashReporter] and is
  /// upgraded to Crashlytics in [deferred], after the first frame. That keeps
  /// the splash→app hand-off bounded by local prefs + DI only (a few ms), so a
  /// missing/slow Firebase config can never hold (or ANR) the cold start.
  static Future<BootstrapResult> minimal() async {
    developer.Timeline.startSync('Bootstrap.minimal');
    try {
      // Fonts are bundled locally (static Inter instances in assets/fonts/).
      // Disable
      // google_fonts' runtime fetch so nothing in the tree can hit
      // fonts.gstatic.com — a no-egress device throws a HandshakeException
      // there, which previously crashed the theme build on first frame.
      // Defence-in-depth: AppTheme already uses the bundled family directly.
      GoogleFonts.config.allowRuntimeFetching = false;
      // Debug-only: resolve the runtime dev seam (intent extras / device file /
      // dart-define) so a single dev APK can render any screen-state-locale via
      // adb. No-op + release-inert (DevSeam.resolve short-circuits when
      // !kDebugMode). Must run before the router/locale read DevSeam.current.
      await DevSeam.resolve();
      final preferences = await SharedPreferences.getInstance();
      // Debug-only W0 dev-seam session/journey harness (62_SEAM_HARNESS.md,
      // RC-1 in 61_W0_QA_RESULTS.md). Seeds onboarding/role/token/biometric/
      // account-status state from `jeeb.seam.session` into the REAL stores the
      // root cubits read — BEFORE the first frame paints and BEFORE the router's
      // first-run redirect fires — so a Maestro flow starts mid-journey
      // deterministically. No-op + release-inert (gated by kDebugMode and an
      // empty DevSeam in release).
      //
      // `awaitMockSeed: false` (LANDING-FIX, 66_W2_QA_RESULTS): the local
      // session-state seed (the LANDING decider) is awaited inside `seed()` and
      // completes in a few ms; the mock-side journey/kyc/wallet POSTs (which only
      // make the mock hold rows the screens fetch AFTER first frame) are fired
      // detached so a slow emulator network can NEVER hold the splash → app
      // hand-off. This is what unblocks `shell_tab_requests` (and every seeded
      // landing) inside the QA window on a re-launch. The POSTs are themselves
      // bounded + fail-safe, and the rows are in the mock long before a flow
      // navigates into them.
      await SessionSeamBootstrap.seed(
        prefs: preferences,
        awaitMockSeed: false,
      );
      // COLD-START ANR FIX (Sprint 5): the crash reporter is a Noop-backed
      // [SwappableCrashReporter] at first frame. NO `Firebase.initializeApp()`
      // runs here — that native call hangs ~40s without google-services.json and
      // blocks the platform main thread → ANR. [deferred] upgrades the delegate
      // to Crashlytics post-first-frame. The hooks are installed on the stable
      // swappable instance now, so a boot-time error is still routed to whatever
      // delegate is live (Noop now, Crashlytics after the swap).
      final reporter = SwappableCrashReporter();
      configureDependencies(
        sharedPreferences: preferences,
        crashReporter: reporter,
      );
      CrashReportingInitializer(reporter).install();
      return BootstrapResult(preferences: preferences, crashReporter: reporter);
    } finally {
      developer.Timeline.finishSync();
    }
  }

  /// Post-first-frame init. Safe to skip (returned future ignored) when the
  /// caller only wants fire-and-forget warm-up.
  ///
  /// Runs the convenient-but-not-critical warm-up (`initializeDateFormatting`)
  /// AND the crash-reporter (Firebase/Crashlytics) init that used to sit on the
  /// boot critical path. When [crashReporter] is a [SwappableCrashReporter], a
  /// successful (timeboxed) Firebase init upgrades its delegate to the real
  /// [FirebaseCrashlyticsReporter]; on failure/timeout it stays Noop. Every step
  /// is fail-safe — this future is fired-and-forgotten from `addPostFrameCallback`
  /// and must never crash the app.
  ///
  /// [crashReporterFactory] is a test seam — widget/unit tests inject a fake that
  /// resolves immediately so they don't need a real Firebase app config.
  static Future<void> deferred({
    CrashReporter? crashReporter,
    Future<CrashReporter> Function()? crashReporterFactory,
  }) async {
    developer.Timeline.startSync('Bootstrap.deferred');
    try {
      await _initDateFormatting();
      await _upgradeCrashReporter(crashReporter, crashReporterFactory);
    } finally {
      developer.Timeline.finishSync();
    }
  }

  static Future<void> _initDateFormatting() async {
    try {
      await initializeDateFormatting();
    } catch (error) {
      // Non-critical warm-up — never let it crash the deferred phase.
      debugPrint('initializeDateFormatting failed (non-fatal): $error');
    }
  }

  /// Upgrades a [SwappableCrashReporter] to the real reporter once Firebase
  /// init resolves. No-op when [crashReporter] is not swappable (e.g. a test
  /// passed a fixed reporter, or none).
  static Future<void> _upgradeCrashReporter(
    CrashReporter? crashReporter,
    Future<CrashReporter> Function()? crashReporterFactory,
  ) async {
    if (crashReporter is! SwappableCrashReporter) return;
    final real =
        await (crashReporterFactory ?? _defaultCrashReporterFactory)();
    crashReporter.setDelegate(real);
  }

  /// Hard ceiling on the crash-reporter (Firebase) init. It now runs in the
  /// DEFERRED phase (post-first-frame), so a slow/hanging init no longer holds
  /// the splash or ANRs the cold start — this bound is belt-and-braces so the
  /// reporter falls back to Noop promptly rather than retrying for ~40s. On a
  /// dev/QA build with no `google-services.json` the native
  /// `Firebase.initializeApp()` does NOT fail fast (it hangs/retries ~40s before
  /// throwing "Failed to load FirebaseOptions from resource"); a healthy
  /// production build (with google-services.json) initialises well within this.
  static const Duration _crashReporterInitTimeout = Duration(seconds: 5);

  static Future<CrashReporter> _defaultCrashReporterFactory() async {
    try {
      await Firebase.initializeApp().timeout(_crashReporterInitTimeout);
      return FirebaseCrashlyticsReporter();
    } catch (error, stack) {
      // Missing google-services.json on dev, no network on first boot, OR the
      // native init exceeded [_crashReporterInitTimeout]. We must never let
      // observability tooling crash the app — fall back to the silent reporter
      // and surface the failure to the console only.
      debugPrint('Crashlytics init failed; falling back to Noop: $error');
      debugPrint(stack.toString());
      return const NoopCrashReporter();
    }
  }
}

/// Output of [Bootstrap.minimal], passed into the root widget so it doesn't
/// re-fetch the same async values.
class BootstrapResult {
  const BootstrapResult({
    required this.preferences,
    required this.crashReporter,
  });

  final SharedPreferences preferences;

  /// The stable crash reporter the widget tree holds. In production this is a
  /// [SwappableCrashReporter] whose delegate is upgraded from Noop to Crashlytics
  /// by [Bootstrap.deferred] after the first frame; tests may pass a fixed one.
  final CrashReporter crashReporter;
}
