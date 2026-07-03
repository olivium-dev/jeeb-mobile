// Unit tests for ServerTime — the shared gateway-timestamp normalizer
// (cycle-5 T11 / SW-03 centralization). Proves the zone-less→UTC rule that
// stops UTC wall clocks leaking as device-local across feed, order history,
// wallet and tracking. Host-timezone-independent by construction (all
// assertions are on absolute UTC instants).

import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/core/formatting/server_time.dart';

void main() {
  group('ServerTime.parse', () {
    test('a zone-less ISO string is re-interpreted as a UTC instant', () {
      final parsed = ServerTime.parse('2026-07-03T12:31:00');
      expect(parsed, isNotNull);
      expect(parsed!.isUtc, isTrue);
      // Wall-clock digits are preserved AS UTC (12:31 UTC) — NOT shifted to the
      // device zone. Downstream toLocal() then becomes a real conversion.
      expect(parsed, DateTime.utc(2026, 7, 3, 12, 31));
    });

    test('a Z-marked string keeps its instant', () {
      final parsed = ServerTime.parse('2026-07-03T12:31:00Z');
      expect(parsed!.isUtc, isTrue);
      expect(parsed, DateTime.utc(2026, 7, 3, 12, 31));
    });

    test('zone-less and Z-marked denoting the same instant are EQUAL', () {
      // The core property: a gateway that drops the Z must not skew the clock.
      expect(
        ServerTime.parse('2026-07-03T12:31:00'),
        ServerTime.parse('2026-07-03T12:31:00Z'),
      );
    });

    test('an explicit +offset string collapses to the correct UTC instant', () {
      // 12:31 at +02:00 is 10:31 UTC.
      expect(
        ServerTime.parse('2026-07-03T12:31:00+02:00'),
        DateTime.utc(2026, 7, 3, 10, 31),
      );
    });

    test('sub-second precision is preserved', () {
      final parsed = ServerTime.parse('2026-07-03T12:31:00.250');
      expect(parsed, DateTime.utc(2026, 7, 3, 12, 31, 0, 250));
    });

    test('null / blank / unparseable → null (caller owns the fallback)', () {
      expect(ServerTime.parse(null), isNull);
      expect(ServerTime.parse(''), isNull);
      expect(ServerTime.parse('not-a-date'), isNull);
    });
  });
}
