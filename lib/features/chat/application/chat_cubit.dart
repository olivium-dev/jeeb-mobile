import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';
import 'chat_state.dart';

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
    PhotoCompressor compressor = const HalvingPhotoCompressor(),
    DateTime Function() clock = _defaultClock,
    String? initialDeliveryId,
    Duration pollInterval = const Duration(seconds: 5),
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

  /// Periodic HTTP-history poll timer (the WS-independent inbound fallback).
  Timer? _pollTimer;

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
    _pollTimer ??= Timer.periodic(_pollInterval, (_) => _pollHistory());
  }

  /// Re-pull history and merge any inbound messages not already shown. Inbound
  /// only: messages authored by the local user are owned optimistically by the
  /// send path (they carry client ids the server never echoes back), so we skip
  /// them to avoid duplicate own-bubbles; counterpart/system messages are
  /// matched by server id, so a message already delivered over the WS is not
  /// re-appended.
  Future<void> _pollHistory() async {
    try {
      final latest = await _gateway.loadHistory(_deliveryId);
      _mergeInbound(latest);
    } catch (_) {
      // Transient fetch failure — the next tick retries. Never surface an error
      // for a background poll.
    }
  }

  void _mergeInbound(List<DeliveryChatMessage> latest) {
    if (isClosed) return;
    final existingIds = state.messages.map((m) => m.id).toSet();
    final additions = latest
        .where((m) => !m.isMine && !existingIds.contains(m.id))
        .toList(growable: false);
    if (additions.isEmpty) return;
    emit(
      state.copyWith(
        // Ordering (S0-CHAT-04): a poll can surface a counterpart message whose
        // server `created_at` predates a bubble already shown (late delivery,
        // clock skew between parties). Re-sort the merged list by server time so
        // the timeline stays chronological instead of appending out of order.
        messages: _ordered([...state.messages, ...additions]),
      ),
    );
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
          messages: List.unmodifiable(history),
          phase: phase,
          // Null when the gateway did not surface a delivery id — copyWith
          // keeps any id already captured (e.g. from a PhaseChanged event).
          acceptedDeliveryId: acceptResult.deliveryId,
          clearAcceptingOfferId: true,
        ),
      );
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
        messages: List.unmodifiable([...state.messages, draft]),
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
      messages: List.unmodifiable([...state.messages, draft]),
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
    _pollTimer?.cancel();
    _pollTimer = null;
    await _subscription?.cancel();
    return super.close();
  }

  Future<void> _pickAndSend(_PickSource source) async {
    if (state.isAttaching) return;
    emit(state.copyWith(isAttaching: true, clearError: true));
    try {
      final raw = source == _PickSource.camera
          ? await _pickerService.pickFromCamera()
          : await _pickerService.pickFromGallery();
      final compressed = await _compressor.compress(raw.bytes);
      final draft = DeliveryChatMessage.photo(
        id: _nextId(),
        author: ChatAuthor.me,
        sentAt: _clock(),
        status: MessageStatus.sending,
        bytes: compressed,
        source: raw.source,
      );
      emit(
        state.copyWith(
          messages: List.unmodifiable([...state.messages, draft]),
          isAttaching: false,
        ),
      );
      await _dispatch(draft);
    } on PhotoPickException catch (e) {
      emit(
        state.copyWith(isAttaching: false, error: _mapPickFailure(e.failure)),
      );
    } catch (_) {
      emit(
        state.copyWith(isAttaching: false, error: ChatError.pickUnavailable),
      );
    }
  }

  Future<void> _dispatch(DeliveryChatMessage draft) async {
    try {
      final ack = await _gateway.send(_deliveryId, draft);
      _updateMessage(draft.id, ack.status);
    } catch (_) {
      _updateMessage(draft.id, MessageStatus.failed);
      emit(state.copyWith(error: ChatError.sendFailed));
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
      case DeliveryReceipt(messageId: final id):
        _promoteAtLeast(id, MessageStatus.delivered);
      case ReadReceipt(throughMessageId: final id):
        _promoteThroughRead(id);
      case PhaseChanged(phase: final phase, deliveryId: final deliveryId):
        emit(state.copyWith(phase: phase, acceptedDeliveryId: deliveryId));
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
    final optimistic = state.messages[index];
    final keepStatus =
        _statusOrder[optimistic.status]! >= _statusOrder[echo.status]!
            ? optimistic.status
            : echo.status;
    final reconciled = echo.copyWith(status: keepStatus);
    final updated = List<DeliveryChatMessage>.from(state.messages);
    updated[index] = reconciled;
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

  /// Stable chronological ordering (S0-CHAT-04). Returns an unmodifiable copy of
  /// [input] sorted by server `created_at` (`sentAt`) ascending, breaking ties
  /// by the message's existing position so equal-timestamped or same-instant
  /// messages keep their arrival order (Dart's `List.sort` is NOT stable, so we
  /// decorate with the original index). The contract's canonical timeline is
  /// "oldest first, sorted by the server clock" — applied on every inbound merge
  /// so live (WS), polled (HTTP), and reloaded order all agree.
  static List<DeliveryChatMessage> _ordered(List<DeliveryChatMessage> input) {
    final indexed = <MapEntry<int, DeliveryChatMessage>>[
      for (var i = 0; i < input.length; i++) MapEntry(i, input[i]),
    ];
    indexed.sort((a, b) {
      final byTime = a.value.sentAt.compareTo(b.value.sentAt);
      return byTime != 0 ? byTime : a.key.compareTo(b.key);
    });
    return List.unmodifiable(indexed.map((e) => e.value));
  }

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
