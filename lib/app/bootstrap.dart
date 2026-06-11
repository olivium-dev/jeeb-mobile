import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dev_seam/dev_seam.dart';
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
      // Debug-only: resolve the runtime dev seam (intent extras / device file /
      // dart-define) so a single dev APK can render any screen-state-locale via
      // adb. No-op + release-inert (DevSeam.resolve short-circuits when
      // !kDebugMode). Must run before the router/locale read DevSeam.current.
      await DevSeam.resolve();
      final preferences = await SharedPreferences.getInstance();
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

  static Future<CrashReporter> _defaultCrashReporterFactory() async {
    try {
      await Firebase.initializeApp();
      return FirebaseCrashlyticsReporter();
    } catch (error, stack) {
      // Missing google-services.json on dev, or no network on first boot.
      // We must never let observability tooling crash the app — fall back
      // to the silent reporter and surface the failure to the console only.
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
