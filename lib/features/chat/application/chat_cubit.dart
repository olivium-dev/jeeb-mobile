import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/idempotency/operation_id.dart';
import '../../../core/network/app_failure.dart';
import '../../../core/network/network_reachability_signals.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/chat_gateway.dart';
import '../domain/chat_message.dart';
import '../domain/chat_outbox.dart';
import '../domain/delivery_chat_message.dart';
import 'chat_state.dart';

/// Backoff for the COLD-LOAD-FAILURE retry. Not a poll: it is armed only while
/// [ChatState.historyLoadFailed] is set and it TERMINATES on the first success.
/// Same shape and same argument as `kChatResolutionRetryBackoff`
/// (`chat_detail_screen.dart`).
///
/// It used to cite a second precedent, the live-tracking SSE re-arm backoff of
/// #186. That constant is **deleted** (MB1 / PR #204) and citing it by name was
/// actively misleading — it is the schedule that turned into a permanent poll
/// against a 404 for four days, because its only reset site sat inside a frame
/// handler a dead route could never reach. The two backoffs here are the
/// opposite shape and that is the whole point: both TERMINATE on the first
/// success.
///
/// It caps rather than exhausts, deliberately: an exhausting schedule leaves a
/// thread permanently blank with no way back short of a restart.
///
/// **Updated — the premise this paragraph used to rest on is gone.** It read
/// "this app has NO connectivity listener (zero hits for `connectivity_plus` /
/// `onConnectivityChanged` in `lib/`), so there is no reconnect event to re-arm
/// on." That was accurate when written and is now false: the app has
/// `NetworkReachabilitySignals` (`core/network/`), bound to the real OS stream
/// at app start, after a tester falsified the sibling "self-heals on reconnect"
/// claim on `chat_detail_screen.dart` — the heal there was the backoff's phase
/// ticking, not a reconnect.
///
/// **This cubit is NOT yet wired to that bus.** Stated plainly rather than left
/// to be inferred: the history retry below is still timer-only, so a reconnect
/// while a thread sits on its cold-load error is still invisible until the next
/// backoff step. Wiring it is the same three lines `chat_detail_screen.dart`
/// now carries (`_onNetworkReachable`) and is deliberately out of that change's
/// scope, not done and undocumented.
const List<Duration> kChatHistoryRetryBackoff = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

