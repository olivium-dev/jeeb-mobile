import 'package:dio/dio.dart';

import '../../../core/realtime/realtime_socket_policy.dart';
import '../domain/chat_socket.dart';
import 'live_realtime_chat_socket.dart';

typedef ChatRealtimeSocketFactory =
    ChatSocket Function(
      String conversationId,
      RealtimeChannelDescriptor descriptor,
      Uri socketUri,
    );

class RealtimeChannelDescriptor {
  const RealtimeChannelDescriptor({
    required this.conversationId,
    required this.viewerId,
    required this.topic,
    required this.ticket,
    required this.roleInConvo,
  });

  final String conversationId;

  final String viewerId;

  final String topic;

  final String ticket;

  final String roleInConvo;
}

class ChatRealtimeResolver {
  ChatRealtimeResolver({
    required Dio dio,
    required this.currentUserId,
    Uri? socketBaseUri,
    ChatRealtimeSocketFactory? socketFactory,
    RealtimeSocketPolicy socketPolicy = const RealtimeSocketPolicy(),
  }) : _dio = dio,
       _socketBaseUriOverride = socketBaseUri,
       _socketFactory = socketFactory,
       _socketPolicy = socketPolicy;

  final Dio _dio;
  final String currentUserId;
  final Uri? _socketBaseUriOverride;
  final ChatRealtimeSocketFactory? _socketFactory;
  final RealtimeSocketPolicy _socketPolicy;

  Future<RealtimeChannelDescriptor?> resolve(String conversationId) async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        '/v1/realtime/jeeb:chat:$conversationId',
      );
      return _parse(conversationId, response.data);
    } on DioException {
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<ChatSocket?> connect(String conversationId) async {
    final descriptor = await resolve(conversationId);
    if (descriptor == null) return null;
    if (descriptor.ticket.isEmpty) return null;
    final socketUri = _socketPolicy.configuredUri(
      developmentOverride: _socketBaseUriOverride,
    );
    if (socketUri == null) return null;
    final factory = _socketFactory ?? _buildSocket;
    return factory(conversationId, descriptor, socketUri);
  }

  RealtimeChannelDescriptor? _parse(
    String conversationId,
    Map<String, dynamic>? data,
  ) {
    if (data == null) return null;
    final returnedId =
        (data['conversationId'] ?? data['conversation_id']) as String?;
    final viewerId = data['viewerId'] as String?;
    final topic = (data['topic'] ?? data['Topic']) as String?;
    final role = (data['roleInConvo'] ?? data['role_in_convo']) as String?;
    if (topic == null || topic.isEmpty) return null;
    if (!_bindingAllowed(conversationId, returnedId, viewerId, topic, role)) {
      return null;
    }
    return _descriptorFrom(data, returnedId!, viewerId!, topic, role!);
  }

  RealtimeChannelDescriptor _descriptorFrom(
    Map<String, dynamic> data,
    String conversationId,
    String viewerId,
    String topic,
    String role,
  ) {
    return RealtimeChannelDescriptor(
      conversationId: conversationId,
      viewerId: viewerId,
      topic: topic,
      ticket: (data['ticket'] ?? data['Ticket']) as String? ?? '',
      roleInConvo: role,
    );
  }

  bool _bindingAllowed(
    String requestedId,
    String? returnedId,
    String? viewerId,
    String topic,
    String? role,
  ) =>
      requestedId.isNotEmpty &&
      currentUserId.isNotEmpty &&
      returnedId == requestedId &&
      viewerId == currentUserId &&
      topic == 'jeeb_conversation:$requestedId' &&
      _validRoles.contains(role);

  ChatSocket _buildSocket(
    String conversationId,
    RealtimeChannelDescriptor descriptor,
    Uri socketUri,
  ) {
    return LiveRealtimeChatSocket(
      conversationId: conversationId,
      currentUserId: currentUserId,
      topic: _topicFor(descriptor.topic, conversationId),
      ticket: descriptor.ticket,
      wsUri: socketUri,
    );
  }

  String _topicFor(String descriptorTopic, String _) => descriptorTopic;
}

const _validRoles = <String>{'client', 'jeeber_offerer', 'jeeber_winner'};
