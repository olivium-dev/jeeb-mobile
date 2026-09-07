import 'package:equatable/equatable.dart';

import '../../../core/network/app_failure.dart';

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

/// F12 — thrown when the accepted read failed, so an empty list can no longer
/// mean both "none" and "the gateway is down". A throw keeps R3's signature.
class AcceptedConversationsException implements Exception {
  const AcceptedConversationsException(this.failure);

  final AppFailure failure;

  @override
  String toString() => 'AcceptedConversationsException($failure)';
}

/// Read contract. Implementations throw [AcceptedConversationsException] on a
/// failure; an empty list means the gateway answered with no rows.
abstract class AcceptedConversationsRepository {
  Future<List<AcceptedConversation>> fetchAccepted();
}
