import 'dart:async';
import 'dart:developer' as developer;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/dev_seam/dev_seam.dart';
import '../core/dev_seam/session_seam_bootstrap.dart';
import '../core/di/injection_container.dart';
import '../core/diagnostics/diag.dart';
import '../core/diagnostics/diag_file_sink.dart';
import '../core/network/auth_token_store.dart';
import '../core/observability/crash_reporter.dart';
import '../core/observability/crash_reporting_initializer.dart';
import '../core/observability/firebase_crashlytics_reporter.dart';
import '../core/observability/session_trace/session_trace.dart';
import '../core/observability/swappable_crash_reporter.dart';
import '../core/role/role_cubit.dart';
import '../core/role/user_role.dart';

class Bootstrap {
  Bootstrap._();

  static Future<BootstrapResult> minimal() async {
    developer.Timeline.startSync('Bootstrap.minimal');
    try {
      GoogleFonts.config.allowRuntimeFetching = false;
      await DevSeam.resolve();
      final preferences = await SharedPreferences.getInstance();
      await SessionSeamBootstrap.seed(
        prefs: preferences,
        awaitMockSeed: false,
      );
      final reporter = SwappableCrashReporter();
      configureDependencies(
        sharedPreferences: preferences,
        crashReporter: reporter,
      );
      CrashReportingInitializer(reporter).install();
      if (Diag.enabled) {
        final role =
            UserRole.fromStorage(preferences.getString(RoleCubit.rolePrefKey));
        unawaited(
          DiagFileSink.installAsGlobal(
            role: role.storageKey,
            subLookup: () => AuthTokenStore().userId,
          ),
        );
      }
      if (kObsCompiledIn && ObservabilityConfig.instance.captureInteractions) {
        ObsInteractionObserver.instance.install();
      }
      return BootstrapResult(preferences: preferences, crashReporter: reporter);
    } finally {
      developer.Timeline.finishSync();
    }
  }

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
      debugPrint('initializeDateFormatting failed (non-fatal): $error');
    }
  }

  static Future<void> _upgradeCrashReporter(
    CrashReporter? crashReporter,
    Future<CrashReporter> Function()? crashReporterFactory,
  ) async {
    if (crashReporter is! SwappableCrashReporter) return;
    final real =
        await (crashReporterFactory ?? _defaultCrashReporterFactory)();
    crashReporter.setDelegate(real);
  }

  static const Duration _crashReporterInitTimeout = Duration(seconds: 5);

  static Future<CrashReporter> _defaultCrashReporterFactory() async {
    try {
      await Firebase.initializeApp().timeout(_crashReporterInitTimeout);
      return FirebaseCrashlyticsReporter();
    } catch (error, stack) {
      debugPrint('Crashlytics init failed; falling back to Noop: $error');
      debugPrint(stack.toString());
      return const NoopCrashReporter();
    }
  }
}

class BootstrapResult {
  const BootstrapResult({
    required this.preferences,
    required this.crashReporter,
  });

  final SharedPreferences preferences;

  final CrashReporter crashReporter;
}
