// Guards the Firebase config-integrity invariants documented in
// docs/firebase-invariants.md.

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _prodConfig = 'android/app/google-services.json';
const _devConfig = 'android/app/src/dev/google-services.json';
const _prodTemplate = 'android/app/google-services.json.template';
const _devTemplate = 'android/app/src/dev/google-services.json.template';
const _iosTemplate = 'ios/Runner/GoogleService-Info.plist.template';
const _realConfigs = <String>[_prodConfig, _devConfig];
const _templates = <String>[_prodTemplate, _devTemplate];

const _expectedProjectId = 'jeeb-5a293';
const _expectedProjectNumber = '1051234312170';
const _forbiddenProject = 'alrahmah';

Future<bool> _isTracked(String path) async {
  final result = await Process.run('git', <String>[
    'ls-files',
    '--error-unmatch',
    path,
  ]);
  return result.exitCode == 0;
}

Future<bool> _isIgnored(String path) async {
  final result = await Process.run('git', <String>[
    'check-ignore',
    '--quiet',
    path,
  ]);
  return result.exitCode == 0;
}

Map<String, dynamic> _readJson(String path) =>
    jsonDecode(File(path).readAsStringSync()) as Map<String, dynamic>;

List<dynamic> _clients(Map<String, dynamic> config) =>
    config['client'] as List<dynamic>;

Set<String> _packageNames(Map<String, dynamic> config) => _clients(config)
    .map((client) => client as Map<String, dynamic>)
    .map((client) => client['client_info'] as Map<String, dynamic>)
    .map(
      (info) => (info['android_client_info'] as Map<String, dynamic>)['package_name']
          as String,
    )
    .toSet();

void main() {
  for (final path in _realConfigs) {
    test('$path is tracked in git and not gitignored', () async {
      expect(
        await _isTracked(path),
        isTrue,
        reason:
            '$path must be a committed (real, not gitignored) Firebase '
            'config — F2 requires the real dev+prod configs to live in VCS.',
      );
      expect(
        await _isIgnored(path),
        isFalse,
        reason:
            '$path matched a .gitignore rule; remove the stale ignore entry '
            'so the real config stays tracked.',
      );
    });
  }

  for (final path in _realConfigs) {
    test('$path targets Firebase project jeeb-5a293 / 1051234312170', () {
      final projectInfo =
          _readJson(path)['project_info'] as Map<String, dynamic>;
      expect(
        projectInfo['project_id'],
        _expectedProjectId,
        reason:
            '$path must point at the ONLY allowed Firebase project '
            '($_expectedProjectId); a different project_id means push/chat '
            'will silently target the wrong Firebase app.',
      );
      expect(
        projectInfo['project_number'],
        _expectedProjectNumber,
        reason:
            '$path project_number must match $_expectedProjectNumber '
            '(the jeeb-5a293 project number).',
      );
    });
  }

  test(
    'dev config has client entries for both app.jeeb.mobile.dev and app.jeeb.mobile',
    () {
      final devPackages = _packageNames(_readJson(_devConfig));
      expect(
        devPackages,
        contains('app.jeeb.mobile.dev'),
        reason:
            '$_devConfig must configure the dev applicationId so the dev '
            'build variant can register for FCM.',
      );
      expect(
        devPackages,
        contains('app.jeeb.mobile'),
        reason:
            '$_devConfig must also cover app.jeeb.mobile so dev builds that '
            'use the prod applicationId still resolve.',
      );
    },
  );

  test('prod config covers app.jeeb.mobile', () {
    expect(
      _packageNames(_readJson(_prodConfig)),
      contains('app.jeeb.mobile'),
      reason: '$_prodConfig must configure the release applicationId.',
    );
  });

  test('every client entry in both real configs has a non-empty api_key', () {
    for (final path in _realConfigs) {
      for (final client in _clients(_readJson(path))) {
        final apiKeys =
            (client as Map<String, dynamic>)['api_key'] as List<dynamic>;
        expect(
          apiKeys,
          isNotEmpty,
          reason:
              '$path: every client entry needs an api_key, else FCM '
              'registration fails at runtime with no build-time signal.',
        );
        for (final key in apiKeys) {
          final currentKey = (key as Map<String, dynamic>)['current_key'];
          expect(
            currentKey is String && currentKey.isNotEmpty,
            isTrue,
            reason: '$path: api_key.current_key must be a non-empty string.',
          );
        }
      }
    }
  });

  test('real configs contain no TODO_ sentinel (they are real, not templates)', () {
    for (final path in _realConfigs) {
      expect(
        File(path).readAsStringSync(),
        isNot(contains('TODO_')),
        reason:
            '$path is the REAL injected config; a TODO_ sentinel means the '
            'template was committed in its place.',
      );
    }
  });

  test(
    'real configs contain no private_key (service-account keys must never land in VCS)',
    () {
      for (final path in _realConfigs) {
        expect(
          File(path).readAsStringSync(),
          isNot(contains('private_key')),
          reason:
              '$path must never carry a service-account private_key — that '
              'is a different (and far more sensitive) credential than an '
              'Android client api_key.',
        );
      }
    },
  );

  test(
    'templates still exist, still hold TODO_ placeholders, and carry no private_key',
    () {
      for (final path in _templates) {
        expect(
          File(path).existsSync(),
          isTrue,
          reason:
              '$path documents how to regenerate the real config on a '
              'fresh clone; deleting it breaks onboarding.',
        );
        final raw = File(path).readAsStringSync();
        expect(
          raw,
          contains('TODO_'),
          reason:
              '$path must stay a placeholder template, never a real key.',
        );
        expect(raw, isNot(contains('private_key')));
        expect(raw, isNot(contains('private_key_id')));
      }
    },
  );

  test(
    'no tracked Firebase config or template references the forbidden alrahmah project',
    () {
      for (final path in <String>[..._realConfigs, ..._templates, _iosTemplate]) {
        expect(
          File(path).readAsStringSync().toLowerCase(),
          isNot(contains(_forbiddenProject)),
          reason:
              '$path references "$_forbiddenProject" — the ONLY allowed '
              'Firebase project is $_expectedProjectId '
              '($_expectedProjectNumber); alrahmah-d7a33 is forbidden.',
        );
      }
    },
  );

  test('docs/firebase-invariants.md exists', () {
    expect(
      File('docs/firebase-invariants.md').existsSync(),
      isTrue,
      reason:
          'docs/firebase-invariants.md is the prose companion to this '
          'guard test and must exist.',
    );
  });
}
