import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/chat_socket.dart';
import 'live_realtime_chat_socket.dart';

/// The realtime channel descriptor the gateway hands a member at the
/// `/v1/realtime/jeeb:chat:{conversationId}` membership pre-check
/// (`RealtimeChannelDescriptor`): the per-conversation Phoenix [topic] to join
/// and the short-lived signed membership [ticket] the client presents on the
/// WS join params. The gateway never opens the socket — it runs the
/// chat-service membership check and mints the ticket.
class RealtimeChannelDescriptor {
  const RealtimeChannelDescriptor({
    required this.conversationId,
    required this.topic,
    required this.ticket,
    this.roleInConvo,
  });

  final String conversationId;

  /// Per-conversation Phoenix topic (`jeeb_conversation:<conversation_id>`).
  final String topic;

  /// Gateway-minted membership ticket (may be empty if minting was unavailable).
  final String ticket;

  final String? roleInConvo;
}

/// Resolves the per-conversation realtime channel from the gateway and builds a
/// [LiveRealtimeChatSocket] bound to it.
///
/// CHAT-CONTRACT (iter6): the canonical realtime join is membership-authorized.
/// The client does NOT self-mint a token and does NOT join a global topic —
/// it asks the gateway (`GET /v1/realtime/jeeb:chat:{conversationId}`) for the
/// per-conversation [RealtimeChannelDescriptor.topic] + [ticket], then joins
/// THAT topic with THAT ticket. A non-member is rejected by the gateway with
/// 403 (`not_in_membership`) — we surface that as "no live socket" and the
/// thread degrades to HTTP history.
class ChatRealtimeResolver {
  ChatRealtimeResolver({
    required Dio dio,
    required this.currentUserId,
    Uri? socketBaseUri,
  })  : _dio = dio,
        _socketBaseUri =
            socketBaseUri ?? Uri.parse(MockGatewayClient.webSocketUrl);

  final Dio _dio;
  final String currentUserId;
  final Uri _socketBaseUri;

  /// Fetch the gateway realtime descriptor for [conversationId]. Returns null
  /// on any failure (non-member 403, flag-off 503, transport) so the caller
  /// degrades to HTTP-history-only without throwing.
  Future<RealtimeChannelDescriptor?> resolve(String conversationId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/v1/realtime/jeeb:chat:$conversationId',
      );
      final data = resp.data;
      if (data == null) return null;
      // The gateway DTO (no STJ rename annotations) serializes camelCase:
      // {conversationId, topic, roleInConvo, ticket}. Accept snake_case too.
      final topic = (data['topic'] ?? data['Topic']) as String?;
      if (topic == null || topic.isEmpty) return null;
      return RealtimeChannelDescriptor(
        conversationId:
            (data['conversationId'] ?? data['conversation_id']) as String? ??
                conversationId,
        topic: topic,
        ticket: (data['ticket'] ?? data['Ticket']) as String? ?? '',
        roleInConvo:
            (data['roleInConvo'] ?? data['role_in_convo']) as String?,
      );
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// Resolve the descriptor and build the per-conversation socket. Returns null
  /// when the descriptor cannot be resolved (degrade-don't-fail).
  Future<ChatSocket?> connect(String conversationId) async {
    final descriptor = await resolve(conversationId);
    if (descriptor == null) return null;
    return LiveRealtimeChatSocket(
      conversationId: conversationId,
      currentUserId: currentUserId,
      topic: descriptor.topic,
      ticket: descriptor.ticket,
      wsUri: _socketBaseUri,
    );
  }
}
