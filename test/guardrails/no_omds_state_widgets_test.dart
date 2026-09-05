// The OMDS state widgets carry no identifier triple, no liveRegion and no copy
// family, so every remaining site is a screen a WP must migrate. RATCHET.

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// Sites on `origin/main` the day WP-0B landed. Stage 2 drives this to 0.
const int _kFloor = 12;

void main() {
  test('OmdsErrorState / OmdsLoadingState do not spread in lib/features', () {
    final List<GuardrailHit> hits = scan(
      'lib/features',
      RegExp(r'\bOmds(ErrorState|LoadingState)\s*\('),
    );
    expect(
      hits.length,
      lessThanOrEqualTo(_kFloor),
      reason: report('OmdsErrorState / OmdsLoadingState', _kFloor, hits),
    );
  });
}
