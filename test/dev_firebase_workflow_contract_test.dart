import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _trustedEvent =
    "github.event_name == 'push' && github.ref == 'refs/heads/main'";
const _forkPullRequest = "github.event_name == 'pull_request'";
const _identityInputs = <String>[
  'DEV_FIREBASE_EXPECTED_PROJECT_NUMBER',
  'DEV_FIREBASE_EXPECTED_PROJECT_ID',
  'DEV_FIREBASE_EXPECTED_APP_ID',
];

int _count(String source, String value) =>
    RegExp(RegExp.escape(value)).allMatches(source).length;

void main() {
  for (final path in const <String>[
    '.github/workflows/ci.yml',
    '.github/workflows/flutter-ci.yml',
  ]) {
    test(
      '$path keeps fork PR quality gates while safely skipping FCM build',
      () {
        final workflow = File(path).readAsStringSync();
        expect(workflow, contains('dart analyze --fatal-infos .'));
        expect(workflow, contains('flutter test'));
        expect(workflow, contains(_trustedEvent));
        expect(workflow, contains(_forkPullRequest));
        expect(workflow, contains('Skip dev FCM APK for fork PR'));
        expect(workflow, isNot(contains('google-services.json.template >')));
        final trustedGateCount = path.endsWith('flutter-ci.yml') ? 2 : 1;
        expect(
          _count(workflow, _trustedEvent),
          greaterThanOrEqualTo(trustedGateCount),
        );
        final skipStart = workflow.indexOf('Skip dev FCM APK for fork PR');
        final skipStep = workflow.substring(skipStart).split('\n\n').first;
        expect(skipStep, isNot(contains('secrets.')));
      },
    );

    test('$path protects config identity inputs and strict dev build', () {
      final workflow = File(path).readAsStringSync();
      expect(workflow, contains('DEV_GOOGLE_SERVICES_JSON_B64'));
      for (final input in _identityInputs) {
        expect(workflow, contains(input));
      }
      expect(workflow, contains('bash tool/validate_dev_google_services.sh'));
      expect(workflow, contains('--dart-define=REQUIRE_REAL_PUSH=true'));
    });
  }
}
