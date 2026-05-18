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
  }) : _deliveryId = deliveryId,
       _gateway = gateway,
       _pickerService = pickerService,
       _compressor = compressor,
       _clock = clock,
       super(const ChatState());

  final String _deliveryId;
  final ChatGateway _gateway;
  final PhotoPickerService _pickerService;
  final PhotoCompressor _compressor;
  final DateTime Function() _clock;

  StreamSubscription<ChatEvent>? _subscription;

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
          messages: List.unmodifiable(history),
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
  }

  /// Accept the Jeeber whose offer card is identified by [offerId]. Flips
  /// the conversation to [ConversationPhase.accepted], drops losing offer
  /// cards out of the visible list, and re-fetches history so the server's
  /// system message is visible.
  Future<void> acceptOffer(String offerId) async {
    if (state.acceptingOfferId != null) return;
    emit(state.copyWith(acceptingOfferId: offerId, clearError: true));
    try {
      await _gateway.acceptOffer(_deliveryId, offerId);
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
          clearAcceptingOfferId: true,
        ),
      );
    } catch (_) {
      emit(
        state.copyWith(
          clearAcceptingOfferId: true,
          error: ChatError.sendFailed,
        ),
      );
    }
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
        emit(
          state.copyWith(messages: List.unmodifiable([...state.messages, m])),
        );
      case DeliveryReceipt(messageId: final id):
        _promoteAtLeast(id, MessageStatus.delivered);
      case ReadReceipt(throughMessageId: final id):
        _promoteThroughRead(id);
      case PhaseChanged(phase: final phase):
        emit(state.copyWith(phase: phase));
    }
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
    final order = _statusOrder;
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
    final order = _statusOrder;
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
