import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/dev_flags.dart';
import 'devtool/devtool_shell.dart';

/// Entrypoint for the **Jeeber Dev Tool** — the second installable app built
/// from this same source tree.
///
/// Build:
///   flutter run   --flavor devtoolDev        --target lib/main_devtool.dart --dart-define=JEEB_DEVTOOL=true
///   flutter build apk --flavor devtoolProduction --target lib/main_devtool.dart --dart-define=JEEB_DEVTOOL=true
///
/// The real product keeps using `lib/main.dart` + the `app*` flavors, and the
/// tree-shaker strips everything behind [kIsDevTool] out of that binary.
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Same Maestro-visibility handle as the main app (see lib/main.dart): keep the
  // semantics tree published for the process lifetime so id-based assertions work.
  SemanticsBinding.instance.ensureSemantics();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  assert(
    kIsDevTool,
    'main_devtool.dart must be built with --dart-define=JEEB_DEVTOOL=true '
    '(and the devtool flavor). kIsDevTool was false.',
  );

  runApp(const DevToolApp());
}
