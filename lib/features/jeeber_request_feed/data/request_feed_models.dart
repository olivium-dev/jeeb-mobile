import 'package:equatable/equatable.dart';

enum JeeberRequestTier {

  light,

  standard,

  bulk,

  flash,
}

enum JeeberFeedItemStatus { incoming, pendingResponse, accepted }

enum JeeberDeliveryAction { orderPicked, headingToDropOff }

class RequestLocation extends Equatable {
  const RequestLocation({
    required this.label,
    required this.latitude,
    required this.longitude,
  });

  final String label;
  final double latitude;
  final double longitude;

  @override
  List<Object?> get props => [label, latitude, longitude];
}

class DeliveryRequest extends Equatable {
  const DeliveryRequest({
    required this.id,
    required this.pickup,
    required this.dropoff,
    required this.tier,
    required this.estimatedDistanceKm,
    required this.potentialEarnings,
    required this.currency,
    required this.expiresAt,
    this.senderName,
    this.senderAvatarUrl,
    this.senderRating,
    this.itemsSummary,
    this.distanceFromYouKm,
    this.receivedAt,
    this.feedStatus = JeeberFeedItemStatus.incoming,
    this.requestIsOpen = true,
    this.nextDeliveryAction,
  });

  final String id;
  final RequestLocation pickup;
  final RequestLocation dropoff;

  final JeeberRequestTier? tier;

  final double estimatedDistanceKm;

  final double potentialEarnings;

  final String currency;

  final DateTime? expiresAt;

  final String? senderName;

  final String? senderAvatarUrl;

  final double? senderRating;

  final String? itemsSummary;

  final double? distanceFromYouKm;

  final DateTime? receivedAt;

  final JeeberFeedItemStatus feedStatus;

  final bool requestIsOpen;

  final JeeberDeliveryAction? nextDeliveryAction;

  @override
  List<Object?> get props => [id];
}
