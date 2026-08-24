// Guards the protected Firebase config invariants documented in
// docs/firebase-invariants.md.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _prodConfig = 'android/app/google-services.json';
const _devConfig = 'android/app/src/dev/google-services.json';
const _iosConfig = 'ios/Runner/GoogleService-Info.plist';
const _prodTemplate = 'android/app/google-services.json.template';
const _devTemplate = 'android/app/src/dev/google-services.json.template';
const _iosTemplate = 'ios/Runner/GoogleService-Info.plist.template';
const _protectedConfigs = <String>[_prodConfig, _devConfig, _iosConfig];
const _templates = <String>[_prodTemplate, _devTemplate, _iosTemplate];

const _expectedProjectId = 'jeeb-5a293';
const _forbiddenProject = 'alrahmah';

Future<bool> _isTracked(String path) async {
  final result = await Process.run('git', <String>[
    'ls-files',
    '--error-unmatch',
    path,
  ]);
  return result.exitCode == 0;
}

/// `--no-index` also evaluates tracked paths, so this test cannot pass merely
/// because a future change accidentally commits one of the protected files.
Future<bool> _isIgnored(String path) async {
  final result = await Process.run('git', <String>[
    'check-ignore',
    '--no-index',
    '--quiet',
    path,
  ]);
  return result.exitCode == 0;
}

Map<String, String> _syntheticDevEnvironment() {
  const projectNumber = '123456789012';
  const projectId = 'jeeb-test';
  const appId = '1:123456789012:android:abcdef0123456789';
  final apiKey = 'AIza${List<String>.filled(35, 'A').join()}';
  final config = <String, Object>{
    'project_info': <String, String>{
      'project_number': projectNumber,
      'project_id': projectId,
      'storage_bucket': '$projectId.appspot.com',
    },
    'client': <Object>[
      <String, Object>{
        'client_info': <String, Object>{
          'mobilesdk_app_id': appId,
          'android_client_info': <String, String>{
            'package_name': 'app.jeeb.mobile.dev',
          },
        },
        'oauth_client': <Object>[],
        'api_key': <Object>[
          <String, String>{'current_key': apiKey},
        ],
        'services': <String, Object>{},
      },
    ],
    'configuration_version': '1',
  };
  return <String, String>{
    'DEV_GOOGLE_SERVICES_JSON_B64': base64Encode(
      utf8.encode(jsonEncode(config)),
    ),
    'DEV_FIREBASE_EXPECTED_PROJECT_NUMBER': projectNumber,
    'DEV_FIREBASE_EXPECTED_PROJECT_ID': projectId,
    'DEV_FIREBASE_EXPECTED_APP_ID': appId,
  };
}

void main() {
  for (final path in _protectedConfigs) {
    test('$path remains an absent, untracked, ignored build input', () async {
      expect(
        await _isTracked(path),
        isFalse,
        reason:
            '$path is injected only through a protected build wrapper and '
            'must never be committed.',
      );
      expect(
        await _isIgnored(path),
        isTrue,
        reason: '$path must stay ignored so a transient injection cannot land.',
      );
      expect(
        File(path).existsSync(),
        isFalse,
        reason:
            '$path remained after a local build; the protected wrapper cleanup '
            'must remove it even when the wrapped command fails.',
      );
    });
  }

  test(
    'templates exist, retain TODO placeholders, and contain no private key',
    () {
      for (final path in _templates) {
        expect(File(path).existsSync(), isTrue, reason: '$path is missing.');
        final raw = File(path).readAsStringSync();
        expect(raw, contains('TODO_'));
        expect(raw, isNot(contains('private_key')));
        expect(raw, isNot(contains('private_key_id')));
        expect(raw.toLowerCase(), isNot(contains(_forbiddenProject)));
      }
    },
  );

  test('production Android template uses canonical store identity', () {
    final raw = File(_prodTemplate).readAsStringSync();
    expect(raw, contains('"package_name": "com.olivium.jeeb"'));
    expect(raw, isNot(contains('"package_name": "app.jeeb.mobile"')));
  });

  test('.firebaserc pins the one existing Firebase project', () {
    final firebaserc = File('.firebaserc');
    expect(firebaserc.existsSync(), isTrue);
    final raw = firebaserc.readAsStringSync();
    expect(raw, contains('"$_expectedProjectId"'));
    expect(raw.toLowerCase(), isNot(contains(_forbiddenProject)));
  });

  test('protected injection wrappers and invariant documentation exist', () {
    for (final path in const <String>[
      'tool/run_with_android_firebase_config.sh',
      'tool/run_with_dev_firebase_config.sh',
      'tool/run_with_ios_firebase_config.sh',
      'docs/firebase-invariants.md',
    ]) {
      expect(File(path).existsSync(), isTrue, reason: '$path is missing.');
    }
  });

  test(
    'dev wrapper validates, exposes transiently, and always cleans up',
    () async {
      final target = File(_devConfig);
      expect(target.existsSync(), isFalse);

      final success = await Process.run('bash', <String>[
        'tool/run_with_dev_firebase_config.sh',
        'bash',
        '-c',
        'test -f android/app/src/dev/google-services.json',
      ], environment: _syntheticDevEnvironment());
      expect(
        success.exitCode,
        0,
        reason: '${success.stdout}\n${success.stderr}',
      );
      expect(
        target.existsSync(),
        isFalse,
        reason: 'success cleanup did not run',
      );

      final failure = await Process.run('bash', <String>[
        'tool/run_with_dev_firebase_config.sh',
        'bash',
        '-c',
        'exit 17',
      ], environment: _syntheticDevEnvironment());
      expect(failure.exitCode, 17);
      expect(
        target.existsSync(),
        isFalse,
        reason: 'failure cleanup did not run',
      );
    },
  );
}
