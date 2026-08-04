import 'package:equatable/equatable.dart';

/// The arrival banner's payload on the client handoff surface (redesign-2026-08
/// screen 13, `tpl 799-804`).
///
/// Every field is already carried by `GET /v1/deliveries/{id}` and parsed by
/// `DeliveryTrackingInfo` — this class exists only so the presentation layer
/// does not depend on the whole tracking aggregate for four values.
///
/// Deliberately absent (privacy, C-13.4): rating, phone, avatar URL. The
/// tracking parser never populates the first two, and a terminal screen opens
/// no CDN fetch for the third — the banner draws a plain initial disc.
class HandoverArrival extends Equatable {
  const HandoverArrival({
    required this.name,
    required this.vehicleLabel,
    required this.atDoor,
    this.cashAmount,
    this.currency,
  });

  /// `JeeberSummary.displayName` — already display-ready, never re-cased.
  final String name;

  /// Server copy (`Scooter`, `Car`…). Rendered verbatim: translating a label
  /// the gateway authored would silently invent product vocabulary.
  final String vehicleLabel;

  /// True once tracking reports `TrackingStage.atDoor`; picks the headline
  /// between "at your door" and "on the way".
  final bool atDoor;

  /// Cash due at handover (`DeliveryTrackingInfo.price`). Null drops the whole
  /// money clause — the banner never guesses an amount.
  final double? cashAmount;

  /// ISO code for [cashAmount]; null is treated as USD by `MoneyFormat`.
  final String? currency;

  @override
  List<Object?> get props => <Object?>[
        name,
        vehicleLabel,
        atDoor,
        cashAmount,
        currency,
      ];
}
