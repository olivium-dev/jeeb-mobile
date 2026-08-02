import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/diagnostics/diag.dart';
import '../../photo_attachment/domain/photo_compressor.dart';
import '../../photo_attachment/domain/photo_picker_service.dart';
import '../domain/chat_gateway.dart';
import '../domain/delivery_chat_message.dart';
import 'chat_state.dart';

/// Retry for cold-load failures; caps and terminates on first success.
const List<Duration> kChatHistoryRetryBackoff = <Duration>[
  Duration(seconds: 2),
  Duration(seconds: 5),
  Duration(seconds: 15),
  Duration(seconds: 30),
];

class ChatCubit extends Cubit<ChatState> {
  ChatCubit({
    required String deliveryId,
    required ChatGateway gateway,
    required PhotoPickerService pickerService,
    PhotoCompressor compressor = const PassthroughPhotoCompressor(),
    DateTime Function() clock = _defaultClock,
    String? initialDeliveryId,
    Stream<void>? refreshSignals,
  }) : _deliveryId = deliveryId,
       _gateway = gateway,
       _pickerService = pickerService,
       _compressor = compressor,
       _clock = clock,
       super(ChatState(
         acceptedDeliveryId: (initialDeliveryId != null &&
                 initialDeliveryId.isNotEmpty)
             ? initialDeliveryId
             : null,
       )) {
    _refreshSubscription = refreshSignals?.listen((_) => _refreshFromPush());
  }

  final String _deliveryId;
  final ChatGateway _gateway;
  final PhotoPickerService _pickerService;
  final PhotoCompressor _compressor;
  final DateTime Function() _clock;

  StreamSubscription<ChatEvent>? _subscription;

  StreamSubscription<void>? _refreshSubscription;

  /// Single-flight latch for overlapping push-driven re-pulls.
  bool _pushRefreshInFlight = false;

  @visibleForTesting
  bool get debugPushRefreshWired => _refreshSubscription != null;

  /// Count of push-driven re-pulls.
  @visibleForTesting
  int get debugPushRefreshCount => _pushRefreshCount;
  int _pushRefreshCount = 0;

  /// Realtime channel liveness (I-13: arming ≠ working).
  bool _realtimeLive = false;

  @visibleForTesting
  bool get debugRealtimeLive => _realtimeLive;

  /// Push signals suppressed while realtime is live.
  @visibleForTesting
  int get debugPushRefreshSuppressedCount => _pushRefreshSuppressedCount;
  int _pushRefreshSuppressedCount = 0;

  /// Counter for outgoing message ids; combined with deliveryId to stay unique.
  int _outboxCounter = 0;

  /// Cold-load history and start listening for events.
  Future<void> load() async {
    emit(state.copyWith(
      isLoadingHistory: true,
      clearError: true,
      historyLoadFailed: false,
    ));
    final historyFuture = _gateway.loadHistory(_deliveryId);
    final phaseFuture = _gateway
        .loadPhase(_deliveryId)
        .then<ConversationPhase?>((p) => p, onError: (Object _) => null);
    try {
      final history = await historyFuture;
      final phase = await phaseFuture;
      _noteServerClock(history);
      final knowsNothing = phase == null && history.isEmpty;
      emit(
        state.copyWith(
          messages: _ordered(history),
          phase: phase ?? ConversationPhase.unknown,
          isLoadingHistory: false,
          historyLoadFailed: knowsNothing,
          error: knowsNothing ? ChatError.historyLoadFailed : null,
        ),
      );
      _resolveImageBytes();
      _subscription ??= _gateway.subscribe(_deliveryId).listen(_handleEvent);
    } catch (_) {
      emit(state.copyWith(
        messages: const [],
        phase: ConversationPhase.unknown,
        isLoadingHistory: false,
        historyLoadFailed: true,
        error: ChatError.historyLoadFailed,
      ));
    }
    _syncHistoryRetry();
  }

  /// Retry cold load; restarts backoff from the top.
  Future<void> retryLoad() {
    _cancelHistoryRetry();
    return load();
  }

