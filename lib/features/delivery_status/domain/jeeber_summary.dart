import 'package:equatable/equatable.dart';

/// Public-facing slice of the matched Jeeber that the sender is allowed to
/// see while a delivery is in flight.
///
/// Ratings, plate number, and full name are not exposed until completion
/// (blind-reveal rule lives in jeeb-gateway `src/JeebGateway/Ratings/`); the
/// status screen only needs enough to populate the contact card and a brief
/// preview ("Karim · Scooter").
class JeeberSummary extends Equatable {
  const JeeberSummary({
    required this.displayName,
    required this.vehicleLabel,
    this.phoneE164,
    this.avatarUrl,
    this.rating,
  });

  /// The short first-name-plus-initial the gateway returns for in-flight
  /// privacy. Already display-ready — no further formatting.
  final String displayName;

  /// Human-readable vehicle label — "Scooter", "Car", "Pickup".
  final String vehicleLabel;

  /// E.164 dialable number. Null while the gateway has not yet exposed the
  /// in-app calling channel.
  final String? phoneE164;

  /// Optional avatar URL (signed via cdn-service). Falls back to initials.
  final String? avatarUrl;

  /// Display rating (1.0 – 5.0) — gateway returns this rounded to one
  /// decimal place. Null hides the rating chip.
  final double? rating;

  @override
  List<Object?> get props => [
        displayName,
        vehicleLabel,
        phoneE164,
        avatarUrl,
        rating,
      ];
}
