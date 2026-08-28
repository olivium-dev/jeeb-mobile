import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'mb1_source_lens.dart';

void main() {
  late Directory tempDirectory;
  late File fakeAdb;

  setUpAll(() async {
    tempDirectory = await Directory.systemTemp.createTemp('msi-launcher-test-');
    fakeAdb = File('${tempDirectory.path}/adb');
    await fakeAdb.writeAsString('''#!/usr/bin/env bash
if [[ "\${1:-}" == "devices" ]]; then
  printf '%s\n' "\${FAKE_ADB_OUTPUT:-}"
  exit 0
fi
exit 0
''');
    await Process.run('chmod', <String>['+x', fakeAdb.path]);
  });

  tearDownAll(() async {
    if (tempDirectory.existsSync()) {
      await tempDirectory.delete(recursive: true);
    }
  });

  Future<ProcessResult> selectDevices(
    String adbOutput, {
    String clientSerial = '',
    String jeeberSerial = '',
  }) {
    final script = '${MB1Source.repoRoot.path}/tool/run_msi_dual.sh';
    return Process.run(
      'bash',
      <String>[
        '-c',
        r'''source "$1"; select_devices; printf "%s|%s" "$CLIENT_SERIAL" "$JEEBER_SERIAL"''',
        '_',
        script,
      ],
      environment: <String, String>{
        'ADB': fakeAdb.path,
        'FAKE_ADB_OUTPUT': adbOutput,
        'CLIENT_SERIAL': clientSerial,
        'JEEBER_SERIAL': jeeberSerial,
      },
    );
  }

  test('MSI launcher passes the gateway defines read by the client', () {
    final script = MB1Source.stripComments(
      MB1Source.raw('tool/run_msi_dual.sh'),
    );

    expect(script, contains('--dart-define=USE_MOCK_GATEWAY=false'));
    expect(
      script,
      contains('--dart-define=JEEB_MOCK_BASE_URL="\${MSI_GATEWAY}"'),
    );
    expect(script, contains('--dart-define=JEEB_USE_MOCK_PREFIXES=false'));
    expect(script, contains('--dart-define=JEEB_DEVTOOL_ENABLED=true'));
    expect(
      script,
      contains('--android-project-arg=jeeb.devtool=true'),
      reason: 'the Android Dev Tool launcher activity must be enabled',
    );
    expect(script, contains('--dart-define=JEEB_REALTIME_TRACKING=true'));
    expect(script, isNot(contains('--dart-define=GATEWAY_BASE_URL=')));
    expect(script, isNot(contains('MAPS_API_KEY')));
    expect(script, isNot(contains('emulator-5554')));
    expect(script, isNot(contains('emulator-5556')));
  });

  test('defaults to attached physical S24 and A33 devices', () async {
    final result = await selectDevices('''List of devices attached
emulator-5554 device product:sdk_gphone model:sdk_gphone
RZCT505K7WF device product:a33 model:SM-A336B
RFCX306JSRT device product:s24 model:SM-S921B
''');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, 'RFCX306JSRT|RZCT505K7WF');
  });

  test('preserves explicit attached serial overrides', () async {
    final result = await selectDevices(
      '''List of devices attached
emulator-client device product:sdk_gphone model:sdk_gphone
emulator-jeeber device product:sdk_gphone model:sdk_gphone
''',
      clientSerial: 'emulator-client',
      jeeberSerial: 'emulator-jeeber',
    );

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, 'emulator-client|emulator-jeeber');
  });

  test('falls back to any two attached non-emulator devices', () async {
    final result = await selectDevices('''List of devices attached
physical-one device product:phone_one model:Phone_One
emulator-5554 device product:sdk_gphone model:sdk_gphone
physical-two device product:phone_two model:Phone_Two
''');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, 'physical-one|physical-two');
  });

  test('fails clearly when a second physical device is unavailable', () async {
    final result = await selectDevices('''List of devices attached
RFCX306JSRT device product:s24 model:SM-S921B
emulator-5554 device product:sdk_gphone model:sdk_gphone
''');

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('No second physical device is available'));
  });
}
