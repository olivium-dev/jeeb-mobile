import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../core/network/app_failure.dart';
import '../../../core/state/guarded.dart';
import '../domain/chat_conversation_summary.dart';
import 'chat_conversations_state.dart';

/// Drives the chat inbox. A failed read raises the FAILURE rung — it never
/// reaches the user as "no conversations yet".
class ChatConversationsCubit extends Cubit<ChatConversationsState> {
  ChatConversationsCubit(
    this._repository, {
    Stream<void>? reachableSignals,
    Stream<void>? resumeSignals,
  }) : super(const ChatConversationsState()) {
    _reachableSub = reachableSignals?.listen((_) => refresh());
    _resumeSub = resumeSignals?.listen((_) => refresh());
  }

  /// Null means DI could not resolve one — a failure, not an empty inbox.
  final ChatConversationsRepository? _repository;

  StreamSubscription<void>? _reachableSub;
  StreamSubscription<void>? _resumeSub;

  bool _loadInFlight = false;
  bool _refreshInFlight = false;

  /// Cold read. Flips to loading; a failure owns the body.
  Future<void> load() async {
    if (_loadInFlight || isClosed) return;
    _loadInFlight = true;
    emit(state.copyWith(
      status: ChatConversationsStatus.loading,
      clearError: true,
      clearRefreshError: true,
    ));
    await guarded(
      () async {
        final ChatConversationsPage page = await _read();
        if (isClosed) return;
        emit(state.copyWith(
          status: ChatConversationsStatus.loaded,
          conversations: page.conversations,
          skippedRows: page.skippedRows,
          clearError: true,
        ));
      },
      (AppFailure failure) {
        if (isClosed) return;
        emit(state.copyWith(
          status: ChatConversationsStatus.failed,
          error: failure,
        ));
      },
    );
    _loadInFlight = false;
  }

  /// Warm read. NEVER flips to loading and never throws rows away.
  Future<void> refresh() async {
    if (_refreshInFlight || isClosed) return;
    // A bus edge during the cold read must not race it: the loser's emit lands
    // last and can flip a successful load to `failed`.
    if (_loadInFlight || state.status == ChatConversationsStatus.initial) return;
    _refreshInFlight = true;
    await guarded(
      () async {
        final ChatConversationsPage page = await _read();
        if (isClosed) return;
        emit(state.copyWith(
          status: ChatConversationsStatus.loaded,
          conversations: page.conversations,
          skippedRows: page.skippedRows,
          clearError: true,
          clearRefreshError: true,
        ));
      },
      (AppFailure failure) {
        if (isClosed) return;
        // A refresh over an empty-and-failed body is still the cold failure.
        emit(state.status == ChatConversationsStatus.loaded
            ? state.copyWith(refreshError: failure)
            : state.copyWith(
                status: ChatConversationsStatus.failed,
                error: failure,
              ));
      },
    );
    _refreshInFlight = false;
  }

  void clearRefreshError() {
    if (state.refreshError == null) return;
    emit(state.copyWith(clearRefreshError: true));
  }

  Future<ChatConversationsPage> _read() async {
    final ChatConversationsRepository? repository = _repository;
    if (repository == null) {
      throw UnknownFailure(
        cause: StateError('chat conversations repository unavailable'),
      );
    }
    return repository.fetchConversations();
  }

  @override
  Future<void> close() async {
    await _reachableSub?.cancel();
    await _resumeSub?.cancel();
    return super.close();
  }
}
