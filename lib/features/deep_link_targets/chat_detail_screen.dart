import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/delivery/delivery_status_vocab.dart';
import '../../core/di/injection_container.dart';
import '../../core/formatting/friendly_reference.dart';
import '../../core/network/auth_token_store.dart';
import '../../core/notifications/domain/active_chat_thread.dart';
import '../../core/role/role_cubit.dart';
import '../../core/router/app_route_observer.dart';
import '../../core/role/user_role.dart';
import '../../l10n/app_localizations.dart';
import '../chat/application/order_compose_coordinator.dart';
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
import '../kyc/domain/cdn_asset_gateway.dart';
import '../otp_handover/domain/handover_code_store.dart';
import '../photo_attachment/data/stub_photo_picker_service.dart';
import '../photo_attachment/domain/photo_picker_service.dart';
import '../request_summary/data/dio_request_submission_service.dart';
import '../request_summary/domain/recipient_phone_resolver.dart';
import 'dev_chat_detail_fixtures.dart';

// The 60s `kChatSummarySafetyNetPollInterval` that used to live here is GONE.
// A "bounded, lifecycle-gated safety net" is still a repeated call: if the user
// does nothing and no push arrives, a second network call happened, which the
// owner's rule bans at ANY interval. Worse, each tick fanned out into THREE
// gateway reads (`fetchSummary` → deliveries/{id} + requests/{id} + offers), so
// it was three repeated calls, not one. The pinned status chip is now driven by
// the `delivery` push (proven arriving on physical hardware) plus one-shot reads
// on open, on returning to this route, and on foreground resume.

/// Canonical post-delivery blind mutual-rating route (T-MOB-020). Mirrors the
/// builder the OTP-handover completion uses (`otp_handover_screen.dart`): the
/// client leg carries no `mode`, the jeeber leg appends `?mode=jeeber`, and the
/// router resolves `isClient = mode != 'jeeber'`. Kept as a tiny local helper
/// so this screen never hard-codes the audience suffix in two places.
String _mutualRateRoute(String deliveryId, {required bool isClient}) =>
    '/orders/$deliveryId/mutual-rate${isClient ? '' : '?mode=jeeber'}';

/// Deep-link entry point for `/chat/:id` — the `order-chat` surface (JM-025).
///
/// The route param can be a conversation id **or** a delivery/request id.
/// When given a delivery/request id (e.g. from the In Progress tab, an accepted
/// order, or the create-flow `location_select_confirm_cta`), the screen
/// resolves the linked conversation against the LIVE gateway contract — first
/// `GET /v1/conversations?correlationKey={requestId}` (correlationKey ==
/// request id), then a `GET /v1/conversations/{id}/messages` 200 probe when the
/// param is already a conversation id — before constructing the gateway. (The
/// old `/v1/chat/jeeb/conversations/{id}` + `/by-request` prefix is create-only
/// and 404s on live, so it is no longer used for resolution.)
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
  const ChatDetailScreen({
    super.key,
    required this.chatId,
    this.debugGateway,
    this.debugPhase,
    this.debugHasWinner = false,
    this.debugSummary,
    this.debugCounterpartName = '',
    this.refreshSignals,
  });

  final String chatId;

  /// JEBV4-282 / b02 wave B.2: the push→refetch bus that advances the pinned
  /// delivery-status chip (Ordered→Picked→InTransit→AtDoor→Done) without leaving
  /// and reopening the chat. Each event triggers exactly ONE re-read; there is no
  /// cadence behind it. Defaults to the DI-registered `PushRefreshSignals` stream
  /// at runtime; `null` in a bare widget test with no DI, which then simply never
  /// receives an event — which is also why no test seam is needed any more to
  /// keep a mounted chat screen free of pending timers.
  final Stream<void>? refreshSignals;

  /// DEVTOOL-ONLY seam (DT-04 screen catalog): when non-null, [initState]
  /// skips the entire async GetIt/Dio resolution below and mounts the screen
  /// directly against this gateway plus the accompanying `debug*` fields — no
  /// live gateway is ever touched. Every real call site leaves this null, so
  /// production behavior (and every existing widget test) is unchanged.
  final ChatGateway? debugGateway;

  /// Paired with [debugGateway]; defaults to [ConversationPhase.unknown]
  /// (compose) when omitted.
  final ConversationPhase? debugPhase;

  /// Paired with [debugGateway].
  final bool debugHasWinner;

  /// Paired with [debugGateway]; seeds the JM-025 AC2 pinned summary strip.
  final OrderChatSummary? debugSummary;

  /// Paired with [debugGateway]; seeds the resolved header title.
  final String debugCounterpartName;

  @override
  State<ChatDetailScreen> createState() => _ChatDetailScreenState();
}

