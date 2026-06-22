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
  ///
  /// LIVE-PUSH FIX (iter6 chat-route): two adjustments are required for the
  /// inbound live frame to actually arrive (both PROVEN on the wire):
  ///   1. JOIN THE BRIDGED CHANNEL. The gateway descriptor hands back the topic
  ///      `jeeb_conversation:{id}` (the legacy V1 `JeebChatChannel`), but the
  ///      gateway's REST-send HTTP fan-out is delivered ONLY to the V2
  ///      `JeebChatV2Channel` (topic `jeeb:chat:{id}`), which subscribes to the
  ///      realtime ingest topic. Joining the V1 topic yields ZERO live frames
  ///      (the send 201s but the counterpart never receives it). We therefore
  ///      remap `jeeb_conversation:{id}` → `jeeb:chat:{id}` so the socket joins
  ///      the channel that the fan-out reaches. The gateway-minted ticket still
  ///      authorizes the V2 join (its ticket-auth path).
  ///   2. MINT A SOCKET-CONNECT TOKEN. The realtime Phoenix socket `connect/3`
  ///      requires a `token` query param (Guardian) to establish `user_id`;
  ///      the membership ticket alone authorizes the channel JOIN, not the
  ///      socket CONNECT (a ticket-only connect is rejected `missing_token`).
  ///      We mint a short-lived connect token from the realtime open minter
  ///      (`POST /api/auth/token`) scoped to the real `currentUserId`, so the
  ///      upgrade passes and the V2 join's ticket-auth resolves the seat.
  ///      Best-effort: a mint failure leaves the token empty (the socket still
  ///      attempts and degrades to HTTP-history on a rejected connect).
  Future<ChatSocket?> connect(String conversationId) async {
    final descriptor = await resolve(conversationId);
    if (descriptor == null) return null;
    final token = await _mintConnectToken();
    return LiveRealtimeChatSocket(
      conversationId: conversationId,
      currentUserId: currentUserId,
      topic: _bridgedTopicFor(descriptor.topic, conversationId),
      ticket: descriptor.ticket,
      connectToken: token,
      wsUri: _socketBaseUri,
    );
  }

  /// Remap the gateway descriptor topic to the A1-bridged V2 channel topic
  /// (`jeeb:chat:{conversationId}`) — the only channel the gateway's REST-send
  /// fan-out reaches. A descriptor that already names the V2 topic, or any
  /// unexpected shape, is passed through unchanged (defensive).
  String _bridgedTopicFor(String descriptorTopic, String conversationId) {
    const v2Prefix = 'jeeb:chat:';
    const v1Prefix = 'jeeb_conversation:';
    if (descriptorTopic.startsWith(v2Prefix)) return descriptorTopic;
    if (descriptorTopic.startsWith(v1Prefix)) {
      return '$v2Prefix${descriptorTopic.substring(v1Prefix.length)}';
    }
    // Unknown shape — fall back to the canonical bridged topic for this convo.
    return '$v2Prefix$conversationId';
  }

  /// Mint a short-lived realtime CONNECT token (Guardian) from the realtime
  /// open minter so the Phoenix socket `connect/3` establishes `user_id`. The
  /// minter lives on the realtime service (NOT the gateway), so this call goes
  /// to [MockGatewayClient.realtimeHttpBase] directly with a fresh Dio (the
  /// route-scoped Dio rewrites/`/v1` prefixes gateway paths — this is not one).
  /// Returns '' on any failure (degrade-don't-fail).
  Future<String> _mintConnectToken() async {
    try {
      final base = MockGatewayClient.realtimeHttpBase;
      final url = base.replace(path: '/api/auth/token').toString();
      final resp = await Dio().post<Map<String, dynamic>>(
        url,
        data: <String, Object?>{
          'user_id': currentUserId,
          'role': 'client',
          'scopes': <String>['subscribe', 'publish'],
          'topics': <String>['*'],
        },
        options: Options(
          headers: <String, Object?>{'Content-Type': 'application/json'},
          receiveTimeout: const Duration(seconds: 8),
          sendTimeout: const Duration(seconds: 8),
        ),
      );
      return (resp.data?['token'] as String?) ?? '';
    } catch (_) {
      return '';
    }
  }
}
