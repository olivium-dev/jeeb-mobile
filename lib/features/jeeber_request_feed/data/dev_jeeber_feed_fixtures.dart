import 'request_feed_models.dart';

/// Deterministic deliveryman-feed fixtures mirroring the Figma mock data for
/// screens 24-26 (file ZOi3kKtw7sd42ssSVX3Kn4). Debug capture aid only — used
/// by the `jeeb.feed` dev seam so a single APK renders each feed variant
/// without a rebuild. Never referenced from release code.
abstract final class DevJeeberFeedFixtures {
  /// The Figma client name + items summary, repeated so every variant shows
  /// identical placeholder content to the design.
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

  /// Displayed "received" time, pinned to the Figma "09:41" for capture.
  static DateTime get _receivedAt => DateTime(2026, 6, 11, 9, 41);

  /// Far-future expiry so the cubit's expiry sweep keeps fixture cards on
  /// screen for the whole capture session (the displayed time stays "09:41").
  static DateTime get _expiresAt =>
      DateTime.now().add(const Duration(days: 365));

  /// One incoming request → screen 24 (Ignore / Offer card).
  static List<DeliveryRequest> incoming() => [
        _base('dev-feed-incoming', JeeberFeedItemStatus.incoming),
      ];

  /// One offered request awaiting a client reply → screen 25 (Pending).
  static List<DeliveryRequest> pending() => [
        _base('dev-feed-pending', JeeberFeedItemStatus.pendingResponse),
      ];

  /// Two accepted requests with delivery actions → screen 26
  /// (Order picked / Heading to drop off).
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
