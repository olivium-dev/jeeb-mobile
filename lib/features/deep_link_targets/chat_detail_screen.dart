import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
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

  /// The delivery/request id this conversation is bound to (mock convention:
  /// `deliveryId == accepted-request-id`). Captured from `conversationData`
  /// during resolution and used as the jeeber's active-delivery route param.
  /// Empty when the conversation carries no `requestId`.
  String _resolvedRequestId = '';
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
    // Mock convention: deliveryId == accepted-request-id. Prefer the
    // conversation's requestId; the jeeber's "Start delivery" CTA pushes
    // `/jeeber/deliveries/<id>/active` with this value (build() falls back to
    // the resolved conversation id when no requestId is present).
    final requestId = conversationData?['requestId'] as String? ?? '';
    final gateway = DioChatGateway(
      dio: dio,
      currentUserId: 'user-client-001',
    );
    if (!mounted) return;
    _finalize(conversationId, gateway, title, requestId: requestId);
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

  void _finalize(
    String conversationId,
    ChatGateway gateway,
    String title, {
    String requestId = '',
  }) {
    if (!mounted) return;
    setState(() {
      _resolvedConversationId = conversationId;
      _gateway = gateway;
      _counterpartName = title;
      _resolvedRequestId = requestId;
      _loading = false;
    });
  }

  /// Reads the active [UserRole] from the app-global [RoleCubit]. Returns
  /// [UserRole.client] when the cubit is not an ancestor (e.g. an isolated
  /// host or widget test), so the screen degrades to the safe client variant
  /// instead of throwing [ProviderNotFoundException].
  UserRole _readRole(BuildContext context) {
    try {
      return context.read<RoleCubit>().state;
    } on ProviderNotFoundException {
      return UserRole.client;
    }
  }

  /// Best-available delivery identifier for the active-delivery route. Prefers
  /// the conversation's `requestId` (mock convention: `deliveryId ==
  /// accepted-request-id`), falling back to the resolved conversation id.
  String get _deliveryId =>
      _resolvedRequestId.isNotEmpty
          ? _resolvedRequestId
          : _resolvedConversationId;

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(body: Center(child: OmdsLoadingState()));
    }
    // Role-aware entry point: a jeeber whose offer was accepted lands here via
    // `/chat/:id` and must be able to start the delivery. RoleCubit is provided
    // app-wide (MultiBlocProvider in JeebApp, above MaterialApp.router), so it
    // is an ancestor of every route the router builds — read it directly. We
    // default to the client variant (null callback, prior behavior) when the
    // cubit is absent from the tree, so non-app-rooted hosts (e.g. the dev
    // capture seam, isolated widget tests) degrade safely rather than throw.
    final isJeeber = _readRole(context) == UserRole.jeeber;
    return ChatScreen(
      deliveryId: _resolvedConversationId,
      counterpartName: _counterpartName,
      gateway: _gateway!,
      pickerService: StubPhotoPickerService(),
      onStartActiveDelivery: isJeeber
          ? () => context.push('/jeeber/deliveries/$_deliveryId/active')
          : null,
    );
  }
}
