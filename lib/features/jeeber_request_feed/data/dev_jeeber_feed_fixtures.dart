import 'request_feed_models.dart';

abstract final class DevJeeberFeedFixtures {

  static const _name = 'Sami Fawaz';
  static const _summary = '1 kilo potato, water gallon, coffee blend';

  static RequestLocation get _pickup => const RequestLocation(
        label: 'Hamra, Beirut',
        latitude: 33.8959,
        longitude: 35.4797,
      );

  static RequestLocation get _dropoff => const RequestLocation(
        label: 'Achrafieh, Beirut',
        latitude: 33.8869,
        longitude: 35.5131,
      );

  static DateTime get _receivedAt => DateTime(2026, 6, 11, 9, 41);

  static DateTime get _expiresAt =>
      DateTime.now().add(const Duration(days: 365));

  static List<DeliveryRequest> incoming() => [
        _base('dev-feed-incoming', JeeberFeedItemStatus.incoming),
      ];

  static List<DeliveryRequest> pending() => [
        _base('dev-feed-pending', JeeberFeedItemStatus.pendingResponse),
      ];

  static List<DeliveryRequest> replies() => [
        _base(
          'dev-feed-accepted-1',
          JeeberFeedItemStatus.accepted,
          action: JeeberDeliveryAction.orderPicked,
        ),
        _base(
          'dev-feed-accepted-2',
          JeeberFeedItemStatus.accepted,
          action: JeeberDeliveryAction.headingToDropOff,
        ),
      ];

  static DeliveryRequest _base(
    String id,
    JeeberFeedItemStatus status, {
    JeeberDeliveryAction? action,
  }) {
    return DeliveryRequest(
      id: id,
      pickup: _pickup,
      dropoff: _dropoff,
      tier: JeeberRequestTier.flash,
      estimatedDistanceKm: 3,
      potentialEarnings: 4.5,
      currency: 'USD',
      expiresAt: _expiresAt,
      senderName: _name,
      senderRating: 4,
      itemsSummary: _summary,
      distanceFromYouKm: 3,
      receivedAt: _receivedAt,
      feedStatus: status,
      nextDeliveryAction: action,
    );
  }
}
