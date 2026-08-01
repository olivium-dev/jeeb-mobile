import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/dev_settings_page.dart';

/// Owner ruling 2026-07-31 (`OWNER-DECISIONS.md`, DEVICE-E2E rulings #2):
/// MSI must be a Dev Tool server-URL preset.
///
/// This pins the ORDER as well as the membership, because the ruling's own
/// rationale is about which chip a tired operator taps at the start of a device
/// session. A preset that exists but sits third is most of the way to not
/// existing: the entire cost the ruling is paying down is that the working URL
/// had to be hand-typed, and a stale `http://127.0.0.1:9000` left from a dead
/// `adb reverse` tunnel then silently broke every backend call and cost a full
/// device window.
void main() {
  group('Dev Tool server-URL presets', () {
    test('MSI is present and is FIRST', () {
      expect(kDevServerUrlPresets.first, kMsiGatewayBaseUrl);
      expect(kMsiGatewayBaseUrl, 'http://192.168.2.39:10090');
    });

    test('MSI is origin-only — no /v1, which would double to /v1/v1', () {
      // AppConfig's anti-drift contract is that every request path carries
      // exactly one `/v1`. A preset ending in `/v1` produces `/v1/v1` on every
      // call, which 404s everything and looks like a dead backend.
      expect(kMsiGatewayBaseUrl.endsWith('/v1'), isFalse);
      expect(Uri.parse(kMsiGatewayBaseUrl).path, isEmpty);
      expect(Uri.parse(kMsiGatewayBaseUrl).port, 10090);
      expect(Uri.parse(kMsiGatewayBaseUrl).host, '192.168.2.39');
    });

    test('the two pre-existing presets are RETAINED, not replaced', () {
      // Additive. The emulator loopback is still the right answer for a mock
      // run, and removing it would break a workflow this ruling never
      // mentioned.
      expect(kDevServerUrlPresets, contains('http://10.0.2.2:4010'));
      expect(kDevServerUrlPresets, contains('https://api.jeeb.app/v1'));
      expect(kDevServerUrlPresets, hasLength(3));
    });

    test('HARD RULE: no preset points at the banned .50 host', () {
      // Owner directive, repeated and escalating: there must never be any call
      // to, or communication with, 192.168.2.50. MSI 192.168.2.39 is the only
      // server. A preset is a one-tap way to dial a host, so this is exactly
      // the surface that rule is about.
      for (final preset in kDevServerUrlPresets) {
        expect(
          preset.contains('192.168.2.50'),
          isFalse,
          reason: '$preset dials the banned host',
        );
      }
      // Positive control: the matcher can see a .50 string when one is there,
      // so the six `isFalse` results above are a measurement and not a
      // vacuous pass.
      expect('http://192.168.2.50:10090'.contains('192.168.2.50'), isTrue);
    });
  });
}
