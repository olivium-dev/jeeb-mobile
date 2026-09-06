// `JeebPullToRefresh` bakes in the onSurfaceVariant spinner (LR-20); a bare
// `OmdsPullToRefresh` in a feature ships the Material default instead. RATCHET.

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// Floor is zero since P05 (2026-09-06); never raise.
const int _kFloor = 0;

void main() {
  test('bare OmdsPullToRefresh does not spread in lib', () {
    final List<GuardrailHit> hits = scan(
      'lib',
      RegExp(r'\bOmdsPullToRefresh\s*\('),
      skipPaths: const ['lib/core/widgets/jeeb/jeeb_pull_to_refresh.dart'],
    );
    expect(
      hits.length,
      lessThanOrEqualTo(_kFloor),
      reason: report('bare OmdsPullToRefresh', _kFloor, hits),
    );
  });
}
