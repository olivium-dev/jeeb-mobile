import 'package:flutter_test/flutter_test.dart';

import 'guardrail_sources.dart';

void main() {
  test('legacy network failures carry reachability evidence', () {
    final pattern = RegExp(r'const\s+NetworkFailure\s*\(\s*\)');
    final hits = <GuardrailHit>[
      ...scan('lib/features', pattern),
      ...scan('lib/core/role', pattern),
    ];
    expect(
      hits,
      isEmpty,
      reason: report('offline-blind network failures', 0, hits),
    );
  });
}
