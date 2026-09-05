// `showJeebErrorSnack` is the transient-failure surface; the OMDS snack (2.79:1,
// no identifier, no retry) and a raw showSnackBar are RATCHETS: fall, never rise.

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// Sites on `origin/main` the day WP-0B landed. Stage 2 drives both to 0.
const int _kOmdsErrorSnackbarFloor = 12;
const int _kRawSnackBarFloor = 19;

void main() {
  test('showOmdsErrorSnackbar does not spread', () {
    final List<GuardrailHit> hits = scan(
      'lib',
      RegExp(r'\bshowOmdsErrorSnackbar\s*\('),
    );
    expect(
      hits.length,
      lessThanOrEqualTo(_kOmdsErrorSnackbarFloor),
      reason: report(
        'showOmdsErrorSnackbar',
        _kOmdsErrorSnackbarFloor,
        hits,
      ),
    );
  });

  test('raw ScaffoldMessenger.showSnackBar does not spread in lib/features', () {
    final List<GuardrailHit> hits = scan(
      'lib/features',
      RegExp(r'\.showSnackBar\s*\('),
    );
    expect(
      hits.length,
      lessThanOrEqualTo(_kRawSnackBarFloor),
      reason: report(
        'raw ScaffoldMessenger.showSnackBar in lib/features',
        _kRawSnackBarFloor,
        hits,
      ),
    );
  });
}
