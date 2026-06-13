// Tests for T-MOB-FIX-001: mock_gateway_client.dart guardrail values.
//
// Verifies that:
//   1. mockBaseUrl targets 10.0.2.2:3055 (Mockoon gateway-mock on emulator).
//   2. useMockPrefixes is false (paths pass through unchanged to :3055).
//   3. webSocketUrl targets port 3056 (companion WebSocket shim).
//   4. rewritePath is a no-op when useMockPrefixes=false.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  group('MockGatewayClient config (T-MOB-FIX-001)', () {
    test('mockBaseUrl points to Android emulator loopback on port 3055', () {
      expect(MockGatewayClient.mockBaseUrl, 'http://10.0.2.2:3055');
    });

    test('useMockPrefixes is false — paths are forwarded unchanged', () {
      expect(MockGatewayClient.useMockPrefixes, isFalse);
    });

    test('webSocketUrl targets port 3056', () {
      final wsUrl = MockGatewayClient.webSocketUrl;
      expect(wsUrl, contains('3056'));
      expect(wsUrl, startsWith('ws://'));
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
