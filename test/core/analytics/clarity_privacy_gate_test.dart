import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Clarity privacy invariants remain structurally enforced', () {
    final dartFiles = Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((file) => file.path.endsWith('.dart'))
        .toList();
    const adapterPath =
        'lib/core/analytics/clarity/data/microsoft_clarity_adapter.dart';

    for (final file in dartFiles) {
      final source = file.readAsStringSync();
      expect(source, isNot(contains('ClarityUnmask')), reason: file.path);
      expect(source, isNot(contains('setCustomUserId')), reason: file.path);
      expect(source, isNot(contains('setCustomSessionId')), reason: file.path);
      expect(source, isNot(contains('setCustomTag')), reason: file.path);
      expect(source, isNot(contains('sendCustomEvent')), reason: file.path);
      if (!file.path.endsWith(adapterPath)) {
        expect(source, isNot(contains('Clarity.')), reason: file.path);
      }
    }

    final adapter = File(adapterPath).readAsStringSync();
    expect(
      adapter,
      contains(
        'Clarity.setOnSessionStartedCallback((_) => onSessionStarted())',
      ),
    );
    expect(adapter, isNot(contains('sessionId')));
    expect(adapter, isNot(contains('userId:')));
    expect(adapter, isNot(contains('.userId')));
    expect(adapter, contains('logLevel: LogLevel.None'));
  });

  test('product root is masked and the devtool remains outside Clarity', () {
    final app = File('lib/app/app.dart').readAsStringSync();
    final bootstrap = File('lib/app/jeeb_bootstrap.dart').readAsStringSync();
    final devtool = File('lib/devtool/devtool_shell.dart').readAsStringSync();
    expect(
      app,
      contains('final maskedProduct = ClarityMask(child: productUi);'),
    );
    expect(app, contains('if (!_clarity.shouldMountSdkWidget) return child!;'));
    expect(app, contains('return ClarityWidget('));
    expect(app, contains('PushBannerHost('));
    expect(bootstrap, contains('return ClarityMask('));
    expect(bootstrap, contains('child: Stack('));
    expect(devtool, isNot(contains('ClarityMask')));
    expect(devtool, isNot(contains('ClarityWidget')));
    expect(devtool, isNot(contains('clarity_flutter')));
  });
}
