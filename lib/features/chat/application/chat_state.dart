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
    this.phase = ConversationPhase.accepted,
    this.acceptingOfferId,
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

  /// Phase the underlying conversation is in. Defaults to `accepted` so
  /// legacy 1:1 photo-chat call sites (which don't know about phases) keep
  /// the composer visible without any code change.
  final ConversationPhase phase;

  /// Offer id currently being accepted via [ChatCubit.acceptOffer]. The
  /// view disables every offer card and renders a spinner on the in-flight
  /// one so the user can't race two accepts.
  final String? acceptingOfferId;

  final ChatError? error;

  bool get canSendText => composerText.trim().isNotEmpty;

  /// Composer visibility. The Figma "Chat [Client]" frame (node 56535:6659)
  /// shows the composer present *during* broadcasting (the client can still
  /// message while offers come in), so it stays visible in every phase except
  /// `closed`, where the conversation is read-only.
  bool get isComposerVisible => phase != ConversationPhase.closed;

  /// The post-approval header (Figma node 56546:2382) shows the winning
  /// counterpart's avatar + name. During broadcasting (node 56535:6659) the
  /// header is the order id only, so the avatar slot is suppressed.
  bool get showsCounterpartHeader => phase == ConversationPhase.accepted;

  /// Offer cards currently sitting in the message list. Used by the
  /// broadcasting screen to render the stacked offer panel.
  List<DeliveryChatMessage> get offerCards =>
      messages.where((m) => m.isOfferCard).toList(growable: false);

  DeliveryChatMessage? get latestMessage => messages.isEmpty ? null : messages.last;

  ChatState copyWith({
    List<DeliveryChatMessage>? messages,
    String? composerText,
    bool? isLoadingHistory,
    bool? isAttaching,
    ConversationPhase? phase,
    String? acceptingOfferId,
    bool clearAcceptingOfferId = false,
    ChatError? error,
    bool clearError = false,
  }) {
    return ChatState(
      messages: messages ?? this.messages,
      composerText: composerText ?? this.composerText,
      isLoadingHistory: isLoadingHistory ?? this.isLoadingHistory,
      isAttaching: isAttaching ?? this.isAttaching,
      phase: phase ?? this.phase,
      acceptingOfferId: clearAcceptingOfferId
          ? null
          : (acceptingOfferId ?? this.acceptingOfferId),
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  List<Object?> get props => [
    messages,
    composerText,
    isLoadingHistory,
    isAttaching,
    phase,
    acceptingOfferId,
    error,
  ];
}
