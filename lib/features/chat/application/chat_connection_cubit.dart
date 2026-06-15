import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../domain/chat_event.dart';
import '../domain/chat_message.dart';
import '../domain/chat_outbox.dart';
import '../domain/chat_socket.dart';
import '../domain/connection_status.dart';
import 'chat_connection_state.dart';
import 'reconnect_policy.dart';

/// Factory the cubit calls to build a fresh transport per attempt. Each
/// reconnect must construct a brand-new [ChatSocket] — re-using a torn-down
/// socket is unsafe.
typedef ChatSocketFactory = ChatSocket Function();

/// Wall-clock provider injected so tests can fake `createdAt` timestamps.
typedef ChatClock = DateTime Function();

/// Random-id generator for new outbound messages. Tests inject a counter.
typedef ChatIdGenerator = String Function();

/// Schedules the reconnect backoff. Defaults to the real [Timer] constructor;
/// tests inject `fakeAsync`'s clock (or a manual fake) so the backoff schedule
/// is driven by virtual time instead of wall-clock sleeps. Keeping this a seam
/// means production behavior is byte-for-byte identical to a bare `Timer(...)`.
typedef ChatTimerFactory = Timer Function(Duration duration, void Function() callback);

/// Owns the chat WebSocket connection, the offline outbox, and reconnect
/// scheduling. Surfaces a single [ChatConnectionState] to the UI.
///
/// Key invariants:
///   - Only one active [ChatSocket] subscription at a time. Reconnect
///     always tears down the previous socket before opening a new one.
///   - Outbox state is the source of truth for `pending`; the in-memory
///     state.pending mirrors what's on disk after every write.
///   - Reconnect attempts grow with [ReconnectPolicy.delayFor]; cancelling
///     the cubit's `close()` stops the loop.
class ChatConnectionCubit extends Cubit<ChatConnectionState> {
  ChatConnectionCubit({
    required ChatSocketFactory socketFactory,
    required ChatOutbox outbox,
    required String currentUserId,
    ReconnectPolicy policy = const ReconnectPolicy(),
    ChatClock? clock,
    ChatIdGenerator? idGenerator,
    ChatTimerFactory? timerFactory,
  })  : _socketFactory = socketFactory,
        _outbox = outbox,
        _currentUserId = currentUserId,
        _policy = policy,
        _clock = clock ?? DateTime.now,
        _idGenerator = idGenerator ?? _defaultIdGenerator,
        _timerFactory = timerFactory ?? Timer.new,
        super(const ChatConnectionState());

  final ChatSocketFactory _socketFactory;
  final ChatOutbox _outbox;
  final String _currentUserId;
  final ReconnectPolicy _policy;
  final ChatClock _clock;
  final ChatIdGenerator _idGenerator;
  final ChatTimerFactory _timerFactory;

  ChatSocket? _socket;
  StreamSubscription<Map<String, Object?>>? _eventsSub;
  StreamSubscription<Object>? _errorsSub;

  /// True once `close()` has run — prevents reconnect timers from firing
  /// after disposal.
  bool _disposed = false;

  Timer? _reconnectTimer;

  /// Hydrate the outbox from disk and open the first connection. Idempotent;
  /// calling it again after the first connect is a no-op while the cubit is
  /// already connected or connecting.
  Future<void> start() async {
    if (_disposed) return;
    if (state.status == ConnectionStatus.connecting ||
        state.status == ConnectionStatus.connected) {
      return;
    }
    final hydrated = await _outbox.load();
    emit(state.copyWith(pending: List.unmodifiable(hydrated)));
    await _connect();
  }

  /// Enqueue a new outbound message. If connected, flushes immediately;
  /// otherwise leaves it on disk until the next successful connect.
  Future<String> sendMessage({
    required String conversationId,
    required String body,
  }) async {
    final message = ChatMessage(
      clientId: _idGenerator(),
      conversationId: conversationId,
      senderId: _currentUserId,
      body: body,
      createdAt: _clock().toUtc(),
    );
    await _outbox.enqueue(message);
    emit(state.copyWith(
      pending: List.unmodifiable([...state.pending, message]),
    ));
    if (state.isConnected) await _flushOutbox();
    return message.clientId;
  }

