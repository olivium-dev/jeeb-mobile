import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app/jeeb_bootstrap.dart';
import 'core/dev_flags.dart';
import 'dev_tools/dev_tool_app.dart';
import 'devtool/devtool_shell.dart' as devtool;

/// Retained for the process lifetime so the semantics tree stays published for
/// Maestro/a11y. Flutter only publishes its accessibility/semantics tree while
/// a client holds a [SemanticsHandle]; storing it in this top-level field keeps
/// it from being garbage-collected (a bare `ensureSemantics()` call would be
/// eligible for GC, dropping the tree and breaking id-based assertions).
// ignore: unused_element
SemanticsHandle? _semanticsHandle;

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
  _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
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
  // Jeeber Dev Tool second-launcher path: the `.DevToolLauncher` activity-alias
  // makes MainActivity.getInitialRoute() return "/devtool", so
  // PlatformDispatcher's defaultRouteName is "/devtool" here. When the Dev Tool
  // is compiled in (dev/staging via --dart-define=JEEB_DEVTOOL_ENABLED=true),
  // boot the full-access Dev Tool shell instead of the product app. In a
  // production build kDevToolEnabled is a compile-time false, so the tree-shaker
  // strips this branch (and DevToolApp) entirely.
  if (kDevToolEnabled &&
      ui.PlatformDispatcher.instance.defaultRouteName == '/devtool') {
    runApp(const devtool.DevToolApp());
    return;
  }
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
