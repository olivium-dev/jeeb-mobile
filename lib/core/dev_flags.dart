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
