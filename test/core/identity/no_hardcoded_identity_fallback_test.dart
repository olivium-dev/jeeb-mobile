// S0-OAD-03 / S0-CHAT-05 anti-drift guardrail.
//
// The live run breaks the instant a real request, chat, or list carries a
// hardcoded FIXTURE identity (`user-client-001` / `user-jeeber-002`) instead of
// the authenticated session user. This guard scans lib/** for the two
// live-run-breaking shapes and fails if either reappears:
//
//   1. a `??` fallback to a hardcoded user-id literal
//      (e.g. `(await AuthTokenStore().userId) ?? 'user-client-001'`), and
//   2. a runtime reference to the DEBUG-ONLY seed constants
//      `SessionSeamBootstrap.jeeberUserId` / `.customerUserId` from a non-seam
//      file (those belong to the kDebugMode-gated seam, never a screen/repo).
//
// Guard proof (lessons honesty rule — a test must catch the bug): restore
// `?? 'user-client-001'` in chat_detail_screen.dart, or
// `jeeberId: SessionSeamBootstrap.jeeberUserId` in any screen → this test FAILS.
//
// Comment-only lines are ignored so the docstrings that NAME the banned literal
// (to explain the fix) don't trip the guard.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// `?? 'user-client-001'` / `?? "user-jeeber-002"` runtime literal fallbacks.
final _literalFallback = RegExp(r'''\?\?\s*['"]user-(client|jeeber)-\d+['"]''');

/// Runtime references to the debug-only seed constants from outside the seam.
final _seamConstRef =
    RegExp(r'SessionSeamBootstrap\.(jeeberUserId|customerUserId)');

bool _isCommentOnly(String line) {
  final t = line.trimLeft();
  return t.startsWith('//') || t.startsWith('*') || t.startsWith('/*');
}

void main() {
  test('lib/** has no hardcoded identity fallbacks (S0-OAD-03 / S0-CHAT-05)',
      () {
    final libDir = Directory('lib');
    expect(libDir.existsSync(), isTrue,
        reason: 'test must run from the package root');

    final offenders = <String>[];

    for (final entity in libDir.listSync(recursive: true)) {
      if (entity is! File || !entity.path.endsWith('.dart')) continue;
      final isSeamFile = entity.path.endsWith('session_seam_bootstrap.dart');

      final lines = entity.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        final line = lines[i];
        if (_isCommentOnly(line)) continue;

        if (_literalFallback.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: $line');
        }
        // The seam file legitimately DEFINES the constants; a `SessionSeamBootstrap.`
        // qualified reference only ever appears OUTSIDE it (a leaking screen/repo).
        if (!isSeamFile && _seamConstRef.hasMatch(line)) {
          offenders.add('${entity.path}:${i + 1}: $line');
        }
      }
    }

    expect(
      offenders,
      isEmpty,
      reason: 'Hardcoded identity fallback(s) found — replace with the real '
          'authenticated session userId (AuthTokenStore):\n'
          '${offenders.join('\n')}',
    );
  });
}
