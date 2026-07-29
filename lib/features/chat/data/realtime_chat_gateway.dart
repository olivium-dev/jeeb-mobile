import 'dart:async';
import 'dart:typed_data';

import '../../client_offers/domain/offers_repository.dart' show OfferAcceptResult;
import '../domain/chat_gateway.dart';
import '../domain/chat_realtime_source.dart';
import '../domain/delivery_chat_message.dart';

/// Replaces ONE method of a [ChatGateway] — [subscribe] — with a realtime
/// [ChatRealtimeSource], and forwards everything else untouched.
///
/// # Why a decorator rather than an edit to `DioChatGateway`
///
/// The split is the architecture, not a style choice. The owner's ruling is
/// *"the backend should only store in firestore… the mobile should subscribe"*,
/// and that maps exactly onto these two halves:
///
///   * **WRITES and one-shot READS stay HTTP.** `send` must keep going through
///     `POST /v1/conversations/{id}/messages`, because the gateway is what
///     stamps `author_id` from the bearer JWT (a client that wrote to Firestore
///     directly could post as anyone), what enforces idempotency, and what runs
///     the offer/accept saga. The cold `loadHistory` stays HTTP too: it is the
///     one read that must return the WHOLE thread, and it comes back already
///     filtered by `MessageVisibilityResolver`.
///   * **The live channel becomes Firestore.** Only the inbound stream changes.
///
/// Keeping that in a decorator means `DioChatGateway` is not conditionally two
/// different things depending on a flag, and a host with no realtime source
/// simply does not build this wrapper.
///
/// # It does not fall back
///
/// If the realtime source cannot open a channel this gateway does NOT quietly
/// substitute the old WebSocket stream. It forwards the source's
/// [RealtimeTransportChanged] `live: false` and lets `ChatCubit` decide — which
/// it does by keeping the HTTP fallback armed. A transport that silently
/// substitutes another transport is how a surface ends up with two live paths
/// and no way to tell which one is carrying it.
class RealtimeChatGateway implements ChatGateway {
  RealtimeChatGateway({
    required ChatGateway inner,
    required ChatRealtimeSource realtime,
  })  : _inner = inner,
        _realtime = realtime;

  final ChatGateway _inner;
  final ChatRealtimeSource _realtime;

  /// THE change. Everything below this method is forwarding.
  ///
  /// # Why this MERGES instead of replacing
  ///
  /// It used to be `=> _realtime.subscribe(conversationId)`, and that dropped
  /// events the Firestore channel structurally cannot carry. `subscribe` is not
  /// only the message pipe: it is the gateway's whole inbound [ChatEvent]
  /// channel, and [DioChatGateway] puts things on it that never touch the
  /// `Messages` subcollection. The one that bites is
  /// `acceptOffer` → `PhaseChanged(ConversationPhase.accepted, deliveryId: …)`
  /// (`dio_chat_gateway.dart:470-474`), synthesised locally from the accept
  /// response because it is the ONLY moment the client learns the server-created
  /// delivery id. Swallow it and the customer taps Accept, the composer does not
  /// appear and the "Track order" path never lights up — the wrap turning the
  /// accept into a no-op is a strictly worse regression than the HTTP refetch it
  /// was built to remove.
  ///
  /// So both legs are live and both are forwarded. Duplicate arrivals are
  /// already handled: `ChatCubit._handleEvent` dedupes by message id and
  /// reconciles the sender's own echo, which is the same machinery that lets the
  /// snapshot and the HTTP history agree on one bubble.
  ///
  /// # Cancellation
  ///
  /// The merged stream owns BOTH subscriptions and cancels BOTH when it is
  /// cancelled — a merge that forgets one leg leaks a live listener, which on
  /// the realtime leg is an open Firestore channel and is a worse bug than the
  /// dropped event. `_realtime.subscribe`'s controller carries
  /// `onCancel: () => unawaited(dispose())`
  /// (`firestore_chat_realtime_source.dart:91`), so cancelling here also tears
  /// the `.snapshots()` listener down rather than merely unhooking from it.
  ///
  /// Single-subscription by construction, matching the one listener the cubit
  /// takes (`chat_cubit.dart:248`). The merged stream closes only when BOTH legs
  /// are done — a realtime channel that closes must NOT take the phase channel
  /// with it, which is exactly the case `RealtimeTransportChanged(live: false)`
  /// exists to describe.
  @override
  Stream<ChatEvent> subscribe(String conversationId) => _MergedChatEvents(
        <Stream<ChatEvent> Function()>[
          () => _realtime.subscribe(conversationId),
          () => _inner.subscribe(conversationId),
        ],
      ).stream;

  /// Still true, and still for the same reason — but read the field's doc on
  /// [ChatGateway]. It no longer gates a poll: it gates the cold-load-failure
  /// retry, which is armed only in an error state and terminates on the first
  /// success. A realtime channel does not make a failed COLD load recover on its
  /// own (there is nothing on screen to push to), so this stays on.
  @override
  bool get supportsPolling => _inner.supportsPolling;

