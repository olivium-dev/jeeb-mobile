import 'package:flutter/foundation.dart';

/// Compile-time gate for the Jeeber Dev Tool.
///
/// The Dev Tool is NOT a separate app — it is a second launcher icon
/// (`activity-alias .DevToolLauncher`) on the SAME app (`app.jeeb.mobile`), so
/// it shares the app's process, DI, session and storage (full access). This
/// flag keeps its code out of the shipped product: dev/staging builds pass
/// `--dart-define=JEEB_DEVTOOL_ENABLED=true`; production omits it, so the
/// tree-shaker strips every `if (kDevToolEnabled)` branch (incl. `DevToolApp`)
/// from the release binary. The native alias is independently gated by
/// `@bool/jeeb_devtool_enabled` (false in production) — defence in depth.
const bool kDevToolEnabled =
    bool.fromEnvironment('JEEB_DEVTOOL_ENABLED', defaultValue: false);

/// True when dev-only affordances are permitted: a Dev-Tool-enabled build, or
/// any debug build. NEVER true in a production release binary.
const bool kDevAffordancesAllowed = kDevToolEnabled || kDebugMode;

/// Hard assertion for code that must NEVER run in the shipped product.
/// Throws in a production release binary; no-ops in dev-tool/debug builds.
void assertDevToolOnly([String? context]) {
  if (!kDevAffordancesAllowed) {
    throw StateError(
      'Dev-only code path reached in a production build'
      '${context == null ? '' : ': $context'}',
    );
  }
}
