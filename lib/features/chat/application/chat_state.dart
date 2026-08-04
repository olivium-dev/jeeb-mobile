import 'package:equatable/equatable.dart';

import '../domain/delivery_chat_message.dart';

enum ChatError {
  pickCancelled,
  permissionDenied,
  pickUnavailable,
  sendFailed,
  voiceUploadFailed,

  attachmentUploadFailed,

  historyLoadFailed,
}

class ChatState extends Equatable {
  const ChatState({
    this.messages = const <DeliveryChatMessage>[],
    this.composerText = '',
    this.isLoadingHistory = false,
    this.isAttaching = false,
    this.phase = ConversationPhase.broadcasting,
    this.acceptingOfferId,
    this.acceptedDeliveryId,
    this.declinedOfferIds = const <String>{},
    this.error,
    this.historyLoadFailed = false,
  });

  final List<DeliveryChatMessage> messages;

  final String composerText;

  final bool isLoadingHistory;

  final bool isAttaching;

  final ConversationPhase phase;

  final String? acceptingOfferId;

  final String? acceptedDeliveryId;

  bool get canTrackDelivery =>
      acceptedDeliveryId != null && acceptedDeliveryId!.isNotEmpty;

  final Set<String> declinedOfferIds;

  final ChatError? error;

  final bool historyLoadFailed;

  bool get canSendText => composerText.trim().isNotEmpty;

  bool get isComposerVisible => phase != ConversationPhase.closed;

  bool get showsCounterpartHeader => phase == ConversationPhase.accepted;

  DateTime? get broadcastExpiresAt {
    if (phase != ConversationPhase.broadcasting) return null;
    final firstOffer = messages.firstWhere(
      (m) => m.kind == MessageKind.offerCard,
      orElse: () => messages.isEmpty ? _never : messages.first,
    );
    if (!firstOffer.isOfferCard) return null;
    if (!firstOffer.hasServerTimestamp) return null;
    return firstOffer.sentAt.add(const Duration(minutes: 5));
  }

  static final DeliveryChatMessage _never = DeliveryChatMessage.system(
    id: '__never__',
    sentAt: DateTime.fromMillisecondsSinceEpoch(0),
    text: '',
    hasServerTimestamp: false,
  );

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
    String? acceptedDeliveryId,
    Set<String>? declinedOfferIds,
    ChatError? error,
    bool clearError = false,
    bool? historyLoadFailed,
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
      acceptedDeliveryId: acceptedDeliveryId ?? this.acceptedDeliveryId,
      declinedOfferIds: declinedOfferIds ?? this.declinedOfferIds,
      error: clearError ? null : (error ?? this.error),
      historyLoadFailed: historyLoadFailed ?? this.historyLoadFailed,
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
    acceptedDeliveryId,
    declinedOfferIds,
    error,
    historyLoadFailed,
  ];
}
