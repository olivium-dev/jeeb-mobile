import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/dev_flags.dart';
import 'core/observability/session_trace/session_trace.dart';
import 'devtool/devtool_shell.dart';

void main() async {
  if (!kDevToolEnabled) {
    throw StateError(
      'main_devtool.dart requires a debug build with '
      'JEEB_DEVTOOL_ENABLED=true',
    );
  }
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  // Hygiene only: same native activity/Info.plist as main.dart already locks.
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Session-trace observability tool (devtool-only inner-loop default): THIS
  if (kObsCompiledIn) {
    ObservabilityConfig.instance.enableAll();
    unawaited(Observability.instance.install(role: 'devtool'));
  }

  runApp(const DevToolApp());
}
