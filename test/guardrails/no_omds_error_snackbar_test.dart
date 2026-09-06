// `showJeebErrorSnack` is the transient-failure surface; the OMDS snack (2.79:1,
// no identifier, no retry) and a raw showSnackBar are RATCHETS: fall, never rise.

import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

/// Floors are zero since P05 (2026-09-06); never raise.
const int _kOmdsErrorSnackbarFloor = 0;
const int _kRawSnackBarFloor = 0;

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
