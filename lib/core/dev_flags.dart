import 'package:flutter/foundation.dart';

/// Compile-time gate for Jeeber Dev Tool.
const bool kDevToolEnabled =
    bool.fromEnvironment('JEEB_DEVTOOL_ENABLED', defaultValue: false);

/// True in debug or dev-tool-enabled builds; NEVER in production.
const bool kDevAffordancesAllowed = kDevToolEnabled || kDebugMode;

/// Hard assertion for code that must never run in production.
void assertDevToolOnly([String? context]) {
  if (!kDevAffordancesAllowed) {
    throw StateError(
      'Dev-only code path reached in a production build'
      '${context == null ? '' : ': $context'}',
    );
  }
}
