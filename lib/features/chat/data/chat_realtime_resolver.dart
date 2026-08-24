import 'package:dio/dio.dart';

import '../../../core/config/app_config.dart';
import '../domain/chat_socket.dart';
import 'live_realtime_chat_socket.dart';

class RealtimeChannelDescriptor {
  const RealtimeChannelDescriptor({
    required this.conversationId,
    required this.topic,
    required this.ticket,
    required this.connectToken,
    required this.socketUrl,
    this.roleInConvo,
  });

  final String conversationId;

  final String topic;

  final String ticket;

  final String connectToken;

  final String socketUrl;

  final String? roleInConvo;
}

class ChatRealtimeResolver {
  ChatRealtimeResolver({
    required Dio dio,
    required this.currentUserId,
    Uri? socketBaseUri,
  }) : _dio = dio,
       _socketBaseUriOverride = socketBaseUri;

  final Dio _dio;
  final String currentUserId;
  final Uri? _socketBaseUriOverride;

  Future<RealtimeChannelDescriptor?> resolve(String conversationId) async {
    try {
      final resp = await _dio.get<Map<String, dynamic>>(
        '/v1/realtime/jeeb:chat:$conversationId',
      );
      final data = resp.data;
      if (data == null) return null;
      final topic = (data['topic'] ?? data['Topic']) as String?;
      if (topic == null || topic.isEmpty) return null;
      return RealtimeChannelDescriptor(
        conversationId:
            (data['conversationId'] ?? data['conversation_id']) as String? ??
            conversationId,
        topic: topic,
        ticket: (data['ticket'] ?? data['Ticket']) as String? ?? '',
        connectToken:
            (data['connectToken'] ?? data['connect_token'] ?? data['token'])
                as String? ??
            '',
        socketUrl: (data['socketUrl'] ?? data['socket_url']) as String? ?? '',
        roleInConvo: (data['roleInConvo'] ?? data['role_in_convo']) as String?,
      );
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ChatSocket?> connect(String conversationId) async {
    final descriptor = await resolve(conversationId);
    if (descriptor == null) return null;
    if (descriptor.ticket.isEmpty || descriptor.connectToken.isEmpty) {
      return null;
    }
    final socketUri =
        _socketBaseUriOverride ?? _validatedSocketUri(descriptor.socketUrl);
    if (socketUri == null) return null;
    return LiveRealtimeChatSocket(
      conversationId: conversationId,
      currentUserId: currentUserId,
      topic: _bridgedTopicFor(descriptor.topic, conversationId),
      ticket: descriptor.ticket,
      connectToken: descriptor.connectToken,
      wsUri: socketUri,
    );
  }

  Uri? _validatedSocketUri(String raw) {
    if (raw.isEmpty) return null;
    final uri = Uri.tryParse(raw);
    if (uri == null || uri.host.isEmpty) return null;
    if (uri.scheme == 'wss') return uri;
    if (uri.scheme == 'ws' && AppConfig.isDevelopmentFlavor) return uri;
    return null;
  }

  String _bridgedTopicFor(String descriptorTopic, String conversationId) {
    const v2Prefix = 'jeeb:chat:';
    const v1Prefix = 'jeeb_conversation:';
    if (descriptorTopic.startsWith(v2Prefix)) return descriptorTopic;
    if (descriptorTopic.startsWith(v1Prefix)) {
      return '$v2Prefix${descriptorTopic.substring(v1Prefix.length)}';
    }
    return '$v2Prefix$conversationId';
  }
}
