// S0-OAD-03 / S0-CHAT-05 anti-drift guardrail.

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