/// Drives the 1:1 chat between the local user and the delivery counterpart.
///
/// Optimistic UI: every outgoing message lands in the list immediately as
/// [MessageStatus.sending] so the user sees their bubble without waiting on
/// the gateway. The status then transitions:
///   sending → sent       (gateway ack)
///          → delivered   (server delivered receipt)
///          → read        (counterpart device read receipt)
/// A network failure flips the entry to [MessageStatus.failed]; the user can
/// retry by sending a fresh message — we do not provide an inline retry in
/// the MVP.
///
/// ## N4 — PUSH-DRIVEN. The 60 s history poll is DELETED.
///
/// This is the surface the owner named. There is no periodic network timer in
/// this class any more; `kChatHistorySafetyNetPollInterval` is gone, not
/// merely disarmed. Every history read is caused by one of exactly four
/// things, and all four fold through the ONE non-destructive merge rule
/// ([_reconciledWithHistory]):
///
///   1. **mount** — [load], from the `..load()` at the `BlocProvider` in
///      `chat_screen.dart`;
///   2. **resume** — [refresh], from `_ChatScaffoldState.onAppResumed`
///      (`AppResumeSignals`, the app-wide coalesced genuine-resume bus);
///   3. **push** — [_refreshFromPush] on a `{chat}` signal, single-flighted;
///   4. **cold-load-failure retry** — [_syncHistoryRetry], armed ONLY while
///      [ChatState.historyLoadFailed] is set.
///
/// ### Why (4) exists, and why it is not a poll
///
/// The deleted 60 s poll was doing two jobs. As a freshness mechanism it was
/// redundant — the push bus is strictly faster and the WS subscription is
/// faster still. As a RECOVERY mechanism it was the only bounded thing that
/// would re-read a thread whose cold load had failed, and deleting it blind
/// would have made the offline chat error state terminal until an app restart:
/// the push bus cannot help, because a thread the user cannot see generates no
/// inbound traffic to push about, and — at the time this was written — the app
/// had no connectivity listener to wake on. It has one now
/// (`NetworkReachabilitySignals`); see the retraction on
/// [kChatHistoryRetryBackoff] for why this cubit is not yet wired to it.
///
/// So (4) replaces only the second job, and it differs from a poll in every way
/// that matters to the mandate: it is armed only in an ERROR state, it is
/// silent (the error body with its retry CTA stays on screen), it terminates on
/// the first success, and a healthy rendering thread has `debugHistoryRetryArmed
/// == false` — which is the assertion that proves the clock is gone.
class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required String deliveryId,
    required ChatGateway gateway,
    required PhotoPickerService pickerService,
    // P4/P5: chat ships REAL bytes to the CDN. [HalvingPhotoCompressor] does
    // not re-encode, it stride-copies every second byte — it would turn a
    // >2 MB JPEG into an undecodable blob. `image_picker` already down-scales
    // at the source, and oversize payloads are rejected by
    // [_maxAttachmentBytes] rather than silently mangled.
    PhotoCompressor compressor = const PassthroughPhotoCompressor(),
    DateTime Function() clock = _defaultClock,
    String? initialDeliveryId,
    Stream<void>? refreshSignals,
    ChatOutbox? outbox,
    String currentUserId = '',
    Stream<void>? reconnectSignals,
  }) : _deliveryId = deliveryId,
       _outbox = currentUserId.isEmpty
           ? null
           : outbox is AccountScopedChatOutbox
               ? (outbox as AccountScopedChatOutbox).forAccount(currentUserId)
               : outbox,
       _currentUserId = currentUserId,
       _gateway = gateway,
       _pickerService = pickerService,
       _compressor = compressor,
       _clock = clock,
       // Seed the tracking delivery id when the host already knows it (e.g. the
       // client accepted the offer from the review-list sheet and landed here
       // with the server-created `deliveryId`). Without this, an order accepted
       // outside the chat would have no delivery id to track until an in-chat
       // accept / PhaseChanged event — leaving the "Track order" CTA hidden on
       // an already-accepted order.
       super(ChatState(
         acceptedDeliveryId: (initialDeliveryId != null &&
                 initialDeliveryId.isNotEmpty)
             ? initialDeliveryId
             : null,
       )) {
    // b02 polling→push: a chat push must DRIVE the open thread.
    //
    // Until this line the chat screen was the only live surface that took no
    // push input at all: `PushRefreshSignals` was wired into `home_tab`,
    // `client_home_cubit` and `request_feed_cubit`, and never into chat. On the
    // deployed build a chat push landed at 18:44:29Z and triggered NO fetch,
    // while `/v1/conversations/{id}/messages` kept ticking at exactly 60.0s on
    // a fixed phase — the safety-net poll was then the ONLY inbound path. That
    // poll is deleted on this branch; this subscription is what replaces it.
    //
    // Same shape as `GreetingProfileCubit` (`core/session/greeting_profile_cubit.dart:53,60`)
    // and the `dashboard_tab` / `request_feed_screen` subscribers: a
    // payload-less `Stream<void>`, resolved by the ONE existing resolver
    // (`resolvePushRefreshStream`, `core/di/injection_container.dart:158`).
    // No second bus — a per-conversation payload would be redundant here
    // because this cubit re-pulls the ONLY conversation it renders, and a
    // parallel bus is how one subscriber silently keeps polling while its twin
    // goes push-driven.
    _refreshSubscription = refreshSignals?.listen((_) => _refreshFromPush());
    // OFF-04: an offline→online edge is the moment a queued send can win.
    _reconnectSubscription =
        (reconnectSignals ?? NetworkReachabilitySignals.instance.stream)
            .listen((_) => unawaited(_flushOutbox()));
  }

  final String _deliveryId;
  final ChatGateway _gateway;
  final PhotoPickerService _pickerService;
  final PhotoCompressor _compressor;
  final DateTime Function() _clock;

  /// Durable store for text sends that failed. Null keeps the pre-outbox
  /// behaviour exactly: a failed bubble that lives only in memory.
  final ChatOutbox? _outbox;

  /// Sender id stamped on outbox rows. Empty when the host did not resolve one.
  final String _currentUserId;
  bool _closing = false;

  StreamSubscription<ChatEvent>? _subscription;

  /// Reachability-edge subscription driving the outbox flush. Cancelled in
  /// [close].
  StreamSubscription<void>? _reconnectSubscription;

  /// In-flight latch for [load] — a double-tapped retry must not issue two
  /// history reads whose completions can land out of order.
  bool _loadInFlight = false;

  /// The error the phase read absorbed, kept so the cold-load failure has a
  /// classified failure to render.
  Object? _lastPhaseError;

  /// Push→refetch subscription (b02). Cancelled in [close].
  StreamSubscription<void>? _refreshSubscription;

  /// Single-flight latch for [_refreshFromPush]. Two pushes landing inside one
  /// round-trip must produce ONE re-pull, not two overlapping ones whose emits
  /// race (the later request can complete first and paint the OLDER snapshot).
  bool _pushRefreshInFlight = false;

  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  /// Number of push-driven re-pulls this cubit has performed. Lets a test
  /// assert "one push → exactly one fetch" without reaching into the gateway.
  @visibleForTesting
  int get debugPushRefreshCount => _pushRefreshCount;
  int _pushRefreshCount = 0;

  /// Whether the gateway's inbound stream is a LIVE realtime channel.
  ///
  /// Set ONLY by a [RealtimeTransportChanged] event the transport emits from its
  /// own lifecycle — `true` when a snapshot has arrived, `false` on the
  /// stream's error/close. A gateway with no realtime transport never emits it
  /// and this stays false forever, which is the correct reading: the HTTP
  /// fallback is what carries that gateway.
  ///
  /// I-13 is the reason it is shaped this way. `debugPositionStreamWired` was
  /// set when its stream was ARMED and never cleared on `onDone`, so it read
  /// `true` on a dead SSE feed and the guard it protected never fired again.
  /// Arming a listener is not evidence a listener works.
  bool _realtimeLive = false;

  /// True while the realtime channel is carrying messages. When it is, the
  /// push-driven HTTP re-pull is SILENT — see [_refreshFromPush].
  @visibleForTesting
  bool get debugRealtimeLive => _realtimeLive;

  /// Push signals that arrived while the realtime channel was live and were
  /// therefore NOT turned into an HTTP read. This is the saving, counted: it is
  /// how many `GET /v1/conversations/{id}/messages` round trips did not happen.
  @visibleForTesting
  int get debugPushRefreshSuppressedCount => _pushRefreshSuppressedCount;
  int _pushRefreshSuppressedCount = 0;

  /// Monotonic counter feeding outgoing message ids. Combined with the
  /// delivery id to stay unique across two cubits running in the same
  /// process during tests.
  int _outboxCounter = 0;

  /// Cold-load entry point. Pulls any historical messages from the gateway
  /// and starts listening for inbound events. Also fetches the conversation
  /// phase so the composer/offer-card UI renders correctly on first paint.
  Future<void> load() async {
    if (_loadInFlight) return;
    _loadInFlight = true;
    _lastPhaseError = null;
    emit(state.copyWith(
      isLoadingHistory: true,
      clearError: true,
      historyLoadFailed: false,
      clearHistoryFailure: true,
      clearRefreshFailure: true,
    ));
    // Both reads still leave together — one round-trip of latency, not two —
    // but their FAILURES are no longer shared. `Future.wait` made a phase-read
    // fault indistinguishable from a history-read fault, and they have opposite
    // consequences: a failed history read is the reason the thread is empty, a
    // failed phase read is not. The phase future absorbs its own error into
    // `null` ("we could not find out") so it can never blank a thread that
    // loaded fine.
    final historyFuture = _gateway.loadHistory(_deliveryId);
    final phaseFuture = _gateway
        .loadPhase(_deliveryId)
        .then<ConversationPhase?>((p) => p, onError: (Object e) {
          _lastPhaseError = e;
          return null;
        });
    try {
      final history = await historyFuture;
      final phase = await phaseFuture;
      _noteServerClock(history);
      // Nothing on screen AND no phase = we know nothing about this thread.
      // Rendering the empty state here would assert "This delivery doesn't have
      // a chat thread", which is a claim about SERVER DATA that a failed read is
      // not evidence for — the same mistake #186 fixed for the history read
      // alone. Raise the error body + retry instead.
      final knowsNothing = phase == null && history.isEmpty;
      emit(
        state.copyWith(
          // Ordering (S0-CHAT-04): present history sorted by server time so a
          // backend that returns rows unsorted (or a paged read that interleaves
          // batches) still paints oldest→newest.
          messages: _ordered(history),
          // `unknown`, NOT `broadcasting`, when the phase read could not find
          // out: `unknown` renders no TTL countdown, no accepted banner and no
          // "Waiting for Jeebers…" copy. It asserts nothing, which is the
          // truthful thing to assert.
          phase: phase ?? ConversationPhase.unknown,
          isLoadingHistory: false,
          historyLoadFailed: knowsNothing,
          error: knowsNothing ? ChatError.historyLoadFailed : null,
          historyFailure: knowsNothing
              ? AppFailure.of(_lastPhaseError ?? const UnknownFailure())
              : null,
          clearHistoryFailure: !knowsNothing,
        ),
      );
      // P4/P5: pull the bytes for any inbound `image` that arrived as a bare
      // CDN ref, so the peer's photo renders rather than a placeholder.
      _resolveImageBytes();
      _subscription ??= _gateway.subscribe(_deliveryId).listen(_handleEvent);
    } catch (error) {
      // b02 — A 500 IS NOT AN EMPTY THREAD.
      //
      // This used to be a bare collapse to `messages: const [], phase:
      // ConversationPhase.unknown`, and `unknown` is precisely the branch
      // `_ChatEmptyState` renders as "No conversation yet / This delivery
      // doesn't have a chat thread. Check back once a Jeeber is assigned." So
      // every history-load failure — a gateway 500, a transport drop, the chat
      // store being down — reached the user as a confident statement that there
      // was nothing to see, WHILE A JEEBER WAS ASSIGNED AND IN TRANSIT. There
      // was no error state to render and no way to ask again short of killing
      // the app. That is how the Firestore outage presented.
      //
      // The phase stays `unknown` (we genuinely do not know it) but the state
      // now SAYS SO: `historyLoadFailed` is sticky and drives an error body with
      // a retry, and the empty state is suppressed while it is set. A
      // successful read on ANY later path — [retryLoad], [refresh], the
      // safety-net poll — clears it.
      //
      // `messages: const []` is kept: this is the COLD path, there is nothing on
      // screen to preserve. The non-destructive rule that protects a rendered
      // thread lives in [refresh] / [_reconciledWithHistory].
      emit(state.copyWith(
        messages: const [],
        phase: ConversationPhase.unknown,
        isLoadingHistory: false,
        historyLoadFailed: true,
        error: ChatError.historyLoadFailed,
        historyFailure: AppFailure.of(error),
      ));
    } finally {
      _loadInFlight = false;
    }
    // OFF-04: a queued row is not in server history, so the cold load has to
    // rebuild its failed bubble or the user never sees the unsent message.
    await _rehydrateOutbox();
    // A cold load that FAILED is the one case with nothing left to re-read it:
    // the push bus only fires on inbound traffic, and a thread the user cannot
    // see generates none. Arm the bounded retry (and cancel it on success).
    _syncHistoryRetry();
  }

  /// Re-run the cold load after a history-read failure. Wired to the retry CTA
  /// on the error body ([ChatState.historyLoadFailed]).
  ///
  /// Deliberately [load] and not [refresh]: the failure path left the thread
  /// with no rows AND no inbound subscription (the `subscribe` call sits after
  /// the awaited history read, so a throw skipped it). Only [load] re-establishes
  /// both. It is idempotent on the subscription — `_subscription ??=`.
  Future<void> retryLoad() {
    // A deliberate user retry restarts the backoff from the top: the user has
    // new information (they can see the network is back) that a schedule
    // walking towards 30 s does not.
    _cancelHistoryRetry();
    return load();
  }

  /// Arm or disarm the cold-load-failure retry to match [ChatState.
  /// historyLoadFailed]. Level-triggered and idempotent, so every emit can call
  /// it: a thread that is rendering has no timer at all.
  ///
  /// Only the network gateway opts in (see [ChatGateway.supportsPolling]);
  /// in-memory / fixture gateways drive their own event streams and must not
  /// spawn a timer (it would trip the `FakeAsync` pending-timer assertion in
  /// widget tests).
  void _syncHistoryRetry() {
    if (isClosed || !_gateway.supportsPolling) return;
    if (!state.historyLoadFailed) {
      _cancelHistoryRetry();
      return;
    }
    if (_historyRetryTimer != null) return;
    final step = _historyRetryAttempt < kChatHistoryRetryBackoff.length
        ? _historyRetryAttempt
        : kChatHistoryRetryBackoff.length - 1;
    _historyRetryAttempt++;
    _historyRetryTimer = Timer(
      kChatHistoryRetryBackoff[step],
      _retryHistorySilently,
    );
  }

  void _cancelHistoryRetry() {
    _historyRetryTimer?.cancel();
    _historyRetryTimer = null;
    _historyRetryAttempt = 0;
  }

  /// One silent re-attempt at a thread whose COLD load failed. Silent because
  /// the error body with its retry CTA is already on screen — this must not
  /// flicker it to a spinner behind the user's back.
  ///
  /// Runs through [refresh], not [load]: [refresh] is the non-destructive path
  /// and clears `historyLoadFailed` on any success, which is what disarms this.
  Future<void> _retryHistorySilently() async {
    _historyRetryTimer = null;
    if (isClosed || !state.historyLoadFailed) return;
    _historyRetryCount++;
    Diag.event('chat_history_retry', <String, Object?>{
      'conversation_id': _deliveryId,
      'n': _historyRetryCount,
    });
    await refresh();
    _syncHistoryRetry();
  }

  Timer? _historyRetryTimer;
  int _historyRetryAttempt = 0;
  int _historyRetryCount = 0;

  /// Whether a cold-load-failure retry is currently armed. A rendering thread
  /// must read `false` — that is the assertion that says "no clock left".
  @visibleForTesting
  bool get debugHistoryRetryArmed => _historyRetryTimer != null;

  @visibleForTesting
  int get debugHistoryRetryCount => _historyRetryCount;

  /// A push says this user has chat traffic — re-pull THIS conversation once.
  ///
  /// The bus (`PushRefreshSignals`) is payload-less by design; that is not a
  /// gap here, because this cubit renders exactly one conversation and so the
  /// only conversation it could re-pull is its own. The result is a TARGETED
  /// read (`GET /v1/conversations/{_deliveryId}/messages`), not a fan-out.
  ///
  /// Reconciliation is [refresh]'s, deliberately — NOT a fresh merge rule.
  /// The receipt path folds server echoes into the optimistic bubble that is
  /// already on screen (that is what advances the double-tick from
  /// sending→sent→delivered→read). A push-driven refetch that replaced the
  /// list instead would stall read receipts and drop own bubbles the server
  /// has not echoed yet. Routing through [refresh] means there is ONE fold on
  /// the mount path, the resume path, the failure-retry path and this push
  /// path.
  ///
  /// Single-flight: a burst of pushes (counterpart sends three lines quickly)
  /// collapses onto one in-flight read rather than stacking overlapping reads
  /// whose completions can land out of order.
  Future<void> _refreshFromPush() async {
    if (isClosed) return;
    // THE SAVING. While the Firestore channel is live the MESSAGE ITSELF has
    // already arrived down it — the push is a duplicate notice about content
    // this cubit is holding. Re-pulling here would cost one full
    // `GET /v1/conversations/{id}/messages` per inbound message: at 10 msg/min
    // that is 10 whole-thread reads a minute, where the 60 s poll this replaced
    // cost 1. So the push drives NOTHING while the stream is carrying the thread
    // — exactly Rahmah, where the FCM handler
    // (`firebase_notification_handler.dart:436,:508,:894`) only ever navigates
    // and no branch reloads the thread.
    //
    // It is suppressed, not deleted, and the distinction is deliberate: the flag
    // is driven by the stream's OWN liveness (I-13), so a channel that errors,
    // closes, or never opens (no Firebase identity — an expired session, an
    // older gateway, or the server-side kill switch; see `ChatFirebaseIdentity`)
    // drops straight back to the push-driven read rather than leaving the thread
    // with no inbound path at all. There is no state in which the thread has no
    // inbound path.
    if (_realtimeLive) {
      _pushRefreshSuppressedCount++;
      Diag.event('chat_push_refetch', <String, Object?>{
        'conversation_id': _deliveryId,
        'skipped': 'realtime_live',
        'n': _pushRefreshSuppressedCount,
      });
      return;
    }
    if (_pushRefreshInFlight) {
      Diag.event('chat_push_refetch', <String, Object?>{
        'conversation_id': _deliveryId,
        'skipped': 'in_flight',
      });
      return;
    }
    _pushRefreshInFlight = true;
    _pushRefreshCount++;
    // Device-run attribution seam. `push_received` (the handler) and this line
    // are what let a capture say "this fetch was driven by THIS push" instead
    // of inferring it from a wall-clock coincidence with a poll tick.
    Diag.event('chat_push_refetch', <String, Object?>{
      'conversation_id': _deliveryId,
      'n': _pushRefreshCount,
    });
    try {
      await refresh();
    } finally {
      _pushRefreshInFlight = false;
    }
  }

  /// Re-fetch history + phase for an ALREADY-loaded thread (the chat-detail
  /// screen resuming from the background within a live session). The
  /// screen-scoped cubit is retained in memory across an app background, so the
  /// one-shot create-time [load] never re-runs and any messages the counterpart
  /// sent while we were away would otherwise stay invisible until an app
  /// restart. Unlike [load] this is non-destructive: a transient failure leaves
  /// the visible thread intact (stale-but-present beats blank) and it never
  /// re-creates the inbound subscription (already established by [load]).
  Future<void> refresh() async {
    if (isClosed) return;
    final historyFuture = _gateway.loadHistory(_deliveryId);
    final phaseFuture = _gateway
        .loadPhase(_deliveryId)
        .then<ConversationPhase?>((p) => p, onError: (Object _) => null);
    try {
      final history = await historyFuture;
      final phase = await phaseFuture;
      if (isClosed) return;
      emit(
        state.copyWith(
          messages: _reconciledWithHistory(history),
          // A phase read that could not find out leaves the LAST KNOWN phase in
          // place (`copyWith` keeps the current value for a null). Same rule as
          // the messages above: stale beats invented. Overwriting with
          // `broadcasting` here would silently UN-ACCEPT a live order on one
          // flaky read, mid-delivery.
          phase: phase,
          // Self-heal: a read that succeeds retires BOTH the cold error body
          // and the warm strip a previous failed re-read raised.
          historyLoadFailed: false,
          clearHistoryFailure: true,
          clearRefreshFailure: true,
        ),
      );
      _resolveImageBytes();
      // A read that came back is proof the thread is reachable again, so the
      // cold-load-failure retry stands down.
      _cancelHistoryRetry();
      unawaited(_flushOutbox());
    } catch (error) {
      // F35 — keep the thread, never raise the cold rung or `isLoadingHistory`,
      // but stop being silent about the failed re-read.
      if (isClosed) return;
      emit(state.copyWith(
        refreshFailure: AppFailure.of(error),
        error: ChatError.refreshFailed,
      ));
    }
  }

  /// Fold a re-fetched [history] into what is already on screen, WITHOUT
  /// dropping anything the read did not return.
  ///
  /// This body used to be `messages: List.unmodifiable(history)` — a full
  /// replace. Two ways that blanked a live thread:
  ///
  ///   1. Every optimistic own message the server had not echoed yet was
  ///      dropped on the first resume after sending. `refresh()` is bound to
  ///      `AppLifecycleState.resumed`, so any HOME-and-back, task switch, or
  ///      dismissed permission dialog wiped the user's own just-sent bubbles.
  ///   2. A history read that decoded to NOTHING replaced a rendered thread with
  ///      the empty state, unrecoverably (the bilateral empty-thread collapse).
  ///      `refresh()`'s own contract says "stale-but-present beats blank"; a
  ///      successful-but-empty read has to honour that as much as a thrown one.
  ///
  /// Server rows win wherever they overlap, and this method hands them on in the
  /// SERVER'S OWN ARRAY ORDER: the reconciled list is `[...history, ...leftovers]`,
  /// so for rows the server did not date — whose only ordering information IS
  /// their place in that array — that position survives instead of whatever order
  /// this client happened to learn about them in.
  ///
  /// WHAT THIS DOES **NOT** PROMISE — read this before relying on it. The list
  /// built here is the INPUT to [_ordered], not the rendered order. [_ordered]
  /// sorts by [DeliveryChatMessage.sortAt], and [_withRebasedAnchors] first
  /// collects every undated row into ONE CONTIGUOUS BAND immediately below the
  /// earliest DATED row. So array position is preserved only WITHIN that band:
  ///
  ///   * a server array of `[dated 12:00, undated, dated 12:02]` renders as
  ///     `[undated, dated 12:00, dated 12:02]` — the undated row does not stay
  ///     between the two dated ones;
  ///   * `[them dated 12:00, me undated, them undated]` renders as
  ///     `[me undated, them undated, them dated 12:00]` — their first message
  ///     sinks to the bottom.
  ///
  /// An earlier version of this comment claimed the rendered order simply IS the
  /// server's array order. It is not, and never was; the claim is corrected here
  /// rather than in the code because honouring it literally means dropping the
  /// chronological sort (S0-CHAT-04), which exists because the backend may return
  /// rows unsorted, may page them newest-first, and may append a system row out of
  /// band. The guarantee that actually holds is pinned, case by case, in
  /// `test/features/chat/chat_undated_band_contract_test.dart`.
  ///
  /// A thread in which EVERY row is dated (the live wire since jeeb-gateway #326)
  /// has no band at all, so the distinction is invisible there; it bites on the
  /// legacy timestamp-less wire.
  ///
  /// Overlaps: same id → the server row wins, but it inherits whatever the shown
  /// copy had learned that a re-decode of the wire cannot know (a further-along
  /// receipt status, resolved attachment bytes — see [_adoptEcho]). Without that
  /// inheritance a 60-second poll would demote a `read` bubble back to
  /// `delivered` and blank every image the device had already fetched.
  ///
  /// An own optimistic bubble the server has echoed under a different
  /// (server-minted) id is absorbed by content match, ONE-FOR-ONE, so two
  /// identical own texts never collapse onto a single row. Anything the read did
  /// not return at all is retained — a decode that yields nothing must never be
  /// able to blank a rendered thread.
  List<DeliveryChatMessage> _reconciledWithHistory(
    List<DeliveryChatMessage> history,
  ) {
    // Every history read is also an observation of the server's clock, and the
    // compose anchor is expressed in server time (see [_anchorAfter]).
    _noteServerClock(history);
    final shownById = <String, DeliveryChatMessage>{
      for (final m in state.messages) m.id: m,
    };
    final serverIds = history.map((m) => m.id).toSet();
    // Own server rows still free to absorb an optimistic bubble. Consumed as
    // they match so two identical own texts never collapse onto one row.
    //
    // `!shownById.containsKey(m.id)` is load-bearing, and its absence was a
    // MESSAGE-LOSS defect. An echo whose id is ALREADY ON SCREEN has already
    // been claimed, by id, by the bubble it belongs to — the loop below skips
    // that bubble via `serverIds.contains(shown.id)` and therefore never
    // consumes the echo. Left in the pool, that same echo was free to be
    // claimed a SECOND time, by CONTENT, by a different optimistic bubble:
    // send "ok", let it echo, send "ok" again, and one fold later the second
    // "ok" was gone. Worse when the second send FAILED — `_isEchoOfOwnMessage`
    // keys on kind + text, not status, so a FAILED bubble folded into the
    // earlier DELIVERED echo and left the user looking at a message they never
    // successfully sent. A failed send is never echoed, so that one never
    // self-healed on any later poll, resume, or reload.
    //
    // Pinned by `test/features/chat/chat_echo_double_claim_regression_test.dart`.
    final unclaimedOwnEchoes = history
        .where((m) => m.isMine && !shownById.containsKey(m.id))
        .toList();
    /// Echo id → the shown bubble it absorbed. The absorbed bubble takes the
    /// echo's PLACE IN THE SERVER ARRAY rather than staying where the local send
    /// path put it; that position is the whole point of absorbing it.
    final absorbed = <String, DeliveryChatMessage>{};
    final retained = <DeliveryChatMessage>[];
    for (final shown in state.messages) {
      if (serverIds.contains(shown.id)) continue;
      if (shown.isMine) {
        final echoIndex = unclaimedOwnEchoes
            .indexWhere((echo) => _isEchoOfOwnMessage(shown, echo));
        if (echoIndex != -1) {
          final echo = unclaimedOwnEchoes.removeAt(echoIndex);
          absorbed[echo.id] = _adoptEcho(shown, echo);
          continue;
        }
      }
      retained.add(shown);
    }
    final rows = <DeliveryChatMessage>[
      for (final row in history)
        absorbed[row.id] ??
            (shownById[row.id] == null
                ? row
                : _adoptEcho(shownById[row.id]!, row)),
    ];
    return _ordered([...rows, ...retained]);
  }

  /// Accept the Jeeber whose offer card is identified by [offerId].
  ///
  /// Optimistic: the accepting state flips immediately. On 409 (race: another
  /// Jeeber's offer was accepted first) the optimistic state reverts and a
  /// [ChatError.sendFailed] toast fires.
  Future<void> acceptOffer(String offerId) async {
    if (state.acceptingOfferId != null) return;
    emit(state.copyWith(acceptingOfferId: offerId, clearError: true));
    try {
      final acceptResult = await _gateway.acceptOffer(_deliveryId, offerId);
      // The accept ALREADY SUCCEEDED at this point. A post-accept phase read
      // that cannot reach the server must not roll the optimistic accept back
      // (the `catch` below reverts and toasts `sendFailed`) — so it absorbs its
      // own error into `null` and `copyWith` keeps whatever phase we hold,
      // which the gateway's synthetic `PhaseChanged(accepted)` has already set.
      final historyFuture = _gateway.loadHistory(_deliveryId);
      final phaseFuture = _gateway
          .loadPhase(_deliveryId)
          .then<ConversationPhase?>((p) => p, onError: (Object _) => null);
      final history = await historyFuture;
      final phase = await phaseFuture;
      emit(
        state.copyWith(
          // Ordering (S0-CHAT-04): run the accept re-fetch through the SAME
          // chronological sort the load/poll/WS paths use. A backend that
          // returns the post-accept history unsorted (newest-first paging, or
          // the system `offerAccepted` row appended out of band) would
          // otherwise paint the timeline out of order on the very screen the
          // accepted 1:1 chat lands on.
          //
          // ...and through the same NON-DESTRUCTIVE reconcile as [refresh]. This
          // was `messages: _ordered(history)` — a full replace, on the customer's
          // core accept-an-offer path, the exact amplifier that blanked threads
          // on resume: a post-accept read that decoded to nothing swapped a
          // rendered thread (plus every optimistic own bubble the server had not
          // echoed yet) for the empty state, on the very screen the accepted 1:1
          // chat lands on. `load()`'s `messages: const []` on a cold-load failure
          // stays as it is — there is nothing on screen to lose there.
          messages: _reconciledWithHistory(history),
          phase: phase,
          // Null when the gateway did not surface a delivery id — copyWith
          // keeps any id already captured (e.g. from a PhaseChanged event).
          acceptedDeliveryId: acceptResult.deliveryId,
          clearAcceptingOfferId: true,
        ),
      );
      // The post-accept read can surface peer images (the winning Jeeber's
      // photos) that the broadcasting thread never resolved.
      _resolveImageBytes();
    } catch (_) {
      // On 409 or any error: revert optimistic state, surface error.
      emit(
        state.copyWith(
          clearAcceptingOfferId: true,
          error: ChatError.sendFailed,
        ),
      );
    }
  }

  /// Decline an offer optimistically (greyed-out card). The WS push from the
  /// server is the authoritative state change; the client-side flag is UI-only.
  void declineOffer(String offerId) {
    final updated = Set<String>.from(state.declinedOfferIds)..add(offerId);
    emit(state.copyWith(declinedOfferIds: updated, clearError: true));
  }

  /// Bind the composer field to the cubit. Cleared automatically after a
  /// successful send.
  void composerChanged(String value) {
    if (value == state.composerText) return;
    emit(state.copyWith(composerText: value));
  }

  /// Send the current composer text. No-op if the trimmed value is empty so
  /// the view doesn't have to guard the call itself.
  Future<void> sendText() async {
    final trimmed = state.composerText.trim();
    if (trimmed.isEmpty) return;
    final draft = DeliveryChatMessage.text(
      id: _nextId(),
      author: ChatAuthor.me,
      sentAt: _clock(),
      status: MessageStatus.sending,
      text: trimmed,
    );
    // Optimistic append + composer clear so the user sees the bubble before
    // the gateway resolves.
    emit(
      state.copyWith(
        messages: _appended(draft),
        composerText: '',
        clearError: true,
      ),
    );
    await _dispatch(draft);
  }

  /// One-tap quick reply (redesign-2026-08 screen 21): stage [text] and send it
  /// in one call so the canned string never round-trips through the composer
  /// field — a user who taps "I'm home" must not find it sitting in the input.
  ///
  /// [sendText] already trims, appends optimistically and clears
  /// `composerText`, so this adds no second send path to keep in sync.
  Future<void> sendQuickReply(String text) async {
    emit(state.copyWith(composerText: text));
    await sendText();
  }

  /// Record and upload a voice note. The bubble appears immediately with the
  /// audio URL placeholder; the transcription fills in once the upload resolves.
  /// [audioBytes] is the raw PCM/M4A from the recorder widget.
  Future<void> sendVoiceNote({
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async {
    final idempotencyKey = _nextId(prefix: 'voice');
    final draft = DeliveryChatMessage.voice(
      id: idempotencyKey,
      author: ChatAuthor.me,
      sentAt: _clock(),
      status: MessageStatus.sending,
      url: '',
      durationMs: durationMs,
    );
    emit(state.copyWith(messages: _appended(draft), clearError: true));
    _pendingVoiceUploads[draft.id] = (
      bytes: List<int>.unmodifiable(audioBytes),
      mimeType: mimeType,
      durationMs: durationMs,
    );
    await _dispatchVoiceNote(
      draft: draft,
      audioBytes: audioBytes,
      mimeType: mimeType,
      durationMs: durationMs,
      idempotencyKey: idempotencyKey,
    );
  }

  final Map<String, ({List<int> bytes, String mimeType, int durationMs})>
      _pendingVoiceUploads = {};

  Future<void> _dispatchVoiceNote({
    required DeliveryChatMessage draft,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
    required String idempotencyKey,
  }) async {
    try {
      final result = await _gateway.uploadVoice(
        idempotencyKey: idempotencyKey,
        audioBytes: audioBytes,
        mimeType: mimeType,
        durationMs: durationMs,
      );
      if (_closing || isClosed) return;
      _pendingVoiceUploads.remove(draft.id);
      final uploaded = DeliveryChatMessage.voice(
        id: draft.id,
        author: ChatAuthor.me,
        sentAt: draft.sentAt,
        status: MessageStatus.sending,
        url: result.url,
        durationMs: durationMs,
        transcription: result.transcription,
      );
      _replaceMessage(draft.id, uploaded);
      await _dispatch(uploaded);
    } catch (_) {
      if (_closing || isClosed) return;
      _updateMessage(draft.id, MessageStatus.failed);
      emit(state.copyWith(error: ChatError.voiceUploadFailed));
    }
  }

  /// Swap the message [id] for [replacement], IN PLACE.
  ///
  /// The voice-note and image upload paths hand in a freshly CONSTRUCTED message
  /// rather than a `copyWith` of the draft, so anything the draft carried that a
  /// factory does not take is lost across the swap. The compose-time ordering
  /// anchor is one of those things, and losing it silently reverts the row to
  /// local-clock ordering the next time anything sorts the thread — the same
  /// defect, reappearing on the two paths that do not use `copyWith`. Carry it.
  void _replaceMessage(String id, DeliveryChatMessage replacement) {
    final updated = state.messages
        .map((m) {
          if (m.id != id) return m;
          final anchor = m.orderAnchor;
          return anchor == null ? replacement : replacement.anchoredAt(anchor);
        })
        .toList(growable: false);
    emit(state.copyWith(messages: List.unmodifiable(updated)));
  }

  /// Pick a photo from the camera and send it as a single photo message.
  Future<void> sendPhotoFromCamera() => _pickAndSend(_PickSource.camera);

  /// Pick a photo from the system gallery and send it.
  Future<void> sendPhotoFromGallery() => _pickAndSend(_PickSource.gallery);

  void acknowledgeError() {
    if (state.error == null) return;
    emit(state.copyWith(clearError: true));
  }

  @override
  Future<void> close() async {
    _closing = true;
    _pendingVoiceUploads.clear();
    _cancelHistoryRetry();
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
    await _reconnectSubscription?.cancel();
    _reconnectSubscription = null;
    await _subscription?.cancel();
    return super.close();
  }

  Future<void> _pickAndSend(_PickSource source) async {
    if (state.isAttaching) return;
    emit(state.copyWith(isAttaching: true, clearError: true));
    final DeliveryChatMessage draft;
    final Uint8List compressed;
    try {
      final raw = source == _PickSource.camera
          ? await _pickerService.pickFromCamera()
          : await _pickerService.pickFromGallery();
      compressed = await _compressor.compress(raw.bytes);
      if (_closing || isClosed) return;
      if (compressed.length > _maxAttachmentBytes) {
        emit(state.copyWith(
          isAttaching: false,
          error: ChatError.attachmentUploadFailed,
        ));
        return;
      }
      // Optimistic LOCAL-BYTES bubble: the sender sees their own photo
      // instantly, with no CDN round trip.
      draft = DeliveryChatMessage.photo(
        id: _nextId(),
        author: ChatAuthor.me,
        sentAt: _clock(),
        status: MessageStatus.sending,
        bytes: compressed,
        source: raw.source,
      );
      emit(
        state.copyWith(
          messages: _appended(draft),
          isAttaching: false,
        ),
      );
    } on PhotoPickException catch (e) {
      if (_closing || isClosed) return;
      emit(
        state.copyWith(isAttaching: false, error: _mapPickFailure(e.failure)),
      );
      return;
    } catch (_) {
      if (_closing || isClosed) return;
      emit(
        state.copyWith(isAttaching: false, error: ChatError.pickUnavailable),
      );
      return;
    }
    await _uploadAndDispatchImage(draft: draft, bytes: compressed);
  }

  /// P4/P5 upload-then-send, mirroring [_dispatchVoiceNote] line for line:
  /// upload FIRST, swap the optimistic bubble for the ref-bearing `image` one,
  /// THEN post. A failed upload never posts anything (no phantom success).
  ///
  /// When the gateway has no CDN wired ([ChatGateway.uploadImage] default `''`)
  /// we keep the legacy local-bytes `photo` bubble and dispatch it unchanged —
  /// the in-memory / fixture / devtool hosts behave exactly as before.
  Future<void> _uploadAndDispatchImage({
    required DeliveryChatMessage draft,
    required Uint8List bytes,
  }) async {
    final String objectRef;
    try {
      objectRef = await _gateway.uploadImage(bytes: bytes);
    } catch (_) {
      if (_closing || isClosed) return;
      _updateMessage(draft.id, MessageStatus.failed);
      emit(state.copyWith(error: ChatError.attachmentUploadFailed));
      Diag.event('chat_image_upload', <String, Object?>{
        'deliveryId': _deliveryId,
        'result': 'failed',
      });
      return;
    }
    if (_closing || isClosed) return;
    if (objectRef.isEmpty) {
      await _dispatch(draft);
      return;
    }
    Diag.event('chat_image_upload', <String, Object?>{
      'deliveryId': _deliveryId,
      'result': 'uploaded',
    });
    // Keep the local bytes on the message so the sender's own bubble never
    // blinks through a placeholder while the peer resolves the ref.
    final uploaded = DeliveryChatMessage.image(
      id: draft.id,
      author: ChatAuthor.me,
      sentAt: draft.sentAt,
      status: MessageStatus.sending,
      url: objectRef,
      caption: draft.text,
      bytes: bytes,
    );
    _replaceMessage(draft.id, uploaded);
    await _dispatch(uploaded);
  }

  /// Object refs already fetched (or in flight) so a poll tick never
  /// re-downloads the same image. The bytes live on the message itself.
  final Set<String> _resolvingImageRefs = <String>{};

  /// Fire-and-forget: pull the bytes for any `image` message that has a ref but
  /// no bytes yet, NEWEST FIRST, and swap them onto the bubble.
  void _resolveImageBytes() {
    final pending = state.messages
        .where((m) =>
            m.kind == MessageKind.image &&
            m.photoBytes == null &&
            (m.imageUrl ?? '').isNotEmpty &&
            !_resolvingImageRefs.contains(m.imageUrl))
        .toList(growable: false)
        .reversed
        .take(_maxResolvedImages)
        .toList(growable: false);
    for (final message in pending) {
      final ref = message.imageUrl!;
      _resolvingImageRefs.add(ref);
      unawaited(_fetchImageInto(message.id, ref));
    }
  }

  Future<void> _fetchImageInto(String messageId, String objectRef) async {
    try {
      final bytes = await _gateway.fetchImageBytes(objectRef);
      if (isClosed || bytes.isEmpty) return;
      final current = state.messages.firstWhere(
        (m) => m.id == messageId,
        orElse: () => _missing,
      );
      if (current.id != messageId) return;
      _replaceMessage(
        messageId,
        DeliveryChatMessage.image(
          id: current.id,
          author: current.author,
          sentAt: current.sentAt,
          status: current.status,
          url: objectRef,
          caption: current.text,
          bytes: bytes,
        ),
      );
    } catch (_) {
      // F36 — the poll tick this used to wait for was deleted in N4, so a bare
      // placeholder was permanent. Mark it so the bubble can offer a reload.
      _resolvingImageRefs.remove(objectRef);
      if (isClosed) return;
      final current = state.messages.firstWhere(
        (m) => m.id == messageId,
        orElse: () => _missing,
      );
      if (current.id != messageId) return;
      _replaceMessage(messageId, current.copyWith(imageLoadFailed: true));
    }
  }

  /// Re-enter the image fetch for a tile whose bytes could not be resolved.
  Future<void> retryImage(String messageId) async {
    final current = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => _missing,
    );
    if (current.id != messageId) return;
    final String ref = current.imageUrl ?? '';
    if (ref.isEmpty) return;
    _replaceMessage(messageId, current.copyWith(imageLoadFailed: false));
    if (_resolvingImageRefs.contains(ref)) return;
    _resolvingImageRefs.add(ref);
    await _fetchImageInto(messageId, ref);
  }

  /// "Not found" sentinel for a `firstWhere` lookup — never rendered, never
  /// merged. Flagged undated so that even if it leaked into a list it could not
  /// contribute a date divider or a clock.
  static final DeliveryChatMessage _missing = DeliveryChatMessage.system(
    id: '__missing__',
    sentAt: DateTime.fromMillisecondsSinceEpoch(0),
    text: '',
    hasServerTimestamp: false,
  );

  Future<void> _dispatch(
    DeliveryChatMessage draft, {
    bool userInitiated = true,
  }) async {
    if (_closing || isClosed) return;
    try {
      final ack = await _gateway.send(_deliveryId, draft);
      if (_closing || isClosed) return;
      _updateMessage(draft.id, ack.status);
      Diag.event('chat_message_send', <String, Object?>{
        'deliveryId': _deliveryId,
        'result': ack.status.name,
      });
    } catch (_) {
      if (_closing || isClosed) return;
      _updateMessage(draft.id, MessageStatus.failed);
      // A background flush that fails again is not a user action, so it must
      // not fire the "send failed" snack on every reachability edge.
      if (userInitiated) emit(state.copyWith(error: ChatError.sendFailed));
      Diag.event('chat_message_send', <String, Object?>{
        'deliveryId': _deliveryId,
        'result': 'failed',
      });
      await _persistFailedSend(draft);
    }
  }

  /// OFF-04 — a failed TEXT send survives the process. Attachments carry no
  /// `body`, so they keep the in-memory failed bubble and [retryMessage].
  Future<void> _persistFailedSend(DeliveryChatMessage draft) async {
    final ChatOutbox? outbox = _outbox;
    if (outbox == null || draft.kind != MessageKind.text) return;
    final row = ChatMessage(
      clientId: draft.id,
      conversationId: _deliveryId,
      senderId: _currentUserId,
      body: draft.text,
      createdAt: draft.sentAt.toUtc(),
      status: ChatMessageStatus.failed,
    );
    try {
      // `enqueue` is a plain append on both stores, so a retry that fails again
      // must UPDATE its row — otherwise every edge duplicates it.
      final queued = await outbox.load();
      if (queued.any((m) => m.clientId == row.clientId)) {
        await outbox.update(row);
      } else {
        await outbox.enqueue(row);
      }
      await _syncOutboxPending();
    } catch (error) {
      Diag.event('chat_outbox_enqueue_failed', <String, Object?>{
        'deliveryId': _deliveryId,
        'error': error.runtimeType.toString(),
      });
    }
  }

  /// Resume a failed upload before dispatch; uploaded attachments reuse their ref.
  Future<void> retryMessage(
    String messageId, {
    bool userInitiated = true,
  }) async {
    if (_closing || isClosed) return;
    final message = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => _missing,
    );
    if (message.id != messageId) return;
    if (!message.isMine || message.status != MessageStatus.failed) return;
    _updateMessage(messageId, MessageStatus.sending);
    final draft = message.copyWith(status: MessageStatus.sending);
    final voice = _pendingVoiceUploads[messageId];
    if (voice != null) {
      await _dispatchVoiceNote(
        draft: draft,
        audioBytes: voice.bytes,
        mimeType: voice.mimeType,
        durationMs: voice.durationMs,
        idempotencyKey: messageId,
      );
    } else if (message.kind == MessageKind.voice &&
        (message.voiceUrl ?? '').isEmpty) {
      _updateMessage(messageId, MessageStatus.failed);
      if (userInitiated) emit(state.copyWith(error: ChatError.voiceUploadFailed));
      return;
    } else if (message.kind == MessageKind.photo && message.photoBytes != null) {
      await _uploadAndDispatchImage(draft: draft, bytes: message.photoBytes!);
    } else {
      await _dispatch(draft, userInitiated: userInitiated);
    }
    if (isClosed) return;
    final settled = state.messages.firstWhere(
      (m) => m.id == messageId,
      orElse: () => _missing,
    );
    if (settled.id == messageId &&
        (settled.status == MessageStatus.sent ||
            settled.status == MessageStatus.delivered ||
            settled.status == MessageStatus.read)) {
      await _removeQueuedRow(messageId);
      await _syncOutboxPending();
    }
  }

  Future<void> _removeQueuedRow(String messageId) async {
    try {
      await _outbox?.remove(messageId);
    } catch (error) {
      Diag.event('chat_outbox_remove_failed', <String, Object?>{
        'error': error.runtimeType.toString(),
      });
    }
  }

  /// OFF-04 — rebuild the failed bubbles for rows that outlived the process.
  /// Server history never carries an unsent draft, so without this the
  /// persisted row is invisible AND unreachable by [retryMessage].
  Future<List<ChatMessage>> _rehydrateOutbox() async {
    final ChatOutbox? outbox = _outbox;
    if (outbox == null || isClosed) return const <ChatMessage>[];
    final List<ChatMessage> queued;
    try {
      queued = (await outbox.load())
          .where(_ownsOutboxRow)
          .toList(growable: false);
    } catch (error) {
      Diag.event('chat_outbox_load_failed', <String, Object?>{
        'error': error.runtimeType.toString(),
      });
      return const <ChatMessage>[];
    }
    if (isClosed) return const <ChatMessage>[];
    final known = state.messages.map((m) => m.id).toSet();
    final restored = <DeliveryChatMessage>[
      for (final ChatMessage row in queued)
        if (!known.contains(row.clientId))
          DeliveryChatMessage.text(
            id: row.clientId,
            author: ChatAuthor.me,
            sentAt: row.createdAt,
            status: MessageStatus.failed,
            text: row.body,
          ),
    ];
    if (restored.isNotEmpty) {
      emit(state.copyWith(
        messages: _ordered(<DeliveryChatMessage>[
          ...state.messages,
          ...restored,
        ]),
      ));
    }
    await _syncOutboxPending();
    return queued;
  }

  /// Re-attempt every queued row for THIS conversation. Bounded by the outbox
  /// size; no timer, no schedule.
  Future<void> _flushOutbox() async {
    if (_outbox == null || isClosed) return;
    final List<ChatMessage> queued = await _rehydrateOutbox();
    for (final ChatMessage row in queued) {
      if (_closing || isClosed) return;
      final message = state.messages.firstWhere(
        (m) => m.id == row.clientId,
        orElse: () => _missing,
      );
      if (message.id == row.clientId &&
          message.isMine &&
          (message.status == MessageStatus.sent ||
              message.status == MessageStatus.delivered ||
              message.status == MessageStatus.read)) {
        await _removeQueuedRow(row.clientId);
      } else {
        await retryMessage(row.clientId, userInitiated: false);
      }
    }
    await _syncOutboxPending();
  }

  /// Publish the queued count for THIS conversation so the connection banner
  /// can render it.
  Future<void> _syncOutboxPending() async {
    final ChatOutbox? outbox = _outbox;
    if (outbox == null || isClosed) return;
    try {
      final rows = await outbox.load();
      if (isClosed) return;
      final int mine = rows.where(_ownsOutboxRow).length;
      if (mine == state.outboxPending) return;
      emit(state.copyWith(outboxPending: mine));
    } catch (_) {
      // A count we could not read is not worth a rung of its own.
    }
  }

  bool _ownsOutboxRow(ChatMessage row) =>
      _currentUserId.isNotEmpty &&
      row.senderId == _currentUserId &&
      row.conversationId == _deliveryId;

  void _handleEvent(ChatEvent event) {
    switch (event) {
      case RealtimeTransportChanged(live: final live, reason: final reason):
        // The transport reporting on itself. Nothing renders from this — it only
        // decides whether the push-driven HTTP fallback is still needed.
        if (_realtimeLive == live) return;
        _realtimeLive = live;
        emit(state.copyWith(realtimeLive: live));
        Diag.event('chat_realtime_transport', <String, Object?>{
          'conversation_id': _deliveryId,
          'live': live,
          'reason': reason,
        });
      case IncomingMessage(message: final m):
        // Dedupe by id: the WS push and the poll fallback can both surface the
        // same server message; whichever arrives first wins, the other is a
        // no-op.
        if (state.messages.any((e) => e.id == m.id)) return;
        // OWN-MESSAGE ECHO dedupe (T-APP-2): the mock backend (and the
        // chat-service) fan the sender's OWN message back out over the WS. That
        // echo carries the SERVER message id, which never matches the optimistic
        // local id (`msg-<deliveryId>-N`) the send path assigned — so an
        // id-only check appends a SECOND copy of the user's own bubble (the
        // double-send artifact seen in the E2E). When an inbound message is mine
        // we reconcile it onto the optimistic bubble it echoes (matched by
        // content) instead of appending: adopt the server id so later
        // delivery/read receipts (keyed by the server id) land, and keep the
        // higher of the two statuses.
        if (m.isMine) {
          final echoIndex = _indexOfUnreconciledOwnEcho(m);
          if (echoIndex != -1) {
            _reconcileOwnEcho(echoIndex, m);
            return;
          }
        }
        emit(
          // Ordering (S0-CHAT-04): a live `new_msg` frame can arrive after a
          // later-timestamped message already landed via the poll; sort the
          // merged list by server time so live and reloaded order agree.
          state.copyWith(messages: _ordered([...state.messages, m])),
        );
        _resolveImageBytes();
      case DeliveryReceipt(messageId: final id):
        _promoteAtLeast(id, MessageStatus.delivered);
      case ReadReceipt(throughMessageId: final id):
        _promoteThroughRead(id);
      case MessageDropped(reason: final reason):
        // F34 — a frame the transport could not parse. The thread is missing a
        // message and no retry will fetch it, so say so and offer the re-read.
        emit(state.copyWith(error: ChatError.messageDropped));
        Diag.event('chat_frame_dropped', <String, Object?>{
          'conversation_id': _deliveryId,
          'reason': reason,
        });
      case PhaseChanged(phase: final phase, deliveryId: final deliveryId):
        emit(state.copyWith(phase: phase, acceptedDeliveryId: deliveryId));
        Diag.event('delivery_status', <String, Object?>{
          'deliveryId': deliveryId ?? _deliveryId,
          'phase': phase.name,
        });
    }
  }

  /// Index of an optimistic OWN message that the inbound [echo] is a server
  /// fan-out of, or -1 when none matches. Matched by content (the server echo
  /// carries a different id than the optimistic local one, so an id compare
  /// can't find it). Iterates earliest-first and skips any candidate that
  /// already bears the echo's server id, so a repeated identical echo is a
  /// no-op rather than re-reconciling.
  int _indexOfUnreconciledOwnEcho(DeliveryChatMessage echo) {
    for (var i = 0; i < state.messages.length; i++) {
      final candidate = state.messages[i];
      if (!candidate.isMine) continue;
      if (candidate.id == echo.id) continue;
      if (_isEchoOfOwnMessage(candidate, echo)) return i;
    }
    return -1;
  }

  /// True when [echo] (an inbound `isMine` WS message) is the server fan-out of
  /// the already-shown optimistic [optimistic] message — same kind + same
  /// load-bearing content. Defensive on kind so an echo of one kind never
  /// collapses a bubble of another.
  bool _isEchoOfOwnMessage(
    DeliveryChatMessage optimistic,
    DeliveryChatMessage echo,
  ) {
    if (optimistic.kind != echo.kind) return false;
    switch (echo.kind) {
      case MessageKind.text:
        return echo.text.isNotEmpty && optimistic.text == echo.text;
      case MessageKind.voice:
        return optimistic.voiceDurationMs == echo.voiceDurationMs;
      case MessageKind.photo:
      case MessageKind.image:
        // P4/P5: key on the CDN ref when BOTH sides have one — two different
        // images with empty captions used to compare equal and collapse onto
        // a single bubble.
        final mine = optimistic.imageUrl ?? '';
        final theirs = echo.imageUrl ?? '';
        if (mine.isNotEmpty && theirs.isNotEmpty) return mine == theirs;
        return optimistic.text == echo.text;
      case MessageKind.location:
        return optimistic.latitude == echo.latitude &&
            optimistic.longitude == echo.longitude;
      case MessageKind.system:
      case MessageKind.offerCard:
      case MessageKind.offerAccepted:
      case MessageKind.offerRejected:
        return false;
    }
  }

  /// Replace the optimistic own message at [index] with its server [echo] so
  /// the bubble adopts the canonical server id (later delivery/read receipts,
  /// keyed by that id, then land) — keeping whichever of the two statuses is
  /// further along the lifecycle so an already-`sent`/`delivered` optimistic
  /// bubble is never demoted by the echo.
  void _reconcileOwnEcho(int index, DeliveryChatMessage echo) {
    final updated = List<DeliveryChatMessage>.from(state.messages);
    updated[index] = _adoptEcho(state.messages[index], echo);
    emit(state.copyWith(messages: List.unmodifiable(updated)));
  }

  void _updateMessage(String id, MessageStatus status) {
    final updated = state.messages
        .map((m) {
          if (m.id != id) return m;
          return m.copyWith(status: status);
        })
        .toList(growable: false);
    emit(state.copyWith(messages: List.unmodifiable(updated)));
  }

  void _promoteAtLeast(String id, MessageStatus target) {
    const order = _statusOrder;
    final updated = state.messages
        .map((m) {
          if (m.id != id) return m;
          if (order[m.status]! >= order[target]!) return m;
          return m.copyWith(status: target);
        })
        .toList(growable: false);
    emit(state.copyWith(messages: List.unmodifiable(updated)));
  }

  /// Promote every outgoing message up to and including [throughId] from
  /// `sent`/`delivered` to `read`. Mirrors WhatsApp's "two blue ticks" sweep:
  /// when the counterpart reads message N, every prior unread message is
  /// also marked read.
  void _promoteThroughRead(String throughId) {
    const order = _statusOrder;
    final target = order[MessageStatus.read]!;
    var hit = false;
    final updated = <DeliveryChatMessage>[];
    for (final m in state.messages) {
      if (hit || !m.isMine) {
        updated.add(m);
        continue;
      }
      if (order[m.status]! < target) {
        updated.add(m.copyWith(status: MessageStatus.read));
      } else {
        updated.add(m);
      }
      if (m.id == throughId) hit = true;
    }
    emit(state.copyWith(messages: List.unmodifiable(updated)));
  }

  /// Stable, deterministic chronological ordering (S0-CHAT-04). Returns an
  /// unmodifiable copy of [input] sorted by [DeliveryChatMessage.sortAt]
  /// ascending — the server `created_at` for every row the server has ordered,
  /// and the compose-time anchor for an own bubble it has not echoed yet (see
  /// [DeliveryChatMessage.orderAnchor]; the LOCAL CLOCK never orders anything
  /// against a server timestamp). Equal-`sortAt` ties break on the SERVER-STABLE
  /// message [id]
  /// (the server sequence) — NOT on the client clock and NOT on arrival
  /// position. This is the load-bearing fix: a tie-break by arrival index made
  /// the rendered order depend on WHICH path a same-instant pair arrived by (WS
  /// frame vs HTTP poll vs cold-load history), so the live order and the
  /// reloaded order could disagree. Sorting equal timestamps by id makes the
  /// timeline identical regardless of the transport. The original index is kept
  /// only as a final, defensive tie-break for the impossible case of two equal
  /// ids (Dart's `List.sort` is NOT stable). The contract's canonical timeline
  /// is "oldest first, sorted by the server clock" — applied on every inbound
  /// merge so live (WS), polled (HTTP), and reloaded order all agree.
  static List<DeliveryChatMessage> _ordered(List<DeliveryChatMessage> input) {
    final rebased = _withRebasedAnchors(input);
    final indexed = <MapEntry<int, DeliveryChatMessage>>[
      for (var i = 0; i < rebased.length; i++) MapEntry(i, rebased[i]),
    ];
    indexed.sort((a, b) {
      final byTime = a.value.sortAt.compareTo(b.value.sortAt);
      if (byTime != 0) return byTime;
      final byId = a.value.id.compareTo(b.value.id);
      if (byId != 0) return byId;
      return a.key.compareTo(b.key);
    });
    return List.unmodifiable(indexed.map((e) => e.value));
  }

  /// Finest step a `DateTime` comparison resolves. Used to lay the undated band
  /// out below the earliest dated message without colliding with it.
  static const Duration _anchorStep = Duration(microseconds: 1);

  /// Re-base the ordering anchor of every row the server did not date.
  ///
  /// An undated row carries no evidence about WHEN it was sent — only WHERE it
  /// sits in the server's array. So the timeline puts all such rows in one
  /// contiguous band immediately BELOW (earlier than) the earliest message that
  /// does carry a real timestamp, in the order they appear in [input] — which is
  /// the server's array order on every path that produces them (cold load,
  /// history reconcile, poll merge, inbound frame appended last). Two things
  /// follow:
  ///
  ///   * the band never outranks a message with a real clock, so an undated
  ///     server row can no longer float above the user's own bubbles — the
  ///     "all of theirs, then all of mine" thread;
  ///   * the band is not a DATE. Anchors used to be pinned inside 1970-01-01,
  ///     which any consumer that skipped [DeliveryChatMessage.hasServerTimestamp]
  ///     rendered as a 1970 divider, a 00:00 clock, or a long-expired TTL.
  ///
  /// When NOTHING in the thread is dated there is no reference point to rebase
  /// against, so the provisional anchors the decoder assigned are kept and only
  /// their relative order means anything (nothing may read them — the flag is
  /// false on every one of them).
  static List<DeliveryChatMessage> _withRebasedAnchors(
    List<DeliveryChatMessage> input,
  ) {
    var undated = 0;
    DateTime? earliestDated;
    for (final m in input) {
      if (!m.hasServerTimestamp) {
        undated++;
        continue;
      }
      // `sortAt`, not `sentAt`: an un-echoed own bubble's ordering position is
      // its compose-time anchor, and the band has to be laid out relative to
      // where rows actually SIT, not to a device clock reading that orders
      // nothing.
      if (earliestDated == null || m.sortAt.isBefore(earliestDated)) {
        earliestDated = m.sortAt;
      }
    }
    if (undated == 0) return input;
    // No dated message yet → no reference point, so the band hangs off a fixed
    // low ceiling instead. It STILL has to be re-derived rather than left alone:
    // a merge mixes rows a previous pass already re-based (a 2026 anchor) with
    // rows just decoded (a provisional one), and comparing anchors minted
    // against two different bases is how a thread would shuffle itself. One
    // base per pass, always.
    final ceiling = earliestDated ?? _undatedBandCeiling;
    final out = <DeliveryChatMessage>[];
    var placed = 0;
    for (final m in input) {
      if (m.hasServerTimestamp) {
        out.add(m);
        continue;
      }
      out.add(m.copyWith(
        sentAt: ceiling.subtract(_anchorStep * (undated - placed)),
      ));
      placed++;
    }
    return out;
  }

  /// Ceiling for the undated band when NOTHING in the thread carries a real
  /// timestamp. Low enough that a dated message appearing later still sorts
  /// above the band; never rendered (every message in the band is flagged
  /// `hasServerTimestamp: false`).
  static final DateTime _undatedBandCeiling = DateTime.utc(1971);

  /// Append an optimistic [draft] to the timeline, ANCHORED to the position the
  /// user composed it in.
  ///
  /// This used to skip [_ordered] entirely, because sorting a draft by the LOCAL
  /// clock lets a device whose clock runs slow paint a brand-new message above
  /// the reply that prompted it. Skipping the sort only hid that: the very next
  /// re-sort — a poll tick, a resume, an accept — sorted the same draft by the
  /// same local clock and flipped the thread anyway (and a send that FAILS is
  /// never echoed, so it never self-heals).
  ///
  /// The draft now carries a compose-time [DeliveryChatMessage.orderAnchor]
  /// instead — one step past the newest server-ordered row on screen — which
  /// makes its position a property of the MESSAGE rather than of whichever code
  /// path last rebuilt the list. One ordering rule for every path, and the local
  /// clock is not part of it.
  List<DeliveryChatMessage> _appended(DeliveryChatMessage draft) => _ordered([
        ...state.messages,
        draft.anchoredAt(
          _anchorAfter(state.messages, draft, _projectedServerNow(draft)),
        ),
      ]);

  /// The ordering anchor for a message composed right now: WHERE THE SERVER'S
  /// CLOCK WAS WHEN THE USER PRESSED SEND ([_projectedServerNow]), raised to a
  /// FLOOR of one [_anchorStep] past the newest row already holding an ordering
  /// position — every server-dated row, plus any earlier drafts' anchors.
  ///
  /// Each half answers one failure, and only taking the later of the two answers
  /// both:
  ///
  ///   * THE FLOOR keeps a draft below nothing it has already rendered. It is
  ///     what stops a device whose clock is behind from painting a brand-new
  ///     message above the reply that prompted it, and it is what makes
  ///     successive sends step monotonically when the clock does not move
  ///     between them.
  ///
  ///   * THE PROJECTED SERVER TIME keeps a draft from being pinned to a STALE
  ///     VIEW. This used to return the floor outright — the newest row THIS
  ///     DEVICE HAD SEEN — which is not when the message was composed, and the
  ///     two diverge by a whole poll interval.
  ///     The gap between two reads is now unbounded (there is no poll left —
  ///     reads happen on mount, on resume and on a push), so any row the
  ///     server dated between the last fetch and compose time was unseen at
  ///     compose time and sorted BELOW the draft once it finally arrived: the
  ///     counterpart's message rendered as a reply to a message they had not yet
  ///     received. That fires on a CORRECT clock, on the ordinary "they typed
  ///     while I was typing" path — strictly more often than the skew case it
  ///     was trading against.
  ///
  /// WHY NOT JUST THE LOCAL CLOCK for the second half: because the skew suite
  /// demands both directions at once, and they are the same comparison. In
  /// `chat_clock_skew_order_regression_test.dart`'s FAST-CLOCK case the device
  /// reads 12:20, the newest row it has seen is 12:00 and the reply that lands
  /// afterwards is server-dated 12:01 — it must render BELOW the draft. In
  /// `chat_late_counterpart_row_order_test.dart`'s case the device reads 10:31,
  /// the newest row it has seen is 10:30 and the row that lands afterwards is
  /// server-dated 10:30:30 — it must render ABOVE the draft. Both are "a row
  /// dated between what I last saw and what my clock reads"; no function of the
  /// LOCAL clock can separate them. What separates them is that the first device
  /// is twenty minutes fast and the second is correct, so the anchor is
  /// expressed in SERVER time, where that difference is visible.
  ///
  /// Rows the server did not date are skipped: they hold no position of their
  /// own, they are laid out relative to the dated ones by [_withRebasedAnchors],
  /// so anchoring off one would chase a value that pass is about to rewrite.
  /// When there is nothing to anchor against at all (an empty thread, or one
  /// where nothing is dated) there is no floor and the draft's own clock reading
  /// is used — with no server timestamp anywhere in the thread there is nothing
  /// for it to be wrong RELATIVE TO, and it keeps the undated band out of 1971.
  ///
  /// Pinned by `test/features/chat/chat_late_counterpart_row_order_test.dart`.
  static DateTime _anchorAfter(
    List<DeliveryChatMessage> shown,
    DeliveryChatMessage draft,
    DateTime composedAtServerTime,
  ) {
    DateTime? newest;
    for (final m in shown) {
      if (!m.hasServerTimestamp) continue;
      final at = m.sortAt;
      if (newest == null || at.isAfter(newest)) newest = at;
    }
    if (newest == null) return draft.sentAt;
    final floor = newest.add(_anchorStep);
    return composedAtServerTime.isAfter(floor) ? composedAtServerTime : floor;
  }

  /// Lower bound on how far the SERVER's clock runs ahead of this device's.
  ///
  /// Learnt from history reads and nothing else: a read taken while this device
  /// read `t`, whose newest dated row is `s`, proves the server's clock had
  /// already reached `s` — so `s - t` is a lower bound on the offset. Null until
  /// a read returns at least one dated row; the legacy timestamp-less wire never
  /// populates it and the anchor falls back to the raw local reading.
  ///
  /// Kept as the LARGEST bound ever observed, because a later read that returns
  /// nothing newer teaches strictly less than an earlier one already proved and
  /// must not be allowed to walk the estimate back. It cannot run away: it is
  /// bounded above by the true offset plus one network round trip, and every
  /// fresh message pulls it towards that.
  Duration? _serverClockOffset;

  /// Fold what a freshly read [rows] batch says about the server's clock into
  /// [_serverClockOffset]. Called on every history read — cold load, resume
  /// refresh, safety-net poll and post-accept re-read.
  void _noteServerClock(List<DeliveryChatMessage> rows) {
    DateTime? newest;
    for (final m in rows) {
      // `sentAt`, not `sortAt`: this is measuring the SERVER'S CLOCK, so only a
      // real server timestamp may contribute. A compose-time anchor is a client
      // value and would make the estimate a function of itself.
      if (!m.hasServerTimestamp) continue;
      if (newest == null || m.sentAt.isAfter(newest)) newest = m.sentAt;
    }
    if (newest == null) return;
    final observed = newest.difference(_clock());
    final known = _serverClockOffset;
    if (known == null || observed > known) _serverClockOffset = observed;
  }

  /// This device's best estimate of what the SERVER's clock read at the instant
  /// [draft] was composed. Falls back to the raw local reading while the offset
  /// is still unknown (no dated row has been seen on this thread yet).
  DateTime _projectedServerNow(DeliveryChatMessage draft) {
    final offset = _serverClockOffset;
    return offset == null ? draft.sentAt : draft.sentAt.add(offset);
  }

  /// Reconcile the shown optimistic bubble [shown] onto its server [echo].
  ///
  /// The echo carries the canonical server id (so later delivery/read receipts,
  /// keyed by it, land) and the server's own ordering position. Two things must
  /// survive the swap: whichever status is further along the lifecycle, so an
  /// already-`delivered` bubble is never demoted; and any locally-held
  /// attachment bytes, because the echo is a re-decode of the wire row and
  /// carries the CDN ref but not the bytes — without this the sender's own
  /// just-sent photo blinks back to a placeholder and never recovers
  /// ([_resolvingImageRefs] does not re-fetch a ref it already served).
  static DeliveryChatMessage _adoptEcho(
    DeliveryChatMessage shown,
    DeliveryChatMessage echo,
  ) =>
      echo.copyWith(
        status: _statusOrder[shown.status]! >= _statusOrder[echo.status]!
            ? shown.status
            : echo.status,
        photoBytes: echo.photoBytes ?? shown.photoBytes,
      );

  String _nextId({String prefix = 'msg'}) {
    final suffix = _currentUserId.isEmpty
        ? '${_outboxCounter++}'
        : newOperationId();
    return '$prefix-$_deliveryId-$suffix';
  }

  ChatError _mapPickFailure(PhotoPickFailure failure) {
    switch (failure) {
      case PhotoPickFailure.cancelled:
        return ChatError.pickCancelled;
      case PhotoPickFailure.permissionDenied:
        return ChatError.permissionDenied;
      case PhotoPickFailure.unavailable:
        return ChatError.pickUnavailable;
    }
  }

  /// P4/P5 hard ceiling for an in-chat attachment. The gateway's streaming
  /// upload proxy rejects >15 MB (`CdnUploadProxyController.MaxUploadBytes`);
  /// fail with an honest error a comfortable margin below that rather than
  /// burning a slow upload for a 413.
  static const int _maxAttachmentBytes = 10 * 1024 * 1024;

  /// Newest-first cap on how many peer images we hold in memory at once.
  static const int _maxResolvedImages = 20;

  static const Map<MessageStatus, int> _statusOrder = {
    MessageStatus.failed: -1,
    MessageStatus.sending: 0,
    MessageStatus.sent: 1,
    MessageStatus.delivered: 2,
    MessageStatus.read: 3,
  };
}

DateTime _defaultClock() => DateTime.now();

enum _PickSource { camera, gallery }
