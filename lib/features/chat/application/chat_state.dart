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
  voiceUploadFailed,

  /// P4/P5: the picked/captured image failed to reach the CDN (upload error or
  /// an oversize payload). The bubble is marked failed; NOTHING was posted to
  /// the thread — no phantom success.
  attachmentUploadFailed,
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

  /// Phase the underlying conversation is in. NEW-BUG-01 (Sprint-2 Contract 5c):
  /// defaults to `broadcasting`, NEVER `accepted`. The old `accepted` default
  /// rendered the "Offer accepted!" banner + counterpart header before the cubit
  /// loaded a real phase (and whenever a gateway returned no phase), falsely
  /// signalling a closed auction. `broadcasting` is the safe compose/waiting
  /// shell — the composer stays visible (`isComposerVisible` only hides on
  /// `closed`) while no winner/header/banner renders until `phase == accepted`.
  final ConversationPhase phase;

  /// Offer id currently being accepted via [ChatCubit.acceptOffer]. The
  /// view disables every offer card and renders a spinner on the in-flight
  /// one so the user can't race two accepts.
  final String? acceptingOfferId;

  /// Server-created delivery id surfaced by the offer-accept response (or the
  /// synthetic `PhaseChanged` event). Null until an accept resolves with a
  /// delivery id — and stays null when the gateway does not surface one. The
  /// client "Track order" CTA is shown only when this is non-null, so a
  /// golden-less / legacy accept response degrades safely to no CTA.
  final String? acceptedDeliveryId;

  /// True when live tracking is reachable for this thread — i.e. an accept
  /// surfaced a delivery id. Drives the client "Track order" CTA visibility.
  bool get canTrackDelivery =>
      acceptedDeliveryId != null && acceptedDeliveryId!.isNotEmpty;

  /// Set of offer ids the user has declined client-side. These cards render
  /// greyed-out while the WS push from the server is the authoritative removal.
  final Set<String> declinedOfferIds;

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

  /// Derives the broadcast window expiry from the first offer card's timestamp
  /// + 5 minutes. This is a client-side heuristic — the server is authoritative.
  /// Returns null when there are no offer cards (pre-offer state).
  DateTime? get broadcastExpiresAt {
    if (phase != ConversationPhase.broadcasting) return null;
    final firstOffer = messages.firstWhere(
      (m) => m.kind == MessageKind.offerCard,
      orElse: () => messages.isEmpty ? _never : messages.first,
    );
    if (!firstOffer.isOfferCard) return null;
    // No server timestamp → no derivable window. The offer card still renders;
    // the TTL indicator hides (it already handles null) rather than counting down
    // from an ordering anchor and claiming the broadcast expired in 1970.
    if (!firstOffer.hasServerTimestamp) return null;
    return firstOffer.sentAt.add(const Duration(minutes: 5));
  }

  static final DeliveryChatMessage _never = DeliveryChatMessage.system(
    id: '__never__',
    sentAt: DateTime.fromMillisecondsSinceEpoch(0),
    text: '',
  );

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
    String? acceptedDeliveryId,
    Set<String>? declinedOfferIds,
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
      // Sticky once set: a later phase event without a delivery id must not
      // erase a tracking id we already captured.
      acceptedDeliveryId: acceptedDeliveryId ?? this.acceptedDeliveryId,
      declinedOfferIds: declinedOfferIds ?? this.declinedOfferIds,
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
    acceptedDeliveryId,
    declinedOfferIds,
    error,
  ];
}
