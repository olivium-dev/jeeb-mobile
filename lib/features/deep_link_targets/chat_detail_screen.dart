import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/network/auth_token_store.dart';
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
/// The route param is the REQUEST id (the order / create-flow
/// `location_select_confirm_cta` push it — see `client_location_screen`). The
/// request id is the conversation's CORRELATION KEY, never the conversation id.
/// CHAT-CONTRACT (iter6): the screen resolves it to the server-minted
/// `conversation_id` via `POST /v1/chat/jeeb/conversations` (create-or-get) — or
/// `GET /v1/conversations?correlationKey={request_id}` — BEFORE constructing the
/// gateway, so every message path uses the real conversation id (no more
/// request-id-as-conversation-id 404, no non-existent `by-request` route).
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
  /// The create-flow compose sentinel id the location step hands off
  /// (`client_location_screen` → `pushNamed('chat-detail', {'id': 'new'})`).
  /// ONLY this entry is allowed to broadcast on the first message (JM-025 AC1).
  static const String _composeSentinelId = 'new';

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

    // CHAT-CONTRACT (iter6): the route param `widget.chatId` is the REQUEST id
    // (the create-flow / order routes push it — see client_location_screen).
    // The request id is NOT a conversation id — it is the conversation's
    // CORRELATION KEY only. We MUST resolve it to the server-minted
    // `conversation_id` BEFORE any messaging (the prior code used the request
    // id directly as the conversation id → POST .../conversations/<REQUEST_ID>
    // → 404, and the `by-request` route does not exist on the gateway).
    //
    // Bind the gateway to the REAL authenticated user id so the local user's
    // own bubbles align right (`senderId == currentUserId`). It is also the
    // `client_user_id` the create-or-get needs.
    final currentUserId =
        (await AuthTokenStore().userId) ?? 'user-client-001';
    final requestId = widget.chatId;

    // CREATE-FLOW sentinel (`new`): the compose leg lands here BEFORE a request
    // exists (it broadcasts on the first message — JM-025 AC1), so there is no
    // request_id to resolve a conversation by. Skip the resolve and keep the
    // sentinel; `_isCreateFlow` gates the broadcast-on-first-message path.
    Map<String, dynamic>? conversationData;
    if (requestId != _composeSentinelId) {
      // Resolve correlation(request_id) → conversation_id (+ phase +
      // participants) via the canonical create-or-get. Returns null when the
      // surface is unavailable (flag off / transport) — we degrade rather than
      // 404 a send.
      conversationData =
          await _resolveConversation(dio, requestId, currentUserId);
    }
    final conversationId =
        conversationData?['conversation_id'] as String? ?? widget.chatId;

    final title = await _resolveTitle(dio, requestId, conversationData);
    final phase = ConversationPhase.fromWire(
      conversationData?['phase'] as String?,
    );
    final hasWinner = _hasWinningJeeber(conversationData);

    // JM-025 AC2: resolve the locked pinned summary for an accepted order. The
    // fetch is best-effort — a failure leaves `_summary` null and the strip
    // simply doesn't render (it never blocks the chat thread).
    OrderChatSummary? summary;
    if (phase == ConversationPhase.accepted || hasWinner) {
      summary = await _resolveSummary(dio, requestId, conversationId);
    }

    // The gateway is bound to the REAL bearer id (resolved above) and the REAL
    // server-minted `conversationId` — so `send`/`loadHistory`/`subscribe` all
    // hit `/v1/conversations/{conversationId}/...` (canonical), and the local
    // user's own bubbles align right (`senderId == currentUserId`).
    final gateway = DioChatGateway(
      dio: dio,
      currentUserId: currentUserId,
      // Thread the authoritative create-or-get phase into the gateway so its
      // `loadPhase` echoes the REAL phase (the per-message route carries none).
      // A `broadcasting`/`unknown` (no-jeeber-yet) conversation must NOT report
      // `accepted`, or the chat flashes the premature "Offer accepted!" banner.
      initialPhase: phase,
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

  /// CHAT-CONTRACT (iter6): create-or-get the conversation for [requestId].
  ///
  /// Canonical sequence (the same create→id sequencing rahma-fe uses):
  ///   1. `POST /v1/chat/jeeb/conversations {request_id, client_user_id}`
  ///      (Idempotency-Key == request_id) — idempotent get-or-create that
  ///      returns the distinct `{conversation_id, phase, participants[]}`.
  ///   2. If create is rejected (e.g. the caller is the jeeber, not the owner),
  ///      fall back to `GET /v1/conversations?correlationKey={request_id}` to
  ///      resolve the existing conversation_id.
  /// Returns null only when neither resolves (surface unavailable) — the screen
  /// then degrades to the original id rather than blocking the thread.
  Future<Map<String, dynamic>?> _resolveConversation(
    Dio dio,
    String requestId,
    String clientUserId,
  ) async {
    // 1) create-or-get.
    try {
      final resp = await dio.post<Map<String, dynamic>>(
        '/v1/chat/jeeb/conversations',
        data: <String, Object?>{
          'request_id': requestId,
          'client_user_id': clientUserId,
        },
        options: Options(
          headers: <String, Object?>{'Idempotency-Key': requestId},
        ),
      );
      final data = resp.data;
      if (data != null && data['conversation_id'] != null) return data;
    } on DioException {
      // Fall through to the correlation lookup.
    }

    // 2) resolve by correlation key (request id).
    try {
      final resp = await dio.get<Map<String, dynamic>>(
        '/v1/conversations',
        queryParameters: <String, Object?>{'correlationKey': requestId},
      );
      final data = resp.data;
      if (data != null && data['conversation_id'] != null) return data;
    } on DioException {
      // Neither path resolved — degrade.
    }
    return null;
  }

  /// True when the conversation has a winning jeeber participant
  /// (`role_in_convo == jeeber_winner`) — the canonical post-accept signal that
  /// replaces the old `winnerJeeberId` projection.
  bool _hasWinningJeeber(Map<String, dynamic>? conversationData) {
    final participants = conversationData?['participants'];
    if (participants is! List) return false;
    return participants.whereType<Map>().any((p) {
      final role = p['role_in_convo'] as String?;
      final removedAt = p['removed_at'];
      return role == 'jeeber_winner' && removedAt == null;
    });
  }

  Future<String> _resolveTitle(
    Dio dio,
    String requestId,
    Map<String, dynamic>? conversationData,
  ) async {
    // Try the request title.
    if (requestId.isNotEmpty && requestId != _composeSentinelId) {
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

    // Fall back to the winning jeeber's name (canonical participants[]).
    final winnerId = _winningJeeberId(conversationData);
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

  /// The `user_id` of the active winning jeeber participant, or null.
  String? _winningJeeberId(Map<String, dynamic>? conversationData) {
    final participants = conversationData?['participants'];
    if (participants is! List) return null;
    for (final p in participants.whereType<Map>()) {
      if (p['role_in_convo'] == 'jeeber_winner' && p['removed_at'] == null) {
        return p['user_id'] as String?;
      }
    }
    return null;
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

  /// True only when this screen was entered through the create-request flow
  /// (`client_location_screen` → `pushNamed('chat-detail', {'id': 'new'})`),
  /// i.e. the documented `new` compose sentinel (50_ROUTE_REQUESTS — JM-024 →
  /// JM-025 hand-off). The create leg routes here with the literal id `new`
  /// and there is no pre-existing conversation to resolve, so the resolved id
  /// stays `new`. ONLY this entry may broadcast on the first message.
  ///
  /// CHAT-FIX (iter6): a conversation's `broadcasting` PHASE is NOT the same as
  /// the create-flow compose entry. Every conversation starts (and stays) in
  /// `broadcasting` until an offer is accepted, so keying compose purely on
  /// `phase != accepted/closed` made EVERY first message into an EXISTING
  /// broadcasting thread (opened from the chat tab / replies / live-tracking)
  /// re-broadcast the request and route to `waiting-no-coverage` — yanking the
  /// user out of a working chat with "We couldn't load your request status".
  /// Gating compose on the `new` sentinel restores normal chatting in a
  /// broadcasting conversation while preserving the genuine create→broadcast
  /// leg (JM-025 AC1).
  bool get _isCreateFlow =>
      widget.chatId == _composeSentinelId ||
      _resolvedConversationId == _composeSentinelId;

  /// JM-025 AC1: compose state — the create-flow first message broadcasts the
  /// request and routes to `waiting-no-coverage`. Restricted to the genuine
  /// create entry (`_isCreateFlow`); an EXISTING broadcasting conversation is
  /// a normal chat thread, never a compose/broadcast surface.
  bool _isComposeState(bool isJeeber) =>
      !isJeeber &&
      _isCreateFlow &&
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
      // Seed the cubit's first-paint phase with the authoritative phase this
      // screen already resolved (create-or-get), so a not-yet-accepted
      // (`broadcasting`/`pending`, no jeeber) conversation shows the honest
      // waiting state — NOT the premature "Offer accepted!" banner. The live
      // `PhaseChanged(accepted)` event then flips it to accepted reactively.
      initialPhase: _phase,
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
