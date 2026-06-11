import 'package:equatable/equatable.dart';

/// Tier the sender selected when filing the request. Drives base fare and
/// vehicle eligibility on the Jeeb-gateway side; here it's a display label
/// that decides which chip color the card uses.
enum JeeberRequestTier {
  /// Smallest envelope — bicycles and scooters can accept.
  light,

  /// Standard parcel — scooters and small cars.
  standard,

  /// Bulk delivery — cars and small vans.
  bulk,

  /// Fastest tier (Figma "Flash"). Surfaces in the deliveryman feed cards
  /// (screens 23-26) with the orange tier accent.
  flash,
}

/// Where a request sits in the deliveryman feed lifecycle, as drawn in the
/// Figma `deliveryman-requests` flow (screens 24-26).
///
/// * [incoming] — a fresh request the Jeeber can Ignore / Offer on (screen 24).
/// * [pendingResponse] — the Jeeber has offered and is awaiting the client's
///   reply; the card shows an italic "Pending" status (screen 25).
/// * [accepted] — the client accepted; the card shows a delivery state-machine
///   action button (screen 26).
enum JeeberFeedItemStatus { incoming, pendingResponse, accepted }

/// Delivery state-machine step a Jeeber advances through after a request is
/// accepted. The feed action card (screen 26) renders the button for the NEXT
/// transition; the same labels back chat screens 05/06.
enum JeeberDeliveryAction { orderPicked, headingToDropOff }

/// Single point on the request (pickup or dropoff). The card only needs the
/// human-readable label; coordinates ride along for the eventual route preview
/// on the detail screen.
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

/// One incoming delivery request as the Jeeber sees it on the feed.
///
/// The feed receives this payload from jeeb-gateway either via WebSocket push
/// (the happy path) or via the polling fallback. Each request is uniquely
/// identified by [id]; equality is by id so the cubit can dedupe pushes that
/// repeat a request the Jeeber already has on screen.
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
    this.nextDeliveryAction,
  });

  final String id;
  final RequestLocation pickup;
  final RequestLocation dropoff;
  final JeeberRequestTier tier;

  /// Distance the Jeeber will cover end-to-end, in kilometres. The card
  /// formats this with one decimal place — the cubit emits the raw value.
  final double estimatedDistanceKm;

  /// What the Jeeber stands to pocket if they accept and complete this
  /// request. Computed gateway-side from the tier's per-km rate and the
  /// distance; the mobile app just renders it.
  final double potentialEarnings;

  /// ISO 4217 currency code (e.g. `USD`, `LBP`). Display formatting concern.
  final String currency;

  /// Server-supplied deadline after which the request auto-dismisses from
  /// the feed even if the user never tapped accept/decline. The cubit also
  /// enforces a configurable per-client timeout (default 60s) and uses
  /// whichever fires first.
  final DateTime expiresAt;

  /// Optional sender display name. Surfaces in screen readers and on the
  /// card subtitle when present; the gateway may omit it for privacy.
  final String? senderName;

  /// Sender avatar URL (cdn-service) shown on the deliveryman feed card
  /// (Figma screens 24-26). `null` falls back to an initial avatar.
  final String? senderAvatarUrl;

  /// Sender's average star rating, 0..5. `null` hides the rating cluster.
  final double? senderRating;

  /// Human-readable items summary the client filed (e.g. "1 kilo potato,
  /// water gallon, coffee blend"). User-generated content — rendered
  /// direction-safe, never l10n-keyed.
  final String? itemsSummary;

  /// Straight-line distance from the Jeeber to the pickup, in kilometres.
  /// Drives the "{distance} away from you" line on the feed card. `null`
  /// hides the distance line.
  final double? distanceFromYouKm;

  /// When the request landed in the feed. Rendered as a locale-formatted
  /// time stamp on the card (Figma "09:41"). `null` hides the timestamp.
  final DateTime? receivedAt;

  /// Lifecycle bucket driving which action affordance the card shows
  /// (Ignore/Offer · Pending · delivery-action button).
  final JeeberFeedItemStatus feedStatus;

  /// The next delivery transition the Jeeber can trigger once a request is
  /// [JeeberFeedItemStatus.accepted] (Figma screen 26). `null` for the
  /// incoming/pending buckets.
  final JeeberDeliveryAction? nextDeliveryAction;

  @override
  List<Object?> get props => [id];
}
