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
    expect(script, contains('--dart-define=JEEB_OBS_OVERLAY=true'));
    expect(script, contains('--dart-define=JEEB_REALTIME_TRACKING=true'));
    expect(script, contains('--dart-define=REQUIRE_REAL_PUSH=true'));
    expect(script, contains('bash tool/run_with_dev_firebase_config.sh'));
    expect(script, isNot(contains(r'CLIENT=${CLIENT_SERIAL}')));
    expect(script, isNot(contains(r'installing on ${SERIAL}')));
    expect(script, isNot(contains('S24_SERIAL')));
    expect(script, isNot(contains('A33_SERIAL')));
    expect(script, isNot(contains('--dart-define=GATEWAY_BASE_URL=')));
    expect(script, isNot(contains('MAPS_API_KEY')));
    expect(script, isNot(contains('emulator-5554')));
    expect(script, isNot(contains('emulator-5556')));
  });

  test('defaults to the off-LAN MSI Cloudflare HTTPS and WSS routes', () {
    final script = MB1Source.raw('tool/run_msi_dual.sh');

    expect(
      script,
      contains(
        'MSI_GATEWAY="\${MSI_GATEWAY:-https://msi.olivium.space/gateway}"',
      ),
    );
    expect(
      script,
      contains(
        'MSI_REALTIME_SOCKET="\${MSI_REALTIME_SOCKET:-wss://msi.olivium.space/socket/websocket}"',
      ),
    );
    expect(script, contains('"\${MSI_GATEWAY}/health/ready"'));
    expect(script, isNot(contains('http://192.168.2.39:10090')));
    expect(script, isNot(contains('ws://192.168.2.39:5804')));
    expect(script, isNot(contains('d1000000-0000-4000-8000-000000000002')));
    expect(script, isNot(contains('(Karim)')));
    expect(script, contains('create/select a clean jeeber'));
  });

  test('defaults to the first two attached physical devices', () async {
    final result = await selectDevices('''List of devices attached
emulator-5554 device product:sdk_gphone model:sdk_gphone
physical-first device product:phone_one model:Phone_One
physical-second device product:phone_two model:Phone_Two
''');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(result.stdout, 'physical-first|physical-second');
  });

  test('recognizes wireless-adb serials as physical devices', () async {
    final result = await selectDevices('''List of devices attached
adb-RZCT505K7WF-vntvpc._adb-tls-connect._tcp device product:a33 model:SM_A336B
adb-RFCX306JSRT-4Wjs7F._adb-tls-connect._tcp device product:s24 model:SM_S921B
''');

    expect(result.exitCode, 0, reason: '${result.stderr}');
    expect(
      result.stdout,
      'adb-RZCT505K7WF-vntvpc._adb-tls-connect._tcp|'
      'adb-RFCX306JSRT-4Wjs7F._adb-tls-connect._tcp',
    );
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
physical-only device product:phone_one model:Phone_One
emulator-5554 device product:sdk_gphone model:sdk_gphone
''');

    expect(result.exitCode, isNot(0));
    expect(result.stderr, contains('No second physical device is available'));
  });
}
