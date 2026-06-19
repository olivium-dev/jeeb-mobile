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

/// Two-phase cold-start bootstrap (T-mobile-047, extended in T-mobile-049).
///
/// Phase 1 — [minimal] runs before the first frame. It loads ONLY what the
/// root widget tree needs to render: [SharedPreferences], the synchronous DI
/// registrations, and **the crash reporter** — because we want to capture
/// crashes that happen during the rest of bootstrap. Target wall-clock:
/// < 250 ms on a Galaxy A14.
///
/// Phase 2 — [deferred] runs from `addPostFrameCallback` after the first
/// frame paints. It performs work that is convenient-but-not-critical
/// (`initializeDateFormatting()` etc.).
///
/// Both phases emit Dart-VM `Timeline` events so Flutter DevTools' CPU
/// profiler can attribute cost back to a named phase.
class Bootstrap {
  Bootstrap._();

  /// Critical-path init. Resolves with the [BootstrapResult] the root widget
  /// needs to start rendering real content (post-splash).
  ///
  /// [firebaseInitializer] is exposed as a seam — widget tests inject a
  /// fake that resolves immediately, so they don't need a real Firebase
  /// app config. The default calls [Firebase.initializeApp] and, on failure
  /// (e.g. missing google-services.json in dev), falls back to a Noop
  /// reporter rather than crashing bootstrap.
  static Future<BootstrapResult> minimal({
    Future<CrashReporter> Function()? crashReporterFactory,
  }) async {
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
      final reporter =
          await (crashReporterFactory ?? _defaultCrashReporterFactory)();
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
  static Future<void> deferred() async {
    developer.Timeline.startSync('Bootstrap.deferred');
    try {
      await initializeDateFormatting();
    } finally {
      developer.Timeline.finishSync();
    }
  }

  /// Hard ceiling on the crash-reporter (Firebase) init that runs on the boot
  /// critical path. LANDING-FIX (66_W2_QA_RESULTS): on a fresh `clearState`
  /// install with no `google-services.json` (every dev/QA build), the native
  /// `Firebase.initializeApp()` does NOT fail fast — it hangs/retries for ~40s
  /// before throwing "Failed to load FirebaseOptions from resource". Because
  /// [minimal] awaits the crash-reporter factory, that ~40s held the branded
  /// splash past the 30s QA `extendedWaitUntil` window on cold-boot launches —
  /// a SECOND boot-hold source alongside the seam mock POSTs. Bounding the init
  /// makes it fall back to the Noop reporter in a few seconds; a healthy
  /// production build (with google-services.json) initialises well within this.
  static const Duration _crashReporterInitTimeout = Duration(seconds: 5);

  static Future<CrashReporter> _defaultCrashReporterFactory() async {
    try {
      await Firebase.initializeApp().timeout(_crashReporterInitTimeout);
      return FirebaseCrashlyticsReporter();
    } catch (error, stack) {
      // Missing google-services.json on dev, no network on first boot, OR the
      // native init exceeded [_crashReporterInitTimeout]. We must never let
      // observability tooling crash OR stall the app — fall back to the silent
      // reporter and surface the failure to the console only. The bounded
      // timeout guarantees boot is never held by a slow/hanging Firebase init.
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
  final CrashReporter crashReporter;
}
