// `JeebPullToRefresh` bakes in the onSurfaceVariant spinner (LR-20); a bare
// `OmdsPullToRefresh` in a feature ships the Material default instead. RATCHET.

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// Sites on `origin/main` the day WP-0B landed. Stage 2 drives this to 0.
const int _kFloor = 0;

void main() {
  test('bare OmdsPullToRefresh does not spread in lib/features', () {
    final List<GuardrailHit> hits = scan(
      'lib/features',
      RegExp(r'\bOmdsPullToRefresh\s*\('),
    );
    expect(
      hits.length,
      lessThanOrEqualTo(_kFloor),
      reason: report('bare OmdsPullToRefresh', _kFloor, hits),
    );
  });
}
