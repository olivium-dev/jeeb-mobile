import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

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

  runApp(const DevToolApp());
}
