// A `_mapError` returning an English sentence is untranslatable copy in a
// cubit; the target is `failureCopy` + a per-typeSuffix ARB key. RATCHET.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// Sentences on `origin/main` the day WP-0B landed. Stage 2 drives this to 0.
const int _kFloor = 26;

/// `String _mapError(...) {`, `String? _mapLoadError(...) {`, and friends.
final RegExp _kMapErrorFn = RegExp(
  r'(?:static\s+)?String\??\s+(_?\w*[Mm]ap\w*(?:Error|Failure)\w*)\s*\([^)]*\)\s*\{',
);

/// A quoted literal with at least two ASCII words — a sentence, not an id.
final RegExp _kSentence = RegExp(
  r'''['"][^'"\n]*[A-Za-z]{2,} [^'"\n]*[A-Za-z]{2,}[^'"\n]*['"]''',
);

/// The `{ … }` body starting at [open], by brace balance.
String _body(String code, int open) {
  int depth = 0;
  for (int i = open; i < code.length; i++) {
    if (code[i] == '{') {
      depth++;
    } else if (code[i] == '}') {
      depth--;
      if (depth == 0) {
        return code.substring(open, i + 1);
      }
    }
  }
  return code.substring(open);
}

void main() {
  test('no English sentences returned from _mapError-shaped functions', () {
    final List<GuardrailHit> hits = <GuardrailHit>[];
    for (final File file in dartFilesUnder('lib/features')) {
      if (!file.path.contains('/application/')) {
        continue;
      }
      final String source = file.readAsStringSync();
      final String code = blankComments(source);
      final List<String> lines = source.split('\n');
      for (final RegExpMatch fn in _kMapErrorFn.allMatches(code)) {
        final int open = code.indexOf('{', fn.start);
        if (open < 0) {
          continue;
        }
        final String body = _body(code, open);
        for (final RegExpMatch lit in _kSentence.allMatches(body)) {
          final int at = open + lit.start;
          final int line = '\n'.allMatches(code.substring(0, at)).length;
          hits.add(
            GuardrailHit(
              '${file.path} (${fn.group(1)})',
              line + 1,
              lines[line],
            ),
          );
        }
      }
    }
    expect(
      hits.length,
      lessThanOrEqualTo(_kFloor),
      reason: report('hardcoded error copy in cubits', _kFloor, hits),
    );
  });
}
