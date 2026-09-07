import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';
import '../domain/chat_conversation_summary.dart';

enum ChatConversationsStatus { initial, loading, loaded, failed }

class ChatConversationsState extends Equatable {
  const ChatConversationsState({
    this.status = ChatConversationsStatus.initial,
    this.conversations = const <ChatConversationSummary>[],
    this.skippedRows = 0,
    this.error,
    this.refreshError,
  });

  final ChatConversationsStatus status;

  final List<ChatConversationSummary> conversations;

  /// Rows the gateway sent that carry neither id — a partial load, not a
  /// silent drop.
  final int skippedRows;

  /// The COLD failure: nothing is on screen because of it.
  final AppFailure? error;

  /// The WARM failure: rows are on screen and stay there.
  final AppFailure? refreshError;

  ChatConversationsState copyWith({
    ChatConversationsStatus? status,
    List<ChatConversationSummary>? conversations,
    int? skippedRows,
    AppFailure? error,
    bool clearError = false,
    AppFailure? refreshError,
    bool clearRefreshError = false,
  }) {
    return ChatConversationsState(
      status: status ?? this.status,
      conversations: conversations ?? this.conversations,
      skippedRows: skippedRows ?? this.skippedRows,
      error: clearError ? null : (error ?? this.error),
      refreshError:
          clearRefreshError ? null : (refreshError ?? this.refreshError),
    );
  }

  @override
  List<Object?> get props => <Object?>[
        status,
        conversations,
        skippedRows,
        error,
        refreshError,
      ];
}
