// An `_error`/`_retry_cta`/`_empty`/`_loading` id nobody asserts is a state
// nobody tests. Counts ids in lib/ that no test names. RATCHET — WP-9 floors it.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// 26 existing unasserted ids measured 2026-09-06 after repairing interpolation.
/// Never raise; P12 records the outstanding coverage debt.
const int _kFloor = 26;

/// `identifier: 'thing_error'` and the four suffixes the contract names.
/// Literals only: ids behind a `static const` or an interpolation are invisible.
final RegExp _kDeclared = RegExp(
  r'''identifier:\s*[\'"]([a-z0-9_]*_(?:error|retry_cta|empty|loading))[\'"]''',
);

void main() {
  test('identifier coverage checks each exact quoted value', () {
    const corpus = "'first_error' \"second_empty\" '\$id'";
    expect(_asserted(corpus, 'first_error'), isTrue);
    expect(_asserted(corpus, 'second_empty'), isTrue);
    expect(_asserted(corpus, 'missing_error'), isFalse);
    expect(_asserted(corpus, 'first'), isFalse);
  });

  test('failure identifiers are asserted by at least one test', () {
    final Set<String> declared = <String>{};
    final Map<String, GuardrailHit> firstSite = <String, GuardrailHit>{};
    for (final GuardrailHit hit in scan('lib', _kDeclared)) {
      final String? id = _kDeclared.firstMatch(hit.text)?.group(1);
      if (id == null) {
        continue;
      }
      declared.add(id);
      firstSite.putIfAbsent(id, () => hit);
    }
    expect(declared, isNotEmpty, reason: 'The declaration scan must not be vacuous.');

    final StringBuffer tests = StringBuffer();
    for (final File file in dartFilesUnder('test')) {
      tests.write(blankComments(file.readAsStringSync()));
    }
    final String corpus = tests.toString();
    final List<GuardrailHit> hits = declared
        .where((String id) => !_asserted(corpus, id))
        .map((String id) => firstSite[id]!)
        .toList()
      ..sort((GuardrailHit a, GuardrailHit b) => a.path.compareTo(b.path));

    expect(
      hits.length,
      lessThanOrEqualTo(_kFloor),
      reason: report('failure identifiers no test asserts', _kFloor, hits),
    );
  });
}

bool _asserted(String corpus, String id) =>
    corpus.contains("'$id'") || corpus.contains('"$id"');
