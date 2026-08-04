import 'package:equatable/equatable.dart';

import '../domain/chat_message.dart';
import '../domain/connection_status.dart';

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

  final int reconnectAttempt;

  final List<ChatMessage> pending;

  final List<ChatMessage> inbox;

  final Map<String, Set<String>> typingSenders;

  /// String (not Object) for cheap equality.
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
