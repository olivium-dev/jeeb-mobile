import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/observability/session_trace/session_trace.dart';
import 'devtool/devtool_shell.dart';

/// Convenience entrypoint to run the **Jeeber Dev Tool** directly during
/// development, without going through the launcher-icon (`.DevToolLauncher`
/// activity-alias) path:
///
///   flutter run --flavor dev --target lib/main_devtool.dart --dart-define=JEEB_DEVTOOL_ENABLED=true
///
/// On a real device the Dev Tool is normally opened via its own launcher icon
/// (same app, same applicationId, full access) — see `lib/main.dart`, which
/// boots [DevToolApp] when the `.DevToolLauncher` alias supplies the `/devtool`
/// initial route. This entrypoint is just a faster inner-loop shortcut.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Same Maestro-visibility handle as the main app (see lib/main.dart): keep the
  // semantics tree published for the process lifetime so id-based assertions work.
  SemanticsBinding.instance.ensureSemantics();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Session-trace observability tool (devtool-only inner-loop default): THIS
  // dedicated fast-inner-loop entrypoint starts a recording session by
  // default, so `flutter run --target lib/main_devtool.dart
  // --dart-define=JEEB_DEVTOOL_ENABLED=true` traces from the first frame
  // without a manual tap on the overlay's Start control. The on-device
  // `.DevToolLauncher` path (reached via `lib/main.dart`, untouched by this
  // block) does NOT get this auto-start — recording there stays strictly
  // opt-in via the overlay, exactly like every other devtool affordance.
  // Fire-and-forget + fail-soft (`Observability.install` never throws) and a
  // hard no-op in a production build (`kObsCompiledIn` is compile-time
  // `false`, so this whole branch is tree-shaken out).
  if (kObsCompiledIn) {
    ObservabilityConfig.instance.enableAll();
    unawaited(Observability.instance.install(role: 'devtool'));
  }

  runApp(const DevToolApp());
}
