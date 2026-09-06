import 'package:equatable/equatable.dart';

import '../domain/chat_message.dart';
import '../domain/connection_status.dart';

/// What went wrong on the socket, as a CLASSIFIED fact. Replaces the
/// `e.toString()` prose the view state used to hold (EP-24).
enum ChatConnectionFailure { connectFailed, socketError, serverRejected, sendFailed }

class ChatConnectionState extends Equatable {
  const ChatConnectionState({
    this.status = ConnectionStatus.disconnected,
    this.reconnectAttempt = 0,
    this.pending = const [],
    this.inbox = const [],
    this.typingSenders = const {},
    this.lastFailure,
  });

  final ConnectionStatus status;

  final int reconnectAttempt;

  final List<ChatMessage> pending;

  final List<ChatMessage> inbox;

  final Map<String, Set<String>> typingSenders;

  /// The classified last failure. Never an exception's text.
  final ChatConnectionFailure? lastFailure;

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
    Object? lastFailure = _sentinel,
  }) {
    return ChatConnectionState(
      status: status ?? this.status,
      reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
      pending: pending ?? this.pending,
      inbox: inbox ?? this.inbox,
      typingSenders: typingSenders ?? this.typingSenders,
      lastFailure: identical(lastFailure, _sentinel)
          ? this.lastFailure
          : lastFailure as ChatConnectionFailure?,
    );
  }

  @override
  List<Object?> get props =>
      [status, reconnectAttempt, pending, inbox, typingSenders, lastFailure];
}

const Object _sentinel = Object();
