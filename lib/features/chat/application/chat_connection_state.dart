import 'package:equatable/equatable.dart';

import '../domain/chat_message.dart';
import '../domain/connection_status.dart';

/// Snapshot of the chat connection visible to the UI.
///
/// One source of truth for: the banner indicator ([status]), the outbox
/// badge count ([pendingCount]), inline typing chips ([typingSenders]), and
/// recently-received messages ([inbox]).
class ChatConnectionState extends Equatable {
  const ChatConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.reconnectAttempt = 0,
    this.pending = const [],
    this.inbox = const [],
    this.typingSenders = const {},
    this.lastError,
  });

  final ConnectionStatus status;

  /// 0 while never-attempted-or-currently-connected. The cubit increments
  /// this each time the backoff fires; tests assert on it to verify the
  /// reconnect schedule.
  final int reconnectAttempt;

  /// Outbox snapshot — messages either queued offline or in flight without
  /// an ack yet. Ordered oldest-first.
  final List<ChatMessage> pending;

  /// Newest-first list of inbound messages received during this session.
  /// History pagination is owned by a separate, screen-scoped cubit; this
  /// stream is just the live-tail.
  final List<ChatMessage> inbox;

  /// Per-conversation set of remote senders currently typing. Cubit clears
  /// each entry on the next typing=false event or after a timeout.
  final Map<String, Set<String>> typingSenders;

  /// Last transport/decoding error surfaced to the cubit. Cleared on
  /// successful reconnect. Kept as a string (not `Object`) to keep state
  /// equality cheap.
  final String? lastError;

  int get pendingCount => pending.length;

  bool get isConnected => status == ConnectionStatus.connected;
  bool get isOffline =>
      status == ConnectionStatus.disconnected ||
      status == ConnectionStatus.reconnecting;

  ChatConnectionState copyWith({
    ConnectionStatus? status,
    int? reconnectAttempt,
    List<ChatMessage>? pending,
    List<ChatMessage>? inbox,
    Map<String, Set<String>>? typingSenders,
    Object? lastError = _sentinel,
  }) {
    return ChatConnectionState(
      status: status ?? this.status,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      pending: pending ?? this.pending,
      inbox: inbox ?? this.inbox,
      typingSenders: typingSenders ?? this.typingSenders,
      lastError:
          identical(lastError, _sentinel) ? this.lastError : lastError as String?,
    );
  }

  @override
  List<Object?> get props =>
      [status, reconnectAttempt, pending, inbox, typingSenders, lastError];
}

const Object _sentinel = Object();
