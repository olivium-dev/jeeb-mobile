import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../../core/lifecycle/lifecycle_poller.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';
import 'chat_state.dart';

const kChatHistorySafetyNetPollInterval = Duration(seconds: 60);

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
    Duration pollInterval = kChatHistorySafetyNetPollInterval,
  }) : _deliveryId = deliveryId,
       _gateway = gateway,
       _pickerService = pickerService,
       _compressor = compressor,
       _clock = clock,
       _pollInterval = pollInterval,
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
       ));

  final String _deliveryId;
  final ChatGateway _gateway;
  final PhotoPickerService _pickerService;
  final PhotoCompressor _compressor;
  final DateTime Function() _clock;

  /// Cadence of the HTTP-history POLL fallback. The live transport is the WS
  /// subscription, but against the mock backend (and any flaky/unauthorized WS)
  /// the socket may never establish — so we also re-pull history on this
  /// interval and merge any inbound messages the socket missed. Keeps inbound
  /// working even with zero live frames ("live == within one poll").
  final Duration _pollInterval;

  StreamSubscription<ChatEvent>? _subscription;

  /// Periodic HTTP-history poll (the WS-independent inbound fallback).
  late final LifecyclePoller _historyPoller = LifecyclePoller(
    interval: _pollInterval,
    onTick: _pollHistory,
    tickOnResume: false,
    debugLabel: 'ChatCubit.history',
  );

  @visibleForTesting
  bool get debugHistoryPollerRunning => _historyPoller.isRunning;

  @visibleForTesting
  // ignore: invalid_use_of_visible_for_testing_member
  int get debugHistoryTickCount => _historyPoller.debugTickCount;

  /// Monotonic counter feeding outgoing message ids. Combined with the
  /// delivery id to stay unique across two cubits running in the same
  /// process during tests.
  int _outboxCounter = 0;

  /// Cold-load entry point. Pulls any historical messages from the gateway
  /// and starts listening for inbound events. Also fetches the conversation
  /// phase so the composer/offer-card UI renders correctly on first paint.
  Future<void> load() async {
    emit(state.copyWith(isLoadingHistory: true, clearError: true));
    try {
      final results = await Future.wait([
        _gateway.loadHistory(_deliveryId),
        _gateway.loadPhase(_deliveryId),
      ]);
      final history = results[0] as List<DeliveryChatMessage>;
      final phase = results[1] as ConversationPhase;
      emit(
        state.copyWith(
          // Ordering (S0-CHAT-04): present history sorted by server time so a
          // backend that returns rows unsorted (or a paged read that interleaves
          // batches) still paints oldest→newest.
          messages: _ordered(history),
          phase: phase,
          isLoadingHistory: false,
        ),
      );
      // P4/P5: pull the bytes for any inbound `image` that arrived as a bare
      // CDN ref, so the peer's photo renders rather than a placeholder.
      _resolveImageBytes();
      _subscription ??= _gateway.subscribe(_deliveryId).listen(_handleEvent);
    } catch (_) {
      emit(state.copyWith(
        messages: const [],
        phase: ConversationPhase.unknown,
        isLoadingHistory: false,
      ));
    }
    // Start the HTTP-history poll fallback regardless of the initial load
    // outcome — it is the inbound path that does NOT depend on a live socket,
    // so it must run even if the first history fetch failed (recovery) or the
    // WS never connects (mock / non-member / transport).
    _startPolling();
  }

  /// Arm the periodic HTTP-history poll. Idempotent — repeated [load] calls
  /// reuse the single timer. Only the network gateway opts in (see
  /// [ChatGateway.supportsPolling]); in-memory / fixture gateways drive their
  /// own event streams and must not spawn a forever-periodic timer (it would
  /// trip the `FakeAsync` pending-timer assertion in widget tests).
  void _startPolling() {
    if (!_gateway.supportsPolling) return;
    _historyPoller.start();
  }

  /// Re-pull history and fold it in. Runs through the SAME non-destructive
  /// reconcile as [refresh] / [acceptOffer], so the polled order, the resumed
  /// order and the accepted order are the server's order on all three paths —
  /// there is one merge rule in this cubit, not three.
  Future<void> _pollHistory() async {
    try {
      final latest = await _gateway.loadHistory(_deliveryId);
      if (isClosed) return;
      emit(state.copyWith(messages: _reconciledWithHistory(latest)));
      _resolveImageBytes();
    } catch (_) {
      // Transient fetch failure — the next tick retries. Never surface an error
      // for a background poll.
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
    try {
      final results = await Future.wait([
        _gateway.loadHistory(_deliveryId),
        _gateway.loadPhase(_deliveryId),
      ]);
      if (isClosed) return;
      final history = results[0] as List<DeliveryChatMessage>;
      final phase = results[1] as ConversationPhase;
      emit(
        state.copyWith(
          messages: _reconciledWithHistory(history),
          phase: phase,
        ),
      );
      _resolveImageBytes();
    } catch (_) {
      // Keep the current thread on a transient refresh failure.
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
  /// Server rows win wherever they overlap, and they keep the SERVER'S OWN
  /// POSITION: the reconciled list is `[...history, ...leftovers]`, so for rows
  /// the server did not date — whose only ordering information IS their place in
  /// that array — the rendered order is the server's array order rather than
  /// whatever order this client happened to learn about them in.
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
    final shownById = <String, DeliveryChatMessage>{
      for (final m in state.messages) m.id: m,
    };
    final serverIds = history.map((m) => m.id).toSet();
    // Own server rows still free to absorb an optimistic bubble. Consumed as
    // they match so two identical own texts never collapse onto one row.
    final unclaimedOwnEchoes = history.where((m) => m.isMine).toList();
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
      final results = await Future.wait([
        _gateway.loadHistory(_deliveryId),
        _gateway.loadPhase(_deliveryId),
      ]);
      final history = results[0] as List<DeliveryChatMessage>;
      final phase = results[1] as ConversationPhase;
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

  /// Record and upload a voice note. The bubble appears immediately with the
  /// audio URL placeholder; the transcription fills in once the upload resolves.
  /// [audioBytes] is the raw PCM/M4A from the recorder widget.
  Future<void> sendVoiceNote({
    required List<int> audioBytes,
    required String mimeType,
    required int durationMs,
  }) async {
    final idempotencyKey = 'voice-$_deliveryId-${_outboxCounter++}';
    final draft = DeliveryChatMessage.voice(
      id: idempotencyKey,
      author: ChatAuthor.me,
      sentAt: _clock(),
      status: MessageStatus.sending,
      url: '',
      durationMs: durationMs,
    );
    emit(state.copyWith(
      messages: _appended(draft),
      clearError: true,
    ));
    await _dispatchVoiceNote(
      draft: draft,
      audioBytes: audioBytes,
      mimeType: mimeType,
      durationMs: durationMs,
      idempotencyKey: idempotencyKey,
    );
  }

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
      final uploaded = DeliveryChatMessage.voice(
        id: draft.id,
        author: ChatAuthor.me,
        sentAt: draft.sentAt,
        status: MessageStatus.sent,
        url: result.url,
        durationMs: durationMs,
        transcription: result.transcription,
      );
      _replaceMessage(draft.id, uploaded);
      await _dispatch(uploaded);
    } catch (_) {
      _updateMessage(draft.id, MessageStatus.failed);
      emit(state.copyWith(error: ChatError.voiceUploadFailed));
    }
  }

  void _replaceMessage(String id, DeliveryChatMessage replacement) {
    final updated = state.messages
        .map((m) => m.id == id ? replacement : m)
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
    _historyPoller.dispose();
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
      emit(
        state.copyWith(isAttaching: false, error: _mapPickFailure(e.failure)),
      );
      return;
    } catch (_) {
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
      _updateMessage(draft.id, MessageStatus.failed);
      emit(state.copyWith(error: ChatError.attachmentUploadFailed));
      Diag.event('chat_image_upload', <String, Object?>{
        'deliveryId': _deliveryId,
        'result': 'failed',
      });
      return;
    }
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
      // Leave the placeholder; a later poll tick retries after eviction.
      _resolvingImageRefs.remove(objectRef);
    }
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

  Future<void> _dispatch(DeliveryChatMessage draft) async {
    try {
      final ack = await _gateway.send(_deliveryId, draft);
      _updateMessage(draft.id, ack.status);
      Diag.event('chat_message_send', <String, Object?>{
        'deliveryId': _deliveryId,
        'result': ack.status.name,
      });
    } catch (_) {
      _updateMessage(draft.id, MessageStatus.failed);
      emit(state.copyWith(error: ChatError.sendFailed));
      Diag.event('chat_message_send', <String, Object?>{
        'deliveryId': _deliveryId,
        'result': 'failed',
      });
    }
  }

  void _handleEvent(ChatEvent event) {
    switch (event) {
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
  /// unmodifiable copy of [input] sorted by the server `created_at` (`sentAt`)
  /// ascending. Equal-`sentAt` ties break on the SERVER-STABLE message [id]
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
      final byTime = a.value.sentAt.compareTo(b.value.sentAt);
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
      if (earliestDated == null || m.sentAt.isBefore(earliestDated)) {
        earliestDated = m.sentAt;
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

  /// Append an optimistic [draft] to the timeline.
  ///
  /// Deliberately NOT the full [_ordered] sort. A draft the user just composed
  /// belongs at the bottom, and sorting it by the LOCAL clock would let a device
  /// whose clock runs slow paint a brand-new message above the reply that
  /// prompted it. The anchors of undated rows are still re-based, because this
  /// draft may be the first dated message the thread has ever had.
  List<DeliveryChatMessage> _appended(DeliveryChatMessage draft) =>
      List.unmodifiable(_withRebasedAnchors([...state.messages, draft]));

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

  String _nextId() => 'msg-$_deliveryId-${_outboxCounter++}';

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
