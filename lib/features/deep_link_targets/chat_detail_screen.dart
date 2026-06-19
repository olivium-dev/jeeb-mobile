import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/role/role_cubit.dart';
import '../../core/role/user_role.dart';
import '../chat/data/dev_chat_fixture_gateway.dart';
import '../chat/data/dio_chat_gateway.dart';
import '../chat/data/dio_order_broadcast_service.dart';
import '../chat/data/dio_order_chat_summary_repository.dart';
import '../chat/data/in_memory_chat_gateway.dart';
import '../chat/domain/chat_gateway.dart';
import '../chat/domain/delivery_chat_message.dart';
import '../chat/domain/order_broadcast_service.dart';
import '../chat/domain/order_chat_summary.dart';
import '../chat/presentation/chat_screen.dart';
import '../photo_attachment/data/stub_photo_picker_service.dart';
import 'dev_chat_detail_fixtures.dart';

/// Deep-link entry point for `/chat/:id` — the `order-chat` surface (JM-025).
///
/// The route param can be a conversation id **or** a delivery/request id.
/// When given a delivery/request id (e.g. from the In Progress tab or the
/// create-flow `location_select_confirm_cta`), the screen resolves the linked
/// conversation via the `by-request` endpoint before constructing the gateway.
///
/// The resolved conversation phase + winner drive the JM-025 order-chat states:
///   * **compose / broadcasting** (client, no winner): the first message the
///     client sends broadcasts the request and routes to `waiting-no-coverage`
///     (JM-026, D83) — AC1.
///   * **accepted** (winner present): the pinned locked-price summary strip
///     (`order_chat_pinned_summary`) shows + `order_chat_view_summary_link` →
///     `order-summary-pinned` (JM-031), and `order_chat_open_dispute` →
///     `dispute-open-evidence` (the `escalate` route, JM-060) — AC2/AC3.
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
  /// during resolution and used as the jeeber's active-delivery route param,
  /// the pinned-summary fetch id, and the broadcast/waiting route id.
  String _resolvedRequestId = '';

  /// Conversation phase resolved at mount. Drives the JM-025 state branch:
  /// `broadcasting` (+ no winner) → compose, `accepted` → pinned summary +
  /// dispute. Defaults to unknown until resolution completes.
  ConversationPhase _phase = ConversationPhase.unknown;

  /// True when the resolved conversation has a winning Jeeber (the accept
  /// system message / `winnerJeeberId`). Distinguishes the accepted state from
  /// the broadcasting compose state.
  bool _hasWinner = false;

  /// JM-025 AC2: locked summary for the accepted order. Null in compose state
  /// or when the fetch could not resolve one (the strip then hides).
  OrderChatSummary? _summary;

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
      // Thread the fixture's own phase through so the screen's compose/accepted
      // logic matches the seeded thread. Without this, an accepted-phase
      // fixture defaults to `_phase == unknown`, the client `_isComposeState`
      // turns TRUE, and the seeded outgoing message fires the first-message
      // broadcast → `goNamed('waiting-no-coverage')` on mount (crashes any host
      // without a GoRouter, e.g. the dev capture seam / isolated widget tests).
      final devPhase = devGateway is DevChatFixtureGateway
          ? devGateway.phase
          : ConversationPhase.unknown;
      _finalize(
        widget.chatId,
        devGateway,
        '',
        phase: devPhase,
        hasWinner: devPhase == ConversationPhase.accepted,
      );
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
          // Neither worked — proceed with the original id (fresh compose: the
          // create-leg may have routed here with a request id whose
          // conversation is created lazily on first send).
        }
      }
    }

    final title = await _resolveTitle(dio, conversationData);
    // Mock convention: deliveryId == accepted-request-id. Prefer the
    // conversation's requestId; the jeeber's "Start delivery" CTA + the pinned
    // summary fetch + the broadcast/waiting route use this value (build()
    // falls back to the resolved conversation id when absent).
    final requestId = conversationData?['requestId'] as String? ?? '';
    final phase = ConversationPhase.fromWire(
      conversationData?['phase'] as String?,
    );
    final winnerId = conversationData?['winnerJeeberId'] as String?;
    final hasWinner = winnerId != null && winnerId.isNotEmpty;

    // JM-025 AC2: resolve the locked pinned summary for an accepted order. The
    // fetch is best-effort — a failure leaves `_summary` null and the strip
    // simply doesn't render (it never blocks the chat thread).
    OrderChatSummary? summary;
    if (phase == ConversationPhase.accepted || hasWinner) {
      summary = await _resolveSummary(dio, requestId, conversationId);
    }

    final gateway = DioChatGateway(
      dio: dio,
      currentUserId: 'user-client-001',
    );
    if (!mounted) return;
    _finalize(
      conversationId,
      gateway,
      title,
      requestId: requestId,
      phase: phase,
      hasWinner: hasWinner,
      summary: summary,
    );
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

  /// Fetches the locked pinned summary for the accepted order. Self-provides a
  /// [DioOrderChatSummaryRepository] over the route-scoped [Dio] (the screen
  /// layer is the only place allowed to touch DI — 40_GUARDRAILS_ARCH §1).
  /// Returns null on any failure so the strip degrades gracefully.
  Future<OrderChatSummary?> _resolveSummary(
    Dio dio,
    String requestId,
    String conversationId,
  ) async {
    final summaryId = requestId.isNotEmpty ? requestId : conversationId;
    if (summaryId.isEmpty) return null;
    try {
      return await DioOrderChatSummaryRepository(dio).fetchSummary(summaryId);
    } on OrderChatSummaryException {
      return null;
    } catch (_) {
      return null;
    }
  }

  void _finalize(
    String conversationId,
    ChatGateway gateway,
    String title, {
    String requestId = '',
    ConversationPhase phase = ConversationPhase.unknown,
    bool hasWinner = false,
    OrderChatSummary? summary,
  }) {
    if (!mounted) return;
    setState(() {
      _resolvedConversationId = conversationId;
      _gateway = gateway;
      _counterpartName = title;
      _resolvedRequestId = requestId;
      _phase = phase;
      _hasWinner = hasWinner;
      _summary = summary;
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

  /// Best-available delivery identifier for the active-delivery / summary /
  /// tracking routes. Prefers the conversation's `requestId` (mock convention:
  /// `deliveryId == accepted-request-id`), falling back to the resolved
  /// conversation id.
  String get _deliveryId =>
      _resolvedRequestId.isNotEmpty
          ? _resolvedRequestId
          : _resolvedConversationId;

  /// JM-025 AC1: compose state — a client thread that has NOT yet matched a
  /// Jeeber (broadcasting / unknown phase, no winner). The first message
  /// broadcasts the request and routes to `waiting-no-coverage`.
  bool _isComposeState(bool isJeeber) =>
      !isJeeber &&
      !_hasWinner &&
      _phase != ConversationPhase.accepted &&
      _phase != ConversationPhase.closed;

  /// JM-025 AC1: broadcast the request, then route to `waiting-no-coverage`
  /// (JM-026). Self-provides the [OrderBroadcastService] over the route Dio.
  /// Fail-safe: even if the broadcast call errors we still route to waiting
  /// (the request is already pending), so the user is never stuck in compose.
  Future<void> _broadcastAndGoWaiting(String requestId) async {
    final id = requestId.isNotEmpty ? requestId : _deliveryId;
    final getIt = GetIt.instance;
    if (getIt.isRegistered<Dio>()) {
      final service = _resolveBroadcastService(getIt<Dio>());
      try {
        await service.broadcast(conversationId: id, requestId: id);
      } on OrderBroadcastException {
        // Soft-fail — the request is pending; the waiting screen will reflect
        // coverage from its own fetch. Do not block the route.
      } catch (_) {
        // Same — never trap the user in compose on a broadcast hiccup.
      }
    }
    if (!mounted) return;
    // EDGE: order-chat (compose) → waiting-no-coverage (JM-026,
    // 21_NAV_PLAN §C). Route is registered by the W1 integrator.
    context.goNamed('waiting-no-coverage', pathParameters: {'id': id});
  }

  OrderBroadcastService _resolveBroadcastService(Dio dio) =>
      DioOrderBroadcastService(dio);

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
    final compose = _isComposeState(isJeeber);
    // JM-025 AC2: the pinned locked-price summary only renders once an offer is
    // accepted (winner present / phase `accepted`), never on the Jeeber variant
    // or compose.
    final isClientAccepted =
        !isJeeber && (_phase == ConversationPhase.accepted || _hasWinner);
    // JM-025 AC3: the dispute affordance is valid on the client's accepted AND
    // in-flight (active/in-transit) order. An active delivery is tracked on the
    // delivery, not the conversation, so its conversation phase may not literally
    // read `accepted` — it lands as `unknown` here. So treat any client thread
    // that is past compose and not closed (i.e. accepted/active) as disputable.
    // This keeps the active-delivery seam (jeeb.seam.journey=active_delivery)
    // honest: order_chat_open_dispute renders even when the conversation phase is
    // not literally `accepted`. The ChatScreen applies the same widened gate.
    final isClientDisputable = !isJeeber &&
        !compose &&
        _phase != ConversationPhase.broadcasting &&
        _phase != ConversationPhase.closed;

    return ChatScreen(
      deliveryId: _resolvedConversationId,
      counterpartName: _counterpartName,
      gateway: _gateway!,
      pickerService: StubPhotoPickerService(),
      // JM-025: this is the customer order-chat surface → expose the
      // `order_chat_composer_*` ids the W1 flow drives.
      isOrderChat: !isJeeber,
      onStartActiveDelivery: isJeeber
          ? () => context.push('/jeeber/deliveries/$_deliveryId/active')
          : null,
      // Client-only: once the accept surfaces a delivery id, the chat banner's
      // "Track order" CTA routes to live tracking (`/orders/:id/tracking`,
      // route `live-tracking`). Null on the Jeeber variant (Jeeber starts the
      // delivery instead). ChatScreen only invokes this when the delivery id
      // is available, so the CTA is never a dead end.
      onTrackOrder: isJeeber
          ? null
          : (deliveryId) => context.push('/orders/$deliveryId/tracking'),
      // JM-025 AC1 (D83): compose → broadcast → waiting-no-coverage. Only wired
      // for the client compose state; null otherwise (no compose entry).
      onFirstMessageBroadcast:
          compose ? (requestId) => _broadcastAndGoWaiting(requestId) : null,
      // JM-025 AC2: pinned locked-price summary + view-summary link.
      pinnedSummary: isClientAccepted ? _summary : null,
      onViewSummary: isClientAccepted
          // EDGE: order_chat_view_summary_link → order-summary-pinned (JM-031,
          // route `order-summary`). 21_NAV_PLAN §C.
          ? () => context.pushNamed(
                'order-summary',
                pathParameters: {'id': _deliveryId},
              )
          : null,
      // JM-025 AC3: dispute affordance → dispute-open-evidence. The
      // `escalate` route (`/orders/:id/escalate`) IS the dispute-open-evidence
      // target (20_GAP_MAP reconciliation note 8; JM-060 extends it). Wired for
      // the client's accepted/active order (see `isClientDisputable`).
      onOpenDispute: isClientDisputable
          ? () => context.pushNamed(
                'escalate',
                pathParameters: {'id': _deliveryId},
              )
          : null,
    );
  }
}
