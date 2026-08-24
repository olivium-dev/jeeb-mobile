import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:get_it/get_it.dart';
import 'package:go_router/go_router.dart';
import 'package:omds/omds.dart';

import '../../core/lifecycle/app_resume_signals.dart';
import '../../core/delivery/delivery_status_vocab.dart';
import '../../core/di/injection_container.dart';
import '../../core/diagnostics/diag.dart';
import '../../core/lifecycle/deferred_refresh_gate.dart';
import '../../core/formatting/friendly_reference.dart';
import '../../core/network/auth_token_store.dart';
import '../../core/network/network_reachability_signals.dart';
import '../../core/notifications/domain/active_chat_thread.dart';
import '../../core/role/role_cubit.dart';
import '../../core/router/app_route_observer.dart';
import '../../core/router/app_router.dart';
import '../../core/role/user_role.dart';
import '../../core/widgets/jeeb/jeeb_cta_button.dart';
import '../../core/widgets/jeeb/jeeb_info_note.dart';
import '../../core/widgets/jeeb/jeeb_midnight_field.dart';
import '../../l10n/app_localizations.dart';
import '../chat/application/order_compose_coordinator.dart';
import '../chat/data/dev_chat_fixture_gateway.dart';
import '../chat/data/dio_chat_gateway.dart';
import '../chat/data/dio_order_broadcast_service.dart';
import '../chat/data/dio_order_chat_summary_repository.dart';
import '../chat/data/firebase_custom_token_identity.dart';
import '../chat/data/firestore_chat_message_mapper.dart';
import '../chat/data/firestore_chat_realtime_source.dart';
import '../chat/data/gateway_chat_firebase_token_minter.dart';
import '../chat/data/in_memory_chat_gateway.dart';
import '../chat/data/chat_realtime_resolver.dart';
import '../chat/data/realtime_chat_gateway.dart';
import '../chat/domain/chat_gateway.dart';
import '../chat/domain/chat_realtime_admission.dart';
import '../chat/domain/conversation_lookup.dart';
import '../chat/domain/delivery_chat_message.dart';
import '../chat/domain/order_broadcast_service.dart';
import '../chat/domain/order_chat_summary.dart';
import '../chat/presentation/chat_screen.dart';
import '../chat/presentation/widgets/chat_app_bar.dart';
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
/// Backoff for re-attempting a conversation resolution that COULD NOT FIND OUT
/// (network down, 5xx, timeout). Widening, and it terminates on the first
/// success — see `_scheduleResolutionRetry`. It used to be described as
/// mirroring the live-tracking SSE re-arm backoff of #186; that constant is
/// deleted (MB1 / PR #204), and the comparison was misleading anyway — the SSE
/// one never terminated.
const List<Duration> kChatResolutionRetryBackoff = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

