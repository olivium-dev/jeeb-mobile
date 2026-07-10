import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app/jeeb_bootstrap.dart';
import 'core/dev_flags.dart';
import 'devtool/devtool_shell.dart';

/// Retains the [SemanticsHandle] for the process lifetime so the semantics tree
/// stays published (Maestro reads the platform a11y tree). A top-level field
/// keeps it from being GC'd — a local in [main] would be collected after main
/// returns, silently turning semantics back off (observed as an empty a11y tree
/// in the Dev Tool). See main() below.
// ignore: unused_element
SemanticsHandle? _semanticsRetainer;

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
  _semanticsRetainer = SemanticsBinding.instance.ensureSemantics();
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

  // Two launcher icons, one app: the Dev Tool icon (`.DevToolLauncher` alias)
  // hands us the `/devtool` initial route (MainActivity.getInitialRoute()). In a
  // dev-tool-enabled build we boot the Dev Tool; otherwise (and always in
  // production, where kDevToolEnabled is const-false and this branch is
  // tree-shaken) we boot the normal Jeeb app.
  if (kDevToolEnabled &&
      ui.PlatformDispatcher.instance.defaultRouteName == '/devtool') {
    runApp(const DevToolApp());
    return;
  }

  runApp(const JeebBootstrap());
}
