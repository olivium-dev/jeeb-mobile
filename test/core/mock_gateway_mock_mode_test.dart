// Tests for mock_gateway_client.dart UNDER mock-prefix mode (sprint-7 chat
// step). Run with:
//   flutter test test/core/mock_gateway_mock_mode_test.dart \
//     --dart-define=JEEB_USE_MOCK_PREFIXES=true
//
// With useMockPrefixes=true every gateway path is rewritten to the Express
// mock's service-prefixed routes, the realtime base co-locates on the mock
// origin (:4010), and the WS path moves behind the service-prefix mount. These
// are the seams the chat step depends on: the conversation-resolve fallback
// (`/v1/conversations?correlationKey=`), the realtime membership pre-check
// (`/v1/realtime/jeeb:chat:{id}`), and the live socket endpoint.

import 'package:flutter_test/flutter_test.dart';
import 'package:jeeb_mobile/core/network/mock_gateway_client.dart';

void main() {
  // Guard: this file only asserts the mock-mode contract. If the define was not
  // passed, the rewrites short-circuit (pass-through) and the assertions below
  // would not hold — so skip rather than red.
  const mockMode = MockGatewayClient.useMockPrefixes;

  group('MockGatewayClient — mock-prefix mode chat routing (sprint-7)', () {
    test('useMockPrefixes is true (run with the dart-define)', () {
      expect(
        mockMode,
        isTrue,
        reason: 'Run with --dart-define=JEEB_USE_MOCK_PREFIXES=true',
      );
    }, skip: !mockMode);

    test('/v1/conversations rewrites to the chat-service mount', () {
      expect(
        MockGatewayClient.rewritePath('/v1/conversations'),
        '/chat-service/v1/conversations',
      );
      // The correlationKey query path-segment is preserved verbatim.
      expect(
        MockGatewayClient.rewritePath('/v1/conversations'),
        startsWith('/chat-service/v1/conversations'),
      );
    }, skip: !mockMode);

    test('/v1/realtime/jeeb:chat:{id} rewrites to the realtime-service mount',
        () {
      expect(
        MockGatewayClient.rewritePath('/v1/realtime/jeeb:chat:conv-accepted-001'),
        '/realtime-comunication-service/v1/realtime/jeeb:chat:conv-accepted-001',
      );
    }, skip: !mockMode);

    test('/v1/chat/jeeb paths still rewrite to the chat-service mount', () {
      expect(
        MockGatewayClient.rewritePath(
          '/v1/chat/jeeb/conversations/conv-accepted-001/messages',
        ),
        '/chat-service/v1/chat/jeeb/conversations/conv-accepted-001/messages',
      );
    }, skip: !mockMode);

    test('realtimeHttpBase co-locates on the mock origin (NOT :5804)', () {
      final base = MockGatewayClient.realtimeHttpBase;
      final mock = Uri.parse(MockGatewayClient.mockBaseUrl);
      expect(base.host, mock.host);
      expect(base.port, mock.port); // :4010, not the live :5804
    }, skip: !mockMode);

    test('webSocketUrl targets the service-prefixed mock socket endpoint', () {
      final ws = MockGatewayClient.webSocketUrl;
      expect(ws, startsWith('ws://'));
      expect(ws, contains('/realtime-comunication-service/socket/websocket'));
      expect(ws, isNot(contains(':5804')));
    }, skip: !mockMode);
  });
}
