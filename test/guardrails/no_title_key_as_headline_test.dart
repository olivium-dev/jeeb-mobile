// An app-bar title is a label, not a headline: a key used as `title:` must
// never also be a `headline:`, or a loading rung reads "Wallet". RATCHET.

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// Floor is zero since P05 (2026-09-06); never raise.
const int _kFloor = 0;

final RegExp _kTitleArg = RegExp(r'\btitle:\s*l10n\.(\w+)\b');
final RegExp _kHeadlineArg = RegExp(r'\bheadline:\s*l10n\.(\w+)\b');

void main() {
  test('no app-bar title key is reused as an empty-state headline', () {
    final Set<String> titleKeys = scan('lib', _kTitleArg)
        .map((GuardrailHit h) => _kTitleArg.firstMatch(h.text)!.group(1)!)
        .toSet();

    final List<GuardrailHit> hits = scan('lib', _kHeadlineArg)
        .where(
          (GuardrailHit h) =>
              titleKeys.contains(_kHeadlineArg.firstMatch(h.text)!.group(1)!),
        )
        .toList();

    expect(
      hits.length,
      lessThanOrEqualTo(_kFloor),
      reason: report('title key reused as headline', _kFloor, hits),
    );
  });
}
