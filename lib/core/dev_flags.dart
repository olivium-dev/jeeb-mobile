import 'package:flutter/foundation.dart';

/// Whether this build explicitly requested the Jeeber Dev Tool.
const bool kDevToolRequested = bool.fromEnvironment(
  'JEEB_DEVTOOL_ENABLED',
  defaultValue: false,
);

/// Compile-time gate for the Jeeber Dev Tool.
///
/// Release and profile builds stay locked even if their build command
/// accidentally supplies the request define.
const bool kDevToolEnabled = kDebugMode && kDevToolRequested;

/// True in debug or dev-tool-enabled builds; NEVER in production.
const bool kDevAffordancesAllowed = kDevToolEnabled || kDebugMode;

/// Whether this build requested the shake-to-open affordance for the Dev Tool.
///
/// Defaults ON so every Dev-Tool build gets it; pass
/// `--dart-define=JEEB_DEVTOOL_SHAKE=false` to compile just the shake wiring
/// out while keeping the rest of the Dev Tool.
const bool kShakeToDevToolRequested = bool.fromEnvironment(
  'JEEB_DEVTOOL_SHAKE',
  defaultValue: true,
);

/// Compile-time gate for shake-to-open-the-Dev-Tool (iOS entry point).
///
/// Derived from [kDevToolEnabled], so it is a compile-time `false` in every
/// release and profile build — the shake wiring, and with it the import of the
/// Dev Tool shell, tree-shakes out of the product binary. The native half of
/// the gesture is gated independently by `#if JEEB_DEV` in
/// `ios/Runner/AppDelegate.swift`; neither gate depends on the other.
const bool kShakeToDevToolEnabled = kDevToolEnabled && kShakeToDevToolRequested;

/// Hard assertion for code that must never run in production.
void assertDevToolOnly([String? context]) {
  if (!kDevToolEnabled) {
    throw StateError(
      'Dev Tool code path reached while the Dev Tool is disabled'
      '${context == null ? '' : ': $context'}',
    );
  }
}

/// Selects the Dev Tool only for its exact native initial route.
bool shouldLaunchDevTool({
  required bool enabled,
  required String initialRoute,
}) => enabled && initialRoute == '/devtool';
