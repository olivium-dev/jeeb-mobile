import 'package:equatable/equatable.dart';

import 'jeeber_vehicle.dart';

/// A single bid from a Jeeber on a client's open delivery request.
///
/// The fields surface in the offer card: name + avatar, price, ETA, vehicle,
/// rating. The gateway emits this shape from
/// `GET /api/requests/{id}/offers`; we mirror it on the wire as JSON and parse
/// it through [Offer.fromJson] in the data layer.
class Offer extends Equatable {
  const Offer({
    required this.id,
    required this.jeeberId,
    required this.jeeberName,
    required this.fee,
    required this.currency,
    required this.etaMinutes,
    required this.vehicle,
    required this.rating,
    required this.ratingCount,
    required this.submittedAt,
    this.avatarUrl,
    this.note,
  });

  /// Server-issued offer id. Used in `POST /requests/{requestId}/offers/{id}/accept`.
  final String id;
  final String jeeberId;
  final String jeeberName;

  /// Quoted fee in whole/decimal currency units (e.g. 35.50). Already a number;
  /// formatting to 2dp happens at the card boundary.
  final double fee;
  final String currency;
  final int etaMinutes;
  final JeeberVehicle vehicle;

  /// Jeeber's lifetime average rating (0–5, half-stars allowed).
  final double rating;

  /// Total ratings the average is computed from. Surfaced as the secondary
  /// number on the star display — keeps "4.9 (3)" honest vs "4.9 (1,200)".
  final int ratingCount;

  /// When the gateway accepted the bid. Drives "newest first" tie-breaks in
  /// the sort order so two equal-price offers don't churn in the list.
  final DateTime submittedAt;

  final String? avatarUrl;

  /// Optional free-text note the Jeeber attached to the bid (the offer-service
  /// `note` field, e.g. "On my way, can pick up now."). Surfaced as a secondary
  /// line on the offer card when present; null when the gateway omits it.
  final String? note;

  @override
  List<Object?> get props => [
        id,
        jeeberId,
        jeeberName,
        fee,
        currency,
        etaMinutes,
        vehicle,
        rating,
        ratingCount,
        submittedAt,
        avatarUrl,
        note,
      ];
}
