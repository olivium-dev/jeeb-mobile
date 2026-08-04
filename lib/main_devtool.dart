import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'core/observability/session_trace/session_trace.dart';
import 'devtool/devtool_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SemanticsBinding.instance.ensureSemantics();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);

  // Session-trace observability tool (devtool-only inner-loop default): THIS
  if (kObsCompiledIn) {
    ObservabilityConfig.instance.enableAll();
    unawaited(Observability.instance.install(role: 'devtool'));
  }

  runApp(const DevToolApp());
}
