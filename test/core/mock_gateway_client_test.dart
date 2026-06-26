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
//   1. mockBaseUrl defaults to localhost on :4010 (LAN IP scrubbed in Sprint 2).
//   2. useMockPrefixes defaults to FALSE (live-gateway / device default).
//   3. webSocketUrl targets the live realtime service (:5804 /socket/websocket).
//   4. rewritePath is a PASS-THROUGH for the default build — the very property
//      the on-device build relies on so its `/v1/*` paths reach the live gateway
//      verbatim (the bug 1717166 fixed: prefixes were hardcoded true, rewriting
//      `/v1/auth/otp` → `/auth-service/...` against a gateway that only knows
//      `/v1/*`).

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/config/app_config.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  group('MockGatewayClient config (W-1 foundation)', () {
    test('mockBaseUrl defaults to localhost on port 4010 (#37)', () {
      // #37 originally swapped the default to a host LAN IP; Sprint 2 scrubbed
      // the hardcoded LAN IP back to `localhost` so the default carries no
      // machine-specific address (overridable via --dart-define=JEEB_MOCK_BASE_URL).
      expect(MockGatewayClient.mockBaseUrl, 'http://localhost:4010');
    });

    test('useMockPrefixes defaults to false (live-gateway / device default)',
        () {
      // 1717166: useMockPrefixes reads JEEB_USE_MOCK_PREFIXES. sprint-7
      // step-login: its default is now AppConfig.useMockGateway (single-switch).
      // With NO dart-define in tests, USE_MOCK_GATEWAY is false → useMockPrefixes
      // is false, so device/CI builds still hit the live gateway. Unchanged.
      expect(MockGatewayClient.useMockPrefixes, isFalse);
    });

    test('useMockPrefixes default tracks AppConfig.useMockGateway '
        '(single-switch invariant)', () {
      // sprint-7 step-login coupling fix: a `--dart-define=USE_MOCK_GATEWAY=true`
      // build must ALSO install the service-prefix rewrite interceptor without a
      // second JEEB_USE_MOCK_PREFIXES define. Pin the invariant so a regression
      // that decouples the two flags (re-introducing the silent raw-/v1 404 on
      // the mock host) is caught. Holds for both build modes: when no
      // JEEB_USE_MOCK_PREFIXES override is passed, the prefix toggle equals the
      // mock-gateway toggle.
      expect(MockGatewayClient.useMockPrefixes, AppConfig.useMockGateway);
    });

    test('webSocketUrl targets the live realtime service (:5804 socket path)',
        () {
      // CHAT-FIX (iter6 / ws): the WS base was repointed off the dead `:3056`
      // mock shim onto the live realtime-comunication-service (LiveComm,
      // Phoenix `:5804` `/socket/websocket`). With no JEEB_REALTIME_BASE_URL
      // define the host derives from the gateway base on the standard port.
      final wsUrl = MockGatewayClient.webSocketUrl;
      expect(wsUrl, contains(':${MockGatewayClient.realtimePort}'));
      expect(wsUrl, contains('/socket/websocket'));
      expect(wsUrl, startsWith('ws://'));
      expect(wsUrl, isNot(contains('3056')));
    });

    test('realtimeHttpBase derives from the gateway host on the realtime port '
        'when no define is set', () {
      final base = MockGatewayClient.realtimeHttpBase;
      expect(base.port, MockGatewayClient.realtimePort);
      // Same host as the mock/gateway base (co-located default).
      expect(base.host, Uri.parse(MockGatewayClient.mockBaseUrl).host);
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
