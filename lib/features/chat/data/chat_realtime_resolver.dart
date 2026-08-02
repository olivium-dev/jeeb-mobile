import 'package:dio/dio.dart';

import '../../../core/network/mock_gateway_client.dart';
import '../domain/chat_socket.dart';
import 'live_realtime_chat_socket.dart';

class RealtimeChannelDescriptor {
  const RealtimeChannelDescriptor({
    required this.conversationId,
    required this.topic,
    required this.ticket,
    this.roleInConvo,
  });

  final String conversationId;

  final String topic;

  final String ticket;

  final String? roleInConvo;
}

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
        roleInConvo:
            (data['roleInConvo'] ?? data['role_in_convo']) as String?,
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

  String _bridgedTopicFor(String descriptorTopic, String conversationId) {
    const v2Prefix = 'jeeb:chat:';
    const v1Prefix = 'jeeb_conversation:';
    if (descriptorTopic.startsWith(v2Prefix)) return descriptorTopic;
    if (descriptorTopic.startsWith(v1Prefix)) {
      return '$v2Prefix${descriptorTopic.substring(v1Prefix.length)}';
    }
    return '$v2Prefix$conversationId';
  }

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
