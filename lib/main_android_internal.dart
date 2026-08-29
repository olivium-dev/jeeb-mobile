import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter/services.dart';

import 'app/jeeb_bootstrap.dart';
import 'core/config/internal_release_policy.dart';
import 'core/theme/app_theme.dart';
import 'internal_devtool/internal_release_blocked_app.dart';
import 'internal_devtool/native_internal_release_policy.dart';

// ignore: unused_element
SemanticsHandle? _semanticsHandle;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  _semanticsHandle = SemanticsBinding.instance.ensureSemantics();
  await _configureSystemUi();
  final route = PlatformDispatcher.instance.defaultRouteName;
  final native = await _readNativePolicy();
  final failure = InternalReleasePolicy.evaluate(
    InternalReleasePolicy.current(native),
  );
  runApp(_rootForPolicy(route: route, native: native, failure: failure));
}

Future<void> _configureSystemUi() async {
  await SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(AppTheme.systemOverlayStyle);
}

Future<NativeInternalReleasePolicy> _readNativePolicy() async {
  try {
    return await NativeInternalReleasePolicyReader.read();
  } on Object {
    return const NativeInternalReleasePolicy(
      releaseBuild: false,
      internalFlavor: false,
      internalResource: false,
      dedicatedLauncher: false,
    );
  }
}

Widget _rootForPolicy({
  required String route,
  required NativeInternalReleasePolicy native,
  required InternalReleasePolicyFailure failure,
}) {
  if (failure != InternalReleasePolicyFailure.none) {
    return const InternalReleaseBlockedApp();
  }
  if (route == '/devtool' &&
      !shouldLaunchInternalDevTool(
        initialRoute: route,
        failure: failure,
        native: native,
      )) {
    return const InternalReleaseBlockedApp();
  }
  return buildJeebRootForInitialRoute(route);
}
