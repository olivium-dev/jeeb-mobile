// Tests for mock_gateway_client.dart guardrail values + the auth-rewrite seam.
//
// The working tree intentionally ships `useMockPrefixes = true` targeting the
// service-prefixed Express mock on :4010 (CTO brief §4 + 42_GUARDRAILS_MOCK B0).
// These tests pin that configuration and the W-1 B1/B2 auth rewrite map so the
// AUTH seam provably reaches :4010.
//
// Verifies that:
//   1. mockBaseUrl defaults to the host LAN IP on :4010 (#37 — reachable from
//      iOS sims/devices, not just the Android-emulator loopback). Port stays
//      :4010 to match useMockPrefixes = true.
//   2. useMockPrefixes is true (paths are rewritten to service prefixes).
//   3. webSocketUrl targets port 3056 (companion WebSocket shim).
//   4. rewritePath maps the app's /v1/auth/* paths onto /auth-service/auth/*.
//   5. social /api/auth/social rewrites to the mock social handler.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  group('MockGatewayClient config (W-1 foundation)', () {
    test('mockBaseUrl defaults to the host LAN IP on port 4010 (#37)', () {
      // #37: default swapped from the Android-emulator-only 10.0.2.2 loopback
      // to the host LAN IP so iOS sims and physical devices reach the mock
      // out of the box. Port stays :4010 (B0/W-1) to match useMockPrefixes.
      expect(MockGatewayClient.mockBaseUrl, 'http://192.168.2.33:4010');
    });

    test(
      'useMockPrefixes is true — paths are rewritten to service prefixes',
      () {
        expect(MockGatewayClient.useMockPrefixes, isTrue);
      },
    );

    test('webSocketUrl targets port 3056', () {
      final wsUrl = MockGatewayClient.webSocketUrl;
      expect(wsUrl, contains('3056'));
      expect(wsUrl, startsWith('ws://'));
    });
  });

  group('rewritePath — B1 auth seam (/v1/auth/* → /auth-service/auth/*)', () {
    test('OTP request rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/otp/request'),
        '/auth-service/auth/otp/request',
      );
    });

    test('OTP verify rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/otp/verify'),
        '/auth-service/auth/otp/verify',
      );
    });

    test('email/password login rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/login'),
        '/auth-service/auth/login',
      );
    });

    test('email-first signup rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/signup'),
        '/auth-service/auth/signup',
      );
    });

    test('recovery request rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/recovery/request'),
        '/auth-service/auth/recovery/request',
      );
    });

    test('recovery verify rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/recovery/verify'),
        '/auth-service/auth/recovery/verify',
      );
    });

    test('set-password rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/set-password'),
        '/auth-service/auth/set-password',
      );
    });

    test('refresh rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/refresh'),
        '/auth-service/auth/refresh',
      );
    });

    test('logout rewrites to the auth-service prefix', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/logout'),
        '/auth-service/auth/logout',
      );
    });
  });

  group('rewritePath — B2 social seam', () {
    test('gateway /v1/auth/social rewrites to the social handler', () {
      expect(
        MockGatewayClient.rewritePath('/v1/auth/social'),
        '/auth-service/auth/social',
      );
    });

    test('legacy /api/auth/social rewrites to the same social handler', () {
      expect(
        MockGatewayClient.rewritePath('/api/auth/social'),
        '/auth-service/auth/social',
      );
    });
  });

  group('rewritePath — non-auth surface still rewrites correctly', () {
    test('getMe (/users/me) rewrites to user-management', () {
      expect(
        MockGatewayClient.rewritePath('/users/me'),
        '/user-management/users/me',
      );
    });

    test('getMe (/v1/users/me) rewrites to user-management', () {
      expect(
        MockGatewayClient.rewritePath('/v1/users/me'),
        '/user-management/users/me',
      );
    });

    test('offers rewrites to offer-service', () {
      expect(
        MockGatewayClient.rewritePath('/v1/offers'),
        '/offer-service/v1/offers',
      );
    });

    test('delivery list rewrites to delivery-service v1', () {
      expect(
        MockGatewayClient.rewritePath('/deliveries'),
        '/delivery-service/v1/deliveries',
      );
    });

    test(
      'the more specific /v1/notifications/send precedes /v1/notifications',
      () {
        expect(
          MockGatewayClient.rewritePath('/v1/notifications/send'),
          '/notification-service/v1/notifications/send',
        );
        expect(
          MockGatewayClient.rewritePath('/v1/notifications'),
          '/notification-service/v1/notifications',
        );
      },
    );

    // W2 KYC (66_W2_QA_RESULTS C2): the KYC gateway speaks `/v1/kyc/*`; the mock
    // mounts it under `/user-management`. Without this rewrite the app hit
    // `:4010/v1/kyc/status` → 404 and the KYC status view never resolved.
    test('KYC status rewrites to user-management', () {
      expect(
        MockGatewayClient.rewritePath('/v1/kyc/status'),
        '/user-management/v1/kyc/status',
      );
    });

    test('KYC form-schema + submit rewrite to user-management', () {
      expect(
        MockGatewayClient.rewritePath('/v1/kyc/jeeb/form-schema'),
        '/user-management/v1/kyc/jeeb/form-schema',
      );
      expect(
        MockGatewayClient.rewritePath('/v1/kyc/submit'),
        '/user-management/v1/kyc/submit',
      );
    });
  });
}
