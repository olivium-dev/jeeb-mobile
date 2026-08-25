import 'package:flutter/widgets.dart';

/// Product-facing boundary for privacy-safe Clarity operations.
///
/// No identity, arbitrary tag, custom event, or custom session-ID operation is
/// exposed. This makes those SDK capabilities unavailable to application code.
abstract interface class ClarityAnalyticsPort {
  /// Registers a readiness callback without exposing the SDK session ID to
  /// product code. The callback may be invoked synchronously when a session is
  /// already running.
  bool setSessionStartedCallback(VoidCallback onSessionStarted);

  bool initialize(BuildContext context);

  bool consent({required bool adsStorage, required bool analyticsStorage});

  bool pause();

  bool isPaused();

  bool resume();

  bool startNewSession();

  bool setScreenName(String? screenName);
}

abstract interface class ClarityScreenReporter {
  bool get canReportClarityScreen;

  void reportClarityScreen(String screenName);
}
