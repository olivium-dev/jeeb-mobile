import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/dev_settings_page.dart';

/// Owner ruling 2026-07-31 (`OWNER-DECISIONS.md`, DEVICE-E2E ru
void main() {
  group('Dev Tool server-URL presets', () {
    test('MSI is present and is FIRST', () {
      expect(kDevServerUrlPresets.first, kMsiGatewayBaseUrl);
      expect(kMsiGatewayBaseUrl, 'http://192.168.2.39:10090');
    });

    test('MSI is origin-only — no /v1, which would double to /v1/v1', () {
      expect(kMsiGatewayBaseUrl.endsWith('/v1'), isFalse);
      expect(Uri.parse(kMsiGatewayBaseUrl).path, isEmpty);
      expect(Uri.parse(kMsiGatewayBaseUrl).port, 10090);
      expect(Uri.parse(kMsiGatewayBaseUrl).host, '192.168.2.39');
    });

    test('the two pre-existing presets are RETAINED, not replaced', () {
      expect(kDevServerUrlPresets, contains('http://10.0.2.2:4010'));
      expect(kDevServerUrlPresets, contains('https://api.jeeb.app/v1'));
      expect(kDevServerUrlPresets, hasLength(3));
    });

    test('HARD RULE: no preset points at the banned .50 host', () {
      for (final preset in kDevServerUrlPresets) {
        expect(
          preset.contains('192.168.2.50'),
          isFalse,
          reason: '$preset dials the banned host',
        );
      }
      expect('http://192.168.2.50:10090'.contains('192.168.2.50'), isTrue);
    });
  });
}
