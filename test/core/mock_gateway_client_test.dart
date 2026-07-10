// Tests for T-MOB-FIX-001 / RC4: mock_gateway_client.dart guardrail values.
//
// Verifies that:
//   1. mockBaseUrl targets 10.0.2.2:3055 (Mockoon gateway-mock on emulator).
//   2. useMockPrefixes is false (paths pass through unchanged to :3055).
//   3. runtime config can repoint a physical device without rebuilding.
//   4. webSocketUrl is derived from the same endpoint config.
//   5. rewritePath is a no-op when useMockPrefixes=false.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam.dart';
import 'package:jeeb_mobile/core/dev_seam/dev_seam_config.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  tearDown(DevSeam.debugReset);

  group('MockGatewayClient config (T-MOB-FIX-001 / RC4)', () {
    test('defaultMockBaseUrl points to Android emulator loopback', () {
      expect(MockGatewayClient.defaultMockBaseUrl, 'http://10.0.2.2:3055');
    });

    test('mockBaseUrl uses dart-define fallback or emulator default', () {
      const dartDefined = String.fromEnvironment(
        'JEEB_MOCK_BASE_URL',
        defaultValue: 'http://10.0.2.2:3055',
      );

      expect(MockGatewayClient.mockBaseUrl, dartDefined);
    });

    test('useMockPrefixes is false — paths are forwarded unchanged', () {
      expect(MockGatewayClient.useMockPrefixes, isFalse);
    });

    test('runtime mockBaseUrl override supports physical devices', () {
      DevSeam.debugOverride(
        const DevSeamConfig(mockBaseUrl: 'http://192.168.1.42:3055/'),
      );

      expect(MockGatewayClient.mockBaseUrl, 'http://192.168.1.42:3055');
      expect(
        MockGatewayClient.createDio().options.baseUrl,
        'http://192.168.1.42:3055',
      );
    });

    test('invalid runtime mockBaseUrl falls back to dart-define/default', () {
      const dartDefined = String.fromEnvironment(
        'JEEB_MOCK_BASE_URL',
        defaultValue: 'http://10.0.2.2:3055',
      );
      DevSeam.debugOverride(
        const DevSeamConfig(mockBaseUrl: 'ws://192.168.1.42:3055'),
      );

      expect(MockGatewayClient.mockBaseUrl, dartDefined);
    });

    test('webSocketUrl targets companion port 3056 on the same host', () {
      final restUri = Uri.parse(MockGatewayClient.mockBaseUrl);
      final expectedScheme = restUri.scheme == 'https' ? 'wss://' : 'ws://';
      final wsUrl = MockGatewayClient.webSocketUrl;

      expect(wsUrl, contains('3056'));
      expect(wsUrl, contains(restUri.host));
      expect(wsUrl, startsWith(expectedScheme));
    });

    test('webSocketUrl derives scheme and host from runtime base URL', () {
      DevSeam.debugOverride(
        const DevSeamConfig(mockBaseUrl: 'https://mock.jeeb.test:3055'),
      );

      expect(
        MockGatewayClient.webSocketUrl,
        'wss://mock.jeeb.test:3056/socket/websocket',
      );
    });

    test('webSocketUrl keeps non-mock ports for proxy-style endpoints', () {
      expect(
        MockGatewayClient.webSocketUrlFor('https://gateway.test'),
        'wss://gateway.test/socket/websocket',
      );
    });

    test('rewritePath returns path unchanged when useMockPrefixes=false', () {
      const path = '/v1/auth/otp/request';
      expect(MockGatewayClient.rewritePath(path), path);
    });

    test('rewritePath preserves /v1/delivery/tiers path unchanged', () {
      const path = '/v1/delivery/tiers';
      expect(MockGatewayClient.rewritePath(path), path);
    });
  });
}
