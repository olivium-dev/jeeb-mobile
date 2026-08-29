import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('internal launcher routes to the original full Dev Tool host', () {
    final entrypoint = File(
      'lib/main_android_internal.dart',
    ).readAsStringSync();

    expect(entrypoint, contains('buildJeebRootForInitialRoute(route)'));
    expect(entrypoint, contains("route == '/devtool'"));
    expect(entrypoint, contains('shouldLaunchInternalDevTool('));
    expect(entrypoint, isNot(contains('InternalDevToolApp')));
    expect(
      File('lib/internal_devtool/internal_devtool_app.dart').existsSync(),
      isFalse,
      reason: 'the status-only replacement surface must stay removed',
    );
  });

  test('the full menu and its launcher controls remain intact', () {
    final shell = File('lib/devtool/devtool_shell.dart').readAsStringSync();
    final app = File('lib/app/app.dart').readAsStringSync();
    final host = File(
      'lib/devtool/shake/devtool_shake.dart',
    ).readAsStringSync();

    for (final capability in _fullDevToolCapabilities) {
      expect(shell, contains(capability), reason: capability);
    }
    expect(host, contains("label: const Text('Apply & Restart')"));
    expect(
      host,
      contains("semanticLabel: 'Close Dev Tool without restarting'"),
    );
    expect(
      app,
      isNot(contains('ObsOverlayHost')),
      reason: 'session logging must not add a floating product overlay',
    );
    expect(
      shell,
      isNot(contains('ObsOverlayHost')),
      reason: 'the Dev Tool must use its normal Session Logs page',
    );
  });

  test('the ordinary product entrypoint remains free of internal routing', () {
    final product = File('lib/main.dart').readAsStringSync();
    expect(product, isNot(contains('main_android_internal')));
    expect(product, isNot(contains('InternalReleasePolicy')));
    expect(product, isNot(contains('InternalReleaseBlockedApp')));
  });
}

const _fullDevToolCapabilities = <String>[
  "'Jeeber Dev Tool'",
  "'Super Login'",
  "'Screen Catalog'",
  "'Actions'",
  "'Location Simulator'",
  "'Session Logs'",
  "'Server URL'",
  "'Clear Local Data'",
  "'Scenario Users'",
];
