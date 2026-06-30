// Tests for mock_gateway_client.dart guardrail values + the path-rewrite seam.
//
// useMockPrefixes is wired to bool.fromEnvironment('JEEB_USE_MOCK_PREFIXES',
// defaultValue: false) (network fix 1717166): physical-device and CI builds
// default to LIVE-gateway mode, where every path passes through `rewritePath`
// UNCHANGED and the app speaks the raw gateway contract (`/v1/auth/otp/request`,
// `/v1/users/me`, …) directly. The Express-mock service-prefix rewrite
// (`/auth-service/auth/*`, …) only engages when a build explicitly passes
// `--dart-define=JEEB_USE_MOCK_PREFIXES=true`.
//
// Tests run with NO dart-define, so they exercise the default (live) seam:
//   1. mockBaseUrl defaults to the host LAN IP on :4010.
//   2. useMockPrefixes defaults to FALSE (live-gateway / device default).
//   3. webSocketUrl targets port 3056 (companion WebSocket shim).
//   4. rewritePath is a PASS-THROUGH for the default build — the very property
//      the on-device build relies on so its `/v1/*` paths reach the live gateway
//      verbatim (the bug 1717166 fixed: prefixes were hardcoded true, rewriting
//      `/v1/auth/otp` → `/auth-service/...` against a gateway that only knows
//      `/v1/*`).

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  group('MockGatewayClient config (W-1 foundation)', () {
    test('mockBaseUrl defaults to the live DEV GATEWAY in debug (no define)',
        () {
      // super-login hardening: with NO --dart-define, a debug build now defaults
      // to the live dev gateway (which serves the raw /v1/* + /api/* contract
      // incl. super-login) instead of the :4010 Express mock, so a plain
      // `flutter run` is coherent and the dev super-login flow works out of the
      // box. Tests run in debug, so this default applies here. A build can still
      // override via --dart-define=JEEB_MOCK_BASE_URL=...; release keeps the
      // historical :4010 fallback.
      expect(MockGatewayClient.mockBaseUrl, 'http://192.168.2.39:10090');
    });

    test('useMockPrefixes defaults to false (live-gateway / device default)',
        () {
      // 1717166: useMockPrefixes reads JEEB_USE_MOCK_PREFIXES (default false) so
      // device/CI builds hit the live gateway. With no dart-define in tests the
      // default applies.
      expect(MockGatewayClient.useMockPrefixes, isFalse);
    });

    test('webSocketUrl targets port 3056', () {
      final wsUrl = MockGatewayClient.webSocketUrl;
      expect(wsUrl, contains('3056'));
      expect(wsUrl, startsWith('ws://'));
    });
  });

  // With useMockPrefixes=false (the default these tests run under), rewritePath
  // short-circuits and returns its input unchanged. This is the contract the
  // live on-device build depends on: every gateway path reaches the gateway
  // verbatim. Pin it across the auth seam, the getMe/profile read, and the
  // broader /v1/* surface so a regression that re-enables rewriting by default
  // (the 1717166 bug) is caught.
  group('rewritePath — default (live) build passes paths through unchanged', () {
    const passthroughPaths = <String>[
      // B1 auth seam
      '/v1/auth/otp/request',
      '/v1/auth/otp/verify',
      '/v1/auth/login',
      '/v1/auth/signup',
      '/v1/auth/recovery/request',
      '/v1/auth/recovery/verify',
      '/v1/auth/set-password',
      '/v1/auth/refresh',
      '/v1/auth/logout',
      // B2 social seam (gateway + legacy shapes)
      '/v1/auth/social',
      '/api/auth/social',
      // getMe / profile read
      '/users/me',
      '/v1/users/me',
      // broader /v1/* surface
      '/v1/offers',
      '/v1/notifications/send',
      '/v1/notifications',
      // W2 KYC
      '/v1/kyc/status',
      '/v1/kyc/jeeb/form-schema',
      '/v1/kyc/submit',
    ];

    for (final path in passthroughPaths) {
      test('$path is passed through unchanged', () {
        expect(MockGatewayClient.rewritePath(path), path);
      });
    }
  });
}
