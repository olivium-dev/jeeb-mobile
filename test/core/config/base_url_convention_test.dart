import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/app_config.dart';

/// ANTI-DRIFT contract for ARCH-01 / INFRA-01 (the S16 `/v1/v1` doubling NO-GO).
/// FROZEN convention: `AppConfig.gatewayBaseUrl` is ORIGIN-ONLY (scheme + host +
int _countV1(String url) => '/v1'.allMatches(url).length;

/// Resolves the full URL Dio would request for [path] under the configured
/// origin-only base, exactly as the real client does (`baseUrl + path`).
String _resolve(String path) =>
    RequestOptions(baseUrl: AppConfig.gatewayBaseUrl, path: path)
        .uri
        .toString();

void main() {
  group('ARCH-01/INFRA-01 base-URL convention', () {
    test('gatewayBaseUrl is origin-only — does NOT end in /v1 or a slash', () {
      expect(
        AppConfig.gatewayBaseUrl.endsWith('/v1'),
        isFalse,
        reason: 'Base must be origin-only; the /v1 belongs on each path. '
            'A /v1 here doubles to /v1/v1 (the S16 availability NO-GO).',
      );
      expect(
        AppConfig.gatewayBaseUrl.endsWith('/'),
        isFalse,
        reason: 'Base must have no trailing slash.',
      );
      expect(AppConfig.gatewayBaseUrl, 'https://api.jeeb.app');
    });

    test('representative core-flow paths resolve to exactly one /v1', () {
      const paths = <String>[
        '/v1/users/me',
        '/v1/jeebers/me/availability',
        '/v1/auth/otp/request',
        '/v1/requests',
        '/v1/offers',
        '/v1/conversations',
      ];
      for (final path in paths) {
        final url = _resolve(path);
        expect(
          _countV1(url),
          1,
          reason: 'Expected exactly one /v1 in "$url" (base + path = "$path").',
        );
        expect(url.contains('/v1/v1'), isFalse, reason: 'No doubling in $url.');
      }
    });

    test('me-scoped availability route carries no userId and one /v1', () {
      final url = _resolve('/v1/jeebers/me/availability');
      expect(url, 'https://api.jeeb.app/v1/jeebers/me/availability');
      expect(url.contains('user-jeeber-002'), isFalse);
    });
  });
}
