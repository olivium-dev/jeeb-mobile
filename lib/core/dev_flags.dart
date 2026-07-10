import 'package:flutter/foundation.dart';

/// Compile-time distribution guard for the Jeeber Dev Tool.
///
/// The Dev Tool is a SECOND installable app (`app.jeeb.mobile.devtool`) built
/// from this same source tree via the Gradle `devtool` distribution flavor and
/// the `lib/main_devtool.dart` entrypoint. Its build passes
/// `--dart-define=JEEB_DEVTOOL=true`, so [kIsDevTool] is a `const` that the
/// tree-shaker uses to strip ALL dev-tool code paths out of the production
/// (`app` distribution) binary — an end user's Jeeb app can never reach them.
///
/// Usage: gate any dev-only widget/route/entry-point with `if (kIsDevTool)`.
const bool kIsDevTool = bool.fromEnvironment('JEEB_DEVTOOL');

/// True when dev-only affordances are permitted: the Dev Tool app, or any
/// debug build. NEVER true in a production-flavor release binary.
const bool kDevAffordancesAllowed = kIsDevTool || kDebugMode;

/// Hard assertion helper for code that must NEVER run in the shipped product.
/// Throws in a production release binary; no-ops in the Dev Tool / debug builds.
void assertDevToolOnly([String? context]) {
  if (!kDevAffordancesAllowed) {
    throw StateError(
      'Dev-only code path reached in a production build'
      '${context == null ? '' : ': $context'}',
    );
  }
}
