// Tests for mock_gateway_client.dart UNDER mock-prefix mode (sprint-7 chat
// step). These run under a PLAIN `flutter test` — no `--dart-define` — and are
// NOT skipped.
//
// PRIOR DEFECT (TEST-INTEGRITY-AUDIT #suspicious-1): every test here was
// `skip: !mockMode` where `mockMode = MockGatewayClient.useMockPrefixes`, a
// COMPILE-TIME const that defaults to `false`. CI runs `flutter test` with no
// `--dart-define=JEEB_USE_MOCK_PREFIXES=true`, so all six silently skipped —
// including the self-referential `useMockPrefixes is true` guard, which could
// never go red. The chat mock-prefix rewrite seams (conversation-resolve
// fallback `/v1/conversations`, realtime membership pre-check `/v1/realtime/…`,
// and the WS socket endpoint) were therefore UNVERIFIED in CI while counted
// green.
//
// FIX: the rewrite/realtime/WS logic is now exposed as flag-INDEPENDENT pure
// helpers (`mapToServicePrefix`, `resolveRealtimeHttpBase`,
// `resolveWebSocketUrl`) that take an explicit `mockMode`. These tests drive
// them with `mockMode: true` so the mock-mode chat-routing contract is asserted
// for real, regardless of the build-time define. They also pin that
// `mockMode: false` (the production/device default) leaves paths un-rewritten
// and targets the live Phoenix :5804 — so neither branch is dead.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  group('MockGatewayClient — mock-prefix mode chat routing (sprint-7)', () {
    test('/v1/conversations rewrites to the chat-service mount', () {
      expect(
        MockGatewayClient.mapToServicePrefix('/v1/conversations'),
        '/chat-service/v1/conversations',
      );
      // The correlationKey query the conversation-resolve fallback appends is
      // carried on the query string, not the path, so the path prefix is the
      // only thing rewritten.
      expect(
        MockGatewayClient.mapToServicePrefix(
            '/v1/conversations?correlationKey=req-1'),
        '/chat-service/v1/conversations?correlationKey=req-1',
      );
    });

    test('/v1/realtime/jeeb:chat:{id} rewrites to the realtime-service mount',
        () {
      expect(
        MockGatewayClient.mapToServicePrefix(
            '/v1/realtime/jeeb:chat:conv-accepted-001'),
        '/realtime-comunication-service/v1/realtime/jeeb:chat:conv-accepted-001',
      );
    });

    test('/v1/chat/jeeb paths still rewrite to the chat-service mount', () {
      expect(
        MockGatewayClient.mapToServicePrefix(
          '/v1/chat/jeeb/conversations/conv-accepted-001/messages',
        ),
        '/chat-service/v1/chat/jeeb/conversations/conv-accepted-001/messages',
      );
    });

    test('realtimeHttpBase co-locates on the mock origin (NOT :5804)', () {
      final base = MockGatewayClient.resolveRealtimeHttpBase(mockMode: true);
      final mock = Uri.parse(MockGatewayClient.mockBaseUrl);
      expect(base.host, mock.host);
      expect(base.port, mock.port); // :4010, not the live :5804
      expect(base.port, isNot(MockGatewayClient.realtimePort));
    });

    test('webSocketUrl targets the service-prefixed mock socket endpoint', () {
      final ws = MockGatewayClient.resolveWebSocketUrl(mockMode: true);
      expect(ws, startsWith('ws://'));
      expect(ws, contains('/realtime-comunication-service/socket/websocket'));
      expect(ws, isNot(contains(':5804')));
      // The socket co-locates on the mock origin (:4010 by default).
      expect(ws, contains(':${Uri.parse(MockGatewayClient.mockBaseUrl).port}'));
    });

    test('rewritePath honours the compile-time flag (gating is intact)', () {
      // rewritePath delegates to mapToServicePrefix ONLY when useMockPrefixes is
      // true; otherwise it passes through. Whatever the build default is, the
      // two must agree — this pins the gate so a future refactor can't silently
      // un-gate (or double-gate) the rewrite in production.
      const path = '/v1/conversations';
      if (MockGatewayClient.useMockPrefixes) {
        expect(MockGatewayClient.rewritePath(path),
            MockGatewayClient.mapToServicePrefix(path));
      } else {
        expect(MockGatewayClient.rewritePath(path), path);
      }
    });
  });

  group('MockGatewayClient — live-gateway mode (real gateway contract)', () {
    test('mockMode:false targets the live Phoenix realtime port :5804', () {
      final base = MockGatewayClient.resolveRealtimeHttpBase(mockMode: false);
      expect(base.port, MockGatewayClient.realtimePort); // 5804
      final ws = MockGatewayClient.resolveWebSocketUrl(mockMode: false);
      expect(ws, contains('/socket/websocket'));
      expect(ws,
          isNot(contains('/realtime-comunication-service/socket/websocket')));
    });
  });
}
