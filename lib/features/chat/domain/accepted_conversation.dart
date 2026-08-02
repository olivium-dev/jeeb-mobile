import 'package:equatable/equatable.dart';

/// Conversation whose offer was ACCEPTED (in-progress order).
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

  final String conversationId;

  /// Preferred by ChatDetailScreen (routes via `GET /v1/conversations?correlationKey={requestId}`).
  final String requestId;

  final String? title;

  final String? displayId;

  final String? counterpartName;

  final String? winnerJeeberId;

  final String? destinationLabel;

  /// Chat-detail route id: prefer requestId (ChatDetailScreen resolves live).
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

/// Read-side contract for accepted-conversation list.
abstract class AcceptedConversationsRepository {
  Future<List<AcceptedConversation>> fetchAccepted();
}