  /// Emit a typing event for the local user. Throttled by the caller (UI).
  void notifyTyping({
    required String conversationId,
    required bool isTyping,
  }) {
    final socket = _socket;
    if (socket == null || !state.isConnected) return;
    try {
      socket.send({
        'type': 'typing',
        'conversationId': conversationId,
        'senderId': _currentUserId,
        'isTyping': isTyping,
      });
    } catch (_) {
      // Typing events are best-effort; a transient send failure must not
      // tear down the cubit. The connection error handler will pick up
      // anything worth surfacing.
    }
  }

  /// Manual retry hook the UI calls when the user taps "Try again" on a
  /// failed message banner.
  Future<void> retry(String clientId) async {
    final hit = state.pending
        .where((m) => m.clientId == clientId)
        .cast<ChatMessage?>()
        .firstWhere((_) => true, orElse: () => null);
    if (hit == null) return;
    final reset = hit.copyWith(
      status: ChatMessageStatus.pending,
      attempts: 0,
    );
    await _outbox.update(reset);
    emit(state.copyWith(pending: _replace(state.pending, reset)));
    if (state.isConnected) await _flushOutbox();
  }

  /// Force a reconnect cycle (UI: pull-to-refresh on the banner).
  Future<void> reconnectNow() async {
    if (_disposed) return;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _teardownSocket();
    emit(state.copyWith(
      status: ConnectionStatus.connecting,
      reconnectAttempt: 0,
      lastError: null,
    ));
    await _connect();
  }

  Future<void> _connect() async {
    if (_disposed) return;
    final isReconnect = state.reconnectAttempt > 0;
    emit(state.copyWith(
      status: isReconnect
          ? ConnectionStatus.reconnecting
          : ConnectionStatus.connecting,
    ));
    final socket = _socketFactory();
    _socket = socket;
    try {
      await socket.connect();
    } catch (error) {
      await _onConnectionFailed(error);
      return;
    }
    if (_disposed) {
      await socket.close();
      return;
    }
    _eventsSub = socket.events.listen(
      _onEvent,
      onError: (Object e, StackTrace _) => _onConnectionFailed(e),
      onDone: () => _onConnectionLost(),
    );
    _errorsSub = socket.errors.listen(
      (e) => emit(state.copyWith(lastError: e.toString())),
    );
    emit(state.copyWith(
      status: ConnectionStatus.connected,
      reconnectAttempt: 0,
      lastError: null,
    ));
    await _flushOutbox();
  }

  void _onEvent(Map<String, Object?> raw) {
    if (_disposed) return;
    final event = ChatEvent.fromJson(raw);
    switch (event) {
      case MessageReceivedEvent(:final message):
        emit(state.copyWith(
          inbox: List.unmodifiable([message, ...state.inbox]),
        ));
      case MessageAckEvent(:final clientId, :final serverId, :final status):
        _handleAck(clientId: clientId, serverId: serverId, status: status);
      case TypingEvent(:final conversationId, :final senderId, :final isTyping):
        _handleTyping(
          conversationId: conversationId,
          senderId: senderId,
          isTyping: isTyping,
        );
      case ServerErrorEvent(:final code, :final message):
        emit(state.copyWith(lastError: '$code: $message'));
      case UnknownEvent():
        // Unknown event types are forward-compat — log nothing, drop nothing
        // else. The gateway can roll new event types without breaking older
        // clients.
        break;
    }
  }

