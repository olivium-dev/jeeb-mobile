import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  const scriptPath = 'tool/verify_android_devtool_launcher.sh';
  const productFlowPath = '.maestro/contracts/devtool-launcher/product.yaml';
  const devToolFlowPath = '.maestro/contracts/devtool-launcher/devtool.yaml';

  test('device contract uses one APK and explicit serial-scoped launches', () {
    final script = File(scriptPath).readAsStringSync();

    expect(script, contains('SERIAL="\$1"'));
    expect(script, contains('APK="\$2"'));
    expect('install -r -d'.allMatches(script), hasLength(1));
    expect(script, contains('com.olivium.jeeb.MainActivity'));
    expect(script, contains('com.olivium.jeeb.LegacyDevToolLauncher'));
    expect(script, contains('01-product'));
    expect(script, contains('02-devtool'));
    expect(script, contains('03-product-repeat'));
    expect(script, contains('04-devtool-repeat'));
    expect(script, contains('foreground.txt'));
    expect(script, contains('--device "\${SERIAL}"'));
    expect(script, contains('-s "\${SERIAL}" get-state'));
    expect(script, isNot(contains('"\${ADB}" devices')));
    expect(
      script.indexOf('run_maestro "\${phase}" "\${flow}"'),
      lessThan(script.indexOf('wait_for_foreground "\${component}"')),
      reason: 'Maestro must dismiss an Android permission overlay first',
    );
  });

  test('device contract preserves state and exposes no route shortcut', () {
    final source = <String>[
      File(scriptPath).readAsStringSync(),
      File(productFlowPath).readAsStringSync(),
      File(devToolFlowPath).readAsStringSync(),
    ].join('\n');

    for (final forbidden in <String>[
      'pm clear',
      'uninstall',
      'clearState',
      'main_devtool.dart',
      'jeeb.route',
      'arguments:',
      'point:',
      'index:',
    ]) {
      expect(source, isNot(contains(forbidden)), reason: forbidden);
    }
  });

  test('Maestro flows use semantic product and Dev Tool assertions', () {
    final product = File(productFlowPath).readAsStringSync();
    final devTool = File(devToolFlowPath).readAsStringSync();

    expect(product, contains('extendedWaitUntil:'));
    expect(product, contains('id:'));
    expect(product, contains('assertNotVisible:'));
    expect(product, contains('text: "Jeeber Dev Tool"'));
    expect(devTool, contains('extendedWaitUntil:'));
    expect(devTool, contains('assertVisible:'));
    expect(devTool, contains('text: "Jeeber Dev Tool"'));
    expect(product, contains('tapOn:'));
    expect(product, contains('text: "Allow"'));
    expect(product, contains('optional: true'));
    expect(product, isNot(contains('point:')));
    expect(devTool, isNot(contains('tapOn:')));
  });
}
