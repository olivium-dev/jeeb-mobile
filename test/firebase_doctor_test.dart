// Runs tool/firebase_doctor.sh on every `flutter test` so the static Firebase
// chain is checked automatically. See docs/firebase-invariants.md §4.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Repo root, found by walking up to `pubspec.yaml` so this works from any
/// cwd the test runner happens to use.
Directory _repoRoot() {
  var dir = Directory.current;
  while (!File('${dir.path}/pubspec.yaml').existsSync()) {
    final parent = dir.parent;
    if (parent.path == dir.path) {
      fail('could not locate the repo root from ${Directory.current.path}');
    }
    dir = parent;
  }
  return dir;
}

Future<bool> _bashAvailable() async {
  try {
    final result = await Process.run('bash', <String>['-c', 'exit 0']);
    return result.exitCode == 0;
  } catch (_) {
    return false;
  }
}

void main() {
  test('tool/firebase_doctor.sh passes the whole static Firebase chain', () async {
    if (!await _bashAvailable()) {
      markTestSkipped('bash is not available on this machine');
      return;
    }

    final repoRoot = _repoRoot();
    final script = File('${repoRoot.path}/tool/firebase_doctor.sh');
    expect(
      script.existsSync(),
      isTrue,
      reason: 'tool/firebase_doctor.sh is missing from $repoRoot',
    );

    final result = await Process.run(
      'bash',
      <String>[script.path],
      workingDirectory: repoRoot.path,
    );

    expect(
      result.exitCode,
      0,
      reason:
          'firebase_doctor.sh exited ${result.exitCode}.\n'
          '--- stdout ---\n${result.stdout}\n'
          '--- stderr ---\n${result.stderr}',
    );
  });
}