  void _handleAck({
    required String clientId,
    required String? serverId,
    required ChatMessageStatus status,
  }) {
    final idx = state.pending.indexWhere((m) => m.clientId == clientId);
    if (idx == -1) return;
    final updated = state.pending[idx].copyWith(
      serverId: serverId,
      status: status,
    );
    if (status == ChatMessageStatus.sent ||
        status == ChatMessageStatus.delivered ||
        status == ChatMessageStatus.read) {
      // Successful delivery → drop from the outbox; the inbox doesn't track
      // outbound messages, that's the conversation cubit's job.
      _outbox.remove(clientId);
      final next = [...state.pending]..removeAt(idx);
      emit(state.copyWith(pending: List.unmodifiable(next)));
    } else {
      _outbox.update(updated);
      emit(state.copyWith(pending: _replace(state.pending, updated)));
    }
  }

  void _handleTyping({
    required String conversationId,
    required String senderId,
    required bool isTyping,
  }) {
    if (senderId == _currentUserId) return; // ignore echoes of our own typing
    final next = {
      for (final entry in state.typingSenders.entries)
        entry.key: {...entry.value},
    };
    final bucket = next.putIfAbsent(conversationId, () => <String>{});
    if (isTyping) {
      bucket.add(senderId);
    } else {
      bucket.remove(senderId);
      if (bucket.isEmpty) next.remove(conversationId);
    }
    emit(state.copyWith(typingSenders: next));
  }

  Future<void> _flushOutbox() async {
    final socket = _socket;
    if (socket == null || !state.isConnected) return;
    // Only flush messages still in pending state — `failed` entries stay
    // put until the user explicitly retries.
    final toSend = state.pending
        .where((m) => m.status == ChatMessageStatus.pending)
        .toList();
    for (final message in toSend) {
      try {
        socket.send({
          'type': 'message',
          'clientId': message.clientId,
          'conversationId': message.conversationId,
          'senderId': message.senderId,
          'body': message.body,
          'createdAt': message.createdAt.toUtc().toIso8601String(),
        });
        final bumped = message.copyWith(attempts: message.attempts + 1);
        await _outbox.update(bumped);
        emit(state.copyWith(pending: _replace(state.pending, bumped)));
      } catch (_) {
        // Send failed mid-flush — let the connection-lost handler reconnect.
        return;
      }
    }
  }

  Future<void> _onConnectionFailed(Object error) async {
    if (_disposed) return;
    emit(state.copyWith(lastError: error.toString()));
    await _scheduleReconnect();
  }

  Future<void> _onConnectionLost() async {
    if (_disposed) return;
    await _scheduleReconnect();
  }

  Future<void> _scheduleReconnect() async {
    if (_disposed) return;
    await _teardownSocket();
    final nextAttempt = state.reconnectAttempt + 1;
    if (_policy.shouldGiveUp(nextAttempt)) {
      emit(state.copyWith(status: ConnectionStatus.disconnected));
      return;
    }
    emit(state.copyWith(
      status: ConnectionStatus.reconnecting,
      reconnectAttempt: nextAttempt,
    ));
    final delay = _policy.delayFor(nextAttempt);
    _reconnectTimer?.cancel();
    _reconnectTimer = _timerFactory(delay, () {
      if (_disposed) return;
      _connect();
    });
  }

  Future<void> _teardownSocket() async {
    await _eventsSub?.cancel();
    await _errorsSub?.cancel();
    _eventsSub = null;
    _errorsSub = null;
    try {
      await _socket?.close();
    } catch (_) {
      // Closing an already-closed socket is fine.
    }
    _socket = null;
  }

  static List<ChatMessage> _replace(
    List<ChatMessage> source,
    ChatMessage replacement,
  ) {
    final out = [...source];
    final idx = out.indexWhere((m) => m.clientId == replacement.clientId);
    if (idx == -1) {
      out.add(replacement);
    } else {
      out[idx] = replacement;
    }
    return List.unmodifiable(out);
  }

  @override
  Future<void> close() async {
    _disposed = true;
    _reconnectTimer?.cancel();
    _reconnectTimer = null;
    await _teardownSocket();
    return super.close();
  }
}

int _idCounter = 0;
String _defaultIdGenerator() {
  _idCounter++;
  return 'chat-${DateTime.now().microsecondsSinceEpoch}-$_idCounter';
}