  /// Arm or disarm the cold-load-failure retry to match [ChatState.historyLoadFailed].
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

  /// Silent re-attempt via [refresh] path.
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

  /// Whether a cold-load-failure retry is currently armed.
  @visibleForTesting
  bool get debugHistoryRetryArmed => _historyRetryTimer != null;

  @visibleForTesting
  int get debugHistoryRetryCount => _historyRetryCount;

  /// Re-pull THIS conversation once on push signal; single-flighted.
  Future<void> _refreshFromPush() async {
    if (isClosed) return;
    /// While Firestore is live, the message itself has already arrived via it.
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

  /// Re-fetch for ALREADY-loaded thread (non-destructive).
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
          phase: phase,
          historyLoadFailed: false,
        ),
      );
      _resolveImageBytes();
      _cancelHistoryRetry();
    } catch (_) {
    }
  }

  /// Fold re-fetched history into what's on screen WITHOUT dropping anything.
  List<DeliveryChatMessage> _reconciledWithHistory(
    List<DeliveryChatMessage> history,
  ) {
    _noteServerClock(history);
    final shownById = <String, DeliveryChatMessage>{
      for (final m in state.messages) m.id: m,
    };
    final serverIds = history.map((m) => m.id).toSet();
    /// Own server rows still free to absorb an optimistic bubble (prevents double-claim).
    final unclaimedOwnEchoes = history
        .where((m) => m.isMine && !shownById.containsKey(m.id))
        .toList();
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

  /// Accept the Jeeber's offer; optimistic on 409 revert + toast.
  Future<void> acceptOffer(String offerId) async {
    if (state.acceptingOfferId != null) return;
    emit(state.copyWith(acceptingOfferId: offerId, clearError: true));
    try {
      final acceptResult = await _gateway.acceptOffer(_deliveryId, offerId);
      /// Phase-read error absorbed to avoid reverting optimistic accept.
      final historyFuture = _gateway.loadHistory(_deliveryId);
      final phaseFuture = _gateway
          .loadPhase(_deliveryId)
          .then<ConversationPhase?>((p) => p, onError: (Object _) => null);
      final history = await historyFuture;
      final phase = await phaseFuture;
      emit(
        state.copyWith(
          messages: _reconciledWithHistory(history),
          phase: phase,
          acceptedDeliveryId: acceptResult.deliveryId,
          clearAcceptingOfferId: true,
        ),
      );
      _resolveImageBytes();
    } catch (_) {
      emit(
        state.copyWith(
          clearAcceptingOfferId: true,
          error: ChatError.sendFailed,
        ),
      );
    }
  }

  /// Decline offer optimistically (UI-only; WS push is authoritative).
  void declineOffer(String offerId) {
    final updated = Set<String>.from(state.declinedOfferIds)..add(offerId);
    emit(state.copyWith(declinedOfferIds: updated, clearError: true));
  }

  /// Bind composer field to the cubit; cleared after successful send.
  void composerChanged(String value) {
    if (value == state.composerText) return;
    emit(state.copyWith(composerText: value));
  }

  /// Send current composer text; no-op if empty.
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
    emit(
      state.copyWith(
        messages: _appended(draft),
        composerText: '',
        clearError: true,
      ),
    );
    await _dispatch(draft);
  }

  /// Record and upload voice note; bubble appears immediately.
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

  /// Swap message in place; carries compose-time anchor to avoid local-clock reordering.
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
    _cancelHistoryRetry();
    await _refreshSubscription?.cancel();
    _refreshSubscription = null;
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
      /// Optimistic LOCAL-BYTES bubble: sender sees their photo instantly.
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

  /// Upload-then-send: upload FIRST, swap bubble for ref-bearing `image`, THEN post.
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
    /// Keep local bytes so sender's bubble never blinks through placeholder.
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

  /// Object refs already fetched so polls never re-download.
  final Set<String> _resolvingImageRefs = <String>{};

  /// Pull bytes for any `image` message with ref but no bytes yet, NEWEST FIRST.
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
      _resolvingImageRefs.remove(objectRef);
    }
  }

  /// Sentinel for failed `firstWhere` lookup; flagged undated so it cannot create dividers.
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
      case RealtimeTransportChanged(live: final live, reason: final reason):
        if (_realtimeLive == live) return;
        _realtimeLive = live;
        Diag.event('chat_realtime_transport', <String, Object?>{
          'conversation_id': _deliveryId,
          'live': live,
          'reason': reason,
        });
      case IncomingMessage(message: final m):
        /// Dedupe by id: WS push and poll fallback both surface same server message.
        if (state.messages.any((e) => e.id == m.id)) return;
        /// Own-message echo dedupe: reconcile onto optimistic bubble (matched by content).
        if (m.isMine) {
          final echoIndex = _indexOfUnreconciledOwnEcho(m);
          if (echoIndex != -1) {
            _reconcileOwnEcho(echoIndex, m);
            return;
          }
        }
        emit(
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

  /// Index of optimistic OWN message that echo is a fan-out of, or -1.
  int _indexOfUnreconciledOwnEcho(DeliveryChatMessage echo) {
    for (var i = 0; i < state.messages.length; i++) {
      final candidate = state.messages[i];
      if (!candidate.isMine) continue;
      if (candidate.id == echo.id) continue;
      if (_isEchoOfOwnMessage(candidate, echo)) return i;
    }
    return -1;
  }

  /// True when echo is the server fan-out of optimistic message.
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
        /// Key on CDN ref when both have one; prevents caption-based collapse.
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

  /// Replace optimistic bubble with server echo; adopts server id and better status.
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

  /// Promote every outgoing message up to and including throughId to `read`.
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

  /// Stable chronological ordering by server time (S0-CHAT-04); ties break on server id.
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

  /// Finest step a `DateTime` comparison resolves.
  static const Duration _anchorStep = Duration(microseconds: 1);

  /// Rebase ordering anchor of undated rows to be below earliest dated message.
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
      if (earliestDated == null || m.sortAt.isBefore(earliestDated)) {
        earliestDated = m.sortAt;
      }
    }
    if (undated == 0) return input;
    /// No dated message: use fixed low ceiling; still must re-derive per pass.
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

  /// Ceiling for undated band when nothing in thread carries real timestamp.
  static final DateTime _undatedBandCeiling = DateTime.utc(1971);

  /// Append optimistic draft anchored to compose-time position.
  List<DeliveryChatMessage> _appended(DeliveryChatMessage draft) => _ordered([
        ...state.messages,
        draft.anchoredAt(
          _anchorAfter(state.messages, draft, _projectedServerNow(draft)),
        ),
      ]);

  /// Compose-time anchor: max of (floor past newest row, projected server now).
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

  /// Lower bound on server clock offset; learnt from history reads.
  Duration? _serverClockOffset;

  /// Fold what a freshly read batch says about the server's clock.
  void _noteServerClock(List<DeliveryChatMessage> rows) {
    DateTime? newest;
    for (final m in rows) {
      if (!m.hasServerTimestamp) continue;
      if (newest == null || m.sentAt.isAfter(newest)) newest = m.sentAt;
    }
    if (newest == null) return;
    final observed = newest.difference(_clock());
    final known = _serverClockOffset;
    if (known == null || observed > known) _serverClockOffset = observed;
  }

  /// Best estimate of server's clock at compose time.
  DateTime _projectedServerNow(DeliveryChatMessage draft) {
    final offset = _serverClockOffset;
    return offset == null ? draft.sentAt : draft.sentAt.add(offset);
  }

  /// Reconcile shown bubble onto server echo; carries better status and locally-held bytes.
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

  /// Hard ceiling for in-chat attachment (gateway rejects >15 MB).
  static const int _maxAttachmentBytes = 10 * 1024 * 1024;

  /// Newest-first cap on peer images held in memory.
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
