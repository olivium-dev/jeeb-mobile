import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app/jeeb_bootstrap.dart';
import 'core/dev_flags.dart';
import 'devtool/devtool_shell.dart' as devtool;

// ignore: unused_element
SemanticsHandle? _semanticsHandle;

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
  if (kDevToolEnabled &&
      ui.PlatformDispatcher.instance.defaultRouteName == '/devtool') {
    runApp(const devtool.DevToolApp());
    return;
  }
  runApp(const JeebBootstrap());
}
