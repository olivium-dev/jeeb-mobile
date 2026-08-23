import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

// The disabled workflows must keep the gates a Phase-P re-enable depends on,
// and must not resurrect the dead base64 dev-config injection design.

const _analyzeGate = 'dart analyze --fatal-infos .';
const _testGate = 'flutter test --exclude-tags capture';
const _pinGate = 'bash tool/check_firebase_core_pin.sh';
const _deadInjectionSecret = 'DEV_GOOGLE_SERVICES_JSON_B64';

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
      'ci.yml and flutter-ci.yml keep the strict analyze + capture-excluded test gates',
      () {
        for (final path in const <String>[
          '.github/workflows/ci.yml',
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
      'ci.yml, flutter-ci.yml, and mobile-ci.yml keep the firebase_core pin gate',
      () {
        for (final path in const <String>[
          '.github/workflows/ci.yml',
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
      'ci.yml and flutter-ci.yml do not resurrect the dead base64 dev-config injection design',
      () {
        for (final path in const <String>[
          '.github/workflows/ci.yml',
          '.github/workflows/flutter-ci.yml',
        ]) {
          final workflow = File(path).readAsStringSync();
          expect(
            workflow,
            isNot(contains(_deadInjectionSecret)),
            reason:
                '$path must not reintroduce $_deadInjectionSecret — that '
                'injection path was never implemented and the validator it '
                'would feed is unusable without it (see p0-gate-truth.md)',
          );
        }
      },
    );

    test(
      'ci.yml, flutter-ci.yml, and mobile-ci.yml still gate pull_request, not just push to main',
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
