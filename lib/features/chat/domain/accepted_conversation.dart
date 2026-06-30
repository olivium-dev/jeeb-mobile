import 'package:equatable/equatable.dart';

/// A conversation whose offer has been ACCEPTED (an in-progress order),
/// resolved from the authenticated `GET /v1/conversations` list.
///
/// This is the in-app re-entry key for the post-accept order chat (JM-025 /
/// S007-P1B). The list is scoped server-side to the bearer's conversations, so
/// it surfaces the accepted order for BOTH parties: the customer sees the
/// orders they placed; the jeeber sees the orders they won. The screen that
/// renders these maps them onto its own card model and routes to the
/// `chat-detail` route (`/chat/:id`) using [routeId].
class AcceptedConversation extends Equatable {
  const AcceptedConversation({
    required this.conversationId,
    required this.requestId,
    this.title,
    this.displayId,
    this.counterpartName,
    this.winnerJeeberId,
    this.destinationLabel,
  });

  /// The conversation's own id (the gateway message-thread key).
  final String conversationId;

  /// The correlation key (== request id) the conversation is bound to. This is
  /// the PREFERRED `chat-detail` route param because `ChatDetailScreen` resolves
  /// it via `GET /v1/conversations?correlationKey={requestId}` and it also keys
  /// the pinned summary + tracking + active-delivery routes.
  final String requestId;

  /// Human-readable order/request title when the conversation row carries one;
  /// otherwise null (the chat header resolves the real title on open).
  final String? title;

  /// Human order ref (e.g. `ORD-23748`) when present.
  final String? displayId;

  /// The other party's display name when the row carries one.
  final String? counterpartName;

  /// The winning jeeber id, when present. Used as a secondary accepted signal.
  final String? winnerJeeberId;

  /// Drop-off address when the row carries one.
  final String? destinationLabel;

  /// The id to hand the `chat-detail` route: prefer the correlation key
  /// (request id) — `ChatDetailScreen` resolves it against the live gateway —
  /// and fall back to the conversation id.
  String get routeId => requestId.isNotEmpty ? requestId : conversationId;

  @override
  List<Object?> get props => [
        conversationId,
        requestId,
        title,
        displayId,
        counterpartName,
        winnerJeeberId,
        destinationLabel,
      ];
}

/// Read-side contract for the accepted-conversation re-entry list.
///
/// Implementations hit the authenticated `GET /v1/conversations` and return
/// only the rows in the `accepted` phase. Every read is best-effort: any
/// transport/parse failure resolves to an empty list so the host surface
/// degrades to its prior (push-only) behaviour rather than breaking.
abstract class AcceptedConversationsRepository {
  Future<List<AcceptedConversation>> fetchAccepted();
}