  @override
  Future<List<DeliveryChatMessage>> loadHistory(String conversationId) =>
      _inner.loadHistory(conversationId);

  @override
  Future<ConversationPhase> loadPhase(String conversationId) =>
      _inner.loadPhase(conversationId);

  @override
  Future<DeliveryChatMessage> send(
    String conversationId,
    DeliveryChatMessage message,
  ) =>
      _inner.send(conversationId, message);

  @override
  Future<OfferAcceptResult> acceptOffer(String conversationId, String offerId) =>
      _inner.acceptOffer(conversationId, offerId);

  @override
  Future<VoiceUploadResult> uploadVoice({
    required String idempotencyKey,
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) =>
      _inner.uploadVoice(
        idempotencyKey: idempotencyKey,
        audioBytes: audioBytes,
        mimeType: mimeType,
        durationMs: durationMs,
      );

  @override
  Future<String> uploadImage({
    required Uint8List bytes,
    String contentType = 'image/jpeg',
  }) =>
      _inner.uploadImage(bytes: bytes, contentType: contentType);

  @override
  Future<Uint8List> fetchImageBytes(String objectRef) =>
      _inner.fetchImageBytes(objectRef);

  Future<void> dispose() => _realtime.dispose();
}

/// The N-leg merge behind [RealtimeChatGateway.subscribe]: one single-listener
/// stream that carries every event from every leg and owns every leg's teardown.
///
/// # Why a class and not closures over locals
///
/// Two reasons, and the second is the honest one.
///
///  1. Opening and cancelling live in ONE object with ONE owner, so "who cancels
///     the inner leg" has a single answer instead of being spread across three
///     nested closures.
///  2. The `cancel_subscriptions` lint reads a `StreamSubscription` held in a
///     LOCAL and cancelled from inside a callback as uncancelled, and it is right
///     to — that shape is one early `return` away from a genuine leak. As fields
///     with a single [_cancelLegs] the teardown is checkable by the analyzer and
///     by a reader.
///
/// Legs are opened LAZILY, on first listen. That preserves the property the
/// realtime source is written around — no listener means the Firestore
/// `.snapshots()` channel is never opened at all — rather than opening a channel
/// nobody is reading.
class _MergedChatEvents {
  _MergedChatEvents(this._legs) {
    _out = StreamController<ChatEvent>(onListen: _open, onCancel: _cancelLegs);
  }

  final List<Stream<ChatEvent> Function()> _legs;
  final List<StreamSubscription<ChatEvent>> _subscriptions =
      <StreamSubscription<ChatEvent>>[];

  late final StreamController<ChatEvent> _out;

  /// Legs that have not yet reported `onDone`.
  int _openLegs = 0;

  Stream<ChatEvent> get stream => _out.stream;

  void _open() {
    // Counted BEFORE the first listen: a leg that completes synchronously must
    // not be able to drive the count to zero while later legs are still being
    // attached, which would close the merged stream on arrival.
    _openLegs = _legs.length;
    for (final leg in _legs) {
      _subscriptions.add(
        leg().listen(
          _forward,
          onError: _forwardError,
          onDone: _legDone,
          // An error must NOT retire the leg. The realtime source reports its
          // own death as an event (`RealtimeTransportChanged(live: false)`) that
          // the cubit re-arms the HTTP fallback from, so the subscription has to
          // survive an error to keep delivering.
          cancelOnError: false,
        ),
      );
    }
  }

  void _forward(ChatEvent event) {
    if (!_out.isClosed) _out.add(event);
  }

  void _forwardError(Object error, StackTrace stackTrace) {
    if (!_out.isClosed) _out.addError(error, stackTrace);
  }

  /// Closes the merged stream only once EVERY leg is done. A realtime channel
  /// that closes must not take the HTTP gateway's phase channel with it — that
  /// is precisely the state `RealtimeTransportChanged(live: false)` describes,
  /// and the accept saga still has to be able to speak afterwards.
  void _legDone() {
    _openLegs -= 1;
    if (_openLegs <= 0 && !_out.isClosed) unawaited(_out.close());
  }

  /// EVERY leg, always. A merge that cancels one and forgets the other leaks a
  /// live listener — on the realtime leg an open Firestore channel — which is a
  /// worse failure than the dropped events this merge exists to fix. Cancelling
  /// the realtime leg also disposes its source, whose controller carries
  /// `onCancel: () => unawaited(dispose())`
  /// (`firestore_chat_realtime_source.dart:91`).
  Future<void> _cancelLegs() async {
    final legs = List<StreamSubscription<ChatEvent>>.of(_subscriptions);
    _subscriptions.clear();
    await Future.wait(legs.map((leg) => leg.cancel()));
  }
}