/// How many times a RECONNECT EVENT may pre-empt the pending backoff step
/// within one failure episode — one per step of [kChatResolutionRetryBackoff]
/// (a test pins the two numbers together, so widening the schedule cannot leave
/// this behind).
///
/// The cap is what stops a flapping transport from becoming a hot retry loop.
/// Each pre-emption also ADVANCES the backoff (the attempt's `whenComplete`
/// re-schedules at the next step), so a device that hands out an offline→online
/// edge every two seconds gets four immediate attempts and is then owned by the
/// 30 s step. Read as a statement about evidence: the OS has now said "online"
/// four times and the gateway was unreachable every time, so its signal has
/// stopped being informative for this episode and the bounded backoff — which
/// probes the thing that actually matters — takes over. A deliberate user
/// retry, or any success, resets the episode.
const int kChatResolutionReconnectPreemptLimit = 4;

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
    with RouteAware, ResumeRefetchMixin {
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
  /// b02 READ ECONOMICS — a [DeferredRefreshGate], not a bare subscription. This
  /// State stays MOUNTED while the order summary, the dispute route or
  /// `/delivery/:id` sits on top of it, and `_refreshSummary` is THREE gateway
  /// reads on the owner-scoped (customer) leg. Every `order` push was paying
  /// those three for a chip nobody could see — the second-largest term in the ten
  /// reads one `delivery` push produced on the customer phone. `_onScreen` (the
  /// [RouteAware] signal this screen already maintains for foreground push
  /// suppression) drives the gate, so a push that lands while the thread is
  /// buried is paid with ONE read on return, not three on arrival.
  DeferredRefreshGate? _summaryRefreshGate;

  /// True once [_armSummaryRefresh] has subscribed. Test-visible in place of the
  /// old `debugSummaryPollerRunning`: an assertion that the ARM decision is
  /// unchanged is what catches a regression where the client-accepted surface
  /// silently stops tracking the delivery at all.
  @visibleForTesting
  bool get debugSummaryRefreshArmed => _summaryRefreshGate != null;

  /// Count of one-shot summary re-reads triggered since mount. Replaces the old
  /// `debugSummaryTickCount`; a poll's tick count and a push's refetch count are
  /// the same number only when nothing is polling.
  @visibleForTesting
  int get debugSummaryRefetchCount => _summaryRefetchCount;
  int _summaryRefetchCount = 0;

  /// Count of summary re-reads that actually reached the WIRE — i.e. attempts
  /// minus the ones the single-flight latch dropped. The pair
  /// ([debugSummaryRefetchCount], [debugSummaryFetchCount]) is what lets a test
  /// assert "three triggers, one read" instead of merely "one read", which a
  /// broken subscription would also satisfy.
  @visibleForTesting
  int get debugSummaryFetchCount => _summaryFetchCount;
  int _summaryFetchCount = 0;

  /// Single-flight latch for [_refreshSummary]. See the long note there: three
  /// independent triggers converge on one resume, and `fetchSummary` fans each
  /// one out into up to three gateway reads.
  bool _summaryRefreshInFlight = false;

  /// One-shot guard for the delivery-complete → mutual-rating auto-navigation.
  /// Set the first time the polled delivery status reaches a delivered-class
  /// terminal (Done/delivered/completed) so a re-emit / late refetch can't
  /// push the rating route twice, and so a completion that already routed the
  /// user (e.g. via the OTP-handover leg) is never double-pushed from here.
  bool _ratingNavFired = false;

  ChatGateway? _gateway;

  /// The inner HTTP gateway, retained SEPARATELY and ONLY when [_gateway] is a
  /// [RealtimeChatGateway] that hides it. Null in every unwrapped case, where
  /// [_gateway] is itself the handle.
  ///
  /// `RealtimeChatGateway.dispose()` forwards to its realtime source and NOT to
  /// its inner gateway (`realtime_chat_gateway.dart:106`), so once the wrap is
  /// in place `_gateway` alone is no longer a handle on the thing that owns the
  /// `DioChatGateway` event controller. Without this field the wrap would leak
  /// that controller on every chat close — a decorator quietly changing what
  /// `dispose` reaches is exactly the kind of leak that never shows up on one
  /// screen and shows up after twenty.
  DioChatGateway? _httpGateway;

  bool _loading = true;

  /// The conversation lookup COULD NOT FIND OUT whether a conversation exists
  /// (network down, 5xx, timeout — see [ConversationLookup.unavailable]).
  ///
  /// This is the third state that used to be collapsed into "not resolved", and
  /// collapsing it is what let a transport failure render as
  /// "Waiting for Jeebers… / No offers yet — sit tight." over an IN-TRANSIT
  /// delivery with an accepted offer. When set, the screen renders an error with
  /// a retry and NEVER constructs a gateway — so no downstream read can turn the
  /// failure into a claim about the conversation.
  bool _resolutionUnavailable = false;

  /// Test/E2E hook: true while the resolution-error body is the rendered state.
  @visibleForTesting
  bool get debugResolutionUnavailable => _resolutionUnavailable;

  /// Pending self-heal re-attempt, `null` when the screen knows the answer.
  Timer? _resolutionRetryTimer;

  /// Index into [kChatResolutionRetryBackoff]. Reset by a success and by a
  /// deliberate user retry.
  int _resolutionRetryAttempt = 0;

  /// A silent re-attempt is outstanding.
  bool _resolutionRetryInFlight = false;

  /// Silent self-heal attempts made since mount. Test hook: it is what
  /// distinguishes "it healed" from "the user tapped".
  int _resolutionRetryCount = 0;

  @visibleForTesting
  int get debugResolutionRetryCount => _resolutionRetryCount;

  /// Subscription to the app-wide reconnect bus. THE fix for the falsified
  /// self-heal claim — see [_onNetworkReachable]. Cancelled in [dispose].
  StreamSubscription<void>? _reachabilitySub;

  /// Reconnect events that actually pre-empted a pending backoff step. The pair
  /// ([debugResolutionRetryCount], [debugReconnectPreemptCount]) is what lets a
  /// test say "this attempt was caused by the EVENT" instead of merely "an
  /// attempt happened" — which a timer would satisfy too, and did.
  @visibleForTesting
  int get debugReconnectPreemptCount => _reconnectPreemptCount;
  int _reconnectPreemptCount = 0;

  /// Reconnect events dropped because an attempt was already on the wire. The
  /// number that distinguishes "coalesced onto the in-flight attempt" from
  /// "the event never arrived".
  @visibleForTesting
  int get debugReconnectCoalescedCount => _reconnectCoalescedCount;
  int _reconnectCoalescedCount = 0;

  @override
  void initState() {
    super.initState();
    // Subscribed BEFORE the devtool early-return below so [dispose] always has
    // a consistent subscription to cancel. On a resolved screen every event is
    // a no-op — `_onNetworkReachable`'s first guard is the CONTROL that keeps
    // an app-wide bus from becoming an ambient read on the healthy path.
    _reachabilitySub = NetworkReachabilitySignals.instance.stream.listen(
      (_) => _onNetworkReachable(),
    );
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
  ///
  /// b02 P0 — driven by [AppResumeSignals]. `_refreshSummary` is THREE gateway
  /// reads on the owner-scoped leg, so an un-coalesced resume burst costs
  /// triple here; its own single-flight latch collapses overlap, not sequence.
  @override
  void onAppResumed() {
    if (_summaryRefreshGate != null) unawaited(_refreshSummary());
    // A resume is the exact moment a user who went to Settings to fix their
    // WiFi comes back expecting the screen to work, and it costs nothing: it
    // fires only while the screen still does not know the answer.
    //
    // It is a COMPLEMENT to `_onNetworkReachable`, not a substitute, and the
    // distinction is the one the falsified claim got wrong. A resume is caused
    // by the USER returning to the app; it says nothing about the network and
    // never fires while the user sits on the dark screen waiting. Only
    // [NetworkReachabilitySignals] reports the network itself.
    if (_resolutionUnavailable) _retryResolutionSilently();
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
    _summaryRefreshGate?.setPollingVisible(true);
  }

  /// Returned to the top of the stack (the route pushed above us popped).
  @override
  void didPopNext() {
    _onScreen = true;
    _publishOpenThread();
    // Pays any push debt taken on while buried. If there is one it collapses
    // with the explicit catch-up read below through `_refreshSummary`'s
    // single-flight latch — one read, never two.
    _summaryRefreshGate?.setPollingVisible(true);
    // One catch-up read on returning to the thread (e.g. back from the order
    // summary or the dispute route). One-shot, user-caused — not a cadence.
    if (_summaryRefreshGate != null) unawaited(_refreshSummary());
  }

  /// Another route was pushed ON TOP — the conversation is no longer visible,
  /// so its pushes must reach the shade again.
  @override
  void didPushNext() {
    _onScreen = false;
    ActiveChatThread.instance.leave(this);
    _summaryRefreshGate?.setPollingVisible(false);
  }

  @override
  void didPop() {
    _onScreen = false;
    ActiveChatThread.instance.leave(this);
    _summaryRefreshGate?.setPollingVisible(false);
  }

  @override
  void dispose() {
    _reachabilitySub?.cancel();
    _reachabilitySub = null;
    _subscribedObserver?.unsubscribe(this);
    // Owner-guarded: a no-op if a LATER chat screen already claimed the slot
    // (chat A → chat B disposes A after B registers).
    ActiveChatThread.instance.leave(this);
    unawaited(_summaryRefreshGate?.dispose());
    _summaryRefreshGate = null;
    _cancelResolutionRetry();
    // TWO handles, deliberately. `_gateway` may now be a [RealtimeChatGateway],
    // whose `dispose()` tears down the Firestore listener but NOT the inner
    // `DioChatGateway` — so disposing only `_gateway` would cancel the stream
    // and leak the HTTP gateway's event controller, and disposing only
    // `_httpGateway` would leak the listener. Both, every time.
    //
    // This is the SECOND teardown path for the Firestore listener, not the
    // only one: `ChatCubit.close()` cancels its subscription
    // (`chat_cubit.dart:782`), which fires the source's
    // `onCancel: () => unawaited(dispose())`
    // (`firestore_chat_realtime_source.dart:91`). Both are wired on purpose —
    // the cubit's path covers a cubit closed without this screen disposing, and
    // `FirestoreChatRealtimeSource.dispose()` is idempotent (it nulls
    // `_snapshots`/`_events` and checks `isClosed`), so running both is safe.
    // Rahmah leaks its listener on exactly this seam; we are not copying that.
    //
    // The two branches are EXCLUSIVE, and `_httpGateway` is non-null only in
    // the wrapped one — so the unwrapped case cannot dispose the same
    // `DioChatGateway` twice.
    final gateway = _gateway;
    if (gateway is RealtimeChatGateway) {
      unawaited(gateway.dispose());
      unawaited(_httpGateway?.dispose());
    } else if (gateway is DioChatGateway) {
      unawaited(gateway.dispose());
    }
    _httpGateway = null;
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
    Future<ConversationLookup> resolveByCorrelationKey() async {
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
          return ConversationLookup.resolved;
        }
        // A 200 whose body carries no conversation id is the server answering
        // "nothing here" — an answer, so absence, not a transport failure.
        return ConversationLookup.absent;
      } on DioException catch (e) {
        // THE FIX. A 404 means "no conversation for this key" (pre-accept —
        // the fallback lookup runs next and compose is the truthful landing).
        // A timeout / connection error / 5xx means we DO NOT KNOW, and must
        // not be reported as either. See [classifyLookupFailure].
        return classifyLookupFailure(e);
      } catch (e) {
        return classifyLookupFailure(e);
      }
    }

    Future<ConversationLookup> resolveByMessagesProbe() async {
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
        return ConversationLookup.resolved;
      } on DioException catch (e) {
        // 404 → not an openable conversation id — fresh compose (no request/
        // conversation yet; the first message creates + broadcasts, JM-025 AC1)
        // or a request id resolved by the correlationKey lookup instead.
        // Anything else → we could not find out.
        return classifyLookupFailure(e);
      } catch (e) {
        return classifyLookupFailure(e);
      }
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
    // The compose sentinel is a LOCAL fact, not a server answer: the route
    // param itself says no request exists yet. That is genuine absence with no
    // round-trip needed.
    var lookup = ConversationLookup.absent;
    if (!isComposeSentinel) {
      lookup = await resolveByCorrelationKey();
      if (lookup != ConversationLookup.resolved) {
        final probe = await resolveByMessagesProbe();
        // ABSENCE NEEDS BOTH LOOKUPS TO HAVE ANSWERED. If either one merely
        // failed to reach the server, we did not learn that the conversation
        // is missing — we learned nothing. A single 404 alongside a timeout is
        // still "could not find out", because the 404-ing lookup is the one
        // that is guaranteed to 404 for the OTHER role's id shape.
        lookup = switch ((lookup, probe)) {
          (_, ConversationLookup.resolved) => ConversationLookup.resolved,
          (ConversationLookup.unavailable, _) ||
          (_, ConversationLookup.unavailable) => ConversationLookup.unavailable,
          _ => ConversationLookup.absent,
        };
      }
    }

    if (!mounted) return;
    if (lookup == ConversationLookup.unavailable) {
      // WE COULD NOT FIND OUT. Do not build a gateway, do not hand anything the
      // compose sentinel, do not let a downstream read invent a phase. Say so,
      // and offer a retry.
      setState(() {
        _resolutionUnavailable = true;
        _gateway = null;
        _loading = false;
      });
      // …and then FIND OUT. Saying "I do not know" is only honest for as long as
      // it takes to try again: the measured pre-fix screen was byte-identical
      // 65 s after connectivity was fully restored, because the only thing that
      // could clear the failure was a successful read and nothing ever issued
      // one.
      _scheduleResolutionRetry();
      return;
    }

    // Whether the correlationKey lookup / messages probe found a REAL backend
    // conversation. Pre-accept the customer opens order-chat keyed on the
    // requestId BEFORE any Jeeber accepts — NEITHER path resolves because no
    // conversation row exists yet, and BOTH answered 404 to say so.
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
    // The PRIVACY fact, deliberately narrower than [hasWinner] above. See
    // [_rosterVerdict] and [realtimeChatAdmitted]: a seated winner is evidence
    // step 3 of the accept saga ran, but ONLY an emptied bidder bench is
    // evidence step 4 did, and step 4 is the one that closes the leak.
    final rosterVerdict = _rosterVerdict(conversationData);

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
    final httpGateway = DioChatGateway(
      dio: dio,
      currentUserId: currentUserId,
      realtimeResolver: ChatRealtimeResolver(
        dio: dio,
        currentUserId: currentUserId,
      ),
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
      _wrapRealtime(
        httpGateway,
        dio,
        currentUserId,
        conversationId: gatewayConversationId,
        conversationResolved: conversationResolved,
        // The PHASE, not the lookup result. `conversationResolved` only says a
        // row came back; a row that came back mid-auction is precisely the one
        // that must not be subscribed to. See [realtimeChatAdmitted].
        phase: phase,
        // The ROSTER, not `hasWinner`. `hasWinner` is the UI's looser "the
        // auction produced a winner"; the gate needs "and the bidder bench is
        // empty", which only the roster can say.
        roster: rosterVerdict,
      ),
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

  /// Wraps the HTTP gateway in the Firestore realtime decorator, or returns it
  /// untouched when this screen must not open a channel.
  ///
  /// # What the wrap buys
  ///
  /// Inbound messages arrive down ONE `.snapshots()` listener instead of being
  /// re-downloaded by HTTP on every push. On the first snapshot the source emits
  /// `RealtimeTransportChanged(live: true)`, `ChatCubit` sets `_realtimeLive`,
  /// and `_refreshFromPush` returns early (`chat_cubit.dart:397`) instead of
  /// calling `refresh()` — which today costs a WHOLE-THREAD
  /// `GET /v1/conversations/{id}/messages` plus a conversation-aggregate read
  /// per inbound message. Nothing on the SEND side changes: writes stay HTTP so
  /// the gateway keeps stamping `author_id` from the bearer.
  ///
  /// # The four refusals, each load-bearing
  ///
  ///  1. **Unresolved conversation.** Pre-accept the client holds the compose
  ///     sentinel and no `Conversations/{id}` document exists. Subscribing would
  ///     open a listener on a non-existent doc, and the membership rule — which
  ///     authorises via a `get()` on that parent — would deny it. Correct
  ///     behaviour here is not to subscribe at all.
  ///
  ///     RESOLUTION IS NOT A PHASE, and this refusal must not be mistaken for
  ///     the phase gate below. `conversationResolved` is a LOOKUP RESULT: it
  ///     says a conversation row came back, nothing more, and a row can come
  ///     back mid-auction. This refusal only keeps us off a doc that does not
  ///     exist; refusal 4 is what keeps us out of the auction.
  ///
  ///     Measured, and worth stating precisely because the raw number misleads:
  ///     an instrumented probe here reports 18 arrivals across the chat /
  ///     deep-link / notification suites, 9 of them with
  ///     `phase: ConversationPhase.broadcasting`. Only ONE of those nine is a
  ///     real auction — the other eight carry a seated `jeeber_winner` with an
  ///     EMPTY bidder bench and are post-accept rows the live gateway simply
  ///     never re-labelled. So the phase STRING alone would refuse eight
  ///     legitimate threads and disable the feature for the main live shape;
  ///     the roster arm is not belt-and-braces here, it is what makes the gate
  ///     correct in both directions.
  ///  2. **Firebase not initialised.** `Firebase.initializeApp()` runs in the
  ///     DEFERRED post-first-frame phase behind a 5 s timeout and falls back to
  ///     a Noop reporter on failure (`bootstrap.dart:208`), so this screen can
  ///     legitimately open before — or entirely without — a Firebase app.
  ///     `FirebaseAuth.instance` / `FirebaseFirestore.instance` THROW in that
  ///     state, and they would throw here, in `_resolveAndBuild`, taking the
  ///     whole chat screen with them.
  ///
  ///     MEASURED, not assumed: with this branch disabled,
  ///     `chat_detail_screen_resolution_test.dart` goes to **11 failures** with
  ///     `[core/no-app] No Firebase App '[DEFAULT]' has been created`, and back
  ///     to 0 with it enabled. So the guard is reached on a live-uid resolution
  ///     and is load-bearing — it is not defensive padding, and deleting it
  ///     breaks the suite immediately.
  ///  3. **No session user id.** `currentUserId` is empty when the token store
  ///     has no subject. A Firestore read would then be authorised for a uid
  ///     this app cannot match against `Participants[].UserId`, and the mapper
  ///     could not fold own-vs-other messages either.
  ///  4. **A bidder can still read this thread.** [realtimeChatAdmitted] — the
  ///     bidder-privacy gate, over the PHASE and the ROSTER ([_rosterVerdict]).
  ///     The released membership rule authorises every non-removed participant,
  ///     and during `broadcasting` that is every BIDDER, so a listener opened
  ///     then streams each rival's offer card to all the others. Read that
  ///     predicate for the full 4 × 3 truth table.
  ///
  ///     It is NOT the same test as the pinned-summary fetch, and that
  ///     difference is the point. `shouldTrackSummary` asks "did the auction
  ///     produce a winner" (`hasWinner`); this asks "and has the bidder bench
  ///     actually been cleared". They diverge on exactly one wire shape — winner
  ///     seated, losers never removed — which is a designed, reachable outcome
  ///     of the gateway's accept saga (step 3 succeeds, step 4 throws and is
  ///     swallowed, accept still returns 200). One extra summary read there is
  ///     harmless; one Firestore listener there is the competing-bid leak.
  ///
  /// Every refusal degrades to precisely today's build: HTTP history, HTTP
  /// send, push-driven HTTP refetch. So does a wrap whose identity fails to
  /// sign in — that path is inside [FirestoreChatRealtimeSource], which never
  /// touches Firestore without an identity.
  ChatGateway _wrapRealtime(
    DioChatGateway inner,
    Dio dio,
    String currentUserId, {
    required String conversationId,
    required bool conversationResolved,
    required ConversationPhase phase,
    required ChatRosterVerdict roster,
  }) {
    if (!conversationResolved ||
        conversationId.isEmpty ||
        conversationId == kComposeConversationSentinel) {
      return inner;
    }
    if (currentUserId.isEmpty) return inner;
    // THE AUCTION GATE — RETIRED 2026-07-30. Now telemetry, not a refusal.
    //
    // It existed because the ruleset it was written against
    // (`be2ddaaf-31e3-4470-8eda-e043478205ce`) authorised a message read purely
    // on conversation MEMBERSHIP, so a `contested` roster — winner seated, a
    // losing bidder still `removed_at == null` — really did let one bidder read
    // a rival's offer card. That is no longer the rule. Batch b03 replaced it
    // with `d9639654-bdce-4948-abe8-3d7e961b05a3`, which authorises on the
    // additive per-message `VisibleTo` array that chat-service computes from
    // `MessageVisibilityResolver` at write time. A leftover bidder is simply not
    // in that array.
    //
    // MEASURED, not reasoned (2026-07-30, live jeeb-5a293, a genuinely contested
    // roster built via `phase` + `remove_others: false`, every identity obtained
    // through the production chain `/auth/tokens` → `/v1/chat/firebase-token` →
    // signInWithCustomToken → Firestore client REST, no admin token anywhere):
    //
    //   leftover loser  → winner-thread message   403   <== the gate's whole job
    //   winner          → same message            200
    //   client          → same message            200
    //   NON-participant → same message            403
    //   loser           → broadcast               200   ← denial is SPECIFIC,
    //   loser           → own message             200   ← not allow-read-false
    //   LIST as loser → 200, 2 docs · as winner → 200, 4 docs
    //
    // So the gate protected nothing the rule does not already protect; all it
    // did was cost 2 HTTP requests per inbound message instead of 0 in the
    // contested state. The predicate is KEPT and still evaluated, because
    // `contested` remains a real server-side defect worth seeing in a device
    // capture (`JeebOffersController.cs:673-702` can still leave that roster
    // behind until the accept saga is made atomic) — but it no longer refuses.
    if (!realtimeChatAdmitted(phase: phase, roster: roster)) {
      Diag.event('chat_realtime_contested_admitted', <String, Object?>{
        'conversation_id': conversationId,
        'reason': kRealtimeRefusedAuctionPhase,
        'phase': phase.name,
        // WHICH arm would have refused. A device capture that only carries the
        // phase cannot tell "still broadcasting" from "accepted but a loser is
        // still seated", and those need opposite follow-ups (wait vs. reconcile
        // the roster on the server).
        'roster': roster.name,
      });
      // NO `return inner` — deliberately. Confidentiality is enforced by the
      // VisibleTo ruleset above, so this thread gets the Firestore wrap like any
      // other and costs 0 requests per message.
    }
    // Cheap, synchronous, and throws nothing — unlike the two `.instance`
    // accessors below, which is the entire reason this check exists.
    if (Firebase.apps.isEmpty) {
      Diag.event('chat_realtime_unavailable', <String, Object?>{
        'conversation_id': conversationId,
        'reason': 'no_firebase_app',
      });
      return inner;
    }
    _httpGateway = inner;
    return RealtimeChatGateway(
      inner: inner,
      realtime: FirestoreChatRealtimeSource(
        // Lazy BY CONTRACT: the source resolves this only after the identity
        // check passes, so "no identity" means Firestore is never reached
        // rather than "reached and refused".
        firestore: () => FirebaseFirestore.instance,
        identity: FirebaseCustomTokenIdentity(
          auth: FirebaseAuth.instance,
          minter: GatewayChatFirebaseTokenMinter(dio: dio),
          // The CURRENT Jeeb subject. A Firebase session outlives a Jeeb
          // logout, so without this the identity would happily reuse the
          // PREVIOUS user's uid on this install. Non-empty by construction:
          // refusal 3 above already returned `inner` when it is empty.
          jeebUserId: currentUserId,
        ),
        mapper: FirestoreChatMessageMapper(currentUserId: currentUserId),
      ),
    );
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
    if (_summaryRefreshGate != null) return;
    // b02 wave D — `{order}`. The chip paints a DELIVERY STATUS. A chat message
    // cannot change it, and this screen is BY DEFINITION on top while chat
    // messages are arriving: every inbound message used to fire one
    // `fetchSummary` here, which is THREE gateway reads on the owner-scoped
    // (customer) leg — `GET /v1/deliveries/{id}` + `/v1/requests/{id}` +
    // `/v1/offers`. That was the single largest term in the measured chat
    // fan-out, and once the trigger became the MESSAGE rate rather than a
    // clock, nothing bounded it.
    final signals =
        widget.refreshSignals ??
        resolvePushRefreshStream(topics: const {RefreshTopic.order});
    // Armed-ness is still "is there a stream", exactly as when this was a bare
    // subscription: with no bus (a bare widget test) nothing is armed and
    // `onAppResumed` / `didPopNext` stay no-ops, unchanged.
    if (signals == null) return;
    _summaryRefreshGate = DeferredRefreshGate(
      onRefresh: _refreshSummary,
      signals: signals,
      // The thread may already be buried when the async resolution completes.
      visible: _onScreen,
      debugLabel: 'ChatDetailScreen.summary',
    );
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
    // SINGLE FLIGHT (b02 wave D). Measured on device: ONE resume produced 4x
    // `GET /v1/deliveries/{id}` + 2x `/v1/offers`, against this method's own
    // documented claim of "ONE summary re-read". Two of those deliveries reads
    // came from `DeliveryDetailScreen` below this route; the other two, plus
    // both offers reads, came from HERE — because three independent triggers
    // reach this method and NONE of them knew about the others:
    //
    //   1. `onAppResumed()` — the coalesced app-resume signal;
    //   2. the push subscription — a `delivery` push the OS queued while
    //      backgrounded is delivered moments after the resume;
    //   3. `didPopNext()` — when the resume also returns to this route.
    //
    // Each is individually correct and none may be deleted (the rating
    // hand-off below hangs off this read path). What was wrong is that they
    // STACKED: three overlapping `fetchSummary` calls, up to nine gateway reads
    // for one user action, with the completions free to land out of order and
    // repaint the chip from the OLDER snapshot.
    //
    // A latch, not a debounce: the second trigger is DROPPED, not delayed. The
    // in-flight read was issued after the event that prompted it, so it already
    // observes the same state the dropped trigger would have — there is nothing
    // for a trailing call to learn. `_summaryRefetchCount` deliberately counts
    // ATTEMPTS (incremented above the latch) so a test can still see how many
    // triggers fired and assert the collapse, rather than the latch hiding it.
    _summaryRefetchCount++;
    if (_summaryRefreshInFlight) return;
    final getIt = GetIt.instance;
    if (!getIt.isRegistered<Dio>()) return;
    _summaryRefreshInFlight = true;
    _summaryFetchCount++;
    final OrderChatSummary? next;
    try {
      next = await _resolveSummary(
        getIt<Dio>(),
        _resolvedRequestId,
        _resolvedConversationId,
        // Belt-and-braces — the refresh is never armed for the Jeeber.
        ownerScopedReads: !_resolvedIsJeeber,
      );
    } finally {
      _summaryRefreshInFlight = false;
    }
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
    // M2-11 carry-in: of the three mutual-rating call sites this is the ONE
    // where the counterpart's name is in scope, so the rating screen finally
    // gets a real `?name=` instead of its role-generic fallback. Never faked —
    // an empty name is passed as null and the helper drops the param.
    final name =
        displayNameOrNull(
          _summary?.counterpartName(viewerIsJeeber: isJeeber),
        ) ??
        displayNameOrNull(_counterpartName);
    context.go(
      mutualRatingLocation(
        _deliveryId,
        isClient: !isJeeber,
        counterpartName: name,
        counterpartAvatarUrl: _summary?.counterpartAvatarUrl(
          viewerIsJeeber: isJeeber,
        ),
      ),
    );
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
  ///
  /// **NOT the privacy gate — [_rosterVerdict] is.** This answers "did the
  /// auction produce a winner", which is the fact the UI needs: it drives
  /// [_isComposeState], [_headerTitle] and the pinned-summary fetch. It stays
  /// deliberately LOOSE, because on a row where the winner is seated but the
  /// losing bidders were never removed the client HAS accepted an offer, and a
  /// false here would drop the composer back to compose state and turn their
  /// next message into a brand-new broadcast request. Whether it is safe to
  /// open a Firestore listener on that same row is a different question with a
  /// different answer, and [_rosterVerdict] is the one that answers it.
  bool _hasSeatedWinner(Map<String, dynamic>? data) {
    final participants = data?['participants'];
    if (participants is! List) return false;
    return participants.whereType<Map>().any((p) {
      final role = p['role_in_convo'] as String?;
      final removedAt = p['removed_at'];
      return role == 'jeeber_winner' && removedAt == null;
    });
  }

  /// Reads the `participants` roster and answers the PRIVACY question: is this
  /// conversation's live membership the post-accept 1:1, or is a losing bidder
  /// still seated and therefore still authorised by the Firestore membership
  /// rule to read every rival's offer card? See [ChatRosterVerdict] for why the
  /// phase string cannot answer it (the accept saga seats the winner and removes
  /// the losers in two separate calls, and the second one is allowed to fail
  /// while the accept still returns 200).
  ///
  /// Role classification mirrors chat-service's own
  /// `MessageVisibilityResolver.MapRole` (`:72-96`) token for token, so client
  /// and server agree on who is a Restricted bidder:
  ///
  ///  * `client*` → the thread owner, never a bidder;
  ///  * `admin` / `support` → privileged readers, not rivals;
  ///  * contains `winner` → the accepted counterpart;
  ///  * anything else, **including blank/unknown** → Restricted, i.e. a live
  ///    bidder. Fail-closed: an unclassifiable seated member is treated as one.
  ///
  /// Soft-removed participants (`removed_at != null`) are skipped — a stamped
  /// `RemovedAt` is exactly what the membership rule denies on, so they can no
  /// longer read and cannot be leaked to.
  ChatRosterVerdict _rosterVerdict(Map<String, dynamic>? data) {
    final participants = data?['participants'];
    if (participants is! List) return ChatRosterVerdict.unknown;
    final rows = participants.whereType<Map>().toList(growable: false);
    if (rows.isEmpty) return ChatRosterVerdict.unknown;

    var seatedWinner = false;
    var liveBidder = false;
    for (final p in rows) {
      // Soft-removed: the rule denies them, so they are neither a winner nor a
      // leak target.
      if (p['removed_at'] != null) continue;
      final raw = p['role_in_convo'];
      final role = raw is String ? raw.trim().toLowerCase() : '';
      if (role.startsWith('client') || role == 'admin' || role == 'support') {
        continue;
      }
      if (role.contains('winner')) {
        seatedWinner = true;
        continue;
      }
      liveBidder = true;
    }

    // A live bidder beats everything: there is a rival in the room.
    if (liveBidder) return ChatRosterVerdict.contested;
    // No bidders AND no winner is not evidence the auction ended — it is a
    // roster that has not been populated yet (client alone). Say so, and let
    // the phase decide.
    return seatedWinner ? ChatRosterVerdict.settled : ChatRosterVerdict.unknown;
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
      // A resolution that produced a gateway retires the error body (the retry
      // CTA re-enters here).
      _resolutionUnavailable = false;
    });
    // Success is the retry's terminating condition. This is the single line that
    // keeps the recovery from being a poll.
    _cancelResolutionRetry();
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
    // Same read the header photo comes from, so name and avatar never disagree.
    final fromSummary = displayNameOrNull(
      _summary?.counterpartName(viewerIsJeeber: isJeeber),
    );
    if (fromSummary != null) return fromSummary;
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

  /// Counterpart photo for the header, from the same summary read as the name.
  /// Null (letter placeholder) until the summary lands or when unset.
  String? _counterpartAvatarUrl(bool isJeeber) =>
      _summary?.counterpartAvatarUrl(viewerIsJeeber: isJeeber);

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

  /// Re-run the conversation lookup after a "could not find out" failure.
  /// Wired to the retry CTA on [_buildResolutionError].
  ///
  /// A DELIBERATE user tap resets the backoff to its first step: the user has
  /// information we do not (they can see the WiFi icon), so their tap is not
  /// just another attempt, it is a reason to be optimistic again.
  void _retryResolution() {
    if (!mounted) return;
    _cancelResolutionRetry();
    setState(() {
      _resolutionUnavailable = false;
      _loading = true;
    });
    unawaited(_resolveAndBuild());
  }

  /// SELF-HEAL. Re-attempt the resolution on a bounded backoff for as long as —
  /// and only as long as — the screen does not know the answer.
  ///
  /// **Why this is not the poll the mandate bans.** A poll is a repeated read of
  /// a surface that is CURRENTLY CORRECT, at a fixed interval, forever. This is
  /// the retry of a read that FAILED, it widens
  /// ([kChatResolutionRetryBackoff]: 2 s → 5 s → 15 s → 30 s, then 30 s), and it
  /// TERMINATES on the first success (`_finalize` → [_cancelResolutionRetry]).
  /// The same SHAPE as the SSE re-arm backoff shipped in #186 — which replaced a
  /// dead stream that "neither resume nor a push could re-open" — but not the
  /// same argument, and that constant is now deleted (MB1 / PR #204). The SSE
  /// one had no terminating condition a dead route could ever satisfy; this one
  /// terminates on the first success.
  ///
  /// **RETRACTED CLAIM — read this before trusting the paragraph that used to
  /// be here.** This comment previously argued that waiting for a connectivity
  /// event "is not available: this app has no connectivity package, and adding
  /// one to learn something a retry already tells us would be a dependency in
  /// place of a fact. The retry IS the connectivity probe." The second half is
  /// still true about the PROBE and was false about the TIMING, and the
  /// difference is the whole defect: a retry probes only when its timer fires,
  /// so a reconnect one second into a 30 s step stays invisible for 29 s. The
  /// screen was merged as "SELF-HEALS on reconnect"; an independent tester
  /// falsified that — the observed 0.46 s heal was this backoff's phase
  /// happening to tick, and re-running with an independently-phased backoff
  /// moved the heal latency with the TIMER, not with the reconnect instant.
  ///
  /// [NetworkReachabilitySignals] now supplies the missing event and
  /// [_onNetworkReachable] consumes it. This backoff is UNCHANGED and remains
  /// the fallback — it is what covers the case a connectivity event cannot
  /// (the router is up and the gateway is down, so the OS never reports a
  /// change), and its bound is what stops a hot retry loop.
  ///
  /// A retry is silent: the error body stays on screen while it runs, so the
  /// screen never flickers between an error and a spinner behind the user's back.
  void _scheduleResolutionRetry() {
    if (!mounted || !_resolutionUnavailable) return;
    _resolutionRetryTimer?.cancel();
    final step = _resolutionRetryAttempt < kChatResolutionRetryBackoff.length
        ? _resolutionRetryAttempt
        : kChatResolutionRetryBackoff.length - 1;
    final delay = kChatResolutionRetryBackoff[step];
    _resolutionRetryAttempt++;
    _resolutionRetryTimer = Timer(delay, _retryResolutionSilently);
  }

  /// One silent re-attempt. Re-entrancy-guarded: a resolution can outlive its
  /// own backoff step (a 15 s timeout inside a 5 s step), and two overlapping
  /// resolutions would race to `_finalize` and could paint the older answer.
  void _retryResolutionSilently() {
    if (!mounted || !_resolutionUnavailable) return;
    if (_resolutionRetryInFlight) {
      _scheduleResolutionRetry();
      return;
    }
    _resolutionRetryInFlight = true;
    _resolutionRetryCount++;
    unawaited(
      _resolveAndBuild().whenComplete(() {
        _resolutionRetryInFlight = false;
        // Still unknown → widen and try again. Resolved → `_finalize` already
        // cancelled, and `_scheduleResolutionRetry`'s own guard returns.
        _scheduleResolutionRetry();
      }),
    );
  }

  void _cancelResolutionRetry() {
    _resolutionRetryTimer?.cancel();
    _resolutionRetryTimer = null;
    _resolutionRetryAttempt = 0;
    // A new episode gets its pre-emption budget back. Reached from success
    // (`_finalize`) and from a deliberate user retry, both of which end the
    // episode this budget was spent on.
    _reconnectPreemptCount = 0;
  }

  /// THE FIX for the falsified self-heal claim: the network came back, so try
  /// NOW instead of waiting out a backoff step that knows nothing about it.
  ///
  /// Four properties, each of which is a separate assertion in
  /// `chat_resolution_reconnect_test.dart`:
  ///
  ///   1. **Zero attempts on a resolved screen.** The bus is app-wide, so every
  ///      mounted chat screen receives every reconnect. A screen that already
  ///      knows its answer must not turn that into a read — otherwise the fix
  ///      for a dark screen becomes an ambient network event on healthy ones,
  ///      which is the poll the mandate bans wearing a different hat.
  ///   2. **Coalesce, never stampede.** An attempt already on the wire will
  ///      report its own outcome and re-arm the backoff in `whenComplete`.
  ///      Starting a second resolution would race it to `_finalize` and could
  ///      paint the older answer.
  ///   3. **Bounded pre-emption.** See [kChatResolutionReconnectPreemptLimit].
  ///   4. **The backoff is NOT reset.** A user's tap resets it, because the user
  ///      can see their WiFi icon and has information we do not. A connectivity
  ///      event does not: "the OS reports a transport" is not "the gateway
  ///      answers", so an attempt that fails after a reconnect must resume
  ///      widening from where it was, not restart at 2 s.
  void _onNetworkReachable() {
    if (!mounted || !_resolutionUnavailable) return;
    if (_resolutionRetryInFlight) {
      _reconnectCoalescedCount++;
      Diag.event('chat_resolution_reconnect', <String, Object?>{
        'action': 'coalesced',
        'count': _reconnectCoalescedCount,
      });
      return;
    }
    if (_reconnectPreemptCount >= kChatResolutionReconnectPreemptLimit) {
      Diag.event('chat_resolution_reconnect', <String, Object?>{
        'action': 'budget_exhausted',
        'count': _reconnectPreemptCount,
      });
      return;
    }
    _reconnectPreemptCount++;
    Diag.event('chat_resolution_reconnect', <String, Object?>{
      'action': 'preempt',
      'count': _reconnectPreemptCount,
    });
    // Cancel the PENDING STEP only — deliberately not `_cancelResolutionRetry`,
    // which would also zero `_resolutionRetryAttempt` and hand a flapping
    // transport a permanent 2 s cadence. `_retryResolutionSilently` re-arms
    // from the un-reset index in its `whenComplete`.
    _resolutionRetryTimer?.cancel();
    _resolutionRetryTimer = null;
    _retryResolutionSilently();
  }

  /// THE THIRD STATE, rendered. We do not know whether this conversation
  /// exists, so we assert nothing about it — no "Waiting for Jeebers", no empty
  /// thread, no composer that would broadcast a duplicate request. The copy is
  /// the same `chatHistoryError*` family the #186 history-read error body uses,
  /// because it is the same statement to the user ("couldn't load this chat —
  /// check your connection and try again"); the redesign-2026-08 rendering of
  /// it lives in [ChatResolutionErrorView].
  Widget _buildResolutionError(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final isJeeber = _readRole(context) == UserRole.jeeber;
    return Semantics(
      identifier: 'chat_resolution_error',
      child: ChatResolutionErrorView(
        title: _headerTitle(l10n, isJeeber),
        onRetry: _retryResolution,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      // The resolving frame carries the SAME chrome the resolved thread does.
      // It used to be a bare `Scaffold(body: Center(OmdsLoadingState()))`: a
      // blank page with no header, so every chat open flashed a pre-redesign
      // screen with no way back while up to three sequential gateway reads ran,
      // and then jumped to a full identity bar. Same top bar, same 24 gutter,
      // same bubble geometry — only the content is missing, which is the one
      // thing that is actually still unknown here.
      return _ChatResolvingView(
        title: _headerTitle(
          AppLocalizations.of(context),
          _readRole(context) == UserRole.jeeber,
        ),
      );
    }
    // Checked BEFORE the gateway is dereferenced below: on this branch there is
    // deliberately no gateway, because building one would give a downstream
    // read something to be confidently wrong about.
    if (_resolutionUnavailable) return _buildResolutionError(context);
    // Role-aware entry point: a jeeber whose offer was accepted lands here via
    // `/chat/:id` and must be able to start the delivery. RoleCubit is provided
    // app-wide (MultiBlocProvider in JeebApp, above MaterialApp.router), so it
    // is an ancestor of every route the router builds — read it directly. We
    // default to the client variant (null callback, prior behavior) when the
    // cubit is absent from the tree, so non-app-rooted hosts (e.g. the dev
    // capture seam, isolated widget tests) degrade safely rather than throw.
    final isJeeber = _readRole(context) == UserRole.jeeber;
    final compose = _isComposeState(isJeeber);
    final canStartDelivery =
        isJeeber && DeliveryStatusVocab.canStartFromChat(_summary?.statusId);
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
      counterpartAvatarUrl: _counterpartAvatarUrl(isJeeber),
      gateway: _gateway!,
      pickerService: _resolvePicker(),
      // JM-025: this is the customer order-chat surface → expose the
      // `order_chat_composer_*` ids the W1 flow drives.
      isOrderChat: !isJeeber,
      // Run-22: role-aware party naming on the pinned order-summary strip.
      viewerIsJeeber: isJeeber,
      onStartActiveDelivery: canStartDelivery
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
      // DEFECT (live COD run, 2026-07-31): `order_summary_status` read "Matched"
      // at 21:44 and still at 21:46, while the jeeber had marked Picked at
      // 21:43:43 and InTransit at 21:44:16. The chip is on the PUSH-ONLY status
      // axis — the 60 s safety net was deleted (see the note at the top of this
      // file), so while the customer stays on this thread the ONLY thing that
      // can advance it is a `type=delivery` push, and on that hardware the push
      // did not land (the same run's gateway journal: fcmAccepted=3/24,
      // fcmRejected=21). `didPopNext` / `onAppResumed` / open are all
      // attention-RETURN events; none of them fires for a customer who never
      // leaves.
      //
      // Expanding the strip is the one user-caused event on this screen that
      // names this data, and the captured frame is exactly that interaction
      // returning a stale chip. It gets one catch-up read — the same shape and
      // the same justification as the `didPopNext` catch-up, and through the
      // same single-flight latch, so it adds no cadence and cannot storm.
      //
      // Customer-only, matching every other trigger here: the refresh is never
      // armed for the Jeeber (`_armSummaryRefresh` is gated on `!isJeeber`), so
      // handing the Jeeber's strip a refresh callback would create a read path
      // the rest of this screen deliberately does not give it.
      onSummaryAttentionRefresh: isJeeber ? null : _refreshSummary,
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

/// The `/chat/:id` RESOLVING frame — screen 21's chrome with the thread still
/// unknown.
///
/// It is a real screen, not a spinner: the identity [ChatAppBar] means the back
/// circle (`chat_detail_back_button`) is reachable for the whole resolution,
/// which the old bare `Center(OmdsLoadingState())` never offered — a user on a
/// slow network had a blank page and no exit.
class _ChatResolvingView extends StatelessWidget {
  const _ChatResolvingView({required this.title});

  /// The same header title the resolved thread will carry (the order reference
  /// pre-accept), so the bar does not re-label itself under the user.
  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: ChatAppBar(title: title),
      // Same field, same placement as the resolved thread, so the page does
      // not repaint its background under the user when resolution lands.
      body: const JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topEnd,
        animateDecor: false,
        child: ChatThreadSkeleton(),
      ),
    );
  }
}

/// The `/chat/:id` resolution-error surface in the redesign-2026-08 language.
///
/// Screen 21's board draws no error state, so this borrows the kit's two error
/// primitives instead of inventing a third: [JeebInfoNote.error] carries the
/// statement (soft `errorContainer` panel, not the legacy full-bleed red slab)
/// and the retry is the standard navy [JeebCtaButton] pill. It replaces
/// `OmdsErrorStatePage`, whose Ø80 red glyph + Material `FilledButton.icon`
/// was the last pre-redesign surface this route could show.
///
/// The `chat_resolution_error` identifier stays on the caller's wrapper — this
/// widget adds only the new retry id.
class ChatResolutionErrorView extends StatelessWidget {
  const ChatResolutionErrorView({
    super.key,
    required this.title,
    required this.onRetry,
  });

  /// Header title — the resolved counterpart name or the order reference.
  final String title;

  /// Re-runs the conversation lookup. Never null: an error page whose only
  /// affordance is dead is the same dead end the old blank loader was.
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: ChatAppBar(title: title),
      body: JeebMidnightField(
        variant: JeebFieldVariant.content,
        glowPlacement: JeebFieldGlowPlacement.topEnd,
        animateDecor: false,
        child: SafeArea(
          top: false,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: Spacing.xLarge,
                vertical: Spacing.xLarge,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  JeebInfoNote.error(
                    // The failure this screen can actually name: the lookup
                    // could not reach the gateway. Never a generic "error".
                    icon: Icons.wifi_off_rounded,
                    title: l10n.chatHistoryErrorTitle,
                    text: l10n.chatHistoryErrorMessage,
                  ),
                  const SizedBox(height: Spacing.large),
                  JeebCtaButton.primary(
                    label: l10n.chatHistoryErrorRetry,
                    onTap: onRetry,
                    identifier: 'chat_detail_resolution_retry',
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
