import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app/jeeb_bootstrap.dart';
import 'core/dev_flags.dart';
import 'core/theme/app_theme.dart';
import 'devtool/devtool_shell.dart' as devtool;

// ignore: unused_element
SemanticsHandle? _semanticsHandle;

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
  // Belt for the native Android manifest lock (iOS plist lock is parked).
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  // Also set in `appBarTheme`; this one covers the first frame, before any
  // AppBar exists.
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
  if (shouldLaunchDevTool(
    enabled: kDevToolEnabled,
    initialRoute: ui.PlatformDispatcher.instance.defaultRouteName,
  )) {
    runApp(const devtool.DevToolApp());
    return;
  }
  runApp(const JeebBootstrap());
}
