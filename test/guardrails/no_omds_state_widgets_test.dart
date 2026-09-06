// The OMDS state widgets carry no identifier triple, no liveRegion and no copy
// family, so every remaining site is a screen a WP must migrate. RATCHET.

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// Floor is zero since P05 (2026-09-06); never raise.
const int _kFloor = 0;

void main() {
  test('OmdsErrorState / OmdsLoadingState do not spread in lib', () {
    final List<GuardrailHit> hits = scan(
      'lib',
      RegExp(r'\bOmds(ErrorState|LoadingState)\s*\('),
    );
    expect(
      hits.length,
      lessThanOrEqualTo(_kFloor),
      reason: report('OmdsErrorState / OmdsLoadingState', _kFloor, hits),
    );
  });
}
