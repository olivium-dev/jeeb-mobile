import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get_it/get_it.dart';

import '../chat/data/dio_chat_gateway.dart';
import '../chat/data/in_memory_chat_gateway.dart';
import '../chat/domain/chat_gateway.dart';
import '../chat/presentation/chat_screen.dart';
import '../photo_attachment/data/stub_photo_picker_service.dart';
import 'dev_chat_detail_fixtures.dart';

/// Deep-link entry point for `/chat/:id`.
///
/// The route param can be a conversation id **or** a delivery/request id.
/// When given a delivery id (e.g. from the In Progress tab), the screen
/// resolves the linked conversation via the `by-request` endpoint before
/// constructing the gateway.
class ChatDetailScreen extends StatefulWidget {
  const ChatDetailScreen({super.key, required this.chatId});

  final String chatId;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen> {
  String _resolvedConversationId = '';
  String _counterpartName = '';
  ChatGateway? _gateway;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _resolveAndBuild();
  }

  @override
  void dispose() {
    final gateway = _gateway;
    if (gateway is DioChatGateway) {
      gateway.dispose();
    }
    super.dispose();
  }

  Future<void> _resolveAndBuild() async {
    // Debug capture aid (screen 13): when the dev seam is driving a seeded
    // client-home tab, a seeded row id (e.g. pen-1) has no live conversation,
    // so route it through the offline fixture gateway — the SAME in-memory
    // mechanism flows 02–07 use — to mount a populated thread without a
    // backend. Always null in release, so production resolution is unchanged.
    final devGateway = DevChatDetailFixtures.resolveGateway(widget.chatId);
    if (devGateway != null) {
      _finalize(widget.chatId, devGateway, '');
      return;
    }

    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) {
      debugPrint(
        '[chat-detail] Dio not registered — falling back to in-memory',
      );
      _finalize(widget.chatId, InMemoryChatGateway(), '');
      return;
    }

    final dio = getIt<Dio>();
    var conversationId = widget.chatId;
    Map<String, dynamic>? conversationData;

    // Try the id as a conversation id first.
    try {
      final resp = await dio.get<Map<String, dynamic>>(
        '/v1/chat/jeeb/conversations/$conversationId',
      );
      conversationData = resp.data;
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        // Not a conversation id — try as a request/delivery id.
        try {
          final byReq = await dio.get<Map<String, dynamic>>(
            '/v1/chat/jeeb/conversations/by-request/${widget.chatId}',
          );
          conversationData = byReq.data;
          conversationId = conversationData?['id'] as String? ?? widget.chatId;
        } on DioException {
          // Neither worked — proceed with the original id.
        }
      }
    }

    final title = await _resolveTitle(dio, conversationData);
    final gateway = DioChatGateway(
      dio: dio,
      currentUserId: 'user-client-001',
    );
    if (!mounted) return;
    _finalize(conversationId, gateway, title);
  }

  Future<String> _resolveTitle(
    Dio dio,
    Map<String, dynamic>? conversationData,
  ) async {
    if (conversationData == null) return '';

    // Try the request title.
    final requestId = conversationData['requestId'] as String?;
    if (requestId != null && requestId.isNotEmpty) {
      try {
        final resp = await dio.get<Map<String, dynamic>>(
          '/v1/requests/$requestId',
        );
        final title = resp.data?['title'] as String?;
        if (title != null && title.isNotEmpty) return title;
      } on DioException {
        // Fall through.
      }
    }

    // Fall back to the winner jeeber name.
    final winnerId = conversationData['winnerJeeberId'] as String?;
    if (winnerId != null && winnerId.isNotEmpty) {
      try {
        final resp = await dio.get<Map<String, dynamic>>(
          '/users/$winnerId',
        );
        return resp.data?['name'] as String? ?? '';
      } on DioException {
        // Fall through.
      }
    }

    return '';
  }

  void _finalize(String conversationId, ChatGateway gateway, String title) {
    if (!mounted) return;
    setState(() {
      _resolvedConversationId = conversationId;
      _gateway = gateway;
      _counterpartName = title;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return ChatScreen(
      deliveryId: _resolvedConversationId,
      counterpartName: _counterpartName,
      gateway: _gateway!,
      pickerService: StubPhotoPickerService(),
    );
  }
}