class _ChatDetailScreenState extends State<ChatDetailScreen>
    with RouteAware, WidgetsBindingObserver {
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

  /// P3: role captured at resolution time so the async summary paths (initial
  /// fetch + refresh) pick the right read mode without a post-await
  /// BuildContext read.
  bool _resolvedIsJeeber = false;

  /// JEBV4-282 / b02 wave B.2: push-driven re-fetch of [_summary] so the pinned
  /// delivery-status chip advances (Ordered→Picked→InTransit→AtDoor→Done) without
  /// leaving and reopening the chat. Armed only for a client-accepted resolution
  /// (the only surface that renders the strip) and cancelled with the state.
  ///
  /// This replaced a 60s `LifecyclePoller`. Do NOT reintroduce one: each tick fanned
  /// out into THREE gateway reads and the mandate bans a repeated call at any
  /// interval, "safety net" included.
  StreamSubscription<void>? _summaryRefreshSub;

  /// True once [_armSummaryRefresh] has subscribed. Test-visible in place of the
  /// old `debugSummaryPollerRunning`: an assertion that the ARM decision is
  /// unchanged is what catches a regression where the client-accepted surface
  /// silently stops tracking the delivery at all.
  @visibleForTesting
  bool get debugSummaryRefreshArmed => _summaryRefreshSub != null;

  /// Count of one-shot summary re-reads triggered since mount. Replaces the old
  /// `debugSummaryTickCount`; a poll's tick count and a push's refetch count are
  /// the same number only when nothing is polling.
  @visibleForTesting
  int get debugSummaryRefetchCount => _summaryRefetchCount;
  int _summaryRefetchCount = 0;

  /// One-shot guard for the delivery-complete → mutual-rating auto-navigation.
  /// Set the first time the polled delivery status reaches a delivered-class
  /// terminal (Done/delivered/completed) so a re-emit / late refetch can't
  /// push the rating route twice, and so a completion that already routed the
  /// user (e.g. via the OTP-handover leg) is never double-pushed from here.
  bool _ratingNavFired = false;

  ChatGateway? _gateway;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final debugGateway = widget.debugGateway;
    if (debugGateway != null) {
      // DEVTOOL-ONLY seam — see [ChatDetailScreen.debugGateway]. Bypasses the
      // GetIt/Dio resolution entirely so the catalog can mount a designed
      // state with zero network calls.
      _finalize(
        widget.chatId,
        debugGateway,
        widget.debugCounterpartName,
        requestId: widget.chatId,
        phase: widget.debugPhase ?? ConversationPhase.unknown,
        hasWinner: widget.debugHasWinner,
        summary: widget.debugSummary,
      );
      return;
    }
    _resolveAndBuild();
  }

  /// One catch-up summary read on return to the foreground. A `delivery` push
  /// that landed while the process was backgrounded may have been dropped or
  /// coalesced by the OS, and the rating hand-off hangs off this read path — so a
  /// single read on resume is the backstop. Explicitly allowed by the mandate: it
  /// is caused by the user returning to the app, not by a clock. No-op until the
  /// client-accepted resolution armed the refresh.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    if (_summaryRefreshSub != null) unawaited(_refreshSummary());
  }

  // ---------------------------------------------------------------------
  // b02 fg-suppression — "is THIS chat thread on screen right now?"
  //
  // Owner requirement: a chat push for a thread the user is NOT viewing must
  // reach the shade even in the foreground; a push for the thread they ARE
  // viewing must not. `initState`/`dispose` cannot answer that — pushing the
  // order summary or the dispute-evidence route on top of this screen leaves
  // this State mounted while the conversation is no longer visible. RouteAware
  // on [appRouteObserver] is the signal that distinguishes the two.
  //
  // Registration is a SET of ids because `/chat/:id`'s param may be a
  // conversation id or a delivery/request id, and the live chat push carries
  // both (`notification_deep_link.dart:56-67`).
  // ---------------------------------------------------------------------

  /// True while this screen is the route on top of the navigator.
  bool _onScreen = false;

  /// Every id that identifies the thread THIS screen is showing, read live.
  ///
  /// Registered with [ActiveChatThread] as a reader, not copied into it, so the
  /// conversation id the async `?correlationKey=` lookup produces is visible to
  /// the push path the instant [_finalize] assigns it — with no republish and
  /// therefore no publish moment to miss.
  ///
  /// A hardware run reported this registry holding only the route param, with
  /// the resolved conversation id absent. That exact failure was NOT reproduced
  /// (see the PR: a snapshot-plus-republish build passes every harness here,
  /// including a real-`GoRouter` one), so the reader is not offered as a fix
  /// for a diagnosed bug — it removes the CLASS the report belongs to, by
  /// leaving nothing that has to be remembered at the right moment.
  Set<String> get _openThreadIds => <String>{
        widget.chatId,
        _resolvedConversationId,
        _resolvedRequestId,
      };

  void _publishOpenThread() {
    if (!_onScreen) return;
    ActiveChatThread.instance.enter(this, () => _openThreadIds);
  }

  /// The observer instance this screen subscribed to. Captured because
  /// `appRouteObserver` is re-minted per router ([newAppRouteObserver]) and
  /// unsubscribing from a DIFFERENT instance would leak the subscription.
  RouteObserver<ModalRoute<void>>? _subscribedObserver;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    // `void` is a top type, so `ModalRoute<T> is ModalRoute<void>` holds for
    // every T — this narrows the nullable, it does not filter by page type.
    if (route is ModalRoute<void> && _subscribedObserver == null) {
      // `subscribe` invokes `didPush()` synchronously on a NEW subscription, so
      // the initial registration falls out of this and needs no separate call.
      _subscribedObserver = appRouteObserver..subscribe(this, route);
    }
  }

  /// The route param changed UNDER A LIVE `State`.
  ///
  /// `go_router` keys its pages on the ROUTE OBJECT, not the location
  /// (`go_router-13.2.5/lib/src/match.dart:178`,
  /// `pageKey: ValueKey<String>(route.hashCode.toString())`), so
  /// `context.go('/chat/B')` while `/chat/A` is on screen matches the SAME
  /// `/chat/:id` `GoRoute`, produces the same page key, and reuses this
  /// `Element` and this `State`. No `didPush`/`didPop` fires. Without this hook
  /// the registry would keep chat A's ids and suppress a push for a thread the
  /// user is no longer on — the notification-tap path itself
  /// (`app/app.dart:613`), plus `dispute_status_screen.dart:122`.
  ///
  /// `AppRouter` now hands this screen a `ValueKey(id)`
  /// (`core/router/app_router.dart`, the `/chat/:id` builder), which forces a
  /// FRESH `State` per thread and makes this branch unreachable in the app —
  /// the key is the real fix, because a reused `State` also keeps the previous
  /// thread's gateway and messages on screen, which this hook cannot repair.
  /// This hook exists for any other host that mounts the screen unkeyed, and it
  /// takes the only honest action available to it: DEREGISTER. The resolved
  /// conversation/request ids still describe the previous thread while the
  /// route param already describes the next one, so no registration would be
  /// truthful, and the safe direction is to suppress nothing.
  @override
  void didUpdateWidget(covariant ChatDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.chatId == widget.chatId) return;
    ActiveChatThread.instance.leave(this);
  }

  @override
  void didPush() {
    _onScreen = true;
    _publishOpenThread();
  }

  /// Returned to the top of the stack (the route pushed above us popped).
  @override
  void didPopNext() {
    _onScreen = true;
    _publishOpenThread();
    // One catch-up read on returning to the thread (e.g. back from the order
    // summary or the dispute route). One-shot, user-caused — not a cadence.
    if (_summaryRefreshSub != null) unawaited(_refreshSummary());
  }

  /// Another route was pushed ON TOP — the conversation is no longer visible,
  /// so its pushes must reach the shade again.
  @override
  void didPushNext() {
    _onScreen = false;
    ActiveChatThread.instance.leave(this);
  }

  @override
  void didPop() {
    _onScreen = false;
    ActiveChatThread.instance.leave(this);
  }

  @override
  void dispose() {
    _subscribedObserver?.unsubscribe(this);
    // Owner-guarded: a no-op if a LATER chat screen already claimed the slot
    // (chat A → chat B disposes A after B registers).
    ActiveChatThread.instance.leave(this);
    unawaited(_summaryRefreshSub?.cancel());
    _summaryRefreshSub = null;
    WidgetsBinding.instance.removeObserver(this);
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

    // Capture the role BEFORE the async resolution awaits so it can gate the
    // client-only pinned-summary fetch without a post-await BuildContext read
    // (use_build_context_synchronously). Defaults to client off-tree.
    final isJeeber = _readRole(context) == UserRole.jeeber;
    _resolvedIsJeeber = isJeeber;

    final dio = getIt<Dio>();
    // Real session user id — drives ChatAuthor.me vs `them` folding and marks
    // outgoing bubbles. NEVER hardcode: the gateway stamps `author_id` from the
    // bearer JWT (the real user), so a hardcoded 'user-client-001' folded EVERY
    // message — including the local user's own sends — as `them`, breaking the
    // thread's left/right rendering. Resolved from AuthTokenStore (populated at
    // login / super-login). Empty when unauthenticated → degrades safely (all
    // messages render as `them`), never crashes.
    final currentUserId = await _resolveSessionUserId(getIt);

    var conversationId = widget.chatId;
    Map<String, dynamic>? conversationData;

    // Resolve against the LIVE gateway contract. The gateway auto-creates one
    // conversation per request, keyed by correlationKey == request id, exposed
    // at `GET /v1/conversations?correlationKey={requestId}`. The live row is
    // snake_case (`{ conversation_id, correlation_key, phase, participants:[
    // { role_in_convo, removed_at } ] }`); the mock/legacy shape is camelCase
    // (`{ id|conversationId, phase, requestId, winnerJeeberId }`). BOTH are
    // tolerated below.
    //
    // The route param resolves via one of two lookups, and each is valid for
    // exactly ONE kind of id — the "wrong" lookup for a given id is a
    // GUARANTEED 404:
    //   * correlationKey lookup — resolves when the param is the REQUEST id
    //     (== correlationKey). The CUSTOMER opens order-chat keyed on the
    //     request id, so this resolves (200) for the customer.
    //   * per-id messages probe — a 200 from `GET /v1/conversations/{id}/messages`
    //     proves the param is already a real, openable CONVERSATION id. The
    //     JEEBER opens the accepted order-chat keyed on the conversation id
    //     (from the accepted feed / active-deliveries entry), so this resolves
    //     for the jeeber.
    // The chat-service resolves a conversation ONLY by correlationKey == request
    // id (never by conversation id → 404), so we run the lookup the caller's
    // ROLE implies FIRST and keep the other as a fallback. This keeps the proven
    // Core-Flow entry for each role free of a guaranteed-404 round-trip
    // (BUG-14 / physical-run12 [Med] chat-load 404 ×2 — the jeeber previously
    // ran the correlationKey lookup on its conversation id and 404'd) while
    // still resolving a param of the unexpected shape.
    // The create-only prefix `/v1/chat/jeeb/conversations/{id}` (+ `/by-request`)
    // 404s on the live gateway and is NO LONGER used for resolution — that was
    // the historical bug that wrongly stranded this screen in compose, where a
    // "send" would create a brand-new request instead of posting to the
    // existing conversation.
    Future<bool> resolveByCorrelationKey() async {
      try {
        final resp = await dio.get<Map<String, dynamic>>(
          '/v1/conversations',
          queryParameters: <String, Object?>{'correlationKey': widget.chatId},
        );
        final data = resp.data;
        // The LIVE gateway returns the conversation row in snake_case
        // (`{ conversation_id, correlation_key, phase, participants }`), so the
        // id MUST be read under `conversation_id` too — reading only the
        // camelCase `id`/`conversationId` (the mock/legacy shape) left this
        // empty on live, so resolution silently failed and the screen fell back
        // to POSTing/GETting `/v1/conversations/{requestId}/messages` → 404 (the
        // run-7 Step-5 chat blocker). Mirrors the tolerant key handling in
        // `DioAcceptedConversationsRepository._string`.
        final resolvedId = _stringField(data, const [
          'id',
          'conversationId',
          'conversation_id',
        ]);
        if (data != null && resolvedId.isNotEmpty) {
          conversationData = data;
          conversationId = resolvedId;
          return true;
        }
      } on DioException {
        // Not resolvable by correlation key — the fallback lookup runs next.
      }
      return false;
    }

    Future<bool> resolveByMessagesProbe() async {
      // A 200 from the canonical messages route proves a real, openable
      // conversation. An existing message thread is, by definition, past
      // compose → treat it as accepted so the composer shows and a send POSTs
      // to this conversation (never re-broadcasts a new request).
      try {
        await dio.get<dynamic>('/v1/conversations/$conversationId/messages');
        conversationData = <String, dynamic>{
          'id': conversationId,
          'phase': 'accepted',
        };
        return true;
      } on DioException {
        // Not an openable conversation id — fresh compose (no request/
        // conversation yet; the first message creates + broadcasts, JM-025 AC1)
        // or a request id resolved by the correlationKey lookup instead.
      }
      return false;
    }

    // Resolve correlationKey-FIRST for BOTH roles (BUG-17). The chat-service
    // resolves a conversation ONLY by correlationKey == request id, so a
    // messages probe on a REQUEST-id param (`GET /v1/conversations/{requestId}/
    // messages`) is a GUARANTEED 404. Every proven entry point now hands this
    // screen the request id (accept sheet, chat push tap via
    // `notification_deep_link.dart`, the accepted-feed CTA, the In-Progress
    // "Open chat" CTA), so the correlationKey lookup resolves them with zero
    // 404s. The messages probe stays as the FALLBACK, which still resolves a
    // conversationId param (e.g. the dashboard active-delivery `chatRouteId`).
    // This drops the old role-based ordering that ran the probe FIRST for the
    // jeeber and 404'd on a requestId push tap (physical-run14 chat-load 404).
    // Fix 5: a compose-sentinel ('new') or empty route param has NO backend
    // conversation yet — both the correlationKey lookup and the messages probe
    // are GUARANTEED 404s (there is nothing to resolve until the first message
    // creates + broadcasts the request, JM-025 AC1). Skip BOTH probes and land
    // directly in compose (conversationData stays null) so a fresh compose
    // never fires two doomed round-trips.
    final isComposeSentinel =
        widget.chatId.isEmpty || widget.chatId == kComposeConversationSentinel;
    if (!isComposeSentinel) {
      if (!await resolveByCorrelationKey()) {
        await resolveByMessagesProbe();
      }
    }

    // Whether the correlationKey lookup / messages probe found a REAL backend
    // conversation. Pre-accept the customer opens order-chat keyed on the
    // requestId BEFORE any Jeeber accepts — NEITHER path resolves because no
    // conversation row exists yet.
    final conversationResolved = conversationData != null;

    final title = await _resolveTitle(dio, conversationData);
    // Live/mock convention: deliveryId == accepted-request-id. Prefer the
    // conversation's requestId/correlationKey; the jeeber's "Start delivery"
    // CTA + the pinned summary fetch + the broadcast/waiting route use this
    // value. Kept even pre-accept (fallback to the route id) so the
    // compose→broadcast route and the phase read have the real request id — the
    // gateway itself is handed the unresolved sentinel (below) so its READS
    // short-circuit rather than polling the requestId messages path.
    // The conversation's REQUEST id (== correlationKey). When resolution
    // succeeded via the correlationKey lookup the row carries it explicitly;
    // when it succeeded ONLY via the messages probe (a conversationId param)
    // the row has NO request/correlation key, so [resolvedRequestId] is empty.
    final resolvedRequestId = _stringField(conversationData, const [
      'requestId',
      'correlationKey',
      'request_id',
      'correlation_key',
    ]);
    // True iff the row carries a real request/correlation key — i.e. the
    // correlationKey lookup resolved it (NOT a probe-only conversationId).
    final resolvedByCorrelationKey = resolvedRequestId.isNotEmpty;
    // Fall back to the route id only as the compose/broadcast + phase-read id;
    // it is a conversationId in the probe-only case, so it must NEVER seed an
    // owner-scoped summary read (see the summary gate below).
    final requestId = resolvedByCorrelationKey
        ? resolvedRequestId
        : widget.chatId;
    final phase = ConversationPhase.fromWire(
      conversationData?['phase'] as String?,
    );
    final winnerId = _stringField(conversationData, const [
      'winnerJeeberId',
      'winner_jeeber_id',
    ]);
    // The LIVE conversation row does not carry a top-level `winnerJeeberId`;
    // the accepted winner is seated as a `jeeber_winner` participant in the
    // `participants` roster (and the row's `phase` can still read
    // `broadcasting` post-accept). Detect that seated winner so the client
    // lands in the ACCEPTED state (composer sends to the conversation) instead
    // of compose — where the first message would wrongly broadcast a NEW
    // request. Mirrors `DioChatGateway._hasActiveWinner`.
    final hasWinner = winnerId.isNotEmpty || _hasSeatedWinner(conversationData);

    // JM-025 AC2 / P3: resolve the locked pinned summary for an accepted order.
    // Best-effort — a failure leaves `_summary` null and the strip simply
    // doesn't render (it never blocks the chat thread).
    // P3: this is now a BOTH-PARTIES surface — the Jeeber previously had zero
    // order context in chat. The Jeeber leg runs with `ownerScopedReads: false`
    // so it reads ONLY the participant-scoped GET /v1/deliveries/{id} and never
    // the owner-scoped /v1/requests/{id} + /v1/offers (403 for a non-owner —
    // physical-run8 [Med] chat READ 404 #3).
    OrderChatSummary? summary;
    // Only fetch the pinned summary when we hold a REAL request/correlation key
    // (correlationKey resolution). In the probe-only case (a conversationId
    // param) [requestId] is the conversationId, and feeding it to
    // `_resolveSummary` fires `GET /v1/deliveries/{convId}` +
    // `/v1/requests/{convId}` + `/v1/offers?requestId={convId}` — a guaranteed
    // triple-404 (BUG-17). The summary strip degrades gracefully when null, so
    // skip the fetch entirely rather than storming the backend.
    final shouldTrackSummary =
        resolvedByCorrelationKey &&
        (phase == ConversationPhase.accepted || hasWinner);
    if (shouldTrackSummary) {
      summary = await _resolveSummary(
        dio,
        requestId,
        conversationId,
        ownerScopedReads: !isJeeber,
      );
    }

    // Pre-accept there is NO conversation to read. Hand the gateway the
    // unresolved sentinel so `loadHistory`/`loadPhase` short-circuit (NO HTTP)
    // instead of polling `GET /v1/conversations/{requestId}/messages` → 404
    // every poll tick (physical-run8 [Med] chat READ 404 #1). Once a
    // conversation exists the resolved `conversation_id` drives BOTH read and
    // send (unchanged — the proven Step-5 send path).
    final gatewayConversationId = conversationResolved
        ? conversationId
        : kComposeConversationSentinel;
    final getItForGateway = GetIt.instance;
    final gateway = DioChatGateway(
      dio: dio,
      currentUserId: currentUserId,
      // The phase read queries the conversation aggregate by its correlation
      // key (== request id). Passing the resolved request id makes the poll hit
      // `?correlationKey={requestId}` (200) instead of
      // `?correlationKey={conversationId}` (404) post-accept (READ 404 #2).
      conversationCorrelationKey: requestId,
      // G4: the chat "Accept" CTA is a live accept path — persist the accept
      // response's handoverCode so the customer can show it at the door.
      handoverCodeStore: getItForGateway.isRegistered<HandoverCodeStore>()
          ? getItForGateway<HandoverCodeStore>()
          : null,
      // P4/P5: the CDN broker for in-chat image attachments. Registered as a
      // lazy singleton in `injection_container.dart`; null in widget tests,
      // where chat degrades to the legacy local-bytes `photo` bubble.
      assetGateway: getItForGateway.isRegistered<CdnAssetGateway>()
          ? getItForGateway<CdnAssetGateway>()
          : null,
    );
    if (!mounted) return;
    _finalize(
      gatewayConversationId,
      gateway,
      title,
      requestId: requestId,
      phase: phase,
      hasWinner: hasWinner,
      summary: summary,
    );
    // JEBV4-282: the pinned status chip is a LIVE view of the delivery — poll it
    // (like [LiveTrackingCubit]) so it advances Ordered→Picked→InTransit→AtDoor→
    // Done without leaving/reopening the chat. Only the client-accepted surface
    // renders the strip, and only a correlationKey-resolved request id is
    // owner-readable, so poll exactly the case that fetched it above. Skip when
    // the delivery is already terminal (nothing left to advance) or when polling
    // is disabled (widget tests pass a null interval).
    // P3: CUSTOMER-ONLY by design. P3 gave the Jeeber the strip, but none of the
    // Jeeber's fields (description / ref / price) change after accept, its live
    // status lives on the Jeeber's own active-delivery screen, and the poll's
    // delivered-status side effect (_navigateToRatingOnce) must keep firing on
    // the client leg only. So P3 adds ZERO background load on the Jeeber device.
    if (shouldTrackSummary &&
        !isJeeber &&
        !_isTerminalStatus(summary?.statusId)) {
      _armSummaryRefresh();
    }
  }

  Future<String> _resolveTitle(
    Dio dio,
    Map<String, dynamic>? conversationData,
  ) async {
    if (conversationData == null) return '';

    // P3: the request-title branch was removed. `title` is not a field of
    // DeliveryRequestDto (the field is `description`), and the key it read
    // (`requestId`, camelCase) never exists on the live snake_case conversation
    // row — so it could not resolve on any wire shape. The order context now
    // lives in the pinned strip (order_chat_request_description); the header
    // keeps the run-22 role-aware fallbacks ("Your Jeeber" / "Customer").

    // Fall back to the winner jeeber name.
    final winnerId = conversationData['winnerJeeberId'] as String?;
    if (winnerId != null && winnerId.isNotEmpty) {
      try {
        final resp = await dio.get<Map<String, dynamic>>('/users/$winnerId');
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
    String conversationId, {
    required bool ownerScopedReads,
  }) async {
    final summaryId = requestId.isNotEmpty ? requestId : conversationId;
    if (summaryId.isEmpty) return null;
    try {
      return await DioOrderChatSummaryRepository(
        dio,
        ownerScopedReads: ownerScopedReads,
      ).fetchSummary(summaryId);
    } on OrderChatSummaryException {
      return null;
    } catch (_) {
      return null;
    }
  }

  /// JEBV4-282 / b02 wave B.2: subscribe the pinned delivery-status chip to the
  /// `delivery` push so it tracks the live delivery with NO cadence behind it.
  /// Idempotent — a second call while already armed is a no-op, so a re-resolve
  /// cannot double-subscribe and turn one push into two reads.
  void _armSummaryRefresh() {
    if (_summaryRefreshSub != null) return;
    _summaryRefreshSub = (widget.refreshSignals ?? resolvePushRefreshStream())
        ?.listen((_) => unawaited(_refreshSummary()));
  }

  /// ONE summary re-read: re-resolve the accepted-order summary and repaint the
  /// chip only when the delivery actually advanced ([OrderChatSummary] is
  /// Equatable, so an unchanged read is a no-op). A failed/empty fetch keeps the
  /// last good summary (the chip never blanks).
  ///
  /// Triggered by a `delivery` push, by returning to this route, and by a
  /// foreground resume. Never by a timer.
  Future<void> _refreshSummary() async {
    if (!mounted) return;
    _summaryRefetchCount++;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) return;
    final next = await _resolveSummary(
      getIt<Dio>(),
      _resolvedRequestId,
      _resolvedConversationId,
      // Belt-and-braces — the refresh is never armed for the Jeeber.
      ownerScopedReads: !_resolvedIsJeeber,
    );
    if (!mounted || next == null) return;
    if (next != _summary) {
      setState(() => _summary = next);
    }
    // ⚠️ LOAD-BEARING BEYOND THE CHIP — do not "simplify" this away. A
    // delivered-class terminal is what fires the rating hand-off below. When this
    // was a poll, the poll was the only thing that could notice the completion
    // while the client sat on the thread; now the `delivery` push is. If the push
    // for the terminal transition were ever lost, the resume/route-return
    // one-shots are the backstop that still reaches this branch.
    //
    // Delivery just completed while the client is sitting on the order-chat.
    // Advance to the MANDATORY blind mutual-rating (the SAME canonical
    // post-delivery route the OTP-handover and jeeber active-delivery
    // completions use), so the client is never stranded on a finished chat
    // with no forward path. Delivered-class only (Done/delivered/completed) —
    // a cancelled/expired/disputed terminal must NOT open the rating screen.
    if (_isDeliveredStatus(next.statusId)) {
      _navigateToRatingOnce();
    }
  }

  /// Navigate to the blind mutual-rating screen exactly once when the delivery
  /// this chat is bound to reaches a delivered-class terminal status while the
  /// client is on the thread. Guarded so a re-emit / late refetch can't push
  /// twice, and short-circuited when the screen was already popped.
  void _navigateToRatingOnce() {
    if (_ratingNavFired || !mounted) return;
    _ratingNavFired = true;
    // Pick the leg from the app-global role (client → no `mode`, jeeber →
    // `?mode=jeeber`); the summary refresh is only armed for the client-accepted
    // surface, so this resolves the client leg in practice, but reading the
    // role keeps the leg correct if the observation ever widens.
    // (The summary refresh is only armed for the client-accepted surface.)
    final isJeeber = _readRole(context) == UserRole.jeeber;
    context.go(_mutualRateRoute(_deliveryId, isClient: !isJeeber));
  }

  /// True when a delivery lifecycle status is a SUCCESSFUL delivery completion
  /// (Done/delivered/completed) — the subset of [_isTerminalStatus] that earns
  /// a rating. Delegates to the shared [DeliveryStatusVocab] (JEBV4-309) so the
  /// chat status chip and the customer delivery-details hub classify the wire
  /// `statusId` identically.
  static bool _isDeliveredStatus(String? statusId) =>
      DeliveryStatusVocab.isDelivered(statusId);

  /// True when a delivery lifecycle status is terminal (Done/delivered/
  /// cancelled/…). Delegates to the shared [DeliveryStatusVocab] (JEBV4-309),
  /// which mirrors the terminal collapse in `JeeberDeliveryStatusX.fromApi`.
  static bool _isTerminalStatus(String? statusId) =>
      DeliveryStatusVocab.isTerminal(statusId);

  /// Resolves the authenticated session user id from [AuthTokenStore] (DI),
  /// populated at login / super-login. Returns '' when the store is absent or
  /// empty so the gateway degrades safely instead of crashing.
  Future<String> _resolveSessionUserId(GetIt getIt) async {
    if (!getIt.isRegistered<AuthTokenStore>()) return '';
    try {
      return (await getIt<AuthTokenStore>().userId) ?? '';
    } catch (_) {
      return '';
    }
  }

  /// First non-empty String value among [keys] in [data], else [fallback].
  /// Tolerates the camelCase (mock/legacy) and snake_case (live gateway) wire
  /// shapes the conversation row can arrive in.
  String _stringField(
    Map<String, dynamic>? data,
    List<String> keys, {
    String fallback = '',
  }) {
    if (data == null) return fallback;
    for (final key in keys) {
      final value = data[key];
      if (value is String && value.isNotEmpty) return value;
    }
    return fallback;
  }

  /// True when the conversation row seats an ACTIVE `jeeber_winner` in its
  /// `participants` roster (role `jeeber_winner`, not yet `removed_at`). The
  /// live `JeebConversationResponse` marks the accepted winner here rather than
  /// with a top-level `winnerJeeberId`, so this is the accepted-state signal
  /// for a route resolved by correlationKey. Mirrors the same gate in
  /// [DioChatGateway] (`_hasActiveWinner`). Defensive on shape: a
  /// missing/non-list roster or a removed winner counts as "no winner".
  bool _hasSeatedWinner(Map<String, dynamic>? data) {
    final participants = data?['participants'];
    if (participants is! List) return false;
    return participants.whereType<Map>().any((p) {
      final role = p['role_in_convo'] as String?;
      final removedAt = p['removed_at'];
      return role == 'jeeber_winner' && removedAt == null;
    });
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
    // b02 fg-suppression: deliberately NO republish here. `ActiveChatThread`
    // holds a READER over `_openThreadIds`, so the conversation/request ids
    // just assigned above are visible to the push path from this line onward
    // with no further call. A republish here was the previous design and it is
    // exactly what a hardware run caught missing its moment; the regression
    // test `resolution lands AFTER registration` fails if a reader is ever
    // swapped back for a snapshot.
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
  String get _deliveryId => _resolvedRequestId.isNotEmpty
      ? _resolvedRequestId
      : _resolvedConversationId;

  /// Human-facing header title (run-22 chat-cluster fix). The resolved title
  /// can be a request title (fine), a synthetic account handle
  /// (`jeeb-<hash>`), a raw UUID, or empty — the latter three rendered a
  /// meaningless header with a generic "J" avatar. Suppress internal
  /// identifiers via [displayNameOrNull], then fall back role-aware:
  ///   * accepted thread → the counterpart's role generic (customer sees
  ///     "Your Jeeber", jeeber sees "Customer");
  ///   * broadcasting/compose → the short order reference (Figma 02 shows the
  ///     order id as the broadcasting header), or the Chat tab label when no
  ///     real id exists yet (fresh compose sentinel).
  String _headerTitle(AppLocalizations l10n, bool isJeeber) {
    final resolved = displayNameOrNull(_counterpartName);
    if (resolved != null) return resolved;
    if (_phase == ConversationPhase.accepted || _hasWinner) {
      return isJeeber
          ? l10n.chatPartyCustomerFallback
          : l10n.chatPartyJeeberFallback;
    }
    final id = _resolvedRequestId.isNotEmpty
        ? _resolvedRequestId
        : widget.chatId;
    if (id.isEmpty || id == kComposeConversationSentinel) return l10n.navChat;
    return friendlyReference(id);
  }

  /// JM-025 AC1: compose state — a client thread that has NOT yet matched a
  /// Jeeber (broadcasting / unknown phase, no winner). The first message
  /// broadcasts the request and routes to `waiting-no-coverage`.
  bool _isComposeState(bool isJeeber) =>
      !isJeeber &&
      !_hasWinner &&
      _phase != ConversationPhase.accepted &&
      _phase != ConversationPhase.closed;

  /// JM-025 AC1: compose → CREATE → broadcast → `waiting-no-coverage` (JM-026).
  ///
  /// THE P0 #3 FIX: in fresh compose [routeId] is the literal `new` sentinel and
  /// no request exists yet. The composed [firstMessage] is turned into a REAL
  /// request via the create-request contract (POST `/v1/requests`, verified 201
  /// on the live gateway); the SERVER-MINTED id is then broadcast and routed to
  /// waiting. On a create failure we surface a soft error, stay in compose, and
  /// return `false` so the composer re-arms for a retry — the literal `new` is
  /// NEVER forwarded to the broadcast or the waiting route. Self-provides the
  /// create + broadcast services over the route [Dio] (the screen layer is the
  /// only place allowed to touch DI — 40_GUARDRAILS_ARCH §1).
  Future<bool> _createBroadcastAndGoWaiting(
    String routeId,
    String firstMessage,
  ) async {
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) return false;
    final dio = getIt<Dio>();
    final coordinator = OrderComposeCoordinator(
      submission: DioRequestSubmissionService(
        dio,
        getIt<RecipientPhoneResolver>(),
      ),
      broadcast: _resolveBroadcastService(dio),
    );
    // Prefer the resolved request id; fall back to the route id (the `new`
    // sentinel in fresh compose → the coordinator then creates a real request).
    final existing = _resolvedRequestId.isNotEmpty
        ? _resolvedRequestId
        : routeId;
    final realId = await coordinator.createAndBroadcast(
      existingRequestId: existing,
      firstMessage: firstMessage,
    );
    if (realId == null) {
      if (mounted) {
        showOmdsErrorSnackbar(
          context,
          message: AppLocalizations.of(context).chatCreateRequestFailed,
        );
      }
      return false;
    }
    if (!mounted) return true;
    // EDGE: order-chat (compose) → waiting-no-coverage (JM-026, 21_NAV_PLAN §C)
    // with the REAL server-minted request id (never the `new` sentinel).
    context.goNamed('waiting-no-coverage', pathParameters: {'id': realId});
    return true;
  }

  OrderBroadcastService _resolveBroadcastService(Dio dio) =>
      DioOrderBroadcastService(dio);

  /// P4/P5 — THE root-cause fix. This production `/chat/:id` surface handed
  /// `ChatScreen` a bare `StubPhotoPickerService()`, whose SYNTHETIC bytes made
  /// "+ → Camera" and "+ → Gallery" silently succeed WITHOUT ever opening the
  /// OS camera or picker. The real `ImagePickerPhotoPickerService` has been
  /// registered in DI all along (`injection_container.dart`); this surface just
  /// never asked for it. The stub stays as the fallback for widget tests and
  /// the dev catalog, where `GetIt` is not populated.
  PhotoPickerService _resolvePicker() {
    final getIt = GetIt.instance;
    if (getIt.isRegistered<PhotoPickerService>()) {
      return getIt<PhotoPickerService>();
    }
    return StubPhotoPickerService();
  }

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
    final isClientDisputable =
        !isJeeber &&
        !compose &&
        _phase != ConversationPhase.broadcasting &&
        _phase != ConversationPhase.closed;

    return ChatScreen(
      deliveryId: _resolvedConversationId,
      counterpartName: _headerTitle(AppLocalizations.of(context), isJeeber),
      gateway: _gateway!,
      pickerService: _resolvePicker(),
      // JM-025: this is the customer order-chat surface → expose the
      // `order_chat_composer_*` ids the W1 flow drives.
      isOrderChat: !isJeeber,
      // Run-22: role-aware party naming on the pinned order-summary strip.
      viewerIsJeeber: isJeeber,
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
      onFirstMessageBroadcast: compose
          ? (requestId, firstMessage) =>
                _createBroadcastAndGoWaiting(requestId, firstMessage)
          : null,
      // JM-025 AC2 / P3: the pinned summary is a BOTH-PARTIES surface. The
      // view-summary LINK stays customer-only (the `order-summary` route is
      // owner-scoped); OrderChatPinnedSummary hides the link when it is null.
      pinnedSummary: _summary,
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
