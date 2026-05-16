import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/features/chat/application/reconnect_policy.dart';

void main() {
  group('ReconnectPolicy', () {
    test('attempt 0 returns Duration.zero', () {
      const policy = ReconnectPolicy();
      expect(policy.delayFor(0), Duration.zero);
    });

    test('exponential growth doubles up to the cap', () {
      const policy = ReconnectPolicy(
        initialDelay: Duration(seconds: 1),
        maxDelay: Duration(seconds: 8),
        multiplier: 2.0,
      );
      expect(policy.delayFor(1), const Duration(seconds: 1));
      expect(policy.delayFor(2), const Duration(seconds: 2));
      expect(policy.delayFor(3), const Duration(seconds: 4));
      expect(policy.delayFor(4), const Duration(seconds: 8));
      expect(policy.delayFor(5), const Duration(seconds: 8)); // capped
    });

    test('shouldGiveUp respects maxAttempts (0 = forever)', () {
      const forever = ReconnectPolicy();
      expect(forever.shouldGiveUp(1000), isFalse);

      const bounded = ReconnectPolicy(maxAttempts: 3);
      expect(bounded.shouldGiveUp(2), isFalse);
      expect(bounded.shouldGiveUp(3), isTrue);
    });
  });
}
