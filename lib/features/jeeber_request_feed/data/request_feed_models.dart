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
}

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

  @override
  List<Object?> get props => [id];
}
