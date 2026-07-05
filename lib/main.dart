import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app/jeeb_bootstrap.dart';
import 'dev_tools/dev_tool_app.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  // Force the semantics tree ON for the app's entire lifetime. Flutter only
  // publishes its accessibility/semantics tree when a client requests it (an
  // a11y service is active, or someone holds a SemanticsHandle). Maestro reads
  // the platform accessibility tree, so without this the tree is empty and
  // `maestro hierarchy` returns nodes with no text/identifier — making every
  // id-based assertion impossible. Holding this handle (never disposing it)
  // keeps semantics published so Maestro can see Semantics(identifier:) values.
  // Flutter 3.44.2: SemanticsBinding.instance.ensureSemantics() returns a
  // SemanticsHandle; we intentionally retain it for the process lifetime.
  SemanticsBinding.instance.ensureSemantics();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
    ),
  );
  runApp(const JeebBootstrap());
}

/// Second Dart entrypoint — the DEV-FLAVOR-ONLY "Jeeb Dev Tool" launcher.
///
/// Wired from `android/app/src/dev/kotlin/app/jeeb/mobile/DevToolActivity.kt`,
/// which overrides `getDartEntrypointFunctionName()` to return `"mainDevTool"`.
/// It MUST live in this file (the default entrypoint library, lib/main.dart):
/// the Flutter build only compiles code reachable from the `--target`
/// entrypoint, so a `mainDevTool` in an otherwise-unreferenced file is never
/// emitted into the kernel and the isolate fails with "Could not resolve main
/// entrypoint function". `@pragma('vm:entry-point')` additionally keeps it from
/// being tree-shaken in AOT (release) builds.
///
/// It intentionally does NOT run the app's Firebase/DI bootstrap
/// (JeebBootstrap): the tool is pure UI over mocked data, so it stays fast and
/// side-effect-free. Screens that resolve dependencies from GetIt rely on the
/// same empty `sl<>()` fallbacks the isolated screen tests rely on.
@pragma('vm:entry-point')
void mainDevTool() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const DevToolApp());
}
