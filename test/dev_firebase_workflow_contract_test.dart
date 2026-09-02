import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// CI must keep the Firebase gates and use the fail-closed protected injection
// wrapper rather than materializing a persistent client config itself.

const _analyzeGate = 'dart analyze --fatal-infos .';
const _testGate = 'flutter test --exclude-tags capture';
const _pinGate = 'bash tool/check_firebase_core_pin.sh';
const _protectedInjectionSecret = 'DEV_GOOGLE_SERVICES_JSON_B64';
const _protectedInjectionWrapper = 'tool/run_with_dev_firebase_config.sh';
const _rawConfigRedirect = '> android/app/src/dev/google-services.json';

/// Extracts the top-level `on:` YAML mapping so the pull_request check
/// inspects the trigger block, not an arbitrary substring in the file.
String _onTriggerBlock(String workflow) {
  final lines = workflow.split('\n');
  final startIndex = lines.indexWhere((line) => line.startsWith('on:'));
  if (startIndex == -1) return '';
  final blockLines = <String>[lines[startIndex]];
  for (final line in lines.skip(startIndex + 1)) {
    final isIndentedOrBlank = line.startsWith(' ') || line.trim().isEmpty;
    if (!isIndentedOrBlank) break;
    blockLines.add(line);
  }
  return blockLines.join('\n');
}

void main() {
  group('workflow re-enable readiness (Phase P depends on these surviving)', () {
    test(
      'Flutter stage and coverage lane keep strict analyze + test gates',
      () {
        for (final path in const <String>[
          '.github/workflows/ci-flutter-stage.yml',
          '.github/workflows/flutter-ci.yml',
        ]) {
          final workflow = File(path).readAsStringSync();
          expect(
            workflow,
            contains(_analyzeGate),
            reason:
                '$path must keep --fatal-infos analyze strictness so '
                'Phase P does not silently re-enable a looser gate',
          );
          expect(
            workflow,
            contains(_testGate),
            reason:
                '$path must keep excluding the host-rendered capture-tag '
                'goldens while still running the rest of the suite',
          );
        }
      },
    );

    test(
      'Flutter, Android, coverage, and mobile stages keep the pin gate',
      () {
        for (final path in const <String>[
          '.github/workflows/ci-flutter-stage.yml',
          '.github/workflows/ci-android-stage.yml',
          '.github/workflows/flutter-ci.yml',
          '.github/workflows/mobile-ci.yml',
        ]) {
          final workflow = File(path).readAsStringSync();
          expect(
            workflow,
            contains(_pinGate),
            reason:
                '$path must invoke tool/check_firebase_core_pin.sh — this '
                'is the one gate the whole P0.4 investigation exists to '
                'protect and must not silently disappear',
          );
        }
      },
    );

    test(
      'Android stage and coverage lane use the protected dev config wrapper',
      () {
        for (final path in const <String>[
          '.github/workflows/ci-android-stage.yml',
          '.github/workflows/flutter-ci.yml',
        ]) {
          final workflow = File(path).readAsStringSync();
          expect(
            workflow,
            contains(_protectedInjectionSecret),
            reason:
                '$path must receive the protected dev Firebase payload only '
                'for the main-branch hardware build.',
          );
          expect(
            workflow,
            contains(_protectedInjectionWrapper),
            reason:
                '$path must build through $_protectedInjectionWrapper so the '
                'validated 0600 file is removed on success and failure.',
          );
          expect(
            workflow,
            isNot(contains(_rawConfigRedirect)),
            reason:
                '$path must not write the protected config directly; direct '
                'redirection bypasses validation, permissions, and cleanup.',
          );
        }
      },
    );

    test(
      'top-level workflows still gate pull requests, not just main pushes',
      () {
        for (final path in const <String>[
          '.github/workflows/ci.yml',
          '.github/workflows/flutter-ci.yml',
          '.github/workflows/mobile-ci.yml',
        ]) {
          final workflow = File(path).readAsStringSync();
          final onBlock = _onTriggerBlock(workflow);
          expect(
            onBlock,
            contains('pull_request:'),
            reason:
                '$path must still declare a pull_request trigger so that '
                'when Phase P re-enables it, PRs are gated too — not just '
                'pushes to main',
          );
        }
      },
    );
  });
}
