import 'package:equatable/equatable.dart';

import '../domain/delivery_chat_message.dart';

/// Transient error surfaces the cubit can publish. One-shot — the view
/// renders the corresponding copy and calls
/// [ChatCubit.acknowledgeError] so the same error isn't replayed on the
/// next rebuild.
enum ChatError {
  /// User dismissed the camera/gallery — no snackbar needed.
  pickCancelled,
  permissionDenied,
  pickUnavailable,
  sendFailed,
}

class ChatState extends Equatable {
  const ChatState({
    this.messages = const <DeliveryChatMessage>[],
    this.composerText = '',
    this.isLoadingHistory = false,
    this.isAttaching = false,
    this.error,
  });

  /// Oldest message first. The list view renders this with `reverse: true`
  /// flipped off, then auto-scrolls the controller down on every change.
  final List<DeliveryChatMessage> messages;

  /// Live text in the composer. The view binds its controller to this value
  /// so a programmatic clear (post-send) propagates back to the field.
  final String composerText;

  /// True while [ChatCubit.load] is in flight on cold start.
  final bool isLoadingHistory;

  /// True while a photo pick is in flight. The composer disables its attach
  /// button so a second tap can't race with the first.
  final bool isAttaching;

  final ChatError? error;

  bool get canSendText => composerText.trim().isNotEmpty;

  DeliveryChatMessage? get latestMessage => messages.isEmpty ? null : messages.last;

  ChatState copyWith({
    List<DeliveryChatMessage>? messages,
    String? composerText,
    bool? isLoadingHistory,
    bool? isAttaching,
    ChatError? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      composerText: composerText ?? this.composerText,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isAttaching: isAttaching ?? this.isAttaching,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    messages,
    composerText,
    isLoadingHistory,
    isAttaching,
    error,
  ];
}
