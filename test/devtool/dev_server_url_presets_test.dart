import 'package:flutter_test/flutter_test.dart';

import 'package:jeeb_mobile/devtool/dev_settings_page.dart';

/// Owner ruling 2026-07-31 (`OWNER-DECISIONS.md`, DEVICE-E2E ru
void main() {
  group('Dev Tool server-URL presets', () {
    test('configured development gateway is first', () {
      expect(kDevServerUrlPresets.first, kConfiguredDevGatewayBaseUrl);
      expect(kConfiguredDevGatewayBaseUrl, 'https://gateway.dev.invalid');
    });

    test('configured development gateway is an HTTPS origin', () {
      final uri = Uri.parse(kConfiguredDevGatewayBaseUrl);
      expect(uri.scheme, 'https');
      expect(uri.path, isEmpty);
      expect(uri.host, 'gateway.dev.invalid');
    });

    test('defaults do not place cleartext endpoints in release snapshots', () {
      expect(kConfiguredDevMockBaseUrl, 'https://mock.dev.invalid');
      expect(kDevServerUrlPresets, hasLength(2));
      expect(
        kDevServerUrlPresets.every(
          (value) =>
              Uri.parse(value).scheme == 'https' &&
              Uri.parse(value).host.endsWith('.invalid'),
        ),
        isTrue,
      );
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
