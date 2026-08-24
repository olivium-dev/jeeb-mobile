// Tests for mock_gateway_client.dart guardrail values + the path-rewrite seam.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  group('MockGatewayClient config (W-1 foundation)', () {
    test('debug fallback is reserved and cannot reach a real environment', () {
      expect(MockGatewayClient.mockBaseUrl, 'https://gateway.dev.invalid');
    });

    test('useMockPrefixes defaults to false (live-gateway / device default)', () {
      // 1717166: useMockPrefixes reads JEEB_USE_MOCK_PREFIXES (default false) so
      expect(MockGatewayClient.useMockPrefixes, isFalse);
    });

    test(
      'webSocketUrl targets the live realtime service (:5804 socket path)',
      () {
        // CHAT-FIX (iter6 / ws): the WS base was repointed off the dead `:3056`
        final wsUrl = MockGatewayClient.webSocketUrl;
        expect(wsUrl, startsWith('wss://'));
        expect(wsUrl, contains(':${MockGatewayClient.realtimePort}'));
        expect(wsUrl, endsWith('/socket/websocket'));
        expect(wsUrl, isNot(contains('3056')));
        expect(wsUrl, isNot(contains('/realtime-comunication-service')));
      },
    );
  });

  // With useMockPrefixes=false (the default these tests run under), rewritePath
  group(
    'rewritePath — default (live) build passes paths through unchanged',
    () {
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
    },
  );
}
