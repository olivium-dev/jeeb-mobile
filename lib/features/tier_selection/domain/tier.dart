import 'package:equatable/equatable.dart';

/// Stable tier identifiers exposed by `GET /api/tiers` in jeeb-gateway.
///
/// Order is the recommended display order on the request-type screen
/// (Figma 56535:2392): Flash → Express → Standard → On-the-way → Eco, with
/// the back-office flagging one tier `recommended` for the default selection.
enum TierId { flash, express, standard, onTheWay, eco }

/// Vehicle category icon a tier card renders alongside its label. The set is
/// intentionally smaller than [VehicleType] in the KYC flow — tier vehicle
/// constraints map to "what kind of Jeeber will pick this up" not to a single
/// vehicle, so we group them by category.
enum TierVehicleClass { bikeOrScooter, scooterOrCar, carOrVan, any }

/// A delivery tier returned by jeeb-gateway. Pricing is given as a min/max
/// range in the user's currency — the back-office computes the actual fee at
/// matching time using base fare + per-km + surge. The range is the indicative
/// quote the user sees before submitting.
class Tier extends Equatable {
  const Tier({
    required this.id,
    required this.priceLow,
    required this.priceHigh,
    required this.currency,
    required this.vehicleClass,
    this.slaMinutes,
    this.recommended = false,
  });

  final TierId id;
  final int priceLow;
  final int priceHigh;
  final String currency;
  final TierVehicleClass vehicleClass;

  /// Upper-bound SLA in minutes. `null` indicates an opportunistic tier
  /// (On-the-way) where there is no SLA — the Jeeber matches when their route
  /// already covers the trip.
  final int? slaMinutes;

  final bool recommended;

  @override
  List<Object?> get props => [
        id,
        priceLow,
        priceHigh,
        currency,
        vehicleClass,
        slaMinutes,
        recommended,
      ];
}
