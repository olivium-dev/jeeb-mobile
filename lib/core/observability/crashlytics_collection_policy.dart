import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' as flutter_services show appFlavor;

enum CrashlyticsBuildMode { debug, profile, release }

/// Explicit Crashlytics collection rules for the two non-production runtimes.
///
/// Production returns `null` so this rollout cannot change its native/default
/// collection behavior. Debug capture is opt-in and accepted only for the
/// development or staging flavors.
class CrashlyticsCollectionPolicy {
  CrashlyticsCollectionPolicy._();

  static const String _configuredAppFlavor = String.fromEnvironment(
    'APP_FLAVOR',
    defaultValue: '',
  );

  /// Prefer the repository's explicit build contract, then Flutter's native
  /// `--flavor` value. This keeps local `--flavor dev` builds fail-closed even
  /// when they omit the redundant APP_FLAVOR dart-define.
  static final String appFlavor = resolveFlavor(
    configuredFlavor: _configuredAppFlavor,
    nativeFlavor: flutter_services.appFlavor,
  );

  static const bool debugCaptureRequested = bool.fromEnvironment(
    'CRASHLYTICS_DEBUG_CAPTURE',
    defaultValue: false,
  );

  static const bool testProbeRequested = bool.fromEnvironment(
    'CRASHLYTICS_TEST_PROBE',
    defaultValue: false,
  );

  static bool? get collectionOverride => resolve(
    buildMode: _currentBuildMode,
    flavor: appFlavor,
    debugCaptureRequested: debugCaptureRequested,
  );

  /// The destructive-looking probe is compiled out of ordinary builds and is
  /// unavailable unless collection is explicitly enabled for a non-production
  /// runtime.
  static bool get testProbeAvailable => testProbeAvailableFor(
    requested: testProbeRequested,
    collectionOverride: collectionOverride,
  );

  static bool testProbeAvailableFor({
    required bool requested,
    required bool? collectionOverride,
  }) => requested && collectionOverride == true;

  static String resolveFlavor({
    required String configuredFlavor,
    required String? nativeFlavor,
  }) {
    if (configuredFlavor.isNotEmpty) return configuredFlavor;
    if (nativeFlavor != null && nativeFlavor.isNotEmpty) return nativeFlavor;
    return 'production';
  }

  static bool? resolve({
    required CrashlyticsBuildMode buildMode,
    required String flavor,
    required bool debugCaptureRequested,
  }) {
    if (flavor != 'dev' && flavor != 'staging') return null;
    if (buildMode == CrashlyticsBuildMode.debug) {
      return debugCaptureRequested;
    }
    return true;
  }

  static CrashlyticsBuildMode get _currentBuildMode => kReleaseMode
      ? CrashlyticsBuildMode.release
      : kProfileMode
      ? CrashlyticsBuildMode.profile
      : CrashlyticsBuildMode.debug;
}
